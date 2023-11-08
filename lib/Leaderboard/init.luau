--[[
	Arxk was here
]]
local Players = game:GetService("Players");

-- Requirements
local Board = require(script.Board);
local Promise = require(script.Promise);
local Signal = require(script.Signal);

-- Constants
local MEMORY_STORE_SERVICE_MAX_EXPIRY = 3888000; -- 45 days
local BOARD_TYPES = {"Hourly", "Daily", "Weekly", "Monthly", "Yearly", "AllTime", "Rolling"};

-- Supports Daily, Weekly, Monthly and AllTime currently
export type Leaderboard = typeof(setmetatable({} :: LeaderboardArguments, {} :: Object));
export type LeaderboardType = "Hourly" | "Daily" | "Weekly" | "Monthly" | "Yearly" | "AllTime" | "Rolling";
export type LeaderboardArguments = {
	Updated: Signal.Signal<{AllTopData}>,
	BoardUpdated: Signal.Signal<{Type: LeaderboardType, Data: {TopData}}>,
	__serviceKey: string,
	__types: {LeaderboardType},
	__boards: {LeaderboardType: Board},
	__valueQueue: ValueQueueType,
	__threads: {thread},
	__connections: {RBXScriptConnection},
}
export type TopData = {
	Rank: number,
	UserId: number,
	Value: number,
	Username: string,
	DisplayName: string,
}

type ValueQueueType = {
	[number]: {
		[LeaderboardType]: {
			Amount: number,
			Board: Board,
		},
	},
}
type AllTopData = {
	Type: LeaderboardType,
	Data: {TopData},
}
type Object = {
	__index: Object,
	IncrementValues: (self: Leaderboard, boardTypes: {LeaderboardType} | string, userId: number, amount: number) -> (),
	UpdateValues: (self: Leaderboard, boardTypes: {LeaderboardType} | string, userId: number, value: number | (number) -> (number)) -> (),
	UpdateStoreValues: (self: Leaderboard, boardTypes: {LeaderboardType} | string, userId: number, value: number | (number) -> (number)) -> (),
	RetrieveEntries: (self: Leaderboard, boardTypes: {LeaderboardType} | string, optionalRange: {[string]: number} | number, sortDirection: string) -> Promise.TypedPromise<{AllTopData}>,
	UpdateBoardWithValues: (self: Leaderboard) -> (),
	Destroy: (self: Leaderboard) -> (),
	new: (serviceKey: string, leaderboardTypes: {LeaderboardType}, automationSettings: AutomationSettings?, rollingExpiry: number?) -> Leaderboard,
}
type Board = Board.Board;
type AutomationSettings = {
	Automation: boolean,
	Interval: number,
	RecordCount: number | {[string]: number},
}

-- Start
local Leaderboards = {} :: {[string]: Leaderboard};
local Leaderboard: Object = {} :: Object;
Leaderboard.__index = Leaderboard;

local function SmartAssert(condition: boolean, message: string)
	if (not condition) then
		error(message, 2);
	end;
end

local function IsValidLeaderboardType(leaderboardType: LeaderboardType): boolean
	return table.find(BOARD_TYPES, leaderboardType) ~= nil;
end

function Leaderboard.new(serviceKey: string, leaderboardTypes: {LeaderboardType}, automationSettings: AutomationSettings?, rollingExpiry: number?)
	if (table.find(leaderboardTypes, "Rolling") and rollingExpiry ~= nil) then
		SmartAssert(rollingExpiry >= 60 and rollingExpiry <= MEMORY_STORE_SERVICE_MAX_EXPIRY, `Rolling expiry must be within 60 and {MEMORY_STORE_SERVICE_MAX_EXPIRY} seconds`);
		SmartAssert(type(rollingExpiry) == "number", "Rolling expiry must be a number");
	end;

	-- Check if the leaderboard types are valid
	SmartAssert(#leaderboardTypes > 0, "Leaderboard types must be greater than 0");
	for _, v in leaderboardTypes do
		SmartAssert(IsValidLeaderboardType(v), `Leaderboard type {v} is not valid`);
	end;

	-- Asserts for settings
	if (automationSettings) then
		SmartAssert(type(automationSettings) == "table", "Settings must be a table");
		SmartAssert(type(automationSettings.Automation) == "nil" or type(automationSettings.Automation) == "boolean", "Automation must be a boolean");
		SmartAssert(type(automationSettings.Interval) == "nil" or type(automationSettings.Interval) == "number", "Interval must be a number");
		SmartAssert(type(automationSettings.RecordCount) == "nil" or type(automationSettings.RecordCount) == "number" or type(automationSettings.RecordCount) == "table", "RecordCount must be a number or a table");
	end;

	local self = setmetatable({} :: LeaderboardArguments, Leaderboard);

	-- Public properties
	self.Updated = Signal.new();
	self.BoardUpdated = Signal.new();

	-- Private properties
	self.__serviceKey = serviceKey;
	self.__types = leaderboardTypes;
	self.__boards = {};
	self.__valueQueue = {};
	self.__threads = {};
	self.__connections = {};

	-- Add to leaderboards
	Leaderboards[serviceKey] = self;

	-- Initialize boards
	for _, v in leaderboardTypes do
		local BoardKey = `{serviceKey}-{v}`;
		self.__boards[v] = Board.new(BoardKey, v, rollingExpiry);
	end;

	-- Start automation
	if (automationSettings and automationSettings.Automation) then
		local Thread = task.spawn(function()
			while (true) do
				-- Update the value from the queue
				self:UpdateBoardWithValues();

				-- Get the top and update the signal
				self:GetAllTop(automationSettings.RecordCount):andThen(function(boards)
					self.Updated:Fire(boards);
					for _, board in boards do
						self.BoardUpdated:Fire(board);
					end;
				end);
				task.wait(automationSettings.Interval);
			end;
		end);
		table.insert(self.__threads, Thread);
	end;

	-- Player removing
	table.insert(self.__connections, Players.PlayerRemoving:Connect(function(player)
		-- Remove the player from the value queue
		if (self.__valueQueue[player.UserId]) then
			self.__valueQueue[player.UserId] = nil;
		end;
	end));

	return self;
end

-- Flushes the queue
function Leaderboard:UpdateBoardWithValues()
	for UserId, BoardType in self.__valueQueue do
		for _, Data in BoardType do
			local Success = Data.Board:Update(UserId, function(oldValue)
				if (Data.Amount < oldValue) then
					return oldValue;
				end;
				return (oldValue + Data.Amount); -- Increment the value
			end);
			if (Success) then
				self.__valueQueue[UserId] = nil;
			end;
		end;
	end;
end

-- Gets the data for all the top boards (should only be used every 90-120 seconds)
function Leaderboard:RetrieveEntries(boardTypes, optionalRange, sortDirection)
	SmartAssert(type(sortDirection) == "nil" or typeof(sortDirection) == "string", "SortDirection must be a string");
	sortDirection = sortDirection or "Descending";

	-- If boardTypes is all, get all the boards
	if (boardTypes == "All") then
		boardTypes = self.__types;
	end;

	-- Check if the optional range is valid
	if (optionalRange) then
		SmartAssert(type(optionalRange) == "number" or type(optionalRange) == "table", "Optional range must be a number or a table");
		if (type(optionalRange) == "number") then
			SmartAssert(optionalRange <= 100, "You can only get the top 100.");
			SmartAssert(optionalRange > 0, "Optional range must be greater than 0");
		else
			for k, v in optionalRange do
				SmartAssert(IsValidLeaderboardType(k), `Leaderboard type {k} is not valid`);
				SmartAssert(type(v) == "number", "Optional range values must be a number");
				SmartAssert(v <= 100, "You can only get the top 100.");
				SmartAssert(v > 0, "Optional range values must be greater than 0");
			end;
		end;
	end;

	-- Get all the data
	local Promises = {};
	for _, v in boardTypes do
		local BoardClass = self.__boards[v] :: Board;
		if (not BoardClass) then
			error(`Board type {v} does not exist`, 2);
		end;

		local Amount = optionalRange and (type(optionalRange) == "number" and optionalRange or optionalRange[v]) or 100;
		table.insert(Promises, BoardClass:GetTopData(Amount, sortDirection):andThen(function(data)
			return {
				Type = v,
				Data = data,
			}
		end));
	end;

	return Promise.all(Promises);
end

-- Increments the queued value(s)
-- either Leaderboard:IncrementValues(nil, userId, amount) or Leaderboard:IncrementValues({"Daily", "Weekly"}, userId, amount
function Leaderboard:IncrementValues(boardTypes, userId, amount)
	SmartAssert(type(userId) == "number", "UserId must be a number");
	SmartAssert(type(amount) == "number", "Amount must be a number");
	SmartAssert(type(boardTypes) == "table", "BoardTypes must be a table");

	-- If boardTypes is all, increment all the boards
	if (boardTypes == "All") then
		boardTypes = self.__types;
	end;

	-- Reconcile the value queue
	if (not self.__valueQueue[userId]) then
		self.__valueQueue[userId] = {};
	end;

	local Queue = self.__valueQueue[userId];
	for _, v in boardTypes do
		-- Update the value queue
		if (not Queue[v]) then
			Queue[v] = {
				Amount = amount,
				Board = self.__boards[v]
			};
		else
			Queue[v].Amount += amount;
		end;
	end;
end

-- Updates the queued value(s)
-- either Leaderboard:UpdateValues(nil, userId, value) or Leaderboard:UpdateValues({"Daily", "Weekly"}, userId, value
function Leaderboard:UpdateValues(boardTypes, userId, value)
	SmartAssert(type(userId) == "number", "UserId must be a number");
	SmartAssert(type(value) == "function" or type(value) == "number", "Value must be a function or a number");
	SmartAssert(type(boardTypes) == "table", "BoardTypes must be a table");

	-- If boardTypes is all, update all the boards
	if (boardTypes == "All") then
		boardTypes = self.__types;
	end;

	-- Reconcile the value queue
	if (not self.__valueQueue[userId]) then
		self.__valueQueue[userId] = {};
	end;

	local Queue = self.__valueQueue[userId];
	for _, v in boardTypes do
		-- Update the value queue
		if (not Queue[v]) then
			Queue[v] = {
				Amount = value,
				Board = self.__boards[v],
			};
		else
			Queue[v].Amount = value;
		end;
	end;
end

-- Updates the actual store value(s) (should only be used every 90-120 seconds)
-- either Leaderboard:UpdateStoreValues(nil, userId, value) or Leaderboard:UpdateStoreValues({"Daily", "Weekly"}, userId, value
function Leaderboard:UpdateStoreValues(boardTypes, userId, value)
	SmartAssert(type(userId) == "number", "UserId must be a number");
	SmartAssert(type(value) == "function" or type(value) == "number", "Value must be a function or a number");
	SmartAssert(type(boardTypes) == "table", "BoardTypes must be a table");

	-- If boardTypes is all, update all the boards
	if (boardTypes == "All") then
		boardTypes = self.__types;
	end;

	for _, v in boardTypes do
		local BoardClass = self.__boards[v] :: Board;
		if (not BoardClass) then
			error(`Board type {v} does not exist`, 2);
		end;

		BoardClass:Update(userId, value);
	end;
end

-- Destroys the leaderboard
function Leaderboard:Destroy()
	-- Update the value from the queue
	self:UpdateBoardWithValues();

	-- Destroy all the boards
	for _, board in self.__boards do
		board:Destroy();
	end;

	-- Cancel all the threads
	for _, thread in self.__threads do
		if (typeof(thread) == "thread") then
			task.cancel(thread);
		end;
	end;

	-- Disconnect all the connections
	for _, connection in self.__connections do
		connection:Disconnect();
	end;

	-- Remove from leaderboards
	if (Leaderboards[self.__serviceKey]) then
		Leaderboards[self.__serviceKey] = nil;
	end;
end

-- Bind to close, destroy all the leaderboards
game:BindToClose(function()
	for _, leaderboard in Leaderboards do
		leaderboard:Destroy();
	end;
end);

-- Make indexing the class with the wrong key throw an error
setmetatable(Leaderboard, {
	__index = function(_, key)
		error(`Attempt to get Leaderboard:{tostring(key)} (not a valid member)`, 2);
	end,
	__newindex = function(_, key, _)
		error(`Attempt to set Leaderboard:{tostring(key)} (not a valid member)`, 2);
	end,
})

return table.freeze({
	new = Leaderboard.new,
	IncrementValues = Leaderboard.IncrementValues,
	UpdateValues = Leaderboard.UpdateValues,
	UpdateStoreValues = Leaderboard.UpdateStoreValues,
	GetAllTop = Leaderboard.GetAllTop,
	GetSpecifcTop = Leaderboard.GetSpecifcTop,
	Destroy = Leaderboard.Destroy,
})
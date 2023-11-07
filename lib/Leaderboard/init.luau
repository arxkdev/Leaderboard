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
	ServiceKey: string,
	Types: {LeaderboardType},
	Boards: {LeaderboardType: Board},
	ValueCache: {[number]: {Amount: number, BoardType: LeaderboardType}},
	Updated: Signal.Signal<{AllTopData}>,
	_threads: {thread},
}
export type TopData = {
	Rank: number,
	UserId: number,
	Value: number,
	Username: string,
	DisplayName: string,
}

type AllTopData = {
	Type: LeaderboardType,
	Data: {TopData},
}
type Object = {
	__index: Object,
	IncrementValue: (self: Leaderboard, boardType: LeaderboardType, userId: number, amount: number) -> (),
	UpdateValue: (self: Leaderboard, boardType: LeaderboardType, userId: number, value: number | (number) -> (number)) -> (),
	GetAllTop: (self: Leaderboard, optionalRange: {[string]: number} | number, sortDirection: string) -> Promise.TypedPromise<{AllTopData}>,
	GetSpecifcTop: (self: Leaderboard, boardType: LeaderboardType, amount: number, sortDirection: string) -> Promise.TypedPromise<{TopData}>,
	Destroy: (self: Leaderboard) -> (),
	new: (serviceKey: string, leaderboardTypes: {LeaderboardType}, automationSettings: AutomationSettings?, rollingExpiry: number?) -> Leaderboard,
}
type Board = Board.Board;
type AutomationSettings = {
	Automation: boolean,
	Interval: number,
	ValuesToCollect: number | {[string]: number},
}

-- Start
local Leaderboard: Object = {} :: Object;
Leaderboard.__index = Leaderboard;

local function SmartAssert(condition: boolean, message: string)
	if (not condition) then
		error(message, 2);
	end;
end

local function IsValidLeaderboardType(leaderboardType: LeaderboardType): boolean
	return table.find(BOARD_TYPES, leaderboardType);
end

function Leaderboard.new(serviceKey: string, leaderboardTypes: {LeaderboardType}, automationSettings: AutomationSettings?, rollingExpiry: number?)
	if (table.find(leaderboardTypes, "Rolling") and rollingExpiry ~= nil) then
		SmartAssert(rollingExpiry >= 60 and rollingExpiry <= MEMORY_STORE_SERVICE_MAX_EXPIRY, `Rolling expiry must be within 60 and {MEMORY_STORE_SERVICE_MAX_EXPIRY} seconds`);
		SmartAssert(type(rollingExpiry) == "number", "Rolling expiry must be a number");
	end;

	-- Check if the leaderboard types are valid
	SmartAssert(#leaderboardTypes > 0, "Leaderboard types must be greater than 0");
	for _, v in ipairs(leaderboardTypes) do
		SmartAssert(IsValidLeaderboardType(v), `Leaderboard type {v} is not valid`);
	end;

	-- Asserts for settings
	if (automationSettings) then
		SmartAssert(type(automationSettings) == "table", "Settings must be a table");
		SmartAssert(type(automationSettings.Automation) == "nil" or type(automationSettings.Automation) == "boolean", "Automation must be a boolean");
		SmartAssert(type(automationSettings.Interval) == "nil" or type(automationSettings.Interval) == "number", "Interval must be a number");
		SmartAssert(type(automationSettings.ValuesToCollect) == "nil" or type(automationSettings.ValuesToCollect) == "number" or type(automationSettings.ValuesToCollect) == "table", "ValuesToCollect must be a number or a table");
	end;

	local self = setmetatable({} :: LeaderboardArguments, Leaderboard);

	self.ServiceKey = serviceKey;
	self.Types = leaderboardTypes;
	self.Boards = {};
	self.ValueCache = {};
	self.Updated = Signal.new();
	self._threads = {};
	self._connections = {};

	-- Initialize boards
	for _, v in ipairs(leaderboardTypes) do
		local BoardKey = `{serviceKey}-{v}`;
		self.Boards[v] = Board.new(BoardKey, v, rollingExpiry);
	end;

	-- Start automation
	if (automationSettings and automationSettings.Automation) then
		local Thread = task.spawn(function()
			while (true) do
				-- Update the value from the cache
				for UserId, Data in pairs(self.ValueCache) do
					self:UpdateValue(Data.BoardType, UserId, Data.Amount);
				end;

				-- Get the top and update the signal
				self:GetAllTop(automationSettings.ValuesToCollect):andThen(function(boards)
					self.Updated:Fire(boards);
				end);
				task.wait(automationSettings.Interval);
			end;
		end);
		table.insert(self._threads, Thread);
	end;

	-- Player removing
	self._connections[#self._connections + 1] = Players.PlayerRemoving:Connect(function(player)
		-- Remove the player from the value cache
		for UserId in pairs(self.ValueCache) do
			if (UserId == player.UserId) then
				self.ValueCache[UserId] = nil;
			end;
		end;
	end);

	return self;
end

-- Gets the data for a specific board
function Leaderboard:GetSpecifcTop(boardType, amount, sortDirection)
	SmartAssert(type(amount) == "number", "Amount must be a number");
	SmartAssert(amount <= 100, "You can only get the top 100.");
	SmartAssert(amount > 0, "Amount must be greater than 0");
	SmartAssert(type(sortDirection) == "nil" or typeof(sortDirection) == "string", "SortDirection must be a string");
	sortDirection = sortDirection or "Descending";

	local BoardClass = self.Boards[boardType] :: Board;
	if (not BoardClass) then
		error(`Board type ${boardType} does not exist`, 2);
	end;

	return BoardClass:GetTopData(amount, sortDirection);
end

-- Gets the data for all the top boards
function Leaderboard:GetAllTop(optionalRange, sortDirection)
	SmartAssert(type(sortDirection) == "nil" or typeof(sortDirection) == "string", "SortDirection must be a string");
	sortDirection = sortDirection or "Descending";

	-- Check if the optional range is valid
	if (optionalRange) then
		SmartAssert(type(optionalRange) == "number" or type(optionalRange) == "table", "Optional range must be a number or a table");
		if (type(optionalRange) == "number") then
			SmartAssert(optionalRange <= 100, "You can only get the top 100.");
			SmartAssert(optionalRange > 0, "Optional range must be greater than 0");
		else
			for k, v in pairs(optionalRange) do
				SmartAssert(IsValidLeaderboardType(k), `Leaderboard type {k} is not valid`);
				SmartAssert(type(v) == "number", "Optional range values must be a number");
				SmartAssert(v <= 100, "You can only get the top 100.");
				SmartAssert(v > 0, "Optional range values must be greater than 0");
			end;
		end;
	end;

	-- Get all the data
	local Promises = {};
	for _, v in ipairs(self.Types) do
		local BoardClass = self.Boards[v] :: Board;
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

-- Increments the cached value
function Leaderboard:IncrementValue(boardType, userId, amount)
	SmartAssert(type(userId) == "number", "UserId must be a number");
	SmartAssert(type(amount) == "number", "Amount must be a number");

	local BoardClass = self.Boards[boardType] :: Board;
	if (not BoardClass) then
		error(`Board type ${boardType} does not exist`, 2);
	end;

	-- Update the value cache
	if (not self.ValueCache[userId]) then
		self.ValueCache[userId] = {
			Amount = amount,
			BoardType = boardType,
		};
	else
		self.ValueCache[userId].Amount += amount;
	end;
end

-- Updates the cached value
function Leaderboard:UpdateValue(boardType, userId, value)
	SmartAssert(type(userId) == "number", "UserId must be a number");
	SmartAssert(type(value) == "function" or type(value) == "number", "Value must be a function or a number");

	local BoardClass = self.Boards[boardType] :: Board;
	if (not BoardClass) then
		error(`Board type ${boardType} does not exist`, 2);
	end;

	-- Update the value cache
	if (not self.ValueCache[userId]) then
		self.ValueCache[userId] = {
			Amount = value,
			BoardType = boardType,
		};
	else
		self.ValueCache[userId].Amount = value;
	end;
end

-- Updates the actual store value (should only be used every 90-120 seconds)
function Leaderboard:UpdateStoreValue(boardType, userId, value)
	SmartAssert(type(userId) == "number", "UserId must be a number");
	SmartAssert(type(value) == "function" or type(value) == "number", "Value must be a function or a number");

	local BoardClass = self.Boards[boardType] :: Board;
	if (not BoardClass) then
		error(`Board type ${boardType} does not exist`, 2);
	end;

	return BoardClass:Update(userId, value);
end

function Leaderboard:Destroy()
	for _, thread in ipairs(self._threads) do
		for _, v in ipairs(thread) do
			task.cancel(v);
		end;
	end;

	for _, connection in ipairs(self._connections) do
		connection:Disconnect();
	end;
end

return table.freeze({
	new = Leaderboard.new,
	UpdateData = Leaderboard.UpdateData,
	GetTopData = Leaderboard.GetTopData,
	Destroy = Leaderboard.Destroy,
})
--[[
	Arxk @ 2023
]]
local Players = game:GetService("Players");

-- Requirements
local Util = require(script.Util);
local Signal = require(script.Signal);
local Promise = require(script.Promise);
local Board = require(script.Board);
local Logger = require(script.Logger);

-- Variables
local SmartAssert = Util.SmartAssert;
local KeysInDictionary = Util.KeysInDictionary;
local GenerateGUID = Util.GenerateGUID;
local Spawn = task.spawn;
local Cancel = task.cancel;

-- Constants
local MEMORY_STORE_SERVICE_MAX_EXPIRY = Util.MEMORY_STORE_SERVICE_MAX_EXPIRY;
local BOARD_TYPES = Util.BOARD_TYPES;
local MAX_OVERALL_LEADERBOARDS = 3; -- Overall, you can only create 5 leaderboards using Leaderboard.new, this is to prevent rate limiting
local MAX_BOARDS = 7; -- You can only create up to 7 boards per leaderboard

--[=[
	@within Leaderboard
	@interface TopData
	@field Rank number
	@field UserId number
	@field Value number
	@field Username string
	@field DisplayName string
]=]
export type TopData = {
	Rank: number,
	UserId: number,
	Value: number,
	Username: string,
	DisplayName: string,
}

--[=[
	@within Leaderboard
	@interface AllTopData
	@field Type LeaderboardType
	@field Data {TopData}
]=]
type AllTopData = {
	Type: LeaderboardType,
	Data: {TopData},
}

-- Supports Daily, Weekly, Monthly and AllTime currently
--[=[
    @within Leaderboard
    @type Leaderboard () -> Leaderboard
]=]
export type Leaderboard = typeof(setmetatable({} :: LeaderboardArguments, {} :: Object));

--[=[
    @within Leaderboard
    @type LeaderboardType "Hourly" | "Daily" | "Weekly" | "Monthly" | "Yearly" | "AllTime" | string;
]=]
export type LeaderboardType = "Hourly" | "Daily" | "Weekly" | "Monthly" | "Yearly" | "AllTime" | string;

--[=[
	@within Leaderboard
	@type LeaderboardTypeArgument {[LeaderboardType]: any}
]=]
export type LeaderboardTypeArgument = {
	[LeaderboardType]: any,
}

--[=[
	@within Leaderboard
	@interface LeaderboardArguments
	@field Updated Signal<{AllTopData}>
	@field BoardUpdated Signal<{Type: LeaderboardType, Data: {TopData}}>
	@field _serviceKey string
	@field _types LeaderboardTypeArgument
	@field _boards {[LeaderboardType]: Board}
	@field _valueQueue ValueQueueType
	@field _threads {thread}
	@field _connections {RBXScriptConnection}
	@field _logger Logger.Logger?
]=]
export type LeaderboardArguments = {
	Updated: Signal.Signal<{AllTopData}>,
	BoardUpdated: Signal.Signal<{Type: LeaderboardType, Data: {TopData}}>,
	_serviceKey: string,
	_types: LeaderboardTypeArgument,
	_boards: {[LeaderboardType]: Board},
	_valueQueue: ValueQueueType,
	_threads: {thread},
	_connections: {RBXScriptConnection},
	_logger: Logger.Logger?,
}

--[=[
	@within Leaderboard
	@interface Board
	@field GetRecords (self: Board, amount: number, sortDirection: string) -> Promise.TypedPromise<{TopData}>
	@field Update (self: Board, userId: number, value: number | (number) -> (number)) -> boolean
	@field Destroy (self: Board) -> ()
]=]
type ValueQueueType = {
	[number]: {
		[LeaderboardType]: {
			Amount: number,
			Board: Board,
		},
	},
}

--[=[
	@within Leaderboard
	@interface Object
	@field IncrementValues (self: Leaderboard, boardTypes: {LeaderboardType} | string, userId: number, amount: number) -> ()
	@field SetValues (self: Leaderboard, boardTypes: {LeaderboardType} | string, userId: number, value: number | (number) -> (number)) -> ()
	@field UpdateStoreValues (self: Leaderboard, boardTypes: {LeaderboardType} | string, userId: number, value: number | (number) -> (number)) -> ()
	@field GetRecords (self: Leaderboard, boardTypes: {LeaderboardType} | string, optionalRange: {[LeaderboardType | string]: number} | number, sortDirection: string) -> Promise.TypedPromise<{AllTopData}>
	@field SaveValues (self: Leaderboard) -> Promise.TypedPromise<nil>
	@field Destroy (self: Leaderboard) -> ()
	@field new (leaderboardTypes: {LeaderboardType}, automationSettings: AutomationSettings?, debugMode: boolean?) -> Leaderboard
]=]
type Object = {
	__index: Object,
	IncrementValues: (self: Leaderboard, boardTypes: {LeaderboardType} | string, userId: number, amount: number) -> (),
	SetValues: (self: Leaderboard, boardTypes: {LeaderboardType} | string, userId: number, value: number | (number) -> (number)) -> (),
	UpdateStoreValues: (self: Leaderboard, boardTypes: {LeaderboardType} | string, userId: number, value: number | (number) -> (number)) -> (),
	GetRecords: (self: Leaderboard, boardTypes: {LeaderboardType} | string, optionalRange: {[LeaderboardType | string]: number} | number, sortDirection: string) -> Promise.TypedPromise<{AllTopData}>,
	SaveValues: (self: Leaderboard) -> Promise.TypedPromise<nil>,
	Destroy: (self: Leaderboard) -> (),
	new: (leaderboardTypes: LeaderboardTypeArgument, automationSettings: AutomationSettings?, debugMode: boolean?) -> Leaderboard,
}

type Board = Board.Board;

--[=[
	@within Leaderboard
	@interface AutomationSettings
	@field Automation boolean?
	@field Interval number?
	@field RecordCount number | {[string]: number}?
]=]
type AutomationSettings = {
	Automation: boolean,
	Interval: number,
	RecordCount: number | {[string]: number},
}

--[=[
	@within Leaderboard
	@readonly
	@prop Updated Signal<{AllTopData}>

	Fired when the leaderboard is updated.
]=]
--[=[
	@within Leaderboard
	@readonly
	@prop BoardUpdated Signal<{Type: LeaderboardType, Data: {TopData}}>

	Fired when a specific board is updated.
]=]

local Leaderboards = {} :: {[string]: Leaderboard};

--[=[
	@class Leaderboard

	Leaderboard allows you to create a leaderboard that can be used to store and retrieve data for a specific service key.

	For example:
	```lua
	local Leaderboard = require(game:GetService("ReplicatedStorage").Leaderboard);
	local MoneyLeaderboard = Leaderboard.new({
		Daily = "DailyMoneyKey1",
		Weekly = "WeeklyMoneyKey1"
	});
	```
]=]
local Leaderboard: Object = {} :: Object;
Leaderboard.__index = Leaderboard;

local function IsValidLeaderboardType(leaderboardType: LeaderboardType, boardKey: string | {number & string}): boolean
	if (type(boardKey) == "table") then
		local RollingExpiry = type(boardKey) == "table" and boardKey[1] or nil;
		return RollingExpiry >= 60 and RollingExpiry <= MEMORY_STORE_SERVICE_MAX_EXPIRY;
	end;
	return table.find(BOARD_TYPES, leaderboardType) ~= nil;
end

--[=[
	@param leaderboardTypes LeaderboardTypeArgument
	@param automationSettings AutomationSettings?
	@param debugMode boolean?
	@return Leaderboard

	Constructs a new leaderboard.
]=]
function Leaderboard.new(leaderboardTypes: LeaderboardTypeArgument, automationSettings: AutomationSettings?, debugMode: boolean?)
	-- Check if the leaderboard types are valid
	SmartAssert(#KeysInDictionary(leaderboardTypes) > 0, "Leaderboard types must be greater than 0");
	SmartAssert(#KeysInDictionary(leaderboardTypes) <= MAX_BOARDS, `You can only create up to {MAX_BOARDS} types of leaderboards`);
	for boardType, boardKey in leaderboardTypes do
		SmartAssert(IsValidLeaderboardType(boardType, boardKey), `Leaderboard type {boardType} is not valid`);
		SmartAssert(boardKey ~= "", "Leaderboard key must not be empty");
	end;

	-- Check if they've exceeded the max leaderboards
	SmartAssert(#KeysInDictionary(Leaderboards) < MAX_OVERALL_LEADERBOARDS, `You can only create up to {MAX_OVERALL_LEADERBOARDS} leaderboards`);

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
	self._serviceKey = GenerateGUID();
	self._types = leaderboardTypes;
	self._boards = {};
	self._valueQueue = {};
	self._threads = {};
	self._connections = {};
	self._logger = Logger.new("Leaderboard", debugMode or false);

	-- Add to leaderboards
	Leaderboards[self._serviceKey] = self;

	-- Initialize boards
	for boardType, boardKey in leaderboardTypes do
		self._boards[boardType] = Board.new(typeof(boardKey) == "table" and boardKey[2] or boardKey, boardType, typeof(boardKey) == "table" and boardKey[1] or nil, debugMode);
	end;

	-- Start automation
	if (automationSettings and automationSettings.Automation) then
		local Thread = Spawn(function()
			local Times = 0;

			while (true) do
				Times += 1;
				-- We work in alternating turns, so one loop we'll update the value queue, the next we'll update the actual store value(s)
				if (Times % 2 == 0) then
					-- Update the value from the queue
					self:SaveValues();
				else
					-- Get the top and update the signal
					local _, Data = self:GetRecords("All", automationSettings.RecordCount):await();
					if (Data) then
						self.Updated:Fire(Data);
						for _, board in Data do
							self.BoardUpdated:Fire(board);
						end;
					end;
				end;

				task.wait(automationSettings.Interval);
			end;
		end);
		table.insert(self._threads, Thread);
	end;

	-- Player removing
	table.insert(self._connections, Players.PlayerRemoving:Connect(function(player)
		-- Remove the player from the value queue
		if (self._valueQueue[player.UserId]) then
			self._valueQueue[player.UserId] = nil;
		end;
	end));

	return self;
end

-- Flushes the queue
-- Should only be used every 90-120 seconds
--[=[
	@yields
	Updates the actual store value(s) (should only be used every 90-120 seconds)
]=]
function Leaderboard:SaveValues()
	local Promises = {};
	for UserId, BoardType in self._valueQueue do
		for _, Data in BoardType do
			local PromiseUpdate = Data.Board:Update(UserId, function(oldValue)
				return (oldValue + Data.Amount); -- Increment the value
			end):andThen(function()
				self._valueQueue[UserId] = nil;
			end);
			table.insert(Promises, PromiseUpdate);
		end;
	end;

	return Promise.all(Promises);
end

-- Gets the data for all the top boards (should only be used every 90-120 seconds)
--[=[
	@param boardTypes {LeaderboardType} | "All"
	@param optionalRange {[string]: number} | number
	@param sortDirection string
	@yields

	@return Promise<{AllTopData}>

	Gets the data for all the top boards (should only be used every 90-120 seconds)
]=]
function Leaderboard:GetRecords(boardTypes, optionalRange, sortDirection)
	SmartAssert(type(sortDirection) == "nil" or typeof(sortDirection) == "string", "SortDirection must be a string");
	sortDirection = sortDirection or "Descending";

	-- If boardTypes is all, get all the boards
	if (boardTypes == "All") then
		boardTypes = self._types;
	end;

	-- Check if the optional range is valid
	if (optionalRange) then
		SmartAssert(type(optionalRange) == "number" or type(optionalRange) == "table", "Optional range must be a number or a table");
		if (type(optionalRange) == "number") then
			SmartAssert(optionalRange <= 100, "You can only get the top 100.");
			SmartAssert(optionalRange > 0, "Optional range must be greater than 0");
		else
			for k, v in optionalRange do
				SmartAssert(IsValidLeaderboardType(k, v), `Leaderboard type {k} is not valid`);
				SmartAssert(type(v) == "number", "Optional range values must be a number");
				SmartAssert(v <= 100, "You can only get the top 100.");
				SmartAssert(v > 0, "Optional range values must be greater than 0");
			end;
		end;
	end;

	-- Get all the data
	local Promises = {};
	for boardType in boardTypes do
		local BoardClass = self._boards[boardType] :: Board;
		SmartAssert(BoardClass ~= nil, `Board type {boardType} does not exist`)

		local Amount = optionalRange and (type(optionalRange) == "number" and optionalRange or optionalRange[boardType]) or 100;
		table.insert(Promises, BoardClass:Get(Amount, sortDirection):andThen(function(data)
			return {
				Type = boardType, -- We want to tell the difference between rolling and non-rolling
				Data = data,
			}
		end));
	end;

	return Promise.all(Promises) :: Promise.TypedPromise<{AllTopData}>;
end

-- Increments the queued value(s)
-- either Leaderboard:IncrementValues(nil, userId, amount) or Leaderboard:IncrementValues({"Daily", "Weekly"}, userId, amount
--[=[
	Increments the queued value(s)
	@param boardTypes {LeaderboardType} | "All"
	@param userId number
	@param amount number

	Increments the queued value(s)
]=]
function Leaderboard:IncrementValues(boardTypes, userId, amount)
	SmartAssert(type(userId) == "number", "UserId must be a number");
	SmartAssert(type(amount) == "number", "Amount must be a number");
	SmartAssert(type(boardTypes) == "table" or type(boardTypes) == "string", "BoardTypes must be a table or a string");

	-- If boardTypes is all, increment all the boards
	if (boardTypes == "All") then
		boardTypes = self._types;
	end;

	-- Reconcile the value queue
	if (not self._valueQueue[userId]) then
		self._valueQueue[userId] = {};
	end;

	local Queue = self._valueQueue[userId];
	for boardType in boardTypes do
		-- Update the value queue
		if (not Queue[boardType]) then
			Queue[boardType] = {
				Amount = amount,
				Board = self._boards[boardType]
			};
		else
			Queue[boardType].Amount += amount;
		end;
	end;
end

-- Updates the queued value(s)
-- either Leaderboard:SetValues("All", userId, value) or Leaderboard:SetValues({"Daily", "Weekly"}, userId, value
--[=[
	Updates the queued value(s)
	@param boardTypes {LeaderboardType} | "All"
	@param userId number
	@param value number | (number) -> (number)

	Updates the queued value(s)
]=]
function Leaderboard:SetValues(boardTypes, userId, value)
	SmartAssert(type(userId) == "number", "UserId must be a number");
	SmartAssert(type(value) == "function" or type(value) == "number", "Value must be a function or a number");
	SmartAssert(type(boardTypes) == "table", "BoardTypes must be a table");

	-- If boardTypes is all, update all the boards
	if (boardTypes == "All") then
		boardTypes = self._types;
	end;

	-- Reconcile the value queue
	if (not self._valueQueue[userId]) then
		self._valueQueue[userId] = {};
	end;

	local Queue = self._valueQueue[userId];
	for boardType in boardTypes do
		-- Update the value queue
		if (not Queue[boardType]) then
			Queue[boardType] = {
				Amount = value,
				Board = self._boards[boardType],
			};
		else
			Queue[boardType].Amount = value;
		end;
	end;
end

-- Updates the actual store value(s) (should only be used every 90-120 seconds)
-- either Leaderboard:UpdateStoreValues(nil, userId, value) or Leaderboard:UpdateStoreValues({"Daily", "Weekly"}, userId, value
--[=[
	Updates the actual store value(s) (should only be used every 90-120 seconds)
	@param boardTypes {LeaderboardType} | "All"
	@param userId number
	@param value number | (number) -> (number)
	@yields

	Updates the actual store value(s) (should only be used every 90-120 seconds)
]=]
function Leaderboard:UpdateStoreValues(boardTypes, userId, value)
	SmartAssert(type(userId) == "number", "UserId must be a number");
	SmartAssert(type(value) == "function" or type(value) == "number", "Value must be a function or a number");
	SmartAssert(type(boardTypes) == "table", "BoardTypes must be a table");

	-- If boardTypes is all, update all the boards
	if (boardTypes == "All") then
		boardTypes = self._types;
	end;

	for boardType in boardTypes do
		local BoardClass = self._boards[boardType] :: Board;
		if (not BoardClass) then
			error(`Board type {boardType} does not exist`, 2);
		end;

		BoardClass:Update(userId, value);
	end;
end

-- Destroys the leaderboard
--[=[
	Destroys the leaderboard
]=]
function Leaderboard:Destroy()
	-- Update the value from the queue
	self:SaveValues();

	-- Destroy all the boards
	for _, board in self._boards do
		board:Destroy();
	end;

	-- Cancel all the threads
	for _, thread in self._threads do
		if (typeof(thread) == "thread") then
			Cancel(thread);
		end;
	end;

	-- Disconnect all the connections
	for _, connection in self._connections do
		connection:Disconnect();
	end;

	-- Logger destroy
	self._logger:Destroy();

	-- Remove from leaderboards
	if (Leaderboards[self._serviceKey]) then
		Leaderboards[self._serviceKey] = nil;
	end;

	-- Destroy the metatable
	setmetatable(self, nil);
end

-- Bind to close, destroy all the leaderboards
game:BindToClose(function()
	for _, leaderboard in Leaderboards do
		Spawn(function()
			leaderboard:Destroy();
		end)
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
	SetValues = Leaderboard.SetValues,
	UpdateStoreValues = Leaderboard.UpdateStoreValues,
	GetRecords = Leaderboard.GetRecords,
	Destroy = Leaderboard.Destroy,
})
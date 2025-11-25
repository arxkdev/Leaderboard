--[[
	Arxk @ 2025
]]
local Players = game:GetService("Players");

-- Requirements
local Packages = script:FindFirstChild("Packages") or script.Parent; -- Development Wally places packages in script.Packages; Production Wally places packages in script.Parent.Packages
local Util = require(script.Util);
local Signal = require(Packages.Signal);
local Promise = require(Packages.Promise);
local Board = require(script.Board);
local Logger = require(script.Logger);
local Trove = require(Packages.Trove);

-- Variables
local SmartAssert = Util.SmartAssert;
local KeysInDictionary = Util.KeysInDictionary;
local GenerateGUID = Util.GenerateGUID;
local Spawn = task.spawn;

-- Constants
local MEMORY_STORE_SERVICE_MAX_EXPIRY = Util.MEMORY_STORE_SERVICE_MAX_EXPIRY;
local MEMORY_STORE_SERVICE_MIN_EXPIRY = Util.MEMORY_STORE_SERVICE_MIN_EXPIRY;
local BOARD_TYPES = Util.BOARD_TYPES;
local MAX_OVERALL_LEADERBOARDS = Util.MAX_OVERALL_LEADERBOARDS;
local MAX_BOARDS = Util.MAX_BOARDS;

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
	@type LeaderboardTypeArgument {[LeaderboardType]: BoardConfig | string | {number & string}}
]=]
export type LeaderboardTypeArgument = {
	[LeaderboardType]: BoardConfig | string | {number & string},
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
	@field _isSaving boolean
	@field _lastSaved number
	@field _isFetching boolean
	@field _lastFetch number
	@field _logger Logger.Logger?
]=]
export type LeaderboardArguments = {
	Updated: Signal.Signal<{AllTopData}>,
	BoardUpdated: Signal.Signal<{Type: LeaderboardType, Data: {TopData}}>,
	_serviceKey: string,
	_types: LeaderboardTypeArgument,
	_boards: {[LeaderboardType]: Board},
	_valueQueue: ValueQueueType,
	_isSaving: boolean,
	_lastSaved: number,
	_isFetching: boolean,
	_lastFetch: number,
	_trove: typeof(Trove.new),
	_logger: Logger.Logger?,
}

--[=[
	@within Leaderboard
	@type OperationType "Set" | "Increment"
	
	The type of operation to perform on the leaderboard value.
	- "Set": Sets the value to the specified amount or result of the transform function
	- "Increment": Adds the specified amount or result of the transform function to the current value
]=]
export type OperationType = "Set" | "Increment";

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
			Amount: number | ((number) -> number),
			Board: Board,
			OperationType: OperationType,
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
	@field new (leaderboardTypes: LeaderboardTypeArgument, debugMode: boolean?) -> Leaderboard
]=]
type Object = {
	__index: Object,
	IncrementValues: (self: Leaderboard, boardTypes: {LeaderboardType} | string, userId: number, amount: number) -> (),
	SetValues: (self: Leaderboard, boardTypes: {LeaderboardType} | string, userId: number, value: number | (number) -> (number)) -> (),
	UpdateStoreValues: (self: Leaderboard, boardTypes: {LeaderboardType} | string, userId: number, value: number | (number) -> (number)) -> (),
	GetRecords: (self: Leaderboard, boardTypes: {LeaderboardType} | string, optionalRange: {[LeaderboardType | string]: number} | number, sortDirection: string) -> Promise.TypedPromise<{AllTopData}>,
	SaveValues: (self: Leaderboard) -> Promise.TypedPromise<nil>,
	Destroy: (self: Leaderboard) -> (),
	new: (leaderboardTypes: LeaderboardTypeArgument, debugMode: boolean?) -> Leaderboard,
}

type Board = Board.Board;

--[=[
	@within Leaderboard
	@interface BoardConfig
	@field Name string
	@field Automation boolean?
	@field Interval number?
	@field RecordCount number?
	@field Shards number?
]=]
export type BoardConfig = {
	Name: string,
	Automation: boolean?,
	Interval: number?,
	RecordCount: number?,
	Shards: number?,
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

local function IsValidLeaderboardType(leaderboardType: LeaderboardType, boardKey: string | BoardConfig | {number & string}): boolean
	if (type(boardKey) == "table") then
		-- Check if it's a rolling expiry table {number, string} (not a BoardConfig)
		-- BoardConfig has a Name field, rolling expiry tables don't
		if (not (boardKey :: any).Name) then
			-- It's a rolling expiry table {number, string}
			local RollingExpiry = boardKey[1];
			if (type(RollingExpiry) == "number") then
				return RollingExpiry >= MEMORY_STORE_SERVICE_MIN_EXPIRY and RollingExpiry <= MEMORY_STORE_SERVICE_MAX_EXPIRY;
			end;
		end;
	end;
	return table.find(BOARD_TYPES, leaderboardType) ~= nil;
end

--[=[
	@within Leaderboard
	@param leaderboardTypes LeaderboardTypeArgument
	@param debugMode boolean?
	@return Leaderboard

	Constructs a new leaderboard.
]=]
function Leaderboard.new(leaderboardTypes: LeaderboardTypeArgument, debugMode: boolean?)
	-- Check if the leaderboard types are valid
	SmartAssert(#KeysInDictionary(leaderboardTypes) > 0, "Leaderboard types must be greater than 0");
	SmartAssert(#KeysInDictionary(leaderboardTypes) <= MAX_BOARDS, `You can only create up to {MAX_BOARDS} types of leaderboards`);
	
	-- Validate and normalize board configs
	local normalizedConfigs: {[LeaderboardType]: {Name: string, RollingExpiry: number?, Config: BoardConfig?}} = {};
	for boardType, boardValue in leaderboardTypes do
		SmartAssert(IsValidLeaderboardType(boardType, boardValue), `Leaderboard type {boardType} is not valid`);
		
		local boardName: string;
		local rollingExpiry: number? = nil;
		local boardConfig: BoardConfig? = nil;
		
		if (type(boardValue) == "string") then
			SmartAssert(boardValue ~= "", "Leaderboard key must not be empty");
			boardName = boardValue;
		elseif (type(boardValue) == "table" and typeof(boardValue) == "table") then
			-- Check if it's a BoardConfig
			if (boardValue.Name) then
				boardConfig = boardValue :: BoardConfig;
				boardName = boardConfig.Name;
				SmartAssert(type(boardConfig.Name) == "string", "BoardConfig.Name must be a string");
				SmartAssert(boardConfig.Name ~= "", "BoardConfig.Name must not be empty");
				if (boardConfig.Automation ~= nil) then
					SmartAssert(type(boardConfig.Automation) == "boolean", "BoardConfig.Automation must be a boolean");
				end;
				if (boardConfig.Interval ~= nil) then
					SmartAssert(type(boardConfig.Interval) == "number", "BoardConfig.Interval must be a number");
				end;
				if (boardConfig.RecordCount ~= nil) then
					SmartAssert(type(boardConfig.RecordCount) == "number", "BoardConfig.RecordCount must be a number");
				end;
				if (boardConfig.Shards ~= nil) then
					SmartAssert(type(boardConfig.Shards) == "number", "BoardConfig.Shards must be a number");
				end;
			else
				-- It's a rolling expiry table {number, string}
				rollingExpiry = boardValue[1];
				boardName = boardValue[2];
				SmartAssert(type(rollingExpiry) == "number", "Rolling expiry must be a number");
				SmartAssert(type(boardName) == "string", "Board name must be a string");
				SmartAssert(boardName ~= "", "Board name must not be empty");
			end;
		end;
		
		normalizedConfigs[boardType] = {
			Name = boardName,
			RollingExpiry = rollingExpiry,
			Config = boardConfig,
		};
	end;

	-- Check if they've exceeded the max leaderboards
	SmartAssert(#KeysInDictionary(Leaderboards) < MAX_OVERALL_LEADERBOARDS, `You can only create up to {MAX_OVERALL_LEADERBOARDS} leaderboards`);

	local self = setmetatable({} :: LeaderboardArguments, Leaderboard);

	-- Public properties
	self.Updated = Signal.new();
	self.BoardUpdated = Signal.new();

	-- Private properties
	self._serviceKey = GenerateGUID();
	self._types = leaderboardTypes;
	self._boards = {};
	self._valueQueue = {};
	self._lastSaved = 0;
	self._isSaving = false;
	self._lastFetch = 0;
	self._isFetching = false;
	self._trove = Trove.new();
	self._logger = Logger.new("Leaderboard", debugMode or false);

	-- Add signals and logger to Trove for cleanup
	self._trove:Add(self.Updated);
	self._trove:Add(self.BoardUpdated);
	self._trove:Add(self._logger);

	-- Add to leaderboards
	Leaderboards[self._serviceKey] = self;

	-- Initialize boards
	for boardType, normalizedConfig in normalizedConfigs do
		local newBoard = Board.new(normalizedConfig.Name, boardType, normalizedConfig.RollingExpiry, normalizedConfig.Config, debugMode);
		self._boards[boardType] = newBoard;

		-- Add to trove to cleanup the board when the leaderboard is destroyed
		self._trove:Add(function()
			newBoard:Destroy();
		end);
	end;

	-- Start automation threads for each board type that has automation enabled
	for boardType, normalizedConfig in normalizedConfigs do
		local boardConfig = normalizedConfig.Config;
		if (boardConfig and boardConfig.Automation) then
			-- Capture boardType in a local variable to avoid closure issues
			local capturedBoardType = boardType;
			local interval = boardConfig.Interval or 300;
			local recordCount = boardConfig.RecordCount or 100;
			
			local automationThread = Spawn(function()
				local CalledTimes = 0;

				while (true) do
					-- Update the value from the queue
					self:SaveValues();

					-- We work in alternating turns, so one loop we'll update the value queue, the next we'll update the actual store value(s)
					if (CalledTimes % 2 == 0 or CalledTimes == 0) then
						-- Get the top and update the signal for this specific board type
						-- Create a dictionary with capturedBoardType as key (not an array)
						local TopData = self:GetRecords({[capturedBoardType] = true}, recordCount):awaitValue() :: {AllTopData};
						if (TopData and #TopData > 0) then
							self.Updated:Fire(TopData);
							for _, board in TopData do
								self.BoardUpdated:Fire(board);
							end;
						end;
					end;

					CalledTimes += 1;
					task.wait(interval);
				end;
			end);
			-- Add thread to Trove for cleanup
			self._trove:Add(automationThread);
		end;
	end;

	-- Player removing
	local playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		-- Remove the player from the value queue
		if (self._valueQueue[player.UserId]) then
			self._valueQueue[player.UserId] = nil;
		end;
	end);
	-- Add connection to Trove for cleanup
	self._trove:Add(playerRemovingConnection);

	return self;
end

-- Flushes the queue
-- Should only be used every 90-120 seconds
--[=[
	@within Leaderboard
	@return Promise.TypedPromise<nil>
	@yields
	Updates the actual store value(s) (should only be used every 90-120 seconds)
]=]
function Leaderboard:SaveValues()
	local Promises = {};
	self._isSaving = true;

	for UserId, BoardType in self._valueQueue do
		for _, Data in BoardType do
			local PromiseUpdate = Data.Board:Update(UserId, function(oldValue)
				if (Data.OperationType == "Set") then
					-- Set operation: use the value/function directly
					if (type(Data.Amount) == "function") then
						return Data.Amount(oldValue);
					else
						return Data.Amount;
					end;
				elseif (Data.OperationType == "Increment") then
					-- Increment operation: add the amount
					if (type(Data.Amount) == "function") then
						return oldValue + Data.Amount(oldValue);
					else
						return oldValue + Data.Amount;
					end;
				else
					self._logger:Log(3, `Invalid operation type: {Data.OperationType} for user {UserId}`);
					return oldValue;
				end;
			end):andThen(function()
				self._valueQueue[UserId] = nil;
			end):catch(function(err)
				self._logger:Log(3, `Error updating value for user {UserId}: {err}`);
			end);
			table.insert(Promises, PromiseUpdate);
		end;
	end;

	return Promise.all(Promises):finally(function()
		self._isSaving = false;
		self._lastSaved = tick();
	end);
end

-- Gets the data for all the top boards (should only be used every 90-120 seconds)
--[=[
	@within Leaderboard
	@param boardTypes {LeaderboardType} | "All"
	@param optionalRange {[string]: number} | number
	@param sortDirection string
	@return Promise.TypedPromise<{AllTopData}>
	@yields

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
				SmartAssert(IsValidLeaderboardType(k, v), `Leaderboard type "{k}" is not valid`);
				SmartAssert(type(v) == "number", "Optional range values must be a number");
				SmartAssert(v <= 100, "You can only get the top 100.");
				SmartAssert(v > 0, "Optional range values must be greater than 0");
			end;
		end;
	end;

	self._isFetching = true;

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

	return Promise.all(Promises):finally(function()
		self._isFetching = false;
		self._lastFetch = tick();
	end) :: Promise.TypedPromise<{AllTopData}>;
end

-- Increments the queued value(s)
-- either Leaderboard:IncrementValues(nil, userId, amount) or Leaderboard:IncrementValues({"Daily", "Weekly"}, userId, amount
--[=[
	@within Leaderboard
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
		print("Incrementing value for board type", boardType);
		-- Update the value queue
		if (not Queue[boardType]) then
			Queue[boardType] = {
				Amount = amount,
				Board = self._boards[boardType],
				OperationType = "Increment",
			};
			print("Added value to queue for board type", boardType);
		else
			Queue[boardType].Amount += amount;
			print("Incremented value for board type", boardType);
		end;
	end;
end

-- Updates the queued value(s)
-- either Leaderboard:SetValues("All", userId, value) or Leaderboard:SetValues({"Daily", "Weekly"}, userId, value
--[=[
	@within Leaderboard
	Updates the queued value(s)
	@param boardTypes {LeaderboardType} | "All"
	@param userId number
	@param value number | (number) -> (number)

	Updates the queued value(s)
]=]
function Leaderboard:SetValues(boardTypes, userId, value)
	SmartAssert(type(userId) == "number", "UserId must be a number");
	SmartAssert(type(value) == "function" or type(value) == "number", "Value must be a function or a number");
	SmartAssert(type(boardTypes) == "table" or type(boardTypes) == "string", "BoardTypes must be a table or a string");

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
		-- For set operations, always replace the value (don't accumulate)
		Queue[boardType] = {
			Amount = value,
			Board = self._boards[boardType],
			OperationType = "Set",
		};
	end;
end

-- Updates the actual store value(s) (should only be used every 90-120 seconds)
-- either Leaderboard:UpdateStoreValues(nil, userId, value) or Leaderboard:UpdateStoreValues({"Daily", "Weekly"}, userId, value
--[=[
	@within Leaderboard
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
	SmartAssert(type(boardTypes) == "table" or type(boardTypes) == "string", "BoardTypes must be a table or a string");

	-- If boardTypes is all, update all the boards
	if (boardTypes == "All") then
		boardTypes = self._types;
	end;

	for boardType in boardTypes do
		local BoardClass = self._boards[boardType] :: Board;
		if (not BoardClass) then
			self._logger:Log(3, `Board Type "{boardType}" does not exist for user {userId}`);
			continue;
		end;

		BoardClass:Update(userId, value);
	end;
end

-- Destroys the leaderboard
--[=[
	@within Leaderboard
	Destroys the leaderboard
]=]
function Leaderboard:Destroy()
	if (not self._isSaving and not self._isFetching) then
		local TimeSinceLastSaved = tick() - self._lastSaved;
		local TimeSinceLastFetch = tick() - self._lastFetch;

		--[[
			If the lastSave was more than 2m ago and the lastFetch was more than 2m ago, OR the lastFetch was 0 and the lastSave was 0, then we should save the values
			This is to prevent us saving the values if we just recently ran an operation
			Unfortunately this is all we can do, and yes there could potentially be some people who don't get saved in the very last cycle
		--]]
		if ((TimeSinceLastSaved >= 60 * 2 and TimeSinceLastFetch >= 60 * 2) or (self._lastFetch == 0 and self._lastSaved == 0)) then
			self._logger:Log(1, "Leaderboard:Destroy() Saving values");
			self:SaveValues();
		end;
	end;

	-- Destroy Trove (this will cleanup boards, threads, connections, signals, and logger)
	self._trove:Destroy();

	-- Remove from leaderboards
	if (Leaderboards[self._serviceKey]) then
		Leaderboards[self._serviceKey] = nil;
	end;

	-- Destroy the metatable
	setmetatable(self, nil);
end

-- Bind to close, destroy all the leaderboards
game:BindToClose(function()
	for _, GlobalBoard in Leaderboards do
		Spawn(function()
			GlobalBoard:Destroy();
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

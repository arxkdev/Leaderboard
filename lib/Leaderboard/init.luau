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
	@field _isSaving {[LeaderboardType]: boolean}
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
	_isSaving: {[LeaderboardType]: boolean},
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
	@field SaveValues (self: Leaderboard, boardType: LeaderboardType?) -> Promise.TypedPromise<number>
	@field Destroy (self: Leaderboard) -> ()
	@field new (leaderboardTypes: LeaderboardTypeArgument, debugMode: boolean?) -> Leaderboard
]=]
type Object = {
	__index: Object,
	IncrementValues: (self: Leaderboard, boardTypes: {LeaderboardType} | string, userId: number, amount: number) -> (),
	SetValues: (self: Leaderboard, boardTypes: {LeaderboardType} | string, userId: number, value: number | (number) -> (number)) -> (),
	UpdateStoreValues: (self: Leaderboard, boardTypes: {LeaderboardType} | string, userId: number, value: number | (number) -> (number)) -> (),
	GetRecords: (self: Leaderboard, boardTypes: {LeaderboardType} | string, optionalRange: {[LeaderboardType | string]: number} | number, sortDirection: string) -> Promise.TypedPromise<{AllTopData}>,
	SaveValues: (self: Leaderboard, boardType: LeaderboardType?) -> Promise.TypedPromise<number>,
	Destroy: (self: Leaderboard) -> (),
	new: (leaderboardTypes: LeaderboardTypeArgument, debugMode: boolean?) -> Leaderboard,
}

type Board = Board.Board;

--[=[
	@within Leaderboard
	@interface BoardConfig
	@field Name string
	@field Automation boolean?
	@field MaxRecords number?
	@field DisplayCount number?
	@field SaveInterval number?
	@field RefreshInterval number?
	@field Shards number?
]=]
export type BoardConfig = {
	Name: string,
	Automation: boolean?,
	MaxRecords: number?,
	DisplayCount: number?,
	SaveInterval: number?,
	RefreshInterval: number?,
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
				if (boardConfig.MaxRecords ~= nil) then
					SmartAssert(type(boardConfig.MaxRecords) == "number", "BoardConfig.MaxRecords must be a number");
				end;
				if (boardConfig.DisplayCount ~= nil) then
					SmartAssert(type(boardConfig.DisplayCount) == "number", "BoardConfig.DisplayCount must be a number");
				end;
				if (boardConfig.SaveInterval ~= nil) then
					SmartAssert(type(boardConfig.SaveInterval) == "number", "BoardConfig.SaveInterval must be a number");
				end;
				if (boardConfig.RefreshInterval ~= nil) then
					SmartAssert(type(boardConfig.RefreshInterval) == "number", "BoardConfig.RefreshInterval must be a number");
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
	self._isSaving = {};
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

	-- Collect all board types with automation enabled for refresh loops
	local automationBoards: {{
		boardType: LeaderboardType,
		refreshInterval: number,
		displayCount: number,
	}} = {};
	local boardTypeIndex = 0;
	
	for boardType, normalizedConfig in normalizedConfigs do
		local boardConfig = normalizedConfig.Config;
		if (boardConfig and boardConfig.Automation) then
			local refreshInterval = boardConfig.RefreshInterval or 600;
			local displayCount = boardConfig.DisplayCount or 50;
			boardTypeIndex += 1;
			
			table.insert(automationBoards, {
				boardType = boardType,
				refreshInterval = refreshInterval,
				displayCount = displayCount,
			});
			
			-- Start refresh loop for this board type with staggered delay
			local capturedBoardType = boardType;
			local staggerDelay = (boardTypeIndex - 1) * 0.5; -- Stagger by 0.5 seconds per board type
			
			local refreshThread = Spawn(function()
				-- Initial stagger delay
				if (staggerDelay > 0) then
					task.wait(staggerDelay);
				end;
				
				local lastRefreshTime = 0;
				while (true) do
					local currentTime = tick();
					
					-- Refresh records if RefreshInterval has passed
					if (currentTime - lastRefreshTime >= refreshInterval) then
						-- Get the top and update the signal for this specific board type
						local TopData = self:GetRecords({[capturedBoardType] = true}, displayCount):awaitValue() :: {AllTopData};
						if (TopData and #TopData > 0) then
							self.Updated:Fire(TopData);
							for _, board in TopData do
								self.BoardUpdated:Fire(board);
							end;
						end;
						lastRefreshTime = currentTime;
					end;
					
					-- Wait until next refresh check
					local timeUntilNextRefresh = math.max(0.1, refreshInterval - (currentTime - lastRefreshTime));
					task.wait(timeUntilNextRefresh);
				end;
			end);
			-- Add thread to Trove for cleanup
			self._trove:Add(refreshThread);
		end;
	end;
	
	-- Start save loops for each board type based on their SaveInterval
	-- Each board processes all its queued items when its SaveInterval elapses
	for boardType, normalizedConfig in normalizedConfigs do
		local boardConfig = normalizedConfig.Config;
		local saveInterval = boardConfig and boardConfig.SaveInterval or 60; -- Default to 60 seconds if not specified
		
		-- Start save loop for this board type
		local capturedBoardType = boardType;
		local saveThread = Spawn(function()
			while (true) do
				-- Wait for the SaveInterval
				task.wait(saveInterval);
				
				-- Process all queued items for this board type
				-- Await the promise to ensure processing completes before the next interval
				self:SaveValues(capturedBoardType):awaitValue();
			end;
		end);
		-- Add thread to Trove for cleanup (Trove will cancel it when destroyed)
		self._trove:Add(saveThread);
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

-- Processes all items in the queue for a specific board type (or all boards if boardType is nil)
--[=[
	@within Leaderboard
	@param boardType LeaderboardType? -- Optional board type to filter by. If nil, processes all boards.
	@return Promise.TypedPromise<number> -- Returns the number of items processed
	@yields
	Processes all items in the value queue for the specified board type (or all boards if nil).
	Continues processing until the queue is empty for that board type.
]=]
function Leaderboard:SaveValues(boardType: LeaderboardType?)
	-- Determine which board types to lock
	-- If boardType is specified, only lock that specific board type
	-- If boardType is nil, lock all board types (since we'll process items from all boards)
	local boardTypesToLock: {LeaderboardType} = {};
	if (boardType) then
		-- Single board type: only check and lock that one
		if (self._isSaving[boardType]) then
			return Promise.resolve(0);
		end;
		table.insert(boardTypesToLock, boardType);
	else
		-- All boards: check if ANY board type is saving, and lock ALL board types
		for bt in self._types do
			if (self._isSaving[bt]) then
				return Promise.resolve(0);
			end;
			table.insert(boardTypesToLock, bt);
		end;
	end;
	
	-- Set saving flags for all relevant board types
	-- This prevents concurrent processing of the same board type(s)
	for _, bt in boardTypesToLock do
		self._isSaving[bt] = true;
	end;
	
	return Promise.new(function(resolve)
		local processedCount = 0;
		
		-- Process items one by one until queue is empty for the specified board type
		-- Continue processing until no more items are found
		while (true) do
			-- Find the next item in the queue matching the board type filter
			local userIdToProcess: number? = nil;
			local boardTypeToProcess: LeaderboardType? = nil;
			local dataToProcess: {Amount: number | ((number) -> number), Board: Board, OperationType: OperationType}? = nil;
			
			-- Iterate through queue to find first item matching the filter
			for userId, boardTypes in self._valueQueue do
				for boardTypeKey, data in boardTypes do
					-- If boardType is specified, only process items for that board type
					-- If boardType is nil, process all items
					if (not boardType or boardTypeKey == boardType) then
						userIdToProcess = userId;
						boardTypeToProcess = boardTypeKey;
						dataToProcess = data;
						break;
					end;
				end;
				if (userIdToProcess) then
					break;
				end;
			end;
			
			-- If no items found, we're done
			if (not userIdToProcess or not boardTypeToProcess or not dataToProcess) then
				break;
			end;
			
			-- CRITICAL: Remove item from queue IMMEDIATELY before processing
			-- This prevents race conditions where multiple threads process the same item
			local boardRef = dataToProcess.Board;
			local operationType = dataToProcess.OperationType;
			local amount = dataToProcess.Amount;
			
			-- Remove from queue immediately
			if (self._valueQueue[userIdToProcess]) then
				self._valueQueue[userIdToProcess][boardTypeToProcess] = nil;
				-- If no more boardTypes for this userId, remove the userId entry entirely
				local hasRemainingBoards = false;
				for _ in self._valueQueue[userIdToProcess] do
					hasRemainingBoards = true;
					break;
				end;
				if (not hasRemainingBoards) then
					self._valueQueue[userIdToProcess] = nil;
				end;
			end;
			
			-- Process the item using stored references (item already removed from queue)
			local updatePromise = boardRef:Update(userIdToProcess, function(oldValue)
				if (operationType == "Set") then
					-- Set operation: use the value/function directly
					if (type(amount) == "function") then
						return amount(oldValue);
					else
						return amount;
					end;
				elseif (operationType == "Increment") then
					-- Increment operation: add the amount
					if (type(amount) == "function") then
						return oldValue + amount(oldValue);
					else
						return oldValue + amount;
					end;
				else
					self._logger:Log(3, `Invalid operation type: {operationType} for user {userIdToProcess}`);
					return oldValue;
				end;
			end);
			
			-- Await the update promise
			local success, result = pcall(function()
				return updatePromise:awaitValue();
			end);
			
			if (success) then
				processedCount += 1;
			else
				self._logger:Log(3, `Error updating value for user {userIdToProcess} in board {boardTypeToProcess}: {result}`);
				-- On error, re-add the item to the queue for retry
				-- This ensures failed items can be retried
				if (not self._valueQueue[userIdToProcess]) then
					self._valueQueue[userIdToProcess] = {};
				end;
				self._valueQueue[userIdToProcess][boardTypeToProcess] = {
					Amount = amount,
					Board = boardRef,
					OperationType = operationType,
				};
			end;
			
			-- Wait 1 second between each save operation to respect rate limits
			task.wait(1);
		end;
		
		-- Reset flags for all relevant board types and return count
		for _, bt in boardTypesToLock do
			self._isSaving[bt] = false;
		end;
		self._lastSaved = tick();
		resolve(processedCount);
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
		-- Update the value queue
		if (not Queue[boardType]) then
			Queue[boardType] = {
				Amount = amount,
				Board = self._boards[boardType],
				OperationType = "Increment",
			};
		else
			Queue[boardType].Amount += amount;
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
	-- Cancel all save threads first by cleaning Trove (which cancels threads/connections but doesn't destroy resources)
	-- This ensures threads sleeping on task.wait() are woken up immediately
	-- Using Clean() instead of Destroy() so resources aren't destroyed yet
	self._trove:Clean();
	
	-- Wait for any in-flight SaveValues() to complete for all board types
	-- Poll until all board types are done saving or timeout after 2 seconds
	local waitStart = tick();
	local anySaving = true;
	while (anySaving and (tick() - waitStart) < 2) do
		anySaving = false;
		-- Check if any board type is still saving
		for boardType in self._types do
			if (self._isSaving[boardType]) then
				anySaving = true;
				break;
			end;
		end;
		if (anySaving) then
			task.wait(0.05);
		end;
	end;
	
	-- CRITICAL: Reset any stuck flags from cancelled SaveValues() operations
	-- If threads were cancelled mid-operation, flags may still be set to true
	-- This prevents Bug 1 where final SaveValues() call is skipped
	for boardType in self._types do
		if (self._isSaving[boardType]) then
			self._isSaving[boardType] = false;
		end;
	end;
	
	if (anySaving) then
		if (self._logger) then
			self._logger:Log(2, "Leaderboard:Destroy() Save operation still in progress after cancellation wait");
		end;
	end;
	
	-- Check if any board type is still saving (should be false now after reset)
	local anySavingFinal = false;
	for boardType in self._types do
		if (self._isSaving[boardType]) then
			anySavingFinal = true;
			break;
		end;
	end;
	
	if (not anySavingFinal and not self._isFetching) then
		local TimeSinceLastSaved = tick() - self._lastSaved;
		local TimeSinceLastFetch = tick() - self._lastFetch;

		--[[
			If the lastSave was more than 2m ago and the lastFetch was more than 2m ago, OR the lastFetch was 0 and the lastSave was 0, then we should save the values
			This is to prevent us saving the values if we just recently ran an operation
			Unfortunately this is all we can do, and yes there could potentially be some people who don't get saved in the very last cycle
		--]]
		if ((TimeSinceLastSaved >= 60 * 2 and TimeSinceLastFetch >= 60 * 2) or (self._lastFetch == 0 and self._lastSaved == 0)) then
			if (self._logger) then
				self._logger:Log(1, "Leaderboard:Destroy() Saving values");
			end;
			-- Process all remaining items in the queue (no board type filter = all boards)
			-- Flags have been reset, so this will proceed normally
			local processedCount = self:SaveValues():awaitValue();
			if (processedCount > 0 and self._logger) then
				self._logger:Log(1, `Leaderboard:Destroy() Processed {processedCount} items`);
			end;
		end;
	end;

	-- Now destroy Trove (which will destroy all managed resources: signals, logger, boards)
	-- This is safe because we haven't manually destroyed anything yet
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

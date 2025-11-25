--[[
	Arxk was here
]]

-- DataStoreService to handle longer than 42 days (all time most likely)
local DataStoreService = game:GetService("DataStoreService");

-- Requirements
local Packages = script.Parent:FindFirstChild("Packages") or script.Parent.Parent; -- Development Wally places packages in script.Parent/Packages; Production Wally places packages in script.Parent.Parent
local MemoryShard = require(script.MemoryShard);
local Manifest = require(script.Manifest);
local Promise = require(Packages.Promise);
local Trove = require(Packages.Trove);
local Util = require(script.Parent.Util);
local Logger = require(script.Parent.Logger);
local UserIdsCache = require(script.Parent.UserIdCache);
local Backoff = require(Packages.Backoff);

-- Variables
local Compression = Util.Compression;
local SmartAssert = Util.SmartAssert;
local Cancel = task.cancel;
local Spawn = task.spawn;

-- Constants
local OFFLINE_ENVIRONMENT = game.GameId == 0;
local SHARD_COUNTS = Util.SHARD_COUNTS;

-- Supports Daily, Weekly, Monthly and AllTime currently
--[=[
    @within Board
    @type LeaderboardType "Hourly" | "Daily" | "Weekly" | "Monthly" | "Yearly" | "AllTime" | "Rolling" | string
]=]
export type LeaderboardType = "Hourly" | "Daily" | "Weekly" | "Monthly" | "Yearly" | "AllTime" | "Rolling" | string;

--[=[
    @within Board
    @type Board () -> Board
]=]
export type Board = typeof(setmetatable({} :: BoardArguments, {} :: Object));

--[=[
	@within Board
	@interface BoardArguments
	@field _boardKey string
	@field _storeUsing string
	@field _store (MemoryStoreSortedMap | OrderedDataStore | MemoryShard)?
]=]
export type BoardArguments = {
	_type: LeaderboardType,
	_boardKey: string,
	_storeUsing: string,
	_store: (MemoryStoreSortedMap | OrderedDataStore | MemoryShard)?,
	_logger: Logger.Logger?,
	_boardConfig: BoardConfig?,
	_maxRecords: number?,
}

--[=[
	@within Board
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

type MemoryShard = MemoryShard.MemoryShard;

--[=[
	@within Board
	@interface Object
	@field __index Object
	@field Update (self: Board, userId: number, value: number | (number) -> (number)) -> Promise.TypedPromise<boolean>
	@field Get (self: Board, amount: number, sortDirection: string) -> Promise.TypedPromise<{TopData}>
	@field Destroy (self: Board) -> ()
	@field new (boardKey: string, leaderboardType: LeaderboardType, rollingExpiry: number?, debugMode: boolean?) -> Board
]=]
type Object = {
	__index: Object,
	Trove: typeof(Trove.new),
	Update: (self: Board, userId: number, value: number | (number) -> (number)) -> Promise.TypedPromise<boolean>,
	Get: (self: Board, amount: number, sortDirection: string) -> Promise.TypedPromise<{TopData}>,
	Destroy: (self: Board) -> (),
	new: (boardKey: string, leaderboardType: LeaderboardType, rollingExpiry: number?, debugMode: boolean?) -> Board,
}

--[=[
	@class Board

	This class is used to create a new leaderboard board.
]=]
local Board: Object = {} :: Object;
Board.__index = Board;

local function Transform(rank: number, key: number, value: number): TopData
	return {
		Rank = rank,
		Value = Compression.Decompress(value),
		UserId = key,
		Username = UserIdsCache:GetNameFromUserId(key),
		DisplayName = "Not supported yet",
	};
end

-- local function GetRequestBudget(typeOfBudget: Enum.DataStoreRequestType): number
-- 	return DataStoreService:GetRequestBudgetForRequestType(typeOfBudget);
-- end

local function ShardCalculation(rollingExpiry: number): number
	return math.round(
		math.max(
			1,
			math.log10(rollingExpiry) - 3
		)
	);
end

local function GetCurrentId(leaderboardType: string)
	local CurrentHour = DateTime.now():ToUniversalTime().Hour;
	local CurrentDay = DateTime.now():ToUniversalTime().Day;
	local CurrentWeek = math.floor(os.date("!*t")["yday"] / 7);
	local CurrentMonth = DateTime.now():ToUniversalTime().Month;
	local CurrentYear = DateTime.now():ToUniversalTime().Year;

	return leaderboardType == "Hourly" and CurrentHour or leaderboardType == "Daily" and CurrentDay or leaderboardType == "Weekly" and CurrentWeek or leaderboardType == "Monthly" and CurrentMonth or leaderboardType == "Yearly" and CurrentYear or "AllTime" and "AllTime";
end

type BoardConfig = {
	Name: string,
	Automation: boolean?,
	MaxRecords: number?,
	DisplayCount: number?,
	SaveInterval: number?,
	RefreshInterval: number?,
	Shards: number?,
}

local function ConstructStore(boardKey: string, leaderboardType: LeaderboardType, rollingExpiry: number?, boardConfig: BoardConfig?, debugMode: boolean?): (string, (MemoryStoreSortedMap | OrderedDataStore | MemoryShard)?)
	-- print(rollingExpiry);
	-- if (leaderboardType == "Hourly" or leaderboardType == "Daily" or leaderboardType == "Weekly" or leaderboardType == "Monthly" or leaderboardType == "Yearly") then
	-- 	return "OrderedDataStore", DataStoreService:GetOrderedDataStore(`{GetCurrentId(leaderboardType)}-{boardKey}`);
	-- end;

	-- If we are using a MemoryStore, we can just update the data
	-- Not a viable solution anymore, limits are too poor
	if (leaderboardType ~= "AllTime" or rollingExpiry) then
		local maxRecords = boardConfig and boardConfig.MaxRecords or Manifest.DEFAULT_RECORD_COUNT;
		local shardCount: number;
		
		if (boardConfig and boardConfig.Shards) then
			-- Use provided shard count
			shardCount = boardConfig.Shards;
		elseif (rollingExpiry) then
			-- Use rolling expiry calculation
			shardCount = ShardCalculation(rollingExpiry);
		elseif (boardConfig and boardConfig.MaxRecords) then
			-- Calculate shard count from max records
			shardCount = Manifest.CalculateShardCount(maxRecords);
		else
			-- Fall back to default shard counts
			shardCount = SHARD_COUNTS[leaderboardType] or 1;
		end;
		
		return "MemoryStore", MemoryShard.new(leaderboardType, boardKey, shardCount, maxRecords, rollingExpiry, debugMode);
	end;

	-- If we are in an offline enviornment
	if (OFFLINE_ENVIRONMENT) then
		return "OrderedDataStore", {} :: any
	end;

	local Success, Result = pcall(function()
		return DataStoreService:GetOrderedDataStore(boardKey);
	end);
	if (not Success) then
		warn(`Failed to create OrderedDataStore for "{boardKey}": {Result}`);
		return "OrderedDataStore", {} :: any
	end;

	return "OrderedDataStore", Result;
end

--[=[
	@within Board
	@param boardKey string
	@param leaderboardType LeaderboardType
	@param rollingExpiry number?
	@param boardConfig BoardConfig?
	@param debugMode boolean?
	@return Board

	Creates a new board within the Leaderboard.
]=]
function Board.new(boardKey: string, leaderboardType: LeaderboardType, rollingExpiry: number?, boardConfig: BoardConfig?, debugMode: boolean?): Board
	local self = setmetatable({} :: BoardArguments, Board);

	self._boardKey = boardKey;
	self._storeType, self._store = ConstructStore(boardKey, leaderboardType, rollingExpiry, boardConfig, debugMode);
	self._logger = Logger.new(`Board-{boardKey}`, debugMode or false);
	self._trove = Trove.new();
	self._boardConfig = boardConfig;
	self._maxRecords = boardConfig and boardConfig.MaxRecords or Manifest.DEFAULT_RECORD_COUNT;

	-- New implementation: we just check if the current id is different from the previous one
	if (leaderboardType == "Hourly" or leaderboardType == "Daily" or leaderboardType == "Weekly" or leaderboardType == "Monthly" or leaderboardType == "Yearly") then
		self._trove:Add(function()
			local CurrentId = GetCurrentId(leaderboardType);
			while (true) do
				local NewId = GetCurrentId(leaderboardType);
				if (NewId ~= CurrentId) then
					CurrentId = NewId;
					self._storeType, self._store = ConstructStore(boardKey, leaderboardType, nil, boardConfig, debugMode);
				end;
				task.wait(5);
			end;
		end);
	end;

	-- Start periodic cleanup for OrderedDataStore
	if (not OFFLINE_ENVIRONMENT and self._storeType == "OrderedDataStore" and self._store) then
		self._trove:Add(task.spawn(function()
			-- Wait a bit before starting cleanup to let the board initialize
			task.wait(60);
			
			while (true) do
				-- Cleanup interval: every 10 minutes (similar to MemoryShard cleanup frequency)
				task.wait(600);
				
				-- Use pcall to handle cleanup failures gracefully (rate limits, etc.)
				-- Other servers will also help clean up over time
				local success, err = pcall(function()
					self:_cleanupOrderedDataStore():await();
				end);
				if (not success) then
					self._logger:Log(3, `OrderedDataStore cleanup cycle pcall failed: {err}`);
				end;
			end;
		end));
		
		self._logger:Log(1, `Started OrderedDataStore cleanup thread for {boardKey} with max {self._maxRecords} records`);
	end;

	return self;
end

-- Gets the top data for a specific board
--[=[
	@within Board
	@param amount number
	@param sortDirection string?
	@return Promise.TypedPromise<{TopData}>
	@yields

	Gets the top data for a specific board.
]=]
function Board:Get(amount, sortDirection)
	SmartAssert(type(amount) == "number", "Amount must be a number");
	SmartAssert(amount <= 100, "You can only get the top 100.");
	SmartAssert(amount > 0, "Amount must be greater than 0");
	SmartAssert(type(sortDirection) == "nil" or typeof(sortDirection) == "string", "SortDirection must be a string");
	sortDirection = sortDirection or "Descending";

	return Promise.new(function(resolve, reject)
		local Success, Result = pcall(function()
			if (OFFLINE_ENVIRONMENT) then
				return {} :: { TopData }
			end;

			if (self._storeType == "MemoryStore") then
				-- Use Backoff to retry Get with exponential backoff
				local backoffSuccess, backoffResult = Backoff.exponentialAsync(function()
					local success, result = pcall(function()
						return self._store:Get(amount, sortDirection):awaitValue();
					end);
					if (not success) then
						return false, result; -- Return (false, error) on failure
					end;
					return true, result; -- Return (true, result) on success
				end, {
					maxRetries = 3,
					minInterval = 0.5,
					maxInterval = 5,
					exponentBase = 2,
					onSuccess = function(attempt, result)
						if attempt > 1 then
							self._logger:Log(1, `MemoryStore Get success on attempt {attempt} for "{self._boardKey}"`)
						end
					end,
					onRetry = function(attempt, lastError, nextWaitSeconds)
						self._logger:Log(2, `Retrying MemoryStore Get for "{self._boardKey}" (attempt {attempt}) after {nextWaitSeconds}s: {lastError}`);
					end,
					onGiveUp = function(attempt, lastError)
						self._logger:Log(3, `Failed to get data from MemoryStore for "{self._boardKey}" after {attempt} attempts: {lastError}`);
					end,
				});
				
				if (not backoffSuccess) then
					error(backoffResult); -- Throw error to be caught by outer pcall
				end;
				
				local Result = backoffResult;
				local Promises = {};
				for rank, data in pairs(Result) do
					table.insert(Promises, Promise.new(function(resolve)
						resolve(Transform(rank, data.key, data.value))
					end));
				end;
				return Promise.all(Promises):awaitValue() :: { TopData };
			else -- TODO: This will be where DataStoreShards are used. Make sure that's explicitly stated.
				-- local RequestBudget = GetRequestBudget(Enum.DataStoreRequestType.GetSortedAsync);
				-- if (RequestBudget < 1) then
				-- 	warn(`Skipping getting top data for {self._boardKey} due to insufficient budget`);
				-- 	return {};
				-- end;
				-- Use Backoff to retry GetSortedAsync with exponential backoff
				local backoffSuccess, backoffResult = Backoff.exponentialAsync(function()
					local success, result = pcall(function()
						return self._store:GetSortedAsync(sortDirection ~= "Descending", amount);
					end);
					if (not success) then
						return false, result; -- Return (false, error) on failure
					end;
					return true, result; -- Return (true, result) on success
				end, {
					maxRetries = 3,
					minInterval = 0.5,
					maxInterval = 5,
					exponentBase = 2,
					onSuccess = function(attempt, result)
						if attempt > 1 then
							self._logger:Log(1, `GetSortedAsync success on attempt {attempt} for "{self._boardKey}"`)
						end
					end,
					onRetry = function(attempt, lastError, nextWaitSeconds)
						self._logger:Log(2, `Retrying GetSortedAsync for "{self._boardKey}" (attempt {attempt}) after {nextWaitSeconds}s: {lastError}`);
					end,
					onGiveUp = function(attempt, lastError)
						self._logger:Log(3, `Failed to get sorted data for "{self._boardKey}" after {attempt} attempts: {lastError}`);
					end,
				});
				
				if (not backoffSuccess) then
					error(backoffResult); -- Throw error to be caught by outer pcall
				end;
				
				local Result = backoffResult;
				local Data = Result:GetCurrentPage() :: {any};
				local Promises = {};
				for rank, data in pairs(Data) do
					table.insert(Promises, Promise.new(function(resolve)
						resolve(Transform(rank, data.key, data.value))
					end));
				end;
				return Promise.all(Promises):awaitValue() :: { TopData };
			end;
		end);

		if (not Success) then
			warn(`Leaderboard had trouble getting top data with error: {Result}`);
			return reject(Result);
		end;
		return resolve(Result);
	end) :: Promise.TypedPromise<{ TopData }>;
end

-- Updates the data for a specific board (either MemoryStore (Shards), or OrderedDataStore)
--[=[
	@within Board
	@param userId number
	@param value number | (number) -> (number)
	@return Promise.TypedPromise<boolean>
	@yields

	Updates the data for a specific board (either MemoryStore (Shards), or OrderedDataStore).
]=]
function Board:Update(userId, value)
	SmartAssert(type(userId) == "number", "UserId must be a number");
	SmartAssert(type(value) == "function" or type(value) == "number", "Transformer must be a function or a number");

	-- If we are using a MemoryStore, we can just update the data
	if (self._storeType == "MemoryStore") then
		self._logger:Log(1, `Successfully updated data for {userId} in "{self._boardKey}"`);
		return self._store:Set(userId, value);
	end;

	-- local Budget = GetRequestBudget(Enum.DataStoreRequestType.UpdateAsync);
	-- if (Budget < 1) then
	-- 	warn(`Skipping updating data for {userId} in {self._boardKey} due to insufficient budget`);
	-- 	return false;
	-- end;

	-- Using an actual DataStore, we need to set the data
	return Promise.new(function(resolve, reject)
		local Success, Result = pcall(function()
			if (OFFLINE_ENVIRONMENT) then
				return;
			end;

			return self._store:UpdateAsync(userId, function(oldValue)
				oldValue = oldValue and Compression.Decompress(oldValue) or 0;
				local TransformedValue = (type(value) == "function") and value(oldValue) or value;

				-- If their oldValue is greater than the new value, we don't want to update it
				if (oldValue > TransformedValue) then
					return nil;
				end;

				if (type(TransformedValue) == "number") then
					return Compression.Compress(TransformedValue);
				end;
				return nil;
			end);
		end);

		if (not Success) then
			warn(`Leaderboard had trouble updating data with error: {Result}`);
			return reject(Result);
		end;

		self._logger:Log(1, `Successfully updated data for "{userId}" in "{self._boardKey}"`);
		return resolve(Result);
	end) :: Promise.TypedPromise<boolean>;
end

--[=[
	@private
	@return Promise.TypedPromise<boolean>
	@yields

	Cleans up excess entries from OrderedDataStore using GetSortedAsync with pagination.
	Removes entries beyond MaxRecords limit, using 1-second delay between deletes.
]=]
function Board:_cleanupOrderedDataStore()
	return Promise.new(function(resolve, reject)
		local success, err = pcall(function()
			if (OFFLINE_ENVIRONMENT or not self._store or self._storeType ~= "OrderedDataStore") then
				return resolve(false);
			end;

			local maxRecords = self._maxRecords or Manifest.DEFAULT_RECORD_COUNT;
			
			-- Get sorted data with pagination, using pagesize up to MaxRecords
			-- This gives us the top MaxRecords entries (which we want to keep)
			local success, pages = pcall(function()
				return self._store:GetSortedAsync(false, maxRecords); -- false = Descending
			end);
			
			if (not success) then
				self._logger:Log(3, `Failed to get sorted data for cleanup: {pages}`);
				return resolve(false);
			end;
			
			-- If there are no more pages, we're done (all entries are within MaxRecords)
			if (pages.IsFinished) then
				return resolve(true);
			end;
			
			-- Now start removing entries beyond MaxRecords
			-- Advance to next page and remove all entries from subsequent pages
			local removedCount = 0;
			local currentPage = pages;
			
			-- Process remaining pages and remove entries
			while (not currentPage.IsFinished) do
				-- Advance to next page
				local advanceSuccess, advanceErr = pcall(function()
					currentPage:AdvanceToNextPageAsync();
				end);
				
				if (not advanceSuccess) then
					-- Rate limit or error, stop cleanup (other servers will help)
					self._logger:Log(2, `Stopped cleanup due to advance error (rate limit?): {advanceErr}`);
					break;
				end;
				
				local pageData = currentPage:GetCurrentPage();
				
				-- Remove each entry on this page with 1-second delay between deletes
				for _, entry in pageData do
					-- Wait 1 second before each delete (similar to _valueQueue pattern)
					task.wait(1);
					
					local deleteSuccess, deleteErr = pcall(function()
						return self._store:RemoveAsync(entry.key);
					end);
					
					if (deleteSuccess) then
						removedCount += 1;
					else
						-- Rate limit or error, stop cleanup (other servers will help)
						self._logger:Log(2, `Stopped cleanup due to delete error (rate limit?): {deleteErr}`);
						return resolve(true);
					end;
				end;
			end;
			
			if (removedCount > 0) then
				self._logger:Log(1, `Cleaned up {removedCount} excess entries from OrderedDataStore "{self._boardKey}"`);
			end;
			
			return resolve(true);
		end);
		
		if (not success) then
			self._logger:Log(3, `OrderedDataStore cleanup failed: {err}`);
			return resolve(false); -- Don't reject, just log and continue
		end;
	end);
end

-- Destroys the board
--[=[
	@within Board
	Destroys the board.
]=]
function Board:Destroy()
	-- Destroy the trove
	self._trove:Destroy();

	-- Destroy the store
	if (self._storeType == "MemoryStore") then
		self._store:Destroy();
	end;

	-- Destroy the logger
	self._logger:Destroy();

	-- Destroy the board
	setmetatable(self, nil);
end

-- Make indexing the class with the wrong key throw an error
setmetatable(Board, {
	__index = function(_, key)
		error(`Attempt to get Board:{tostring(key)} (not a valid member)`, 2);
	end,
	__newindex = function(_, key, _)
		error(`Attempt to set Board:{tostring(key)} (not a valid member)`, 2);
	end,
})

return table.freeze({
	new = Board.new,
	Get = Board.Get,
	Update = Board.Update,
	Destroy = Board.Destroy,
})
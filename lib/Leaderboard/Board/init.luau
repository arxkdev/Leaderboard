--[[
	Arxk was here
]]

-- DataStoreService to handle longer than 42 days (all time most likely)
local DataStoreService = game:GetService("DataStoreService");

-- Requirements
local Packages = script.Parent.Parent;
local MemoryShard = require(script.MemoryShard);
local Promise = require(Packages.Promise);
local Util = require(script.Parent.Util);
local Logger = require(script.Parent.Logger);
local UserIdsCache = require(script.Parent.UserIdCache);

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
	@field _threads {thread}
]=]
export type BoardArguments = {
	_type: LeaderboardType,
	_boardKey: string,
	_storeUsing: string,
	_store: (MemoryStoreSortedMap | OrderedDataStore | MemoryShard)?,
	_threads: {thread},
	_logger: Logger.Logger?,
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

local function ConstructStore(boardKey: string, leaderboardType: LeaderboardType, rollingExpiry: number?): (string, (MemoryStoreSortedMap | OrderedDataStore | MemoryShard)?)
	-- print(rollingExpiry);
	-- if (leaderboardType == "Hourly" or leaderboardType == "Daily" or leaderboardType == "Weekly" or leaderboardType == "Monthly" or leaderboardType == "Yearly") then
	-- 	return "OrderedDataStore", DataStoreService:GetOrderedDataStore(`{GetCurrentId(leaderboardType)}-{boardKey}`);
	-- end;

	-- If we are using a MemoryStore, we can just update the data
	-- Not a viable solution anymore, limits are too poor
	if (leaderboardType ~= "AllTime" or rollingExpiry) then
		local ShardCount = rollingExpiry and ShardCalculation(rollingExpiry) or SHARD_COUNTS[leaderboardType];
		return "MemoryStore", MemoryShard.new(leaderboardType, boardKey, ShardCount, rollingExpiry);
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
	@param boardKey string
	@param leaderboardType LeaderboardType
	@param rollingExpiry number?
	@param debugMode boolean?
	@return Board

	Creates a new board within the Leaderboard.
]=]
function Board.new(boardKey: string, leaderboardType: LeaderboardType, rollingExpiry: number?, debugMode: boolean?): Board
	local self = setmetatable({} :: BoardArguments, Board);

	self._boardKey = boardKey;
	self._storeType, self._store = ConstructStore(boardKey, leaderboardType, rollingExpiry);
	self._threads = {};
	self._logger = Logger.new(`Board-{boardKey}`, debugMode or false);

	-- New implementation: we just check if the current id is different from the previous one
	if (leaderboardType == "Hourly" or leaderboardType == "Daily" or leaderboardType == "Weekly" or leaderboardType == "Monthly" or leaderboardType == "Yearly") then
		table.insert(self._threads, Spawn(function()
			local CurrentId = GetCurrentId(leaderboardType);
			while (true) do
				local NewId = GetCurrentId(leaderboardType);
				if (NewId ~= CurrentId) then
					CurrentId = NewId;
					self._storeType, self._store = ConstructStore(boardKey, leaderboardType);
				end;
				task.wait(5);
			end;
		end));
	end;

	return self;
end

-- Gets the top data for a specific board
--[=[
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

	local function RetrieveTopData()
		if (OFFLINE_ENVIRONMENT) then
			return {} :: { TopData }
		end;

		if (self._storeType == "MemoryStore") then
			local Result = self._store:Get(amount, sortDirection):awaitValue();
			local Promises = {};
			for rank, data in pairs(Result) do
				table.insert(Promises, Promise.new(function(resolve)
					resolve(Transform(rank, data.key, data.value))
				end));
			end;
			return Promise.all(Promises):awaitValue() :: { TopData };
		else
			-- local RequestBudget = GetRequestBudget(Enum.DataStoreRequestType.GetSortedAsync);
			-- if (RequestBudget < 1) then
			-- 	warn(`Skipping getting top data for {self._boardKey} due to insufficient budget`);
			-- 	return {};
			-- end;
			local Result = self._store:GetSortedAsync(sortDirection ~= "Descending", amount);
			local Data = Result:GetCurrentPage() :: {any};
			local Promises = {};
			for rank, data in pairs(Data) do
				table.insert(Promises, Promise.new(function(resolve)
					resolve(Transform(rank, data.key, data.value))
				end));
			end;
			return Promise.all(Promises):awaitValue() :: { TopData };
		end;
	end;

	return Promise.new(function(resolve, reject)
		local Success, Result = pcall(function()
			return RetrieveTopData();
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
	@param userId number
	@param value number | (number) -> (number)
	@yields
	@return boolean

	Updates the data for a specific board (either MemoryStore (Shards), or OrderedDataStore).
]=]
function Board:Update(userId, value)
	SmartAssert(type(userId) == "number", "UserId must be a number");
	SmartAssert(type(value) == "function" or type(value) == "number", "Transformer must be a function or a number");

	-- If we are using a MemoryStore, we can just update the data
	if (self._storeType == "MemoryStore") then
		self._logger:Log(1, `Successfully updated data for ${userId} in "{self._boardKey}"`);
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

-- Destroys the board
--[=[
	Destroys the board.
]=]
function Board:Destroy()
	-- Destroy the threads
	for _, Thread in self._threads do
		if (typeof(Thread) == "thread") then
			Cancel(Thread);
		end;
	end;

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
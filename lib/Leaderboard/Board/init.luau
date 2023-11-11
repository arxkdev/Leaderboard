--[[
	Arxk was here
]]

-- DataStoreService to handle longer than 42 days (all time most likely)
local DataStoreService = game:GetService("DataStoreService");
local UserService = game:GetService("UserService");
local Players = game:GetService("Players");

-- Requirements
local MemoryShard = require(script.MemoryShard);
local Promise = require(script.Parent.Promise);
local Util = require(script.Parent.Util);

-- Variables
local Compression = Util.Compression;
local SmartAssert = Util.SmartAssert;
local Map = Util.Map;

-- Constants
local SHARD_COUNTS = { -- Feel free to change these based on how many MAU your game does have
	["Hourly"] = 1,
	["Daily"] = 3,
	["Weekly"] = 10,
	["Monthly"] = 15,
}
local DEBUG = false;

-- Supports Daily, Weekly, Monthly and AllTime currently
--[=[
    @within Board
    @type LeaderboardType "Hourly" | "Daily" | "Weekly" | "Monthly" | "Yearly" | "AllTime" | "Rolling"
]=]
export type LeaderboardType = "Hourly" | "Daily" | "Weekly" | "Monthly" | "Yearly" | "AllTime" | "Rolling";

--[=[
    @within Board
    @type Board () -> Board
]=]
export type Board = typeof(setmetatable({} :: BoardArguments, {} :: Object));

--[=[
	@within Board
	@interface BoardArguments
	@field __serviceKey string
	@field __type LeaderboardType
	@field __storeUsing string
	@field __store MemoryStoreSortedMap | OrderedDataStore | MemoryShard
	@field __threads {thread}
]=]
export type BoardArguments = {
	__serviceKey: string,
	__type: LeaderboardType,
	__storeUsing: string,
	__store: MemoryStoreSortedMap | OrderedDataStore | MemoryShard,
	__threads: {thread},
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
	@field new (serviceKey: string, leaderboardType: LeaderboardType, rollingExpiry: number?) -> Board
]=]
type Object = {
	__index: Object,
	Update: (self: Board, userId: number, value: number | (number) -> (number)) -> Promise.TypedPromise<boolean>,
	Get: (self: Board, amount: number, sortDirection: string) -> Promise.TypedPromise<{TopData}>,
	Destroy: (self: Board) -> (),
	new: (serviceKey: string, leaderboardType: LeaderboardType, rollingExpiry: number?) -> Board,
}

-- Start
local UserIdsCache = {}; -- To assign userids {username, displayName}

--[=[
	@class Board

	This class is used to create a new leaderboard board.
]=]
local Board: Object = {} :: Object;
Board.__index = Board;

local function dPrint(...)
	if (DEBUG) then
		warn(`[Leaderboard]`, ...);
	end;
end

local function GetUserInfosFromId(userId: number | string): (string, string)
	if (typeof(userId) == "string") then
		userId = tonumber(userId);
	end;

	-- First, check if the cache contains the name
	if (UserIdsCache[userId]) then
		local Username, DisplayName = unpack(UserIdsCache[userId]);
		return Username, DisplayName;
	end;

	-- Second, check if the user is already connected to the server
	local player = Players:GetPlayerByUserId(userId);
	if (player) then
		UserIdsCache[userId] = {player.Name, player.DisplayName};
		return player.Name, player.DisplayName;
	end;

	-- If all else fails, send a request
	local Success, Result = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync({userId});
	end);
	if (not Success) then
		warn(`Leaderboard had trouble getting user info: {Result}`);
		return "Unknown", "Unknown";
	end;
	local Username = Result[1] and Result[1].Username or "Unknown";
	local DisplayName = Result[1] and Result[1].DisplayName or "Unknown";
	UserIdsCache[userId] = {Username, DisplayName};
	return Username, DisplayName;
end

local function Transform(rank: number, key: number, value: number): TopData
	local Username, DisplayName = GetUserInfosFromId(key);
	return {
		Rank = rank,
		Value = Compression.Decompress(value),
		UserId = key,
		Username = Username,
		DisplayName = DisplayName,
	};
end

local function ShardCalculation(rollingExpiry: number): number
	-- desmos latex: f(x) = \lfloor 1 + 20 \log_{10}(\frac{x}{1.3 \times 10^7}) \rfloor
	return math.floor(math.clamp((1 + 20 * math.log10(rollingExpiry * 0.000013) / math.log10(20)), 1, 30) + 0.5);
end

local function ConstructStore(serviceKey: string, leaderboardType: LeaderboardType, rollingExpiry: number?): (string, MemoryStoreSortedMap | OrderedDataStore | MemoryShard)
	if (leaderboardType ~= "Yearly" and leaderboardType ~= "AllTime") then
		local shardCount = leaderboardType == "Rolling" and ShardCalculation(rollingExpiry) or SHARD_COUNTS[leaderboardType];
		return "MemoryStore", MemoryShard.new(leaderboardType, serviceKey, shardCount, rollingExpiry);
	elseif (leaderboardType == "Yearly") then
		local currentYear = DateTime.now():ToUniversalTime().Year;
		return "OrderedDataStore", DataStoreService:GetOrderedDataStore(`{currentYear}:{serviceKey}`);
	end;

	return "OrderedDataStore", DataStoreService:GetOrderedDataStore(serviceKey);
end

--[=[
	@param serviceKey string
	@param leaderboardType LeaderboardType
	@param rollingExpiry number?
	@return Board

	Creates a new board within the Leaderboard.
]=]
function Board.new(serviceKey: string, leaderboardType: LeaderboardType, rollingExpiry: number?)
	local self = setmetatable({} :: BoardArguments, Board);

	self.__serviceKey = serviceKey;
	self.__storeType, self.__store = ConstructStore(serviceKey, leaderboardType, rollingExpiry);
	self.__threads = {};

	-- If the leaderboard is yearly, we need to check if the year has changed and update the store
	-- Ty Proxus for writing this
	if (leaderboardType == "Yearly") then
		local initialDate = os.date("*t", os.time());
		local isLastMinute = false;

		local thread = task.spawn(function()
			while (true) do
				local currentDate = os.date("*t", os.time());
				local isNewYear = currentDate.year ~= initialDate.year;
				isLastMinute = isLastMinute or (currentDate.yday == 365 and currentDate.hour == 23 and currentDate.min == 59);

				if (isNewYear) then
					initialDate = currentDate;
					isLastMinute = false;
					self.StoreType, self.Store = ConstructStore(serviceKey, leaderboardType);
				end;
				task.wait(if isLastMinute then nil else 30);
			end;
		end);
		table.insert(self.__threads, thread);
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
		if (self.__storeType == "MemoryStore") then
			local Data = self.__store:Get(amount, sortDirection);
			return Data:andThen(function(data)
				return Map(data, function(v, rank) return Transform(rank, v.key, v.value); end) :: {TopData};
			end);
		else
			local Result = self.__store:GetSortedAsync(if sortDirection == "Descending" then false else true, amount);
			local Data = Result:GetCurrentPage() :: {any};
			return Map(Data, function(v, rank) return Transform(rank, v.key, v.value); end) :: {TopData};
		end;
	end;

	return Promise.try(RetrieveTopData)
	:andThen(function(data)
		dPrint(`Successfully retrieved top data for {self.__serviceKey}`, data);
		return data;
	end)
	:catch(function(Error)
		warn(`Leaderboard had trouble getting top data with error: {Error}`);
		return {};
	end) :: Promise.TypedPromise<{TopData}>;
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
	if (self.__storeType == "MemoryStore") then
		dPrint(`Successfully updated data for ${userId} in {self.__serviceKey}`);
		return self.__store:Set(userId, value);
	end;

	-- Using an actual DataStore, we need to set the data
	return Promise.retryWithVariableDelay(function()
		return self.__store:UpdateAsync(userId, function(oldValue)
			oldValue = oldValue and Compression.Decompress(oldValue) or 0;
			local transformedValue = (type(value) == "function") and value(oldValue) or value;

			-- If their oldValue is greater than the new value, we don't want to update it
			if (oldValue > transformedValue) then
				return nil;
			end;

			if (type(transformedValue) == "number") then
				local compressedValue = Compression.Compress(transformedValue);
				return compressedValue;
			end;
			return nil;
		end);
	end, 10, 1, "Exponential"):catch(warn);
end

-- Destroys the board
--[=[
	Destroys the board.
]=]
function Board:Destroy()
	-- Destroy the threads
	for _, thread in self.__threads do
		if (typeof(thread) == "thread") then
			task.cancel(thread);
		end;
	end;
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
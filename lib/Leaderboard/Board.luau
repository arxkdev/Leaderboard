--[[
	Arxk was here
]]

-- DataStoreService to handle longer than 42 days (all time most likely)
local DataStoreService = game:GetService("DataStoreService");
local UserService = game:GetService("UserService");
local Players = game:GetService("Players");

-- Requirements
local Promise = require(script.Parent.Promise);
local MemoryShard = require(script.Parent.MemoryShard);
local Compression = require(script.Parent.Compression);

-- Constants
local SHARD_COUNTS = { -- Feel free to change these based on how many MAU your game does have
	["Hourly"] = 1,
	["Daily"] = 3,
	["Weekly"] = 10,
	["Monthly"] = 15,
}
local DEBUG = false;

-- Supports Daily, Weekly, Monthly and AllTime currently
export type LeaderboardType = "Hourly" | "Daily" | "Weekly" | "Monthly" | "Yearly" | "AllTime" | "Rolling";
export type Board = typeof(setmetatable({} :: BoardArguments, {} :: Object));
export type BoardArguments = {
	__serviceKey: string,
	__type: LeaderboardType,
	__storeUsing: string,
	__store: MemoryStoreSortedMap | OrderedDataStore | MemoryShard,
	__threads: {thread},
}
export type TopData = {
	Rank: number,
	UserId: number,
	Value: number,
	Username: string,
	DisplayName: string,
}

type MemoryShard = MemoryShard.MemoryShard;
type Object = {
	__index: Object,
	Update: (self: Board, userId: number, value: number | (number) -> (number)) -> boolean,
	GetTopData: (self: Board, amount: number, sortDirection: string) -> Promise.TypedPromise<{TopData}>,
	Destroy: (self: Board) -> (),
	new: (serviceKey: string, leaderboardType: LeaderboardType, rollingExpiry: number?) -> Board,
}

-- Start
local UserIdsCache = {}; -- To assign userids {username, displayName}

local Board: Object = {} :: Object;
Board.__index = Board;

local function dPrint(...)
	if (DEBUG) then
		warn(`[Leaderboard]`, ...);
	end;
end

local function Map<T>(tbl: {T}, fn: (T, number) -> (any)): {any}
    local t = {};
    for i, v in ipairs(tbl) do
        t[i] = fn(v, i);
    end;
    return t;
end

local function SmartAssert(condition: boolean, message: string)
	if (not condition) then
		error(message, 2);
	end;
end

local function GetUserInfosFromId(userId: number): (string, string)
	userId = tonumber(userId);

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
		table.insert(self._threads, thread);
	end;

	return self;
end

-- Gets the top data for a specific board
function Board:GetTopData(amount, sortDirection)
	SmartAssert(type(amount) == "number", "Amount must be a number");
	SmartAssert(amount <= 100, "You can only get the top 100.");
	SmartAssert(amount > 0, "Amount must be greater than 0");
	SmartAssert(type(sortDirection) == "nil" or typeof(sortDirection) == "string", "SortDirection must be a string");
	sortDirection = sortDirection or "Descending";

	local function PromiseRetrieveTopData()
		if (self.__storeType == "MemoryStore") then
			local Data = self.__store:GetTopShardData(amount, sortDirection);
			return Map(Data, function(v, rank)
				return Transform(rank, v.key, v.value);
			end);
		else
			local Result = self.__store:GetSortedAsync(if sortDirection == "Descending" then false else true, amount);
			local Data = Result:GetCurrentPage() :: {any};
			return Map(Data, function(v, rank)
				return Transform(rank, v.key, v.value);
			end);
		end;
	end;

	return Promise.new(function(resolve, reject)
		local Success, Data = pcall(PromiseRetrieveTopData);

		if (Success) then
			dPrint(`Successfully retrieved top data for {self.__serviceKey}`);
			resolve(Data);
		else
			warn(Success, Data);
			reject(Data);
		end;
	end);
end

-- Updates the data for a specific board (either MemoryStore (Shards), or OrderedDataStore)
function Board:Update(userId, value)
	SmartAssert(type(userId) == "number", "UserId must be a number");
	SmartAssert(type(value) == "function" or type(value) == "number", "Transformer must be a function or a number");

	-- If we are using a MemoryStore, we can just update the data
	if (self.__storeType == "MemoryStore") then
		dPrint(`Successfully updated data for ${userId} in {self.__serviceKey}`);
		return self.__store:UpdateShardValue(userId, value);
	end;

	-- Using an actual DataStore, we need to set the data
	local Success, Error = pcall(function()
		self.__store:UpdateAsync(userId, function(oldValue)
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
	end);
	if (not Success) then
		warn(`Leaderboard had trouble saving: {Error}`);
		return false;
	end;

	dPrint(`Successfully updated data for ${userId} in {self.__serviceKey}`);
	return true;
end

function Board:Destroy()
	for _, thread in self._threads do
		for _, v in ipairs(thread) do
			task.cancel(v);
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
	GetTopData = Board.GetTopData,
	Update = Board.Update,
	Destroy = Board.Destroy,
})
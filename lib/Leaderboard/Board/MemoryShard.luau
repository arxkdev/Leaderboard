-- Instead of one monolithic leaderboard, we can use multiple shards to store the data
local MemoryStoreService = game:GetService("MemoryStoreService");

local Leaderboard = script.Parent.Parent;
local Util = require(Leaderboard.Util);
local Promise = require(Leaderboard.Promise);
local Logger = require(Leaderboard.Logger);

-- Variables
local Compression = Util.Compression;
local SmartAssert = Util.SmartAssert;
local FoundInTable = Util.FoundInTable;
local GetDaysInMonth = Util.GetDaysInMonth;
local Sha1 = Util.Sha1;

-- Constants
local FALLBACK_EXPIRY_TIMES = {
	["Hourly"] = 3600,
	["Daily"] = 24 * 3600,
	["Weekly"] = 7 * 24 * 3600,
	["Monthly"] = (GetDaysInMonth()) * 24 * 3600, -- Used to have it as 30, but that's not accurate, so we use GetDaysInMonth()
}

--[=[
    @within MemoryShard
    @type LeaderboardType "Hourly" | "Daily" | "Weekly" | "Monthly" | "Yearly" | "AllTime" | "Rolling" | string
]=]
export type LeaderboardType = "Hourly" | "Daily" | "Weekly" | "Monthly" | "AllTime" | "Rolling" | string;

--[=[
    @within MemoryShard
    @type MemoryShard () -> MemoryShard
]=]
export type MemoryShard = typeof(setmetatable({} :: MemoryShardArguments, {} :: Object));

--[=[
	@within MemoryShard
	@interface MemoryShardArguments
	@field _type LeaderboardType
	@field _fallbackExpiry number
	@field _shards {MemoryStoreSortedMap}
	@field _shardCount number
]=]
export type MemoryShardArguments = {
	_type: LeaderboardType,
	_fallbackExpiry: number,
	_shards: {MemoryStoreSortedMap},
	_shardCount: number,
}

--[=[
	@within MemoryShard
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
	@within MemoryShard
	@interface Object
	@field __index Object
	@field _getShardKey (self: MemoryShard, userId: number) -> (number)
	@field _getAsync (self: MemoryShard, key: string) -> any
	@field _setAsync (self: MemoryShard, key: string, value: any, expiry: number, sortKey: number) -> boolean
	@field _updateAsync (self: MemoryShard, key: string, transformer: (any) -> (any), expiry: number) -> boolean
	@field Set (self: MemoryShard, userId: number, value: number | (number) -> (number)) -> Promise.TypedPromise<boolean>
	@field Get (self: MemoryShard, amount: number, sortDirection: string) -> Promise.TypedPromise<{TopData}>
	@field Destroy (self: MemoryShard) -> ()
	@field new (leaderboardType: LeaderboardType, serviceKey: string, shardCount: number, rollingExpiry: number?, debugMode: boolean?) -> MemoryShard
]=]
type Object = {
	__index: Object,
	_getShardKey: (self: MemoryShard, userId: number) -> (number),
	_getAsync: (self: MemoryShard, userId: number) -> Promise.TypedPromise<any>,
	_setAsync: (self: MemoryShard, userId: number, value: any, expiry: number, sortKey: number) -> Promise.TypedPromise<boolean>,
	_updateAsync: (self: MemoryShard, userId: number, transformer: (any) -> (any), expiry: number) -> Promise.TypedPromise<boolean>,
	Set: (self: MemoryShard, userId: number, value: number | (number) -> (number)) -> Promise.TypedPromise<boolean>,
	Get: (self: MemoryShard, amount: number, sortDirection: string) -> Promise.TypedPromise<{TopData}>,
	Destroy: (self: MemoryShard) -> (),
	new: (leaderboardType: LeaderboardType, serviceKey: string, shardCount: number, rollingExpiry: number?, debugMode: boolean?) -> MemoryShard,
}

--[=[
	@class MemoryShard

	A memory shard is a way to split up the leaderboard into multiple shards, each shard is a MemoryStoreSortedMap
]=]
local MemoryShard: Object = {} :: Object;
MemoryShard.__index = MemoryShard;

local function GetExpiry(leaderboardType: LeaderboardType): number | nil
	if (leaderboardType == "Rolling") then
		-- rolling expiry is dynamic so we can't return a fixed value
		return nil;
	end;

	local DateTimeNow = DateTime.now();
	local DateTable = DateTimeNow:ToUniversalTime();
	local CurrentDayOfWeek = (math.floor(DateTimeNow.UnixTimestamp / 86400) + 4) % 7 + 1;
	local DaysInCurrentMonth = GetDaysInMonth();

	-- Define
	local TotalSecondsInAnHour = FALLBACK_EXPIRY_TIMES["Hourly"];
	local TotalSecondsInADay = FALLBACK_EXPIRY_TIMES["Daily"];
	local TotalSecondsInAWeek = FALLBACK_EXPIRY_TIMES["Weekly"];
	local TotalSecondsInMonth = DaysInCurrentMonth * 86400;

	-- Seconds passed for Hourly, Daily, Weekly, Monthly
	local SecondsPassedThisHour = DateTable.Minute * 60 + DateTable.Second;
	local SecondsPassedToday = (DateTable.Hour * 3600) + (DateTable.Minute * 60) + DateTable.Second;
	local SecondsPassedThisWeek = (CurrentDayOfWeek - 1) * 86400 + SecondsPassedToday;
	local SecondsPassedThisMonth = (DateTable.Day - 1) * 86400 + SecondsPassedToday;

	if (leaderboardType == "Hourly") then
		local SecondsLeft = (TotalSecondsInAnHour - SecondsPassedThisHour);
		return SecondsLeft;
	end;

	if (leaderboardType == "Daily") then
		local SecondsLeft = (TotalSecondsInADay - SecondsPassedToday);
		return SecondsLeft;
	end;

	if (leaderboardType == "Weekly") then
		local SecondsLeft = (TotalSecondsInAWeek - SecondsPassedThisWeek);
		return SecondsLeft;
	end;

	if (leaderboardType == "Monthly") then
		local SecondsLeft = (TotalSecondsInMonth - SecondsPassedThisMonth);
		return SecondsLeft;
	end;

	return nil;
end

--[=[
	@param leaderboardType LeaderboardType
	@param serviceKey string
	@param shardCount number
	@param rollingExpiry number?
	@param debugMode boolean?

	Creates a new MemoryShard
]=]
function MemoryShard.new(leaderboardType: LeaderboardType, serviceKey: string, shardCount: number, rollingExpiry: number?, debugMode: boolean?)
	local self = setmetatable({} :: MemoryShardArguments, MemoryShard);
	self._shards = {};
	self._shardCount = shardCount;
	self._type = leaderboardType;
	self._fallbackExpiry = (rollingExpiry ~= nil) and rollingExpiry or (leaderboardType == "Monthly") and GetDaysInMonth() * 86400 or FALLBACK_EXPIRY_TIMES[self._type];
	self.Logger = Logger.new("MemoryShard", debugMode or false);

	for i = 1, shardCount do
		-- Each shard is a MemoryStoreSortedMap with a unique name based on the service name and shard index
		self._shards[i] = MemoryStoreService:GetSortedMap(serviceKey .. "_Shard" .. tostring(i));
		self.Logger:Log(1, `Created MemoryStoreSortedMap for _Shared{tostring(i)}`);
	end;

	return self;
end

-- Gets the Shard Key using prefixing and modulo
--[=[
	@param userId number
	@private
	@return number

	Gets the Shard Key using prefixing and modulo
]=]
function MemoryShard:_getShardKey(userId)
	SmartAssert(userId, "userId must be provided");
	SmartAssert(typeof(userId) == "number", "userId must be a number");

	-- Get the SHA-256 hash of the userId
	local ShaHash = Sha1.sha1(tostring(userId));
	local HashPrefix = tonumber(string.sub(ShaHash, 1, 8), 16);

	-- Use the modulo operation to get the shard index
	local ShardIndex = (HashPrefix % self._shardCount) + 1;
	return ShardIndex;
end

--[=[
	@param userId string
	@private
	@return Promise.TypedPromise<{TopData}>

	Gets the value for a specific key from a specific shard
]=]
function MemoryShard:_getAsync(userId)
	local ShardKey = self:_getShardKey(userId);
	local Shard = self._shards[ShardKey] or self._shards[1];
	return Promise.retryWithVariableDelay(function()
		return Shard:GetAsync(userId);
	end, 10, 1, "Exponential"):catch(warn);
end

--[=[
	@param userId string
	@param value any
	@param expiry number
	@param sortKey number
	@private
	@return ()

	Destroys all the shards for this MemoryShard
]=]
function MemoryShard:_setAsync(userId, value, expiry, sortKey)
	local ShardKey = self:_getShardKey(userId);
	local Shard = self._shards[ShardKey] or self._shards[1];
	return Promise.retryWithVariableDelay(function()
		return Shard:SetAsync(userId, value, expiry, sortKey);
	end, 10, 1, "Exponential"):catch(warn);
end

--[=[
	@param userId string
	@param transformer (any) -> (any)
	@param expiry number
	@private
	@return ()

	Updates the value for a specific key from a specific shard
]=]
function MemoryShard:_updateAsync(userId, transformer, expiry)
	local ShardKey = self:_getShardKey(userId);
	local Shard = self._shards[ShardKey] or self._shards[1];
	return Promise.retryWithVariableDelay(function()
		return Shard:UpdateAsync(userId, transformer, expiry);
	end, 10, 1, "Exponential"):catch(warn);
end

-- Gets the top data from all the shards for this MemoryShard
--[=[
	@param topAmount number
	@param sortDirection string
	@return {TopData}
	@yields

	Gets the top data from all the shards for this MemoryShard
]=]
function MemoryShard:Get(topAmount, sortDirection)
	SmartAssert(topAmount, "topAmount must be provided");
	SmartAssert(sortDirection, "sortDirection must be provided");
	SmartAssert(typeof(topAmount) == "number", "topAmount must be a number");
	SmartAssert(typeof(sortDirection) == "string", "sortDirection must be a string");
	local CombinedResults = {};

	local function ProcessRecord(record: {key: string, value: number})
		local IndexFound, Found = FoundInTable(CombinedResults, tonumber(record.key));
		if (Found) then
			local FoundValueHigherThanCurrent = (Found.value > record.value);
			if (not FoundValueHigherThanCurrent) then
				-- The found value already there, is LOWER than this new one, update it
				CombinedResults[IndexFound].value = record.value;
			end;
		else
			-- There is no found value, add it to the combined results
			table.insert(CombinedResults, {
				key = tonumber(record.key),
				value = record.value
			});
		end;
	end

	local function ProcessShard(shard: MemoryStoreSortedMap)
		return function()
			local data = shard:GetRangeAsync(
				Enum.SortDirection[sortDirection],
				topAmount
			)
			if (self._type == "Rolling") then
				for _, record in ipairs(data) do
					-- get rid of expiry and creation date padding, convert back to number
					record.value = tonumber(record.value.value);
				end;
			end;
			return data;
		end;
	end

	-- Go through the shards, extract the data, and combine it
	local Promises = {};
	for _, Shard in self._shards do
		local ShardPromise = Promise.retryWithVariableDelay(ProcessShard(Shard), 10, 1, "Exponential"):andThen(function(Result)
			for _, record in ipairs(Result) do
				ProcessRecord(record);
			end;
		end):catch(warn);
		table.insert(Promises, ShardPromise);
	end;

	-- Sort it
	return Promise.all(Promises):andThen(function()
		-- Sort the combined results after all promises have resolved
		table.sort(CombinedResults, function(a, b)
			return a.value > b.value;
		end);

		-- Trim the results if necessary
		if (#CombinedResults > topAmount) then
			for i = #CombinedResults, topAmount + 1, -1 do
				table.remove(CombinedResults, i);
			end;
		end;

		return CombinedResults;
	end):catch(function(error)
		warn("An error occurred while processing shards: " .. error);
	end);
end

-- Updates the value for a specific user in a specific shard
--[=[
	@param userId number
	@param value number | (number) -> (number)
	@return boolean
	@yields

	Updates the value for a specific user in a specific shard
]=]
function MemoryShard:Set(userId, value)
	SmartAssert(userId, "userId must be provided");
	SmartAssert(value, "transformer must be provided");
	SmartAssert(typeof(userId) == "number", "userId must be a number");
	SmartAssert(typeof(value) == "function" or typeof(value) == "number", "transformer must be a function or a number");

	-- Get the shard key, shard, leaderboard type, and user key
	local LeaderboardType = self._type;

	-- Rolling support
	if (LeaderboardType == "Rolling") then
		return self:_getAsync(userId):andThen(function(oldValue)
			local firstTime = oldValue == nil;
			local created = if not firstTime then oldValue._created else nil
			oldValue = if firstTime then 0 else Compression.Decompress(oldValue.value);
			local transformedValue = (typeof(value) == "function" and value(oldValue) or value);

			-- If their oldValue is greater than the new value, we don't want to update it
			if (oldValue > transformedValue) then
				return nil;
			end;

			local compressedValue = Compression.Compress(transformedValue);
			local newSortKey = transformedValue;
			
			local newValue = {
				value = compressedValue, -- this will be the value we save, we need to save as table to carry over creation data
				_created = if firstTime then os.time() else created,
				_expiry = self._fallbackExpiry
			};
			
			-- update the value with appropriate expiry time left
			self:_setAsync(userId, newValue, newValue._expiry - (os.time() - newValue._created), newSortKey):catch(warn);
			return true;
		end);
	end;

	-- Update the value
	return self:_updateAsync(userId, function(oldValue)
		oldValue = oldValue and Compression.Decompress(oldValue) or 0;
		local transformedValue = (typeof(value) == "function") and value(oldValue) or value;

		-- If their oldValue is greater than the new value, we don't want to update it
		if (oldValue > transformedValue) then
			return nil;
		end;

		local compressedValue = Compression.Compress(transformedValue);
		local newSortKey = transformedValue;
		if (compressedValue and newSortKey) then
			return compressedValue, newSortKey;
		end;
		return nil;
	end, GetExpiry(LeaderboardType) or self._fallbackExpiry):catch(warn);
end

-- Make indexing the wrong key throw an error
setmetatable(MemoryShard, {
	__index = function(_, key)
		error(`Attempt to get MemoryShard:{tostring(key)} (not a valid member)`, 2);
	end,
	__newindex = function(_, key, _)
		error(`Attempt to set MemoryShard:{tostring(key)} (not a valid member)`, 2);
	end,
})

return table.freeze({
	new = MemoryShard.new,
});

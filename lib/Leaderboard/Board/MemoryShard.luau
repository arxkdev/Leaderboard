-- Instead of one monolithic leaderboard, we can use multiple shards to store the data
local MemoryStoreService = game:GetService("MemoryStoreService");

local Leaderboard = script.Parent.Parent;
local Packages = Leaderboard.Parent;
local Promise = require(Packages.Promise);
local Util = require(Leaderboard.Util);
local Logger = require(Leaderboard.Logger);

-- Variables
local Compression = Util.Compression;
local SmartAssert = Util.SmartAssert;
local FoundInTable = Util.FoundInTable;
local GetDaysInMonth = Util.GetDaysInMonth;
local Sha1 = Util.Sha1;
local FALLBACK_EXPIRY_TIMES = Util.FALLBACK_EXPIRY_TIMES;
local OFFLINE_ENVIRONMENT = game.GameId == 0;

--[=[
    @within MemoryShard
    @type LeaderboardType "Hourly" | "Daily" | "Weekly" | "Monthly" | "Yearly" | "AllTime" | string
]=]
export type LeaderboardType = "Hourly" | "Daily" | "Weekly" | "Monthly" | "AllTime" | string;

--[=[
    @within MemoryShard
    @type MemoryShard () -> MemoryShard
]=]
export type MemoryShard = typeof(setmetatable({} :: MemoryShardArguments, {} :: Object));

--[=[
	@within MemoryShard
	@interface MemoryShardArguments
	@field _type LeaderboardType
	@field _boardKey string
	@field _fallbackExpiry number
	@field _isRollingExpiry boolean
	@field _shards {MemoryStoreSortedMap}
	@field _shardCount number
	@field _logger Logger.Logger?
]=]
export type MemoryShardArguments = {
	_type: LeaderboardType,
	_boardKey: string,
	_fallbackExpiry: number,
	_isRollingExpiry: boolean,
	_shards: {MemoryStoreSortedMap},
	_shardCount: number,
	_logger: Logger.Logger?,
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
	@field new (leaderboardType: LeaderboardType, boardKey: string, shardCount: number, rollingExpiry: number?, debugMode: boolean?) -> MemoryShard
]=]
type Object = {
	__index: Object,
	_getShardKey: (self: MemoryShard, userId: number) -> (number),
	_getExpiry: (leaderboardType: LeaderboardType, leaderboardKey: number | string | {number & string}) -> (number | nil),
	_getAsync: (self: MemoryShard, userId: number) -> Promise.TypedPromise<any>,
	_setAsync: (self: MemoryShard, userId: number, value: any, expiry: number, sortKey: number) -> Promise.TypedPromise<boolean>,
	_updateAsync: (self: MemoryShard, userId: number, transformer: (any) -> (any), expiry: number) -> Promise.TypedPromise<boolean>,
	Set: (self: MemoryShard, userId: number, value: number | (number) -> (number)) -> Promise.TypedPromise<boolean>,
	Get: (self: MemoryShard, amount: number, sortDirection: string) -> Promise.TypedPromise<{TopData}>,
	Destroy: (self: MemoryShard) -> (),
	new: (leaderboardType: LeaderboardType, boardKey: string, shardCount: number, rollingExpiry: number?, debugMode: boolean?) -> MemoryShard,
}

--[=[
	@class MemoryShard

	A memory shard is a way to split up the leaderboard into multiple shards, each shard is a MemoryStoreSortedMap
]=]
local MemoryShard: Object = {} :: Object;
MemoryShard.__index = MemoryShard;

local function GetResultCount(shardCount: number): number
	-- Depending on how many shards there are the result count should be based on
	-- For example, 1 shard is 100 records, 2 shards is 50 records, 4 shards is 25 records, 10 shards is 10 records
	local BASE = 100;
	local RECORD_COUNT = math.ceil(BASE / shardCount);
	return math.max(RECORD_COUNT, 1);
end

--[=[
	@param leaderboardType LeaderboardType
	@param boardKey string
	@param shardCount number
	@param rollingExpiry number?
	@param debugMode boolean?

	Creates a new MemoryShard. This is not a viable solution anymore, as the limits to MemoryStoreService are too poor.
	See: https://devforum.roblox.com/t/introducing-memorystore-sortedmap-sortkey-beta/2673559/23
]=]
function MemoryShard.new(leaderboardType: LeaderboardType, boardKey: string, shardCount: number, rollingExpiry: number?, debugMode: boolean?)
	local self = setmetatable({} :: MemoryShardArguments, MemoryShard);
	self._shards = {};
	self._shardCount = shardCount;
	self._type = leaderboardType;
	self._isRollingExpiry = rollingExpiry ~= nil;
	self._fallbackExpiry = (rollingExpiry ~= nil) and rollingExpiry or (leaderboardType == "Monthly") and GetDaysInMonth() * 86400 or FALLBACK_EXPIRY_TIMES[self._type];
	self._boardKey = boardKey;
	self._logger = Logger.new("MemoryShard", debugMode or false);

	-- Each shard is a MemoryStoreSortedMap with a unique name based on the service name and shard index
	for Index = 1, shardCount do
		if (OFFLINE_ENVIRONMENT) then
			continue;
		end;

		local Success, Response = pcall(function()
			return MemoryStoreService:GetSortedMap(`{boardKey}_Shard{Index}`);
		end);

		if (Success) then
			self._logger:Log(1, `Created MemoryStoreSortedMap for "{boardKey}_Shard{Index}"`);
		else
			self._logger:Log(1, `Failed to create MemoryStoreSortedMap for "{boardKey}_Shard{Index}": {Response}`);
		end;

		self._shards[Index] = Success and Response or nil;
	end;

	return self;
end

--[=[
	@private
	@return number | nil

	Gets the expiry for a specific leaderboard type and key
]=]
function MemoryShard:_getExpiry()
	if (self._isRollingExpiry) then
		-- rolling expiry is dynamic so we can't return a fixed value
		return nil;
	end;

	local LeaderboardType = self._type;
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

	if (LeaderboardType == "Hourly") then
		local SecondsLeft = (TotalSecondsInAnHour - SecondsPassedThisHour);
		return SecondsLeft;
	end;

	if (LeaderboardType == "Daily") then
		local SecondsLeft = (TotalSecondsInADay - SecondsPassedToday);
		return SecondsLeft;
	end;

	if (LeaderboardType == "Weekly") then
		local SecondsLeft = (TotalSecondsInAWeek - SecondsPassedThisWeek);
		return SecondsLeft;
	end;

	if (LeaderboardType == "Monthly") then
		local SecondsLeft = (TotalSecondsInMonth - SecondsPassedThisMonth);
		return SecondsLeft;
	end;

	return nil;
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

	return Promise.new(function(resolve, reject)
		local Success, Result = pcall(function()
			if (not Shard) then
				return;
			end;

			return Shard:GetAsync(userId);
		end);
		if (not Success) then
			return reject(Result);
		end;
		return resolve(Result);
	end):catch(warn);
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

	return Promise.new(function(resolve, reject)
		local Success, Result = pcall(function()
			if (not Shard) then
				return;
			end;

			return Shard:SetAsync(userId, value, expiry, sortKey);
		end);
		if (not Success) then
			return reject(Result);
		end;
		return resolve(Result);
	end):catch(warn);
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

	return Promise.new(function(resolve, reject)
		local Success, Result = pcall(function()
			if (not Shard) then
				return;
			end;

			return Shard:UpdateAsync(userId, transformer, expiry);
		end);
		if (not Success) then
			return reject(Result);
		end;
		return resolve(Result);
	end):catch(warn);
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
	local ResultsToFetch = GetResultCount(self._shardCount);

	self._logger:Log(1, `[{self._boardKey}]: Fetching {ResultsToFetch} records in {self._type}`);
	-- print(`[{self._boardKey}]: Fetching {ResultsToFetch} records in {self._type}`);

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
			local ShardData = shard:GetRangeAsync(
				Enum.SortDirection[sortDirection],
				ResultsToFetch
			);

			if (self._isRollingExpiry) then
				for _, record in ShardData do
					-- get rid of expiry and creation date padding, convert back to number
					record.value = tonumber(record.value.value);
				end;
			end;

			return ShardData;
		end;
	end

	-- Go through the shards, extract the data, and combine it
	local Promises = {};
	for _, Shard in self._shards do
		local ShardPromise = Promise.new(function(resolve, reject)
			local Success, Result = pcall(ProcessShard(Shard));
			if (not Success) then
				return reject(Result);
			end;
			return resolve(Result);
		end):andThen(function(data)
			for _, record in data do
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
	end):catch(function(err: string)
		warn(`An error occurred while processing shards: {err}`);
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

	-- Rolling support
	if (self._isRollingExpiry) then
		return self:_getAsync(userId):andThen(function(oldValue)
			local FirstTime = oldValue == nil;
			local Created = if not FirstTime then oldValue._created else nil
			oldValue = if FirstTime then 0 else Compression.Decompress(oldValue.value);
			local TransformedValue = (typeof(value) == "function" and value(oldValue) or value);

			local CompressedValue = Compression.Compress(TransformedValue);
			local NewSortKey = TransformedValue;

			local NewValue = {
				value = CompressedValue, -- this will be the value we save, we need to save as table to carry over creation data
				_created = if FirstTime then os.time() else Created,
				_expiry = self._fallbackExpiry
			};

			-- update the value with appropriate expiry time left
			self:_setAsync(userId, NewValue, NewValue._expiry - (os.time() - NewValue._created), NewSortKey):catch(warn);
			return true;
		end);
	end;

	-- Update the value
	return self:_updateAsync(userId, function(oldValue)
		oldValue = oldValue and Compression.Decompress(oldValue) or 0;
		local TransformedValue = (typeof(value) == "function") and value(oldValue) or value;
		local CompressedValue = Compression.Compress(TransformedValue);
		local NewSortKey = TransformedValue;

		-- Get size of Value
		-- local ValueSize = string.len(HttpService:JSONEncode(CompressedValue));
		-- print(`ValueSize of {ValueSize} for {userId} in {self._boardKey}`);

		if (CompressedValue and NewSortKey) then
			return CompressedValue, NewSortKey;
		end;
	end, self:_getExpiry() or self._fallbackExpiry):catch(warn);
end

--[=[
	@return ()
	@yields

	Destroys the MemoryShard
]=]
function MemoryShard:Destroy()
	self._logger:Destroy();
	setmetatable(self, nil);
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

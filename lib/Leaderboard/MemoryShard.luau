-- Instead of one monolithic leaderboard, we can use multiple shards to store the data
local MemoryStoreService = game:GetService("MemoryStoreService");

local Compression = require(script.Parent.Compression);
local HashLib = require(script.Parent.HashLib);

local FALLBACK_EXPIRY_TIMES = {
	["Hourly"] = 3600,
	["Daily"] = 24 * 3600,
	["Weekly"] = 7 * 24 * 3600,
	["Monthly"] = 30 * 24 * 3600, -- Could be 31, but we'll use 30 for now
}
local DEBUG = false;
local DAYS_IN_MONTH = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}

export type LeaderboardType = "Hourly" | "Daily" | "Weekly" | "Monthly" | "AllTime" | "Rolling";
export type LeaderboardArguments = {
	Type: LeaderboardType,
	FallbackExpiry: number,
	Shards: {MemoryStoreSortedMap},
	ShardCount: number,
}
export type TopData = {
	Rank: number,
	UserId: number,
	Value: number,
	Username: string,
	DisplayName: string,
}

type Object = {
	__index: Object,
	UpdateValue: (self: MemoryShard, userId: number, value: number | (number) -> (number)) -> (),
	GetTopData: (self: MemoryShard, amount: number, sortDirection: string) -> {TopData},
	GetShardKey: (self: MemoryShard, userId: number) -> (number),
	new: (leaderboardType: LeaderboardType, serviceKey: string, shardCount: number, debug: boolean) -> MemoryShard,
	Destroy: (self: MemoryShard) -> (),
}
export type MemoryShard = typeof(setmetatable({} :: LeaderboardArguments, {} :: Object));

local MemoryShard: Object = {} :: Object;
MemoryShard.__index = MemoryShard;

local function dPrint(...)
	if (DEBUG) then
		warn(`[Shards]`, ...);
	end;
end

local function SmartAssert(condition: boolean, message: string)
	if (not condition) then
		error(message, 2);
	end;
end

local function FoundInTable(tbl: {any}, value: any): (boolean | number, any)
	local function search(t: {any}, val: any)
		for index, v in t do
			if (v == val) then
				return index, v;
			elseif (type(v) == "table") then
				if search(v, val) then
					return index, v;
				end;
			end;
		end;
		return false, nil;
	end;
	return search(tbl, value)
end

local function GetDaysInMonth(): number
	local CurrentDate = DateTime.now():ToUniversalTime();
	local Month, Year = CurrentDate.Month, CurrentDate.Year;
	if (Month == 2) then -- This is for a leap year
		if (Year % 4 == 0 and (Year % 100 ~= 0 or Year % 400 == 0)) then
			return 29; -- Leap year month (29 days)
		end;
	end;
	return DAYS_IN_MONTH[Month];
end

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

function MemoryShard.new(leaderboardType: LeaderboardType, serviceKey: string, shardCount: number, rollingExpiry: number?)
	local self = setmetatable({} :: LeaderboardArguments, MemoryShard);
	self.Shards = {};

	for i = 1, shardCount do
		-- Each shard is a MemoryStoreSortedMap with a unique name based on the service name and shard index
		self.Shards[i] = MemoryStoreService:GetSortedMap(serviceKey .. "_Shard" .. tostring(i));
		dPrint(`Cerated MemoryStoreSortedMap for _Shared{tostring(i)}`);
	end;

	self.ShardCount = shardCount;
	self.Type = leaderboardType;
	self.FallbackExpiry = (leaderboardType == "Rolling" and rollingExpiry ~= nil) and rollingExpiry or (leaderboardType == "Monthly") and GetDaysInMonth() * 86400 or FALLBACK_EXPIRY_TIMES[self.Type];
	return self;
end

function MemoryShard:GetShardKey(userId)
	SmartAssert(userId, "userId must be provided");
	SmartAssert(typeof(userId) == "number", "userId must be a number");

	-- Get the SHA-256 hash of the userId
	local ShaHash = HashLib.sha1(tostring(userId));
	local HashPrefix = tonumber(string.sub(ShaHash, 1, 8), 16);

	-- Use the modulo operation to get the shard index
	local ShardIndex = (HashPrefix % self.ShardCount) + 1;
	return ShardIndex;
end

function MemoryShard:GetTopData(topAmount, sortDirection)
	SmartAssert(topAmount, "topAmount must be provided");
	SmartAssert(sortDirection, "sortDirection must be provided");
	SmartAssert(typeof(topAmount) == "number", "topAmount must be a number");
	SmartAssert(typeof(sortDirection) == "string", "sortDirection must be a string");
	local CombinedResults = {};

	-- Go through the shards, extract the data, and combine it
	for _, Shard in self.Shards do
		local Success, Result = pcall(function()
			local data = Shard:GetRangeAsync(
				Enum.SortDirection[sortDirection],
				topAmount
			);
			if (self.Type == "Rolling") then
				for _, entry in data do
					-- get rid of expiry and creation date padding, convert back to number
					entry.value = tonumber(entry.value.value)
				end
			end
			return data
		end);

		if (not Success) then
			warn(Result);
			continue; -- Skip this shard, there was a problem with it
		end;

		for _, entry in Result do
			local IndexFound, Found = FoundInTable(CombinedResults, tonumber(entry.key));
			if (Found) then
				local FoundValueHigherThanCurrent = (Found.value > entry.value);
				if (not FoundValueHigherThanCurrent) then
					-- The found value already there, is LOWER than this new one, update it
					CombinedResults[IndexFound].value = entry.value;
				end;
			else
				-- There is no found value, add it to the combined results
				table.insert(CombinedResults, {
					key = tonumber(entry.key),
					value = entry.value
				});
			end;
		end;
	end;

	-- Sort it
	table.sort(CombinedResults, function(a, b)
		return a.value > b.value;
	end);

	-- Take off excess
	if (#CombinedResults > topAmount) then
		for i = #CombinedResults, topAmount + 1, -1 do
			table.remove(CombinedResults, i);
		end;
	end;

	return CombinedResults;
end

function MemoryShard:UpdateValue(userId, value)
	SmartAssert(userId, "userId must be provided");
	SmartAssert(value, "transformer must be provided");
	SmartAssert(typeof(userId) == "number", "userId must be a number");
	SmartAssert(typeof(value) == "function" or typeof(value) == "number", "transformer must be a function or a number");

	-- Get the shard key, shard, leaderboard type, and user key
	local ShardKey = self:GetShardKey(userId);
	local Shard = self.Shards[ShardKey] or self.Shards[1];
	local LeaderboardType = self.Type;
	local Key = tostring(userId);

	-- Rolling support
	if (LeaderboardType == "Rolling") then
		local Success, NewData = pcall(function()
			local oldValue = Shard:GetAsync(Key);
			local firstTime = oldValue == nil;
			oldValue = if firstTime then 0 else Compression.Decompress(oldValue.value);

			local transformedValue = (typeof(value) == "function" and value(oldValue) or value);
			local compressedValue = Compression.Compress(transformedValue);
			local newSortKey = transformedValue;

			local newValue = {
				value = compressedValue, -- this will be the value we save, we need to save as table to carry over creation data
				__created = if (typeof(oldValue) ~= "table") then os.time() else oldValue.__created,
				__expiry = self.FallbackExpiry
			};
			-- update the value with appropriate expiry time left
			Shard:SetAsync(Key, newValue, newValue.__expiry - (os.time() - newValue.__created), newSortKey);
			return compressedValue, newSortKey; -- share same format as UpdateAsync
		end);

		if (not Success) then
			warn(NewData);
			return false;
		end;

		return true;
	end;

	local Success, NewData = pcall(function()
		return Shard:UpdateAsync(
			Key,
			function(oldValue)
				oldValue = oldValue or 0;
				local transformedValue = (typeof(value) == "function") and value(oldValue) or value;
				local compressedValue = Compression.Compress(transformedValue);
				local newSortKey = transformedValue;
				if (compressedValue and newSortKey) then
					return compressedValue, newSortKey;
				end;
				return nil;
			end,
			GetExpiry(LeaderboardType) or self.FallbackExpiry
		);
	end);

	if (not Success) then
		warn(NewData);
		return false;
	end;
	return true;
end

function MemoryShard:Destroy()

end

return table.freeze({
	new = MemoryShard.new,
});
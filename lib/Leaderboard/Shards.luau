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

export type LeaderboardType = "Hourly" | "Daily" | "Weekly" | "Monthly" | "AllTime";
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
	UpdateData: (self: Shards, userId: number, value: number) -> (),
	GetTopData: (self: Shards, amount: number, sortDirection: Enum.SortDirection) -> {TopData},
	GetShardKey: (self: Shards, userId: number) -> (number),
	new: (leaderboardType: LeaderboardType, serviceKey: string, shardCount: number, debug: boolean) -> Shards,
}
export type Shards = typeof(setmetatable({} :: LeaderboardArguments, {} :: Object));

local Shards: Object = {} :: Object;
Shards.__index = Shards;

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

local function FoundInTable(tbl: {any}, value: any)
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
		return false;
	end;
	return search(tbl, value)
end

local function GetDaysInMonth(month: number, year: number): number
	local DaysInMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
	if (month == 2) then -- This is for a leap year
		if (year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)) then
			return 29; -- Leap year month (29 days)
		end;
	end;
	return DaysInMonth[month];
end

local function GetExpiry(leaderboardType: LeaderboardType): number | nil
	local DateTable = os.date("*t", os.time());
	local DaysInCurrentMonth = GetDaysInMonth(DateTable.month, DateTable.year);

	-- Define
	local TotalSecondsInAnHour = FALLBACK_EXPIRY_TIMES["Hourly"];
	local TotalSecondsInADay = FALLBACK_EXPIRY_TIMES["Daily"];
	local TotalSecondsInAWeek = FALLBACK_EXPIRY_TIMES["Weekly"];
	local TotalSecondsInMonth = DaysInCurrentMonth * 86400;

	-- Seconds passed for Hourly, Daily, Weekly, Monthly
	local DayOfWeek = DateTable.wday;
	local SecondsPassedThisHour = DateTable.min * 60 + DateTable.sec;
	local SecondsPassedToday = (DateTable.hour * 3600) + (DateTable.min * 60) + DateTable.sec;
	local SecondsPassedThisWeek = (DayOfWeek - 1) * 86400 + SecondsPassedToday;
	local SecondsPassedThisMonth = (DateTable.day - 1) * 86400 + SecondsPassedToday;

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

function Shards.new(leaderboardType: LeaderboardType, serviceKey: string, shardCount: number)
	local self = setmetatable({} :: LeaderboardArguments, Shards);
	self.Shards = {};

	for i = 1, shardCount do
		-- Each shard is a MemoryStoreSortedMap with a unique name based on the service name and shard index
		self.Shards[i] = MemoryStoreService:GetSortedMap(serviceKey .. "_Shard" .. tostring(i));
		dPrint("Created MemoryStoreSortedMap for shard", i);
	end;

	self.ShardCount = shardCount
	self.Type = leaderboardType;
	self.FallbackExpiry = self.Type == "Monthly" and GetDaysInMonth(os.date("*t", os.time()).month, os.date("*t", os.time()).year) * 24 * 3600 or FALLBACK_EXPIRY_TIMES[self.Type];
	return self;
end

function Shards:GetShardKey(userId)
	SmartAssert(userId, "userId must be provided");

	-- Get the SHA-256 hash of the userId
	local ShaHash = HashLib.sha1(tostring(userId));
	local HashPrefix = tonumber(string.sub(ShaHash, 1, 8), 16);

	-- Use the modulo operation to get the shard index
	local ShardIndex = (HashPrefix % self.ShardCount) + 1;
	return ShardIndex;
end

function Shards:UpdateData(userId, value)
	SmartAssert(userId, "userId must be provided");
	SmartAssert(value, "value must be provided");
	SmartAssert(typeof(userId) == "number", "userId must be a number");
	SmartAssert(typeof(value) == "number", "value must be a number");

	-- Get the compressed value, ShardKey and the shard of the memory map
	local CompressedValue = Compression.Compress(value);
	local ShardKey = self:GetShardKey(userId);
	local Shard = self.Shards[ShardKey] or self.Shards[1];

	local success, newData, _ = pcall(function()
		return Shard:UpdateAsync(
			tostring(userId),
			function(oldValue, oldSortKey)
				-- oldValue is the current score, oldSortKey is the sort key previously stored
				oldValue = oldValue or 0;
				oldSortKey = oldSortKey or 0;
				local newValue = CompressedValue;

				-- If newValue is valid, then update the sort key and value
				if (newValue) then
					local newSortKey = newValue; -- Assuming the value is the score for sorting
					return newValue, newSortKey;
				end;
				-- If newValue is not valid, do not update
				return nil
			end,
			GetExpiry(self.Type) or self.FallbackExpiry
		);
	end);

	if (not success) then
		warn(newData);
		return false;
	end;

	return true;
end

function Shards:GetTopData(topAmount, sortDirection)
	SmartAssert(topAmount, "topAmount must be provided");
	SmartAssert(sortDirection, "sortDirection must be provided");
	SmartAssert(typeof(topAmount) == "number", "topAmount must be a number");
	SmartAssert(typeof(sortDirection) == "EnumItem", "sortDirection must be an Enum.SortDirection");
	local CombinedResults = {};

	-- Go through the shards, extract the data, and combine it
	for _, shard in self.Shards do
		local success, result = pcall(function()
			return shard:GetRangeAsync(
				sortDirection,
				topAmount
			);
		end);

		if (success and result) then
			for _, entry in result do
				local IndexFound, Found = FoundInTable(CombinedResults, tonumber(entry.key));
				if (Found) then
					local FoundValueHigherThanCurrent = (Found.Value > entry.value);
					if (not FoundValueHigherThanCurrent) then
						-- The found value already there, is LOWER than this new one, update it
						CombinedResults[IndexFound].Value = entry.value;
					end;
				else
					-- There is no found value, add it to the combined results
					table.insert(CombinedResults, {
						UserId = tonumber(entry.key),
						Value = entry.value
					});
				end;
			end;
		else
			warn(result);
		end;
	end;

	-- Sort it
	table.sort(CombinedResults, function(a, b)
		return a.Value > b.Value;
	end);

	-- Take off excess
	if (#CombinedResults > topAmount) then
		for i = #CombinedResults, topAmount + 1, -1 do
			table.remove(CombinedResults, i);
		end;
	end;

	return CombinedResults;
end

return Shards;
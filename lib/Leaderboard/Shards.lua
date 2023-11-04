local MemoryStoreService = game:GetService("MemoryStoreService");

local Compression = require(script.Parent.Compression);
local HashLib = require(script.Parent.HashLib);

export type LeaderboardType = "Daily" | "Weekly" | "Monthly" | "AllTime";
export type LeaderboardArguments = {
	Type: LeaderboardType,
	FallbackExpiry: number,
	Shards: {MemoryStoreSortedMap},
	ShardCount: number,
}

type Object = {
	__index: Object,
	UpdateData: (self: Shards, userId: number, value: number) -> (),
	GetTopData: (self: Shards, amount: number, sortDirection: Enum.SortDirection) -> (),
	GetShardKey: (self: Shards, userId: number) -> (number),
	new: (leaderboardType: LeaderboardType, serviceKey: string, shardCount: number) -> Shards,
}
export type Shards = typeof(setmetatable({} :: LeaderboardArguments, {} :: Object));

local Shards: Object = {} :: Object;
Shards.__index = Shards;

local FALLBACK_EXPIRY_TIMES = {
	["Daily"] = 86400,
	["Weekly"] = 604800,
	["Monthly"] = 2.628e+6,
}

local function FoundInTable(tbl: {any}, value: any)
	local function search(t, val)
		for index, v in pairs(t) do
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

--local test = {
--	{key = 1234324, value = 10},
--	{key = 0, value = 325},
--	{key = 0, value = 5325},
--	{key = 0, value = 34},
--}

----print(FoundInTable(test, 1))
--local FoundIndex, Found = FoundInTable(test, 1234324);
--if (Found) then
--	print(FoundIndex)
--end

local function GetDaysInMonth(month: number, year: number): number
	local daysInMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
	if (month == 2) then -- This is for a leap year
		if (year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)) then
			return 29; -- Leap year month (29 days)
		end;
	end;
	return daysInMonth[month];
end
local function GetExpiry(leaderboardType: LeaderboardType): number | nil
	local DateTable = os.date("*t", os.time());
	local DaysInCurrentMonth = GetDaysInMonth(DateTable.month, DateTable.year);

	-- Define
	local TotalSecondsInADay = 24 * 3600;
	local TotalSecondsInAWeek = 7 * 24 * 3600;
	local TotalSecondsInMonth = DaysInCurrentMonth * 86400;

	-- Seconds passed for Daily, Weekly, Monthly
	local DayOfWeek = DateTable.wday;
	local SecondsPassedToday = (DateTable.hour * 3600) + (DateTable.min * 60) + DateTable.sec;
	local SecondsPassedThisWeek = (DayOfWeek - 1) * 86400 + SecondsPassedToday;
	local SecondsPassedThisMonth = (DateTable.day - 1) * 86400 + SecondsPassedToday;

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
	end;

	self.ShardCount = shardCount
	self.Type = leaderboardType;
	self.FallbackExpiry = FALLBACK_EXPIRY_TIMES[self.Type];

	return self;
end

-- Define a method to determine the shard key based on the user ID
function Shards:GetShardKey(userId)
	-- Get the SHA-256 hash of the userId
	local ShaHash = HashLib.sha1(tostring(userId));
	local HashPrefix = tonumber(string.sub(ShaHash, 1, 8), 16);

	-- Use the modulo operation to get the shard index
	local ShardIndex = (HashPrefix % self.ShardCount) + 1;
	return ShardIndex;
end

function Shards:UpdateData(userId, value)
	local compressedValue = Compression.Compress(value);
	local shardKey = self:GetShardKey(userId);
	local shard = self.Shards[shardKey];

	local success, newData, _ = pcall(function()
		return shard:UpdateAsync(
			tostring(userId),
			function(oldValue, oldSortKey)
				-- oldValue is the current score, oldSortKey is the sort key previously stored
				oldValue = oldValue or 0
				local newValue = compressedValue

				-- If newValue is valid, then update the sort key and value
				if newValue then
					local newSortKey = newValue -- Assuming the value is the score for sorting
					return newValue, newSortKey
				end
				-- If newValue is not valid, do not update
				return nil
			end,
			GetExpiry(self.Type) or self.FallbackExpiry
		);
	end);

	if (not success) then
		warn(newData);
	end;
end

function Shards:GetTopData(topAmount, sortDirection)
	local CombinedResults = {};

	for _, shard in ipairs(self.Shards) do
		local success, result = pcall(function()
			return shard:GetRangeAsync(
				sortDirection,
				topAmount
			);
		end);

		if (success and result) then
			for _, entry in ipairs(result) do
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
		else
			warn(result);
		end;
	end;

	table.sort(CombinedResults, function(a, b)
		return a.value > b.value;
	end);

	if (#CombinedResults > topAmount) then
		for i = #CombinedResults, topAmount + 1, -1 do
			table.remove(CombinedResults, i);
		end;
	end;

	return CombinedResults;
end

return Shards;
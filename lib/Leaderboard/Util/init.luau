local HttpService = game:GetService("HttpService");

-- Requirements
local Compression = require(script.Compression);
local Sha1 = require(script.Sha1);

local Util = {};

-- Constants
local MEMORY_STORE_SERVICE_MAX_EXPIRY = 24 * 60 * 60 * 25;
local MEMORY_STORE_SERVICE_MIN_EXPIRY = 60;
local BOARD_TYPES = {"Hourly", "Daily", "Weekly", "Monthly", "Yearly", "AllTime"};
local DAYS_IN_MONTH = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
local MAX_OVERALL_LEADERBOARDS = 4; -- Overall, you can only create 4 leaderboards using Leaderboard.new, this is to prevent rate limiting
local MAX_BOARDS = 7; -- You can only create up to 7 boards per leaderboard
local SHARD_COUNTS = { -- Feel free to change these based on how many MAU your game does have
	["Hourly"] = 1,
	["Daily"] = 2,
	["Weekly"] = 3,
	["Monthly"] = 4,
}

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

-- Our own very basic implementation of assert because Roblox refuses to fix theirs
local function SmartAssert(condition: boolean, message: string)
	if (not condition) then
		error(message, 2);
	end;
end

local function Map<T>(tbl: {T}, fn: (T, number) -> (any)): {T}
    local t = {};

    for i, v in tbl do
        t[i] = fn(v, i);
    end;

    return t;
end

local function FoundInTable(tbl: {any}, value: any): (boolean | number, any)
	local function Search(t: {any}, val: any)
		for index, v in t do
			if (v == val) then
				return index, v;
			elseif (type(v) == "table") then
				if Search(v, val) then
					return index, v;
				end;
			end;
		end;
		return false, nil;
	end;

	return Search(tbl, value);
end

local function KeysInDictionary(dictionary: {any}): {any}
	local keys = {};

	for key, _ in dictionary do
		table.insert(keys, key);
	end;

	return keys;
end

local function GenerateGUID(): string
	return HttpService:GenerateGUID(false);
end

Util.SmartAssert = SmartAssert;
Util.Map = Map;
Util.FoundInTable = FoundInTable;
Util.GetDaysInMonth = GetDaysInMonth;
Util.KeysInDictionary = KeysInDictionary;
Util.Compression = Compression;
Util.Sha1 = Sha1;
Util.GenerateGUID = GenerateGUID;
Util.BOARD_TYPES = BOARD_TYPES;
Util.MEMORY_STORE_SERVICE_MAX_EXPIRY = MEMORY_STORE_SERVICE_MAX_EXPIRY;
Util.MEMORY_STORE_SERVICE_MIN_EXPIRY = MEMORY_STORE_SERVICE_MIN_EXPIRY;
Util.FALLBACK_EXPIRY_TIMES = {
	["Hourly"] = 3600,
	["Daily"] = 24 * 3600,
	["Weekly"] = 7 * 24 * 3600,
	["Monthly"] = (GetDaysInMonth()) * 24 * 3600, -- Used to have it as 30, but that's not accurate, so we use GetDaysInMonth()
}
Util.MAX_OVERALL_LEADERBOARDS = MAX_OVERALL_LEADERBOARDS;
Util.MAX_BOARDS = MAX_BOARDS;
Util.SHARD_COUNTS = SHARD_COUNTS;

return Util :: {
	SmartAssert: (boolean, string) -> ();
	Map: <T>({T}, (T, number) -> (any)) -> {T};
	FoundInTable: ({any}, any) -> (boolean | number, any);
	GetDaysInMonth: () -> number;
	Compression: typeof(Compression);
	KeysInDictionary: ({any}) -> {any};
	Sha1: typeof(Sha1);
	GenerateGUID: () -> string;
	BOARD_TYPES: {string};
	MEMORY_STORE_SERVICE_MAX_EXPIRY: number;
	MEMORY_STORE_SERVICE_MIN_EXPIRY: number;
	FALLBACK_EXPIRY_TIMES: {[string]: number};
	MAX_OVERALL_LEADERBOARDS: number;
	MAX_BOARDS: number;
	SHARD_COUNTS: {[string]: number};
}
-- Requirements
local Compression = require(script.Compression);
local ExponentialBackoff = require(script.ExponentialBackoff);

local Util = {};
local DAYS_IN_MONTH = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}

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

Util.SmartAssert = SmartAssert;
Util.Map = Map;
Util.FoundInTable = FoundInTable;
Util.GetDaysInMonth = GetDaysInMonth;
Util.ExponentialBackoff = ExponentialBackoff;
Util.Compression = Compression;
return Util;
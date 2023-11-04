--[[
	Arxk was here
]]

-- DataStoreService to handle longer than 42 days (all time most likely)
local DataStoreService = game:GetService("DataStoreService");
local UserService = game:GetService("UserService");
local Players = game:GetService("Players");

-- Requirements
local Promise = require(script.Promise);
local Signal = require(script.Signal);
local Shards = require(script.Shards);
local Compression = require(script.Compression);

-- We support Daily, Weekly, Monthly and AllTime currently
type Shard = Shards.Shards;
export type LeaderboardType = "Daily" | "Weekly" | "Monthly" | "Yearly" | "AllTime";
export type LeaderboardArguments = {
	ServiceKey: string,
	Type: LeaderboardType,
	StoreUsing: string,
	Store: MemoryStoreSortedMap | OrderedDataStore | Shard,
	FallbackExpiry: number,
	LeaderboardUpdated: Signal.Signal<...any>,
}
export type TopData = {
	key: number,
	value: number,
	username: string,
	displayName: string,
}

type Object = {
	__index: Object,
	UpdateInterval: number,
	TopAmount: number,
	UpsertFunction: ((Leaderboard) -> ())?,
	Start: (self: Object, topAmount: number, interval: number, func: (Leaderboard) -> ()) -> (),
	UpdateData: (self: Leaderboard, userId: number, value: number) -> (),
	GetTopData: (self: Leaderboard, amount: number) -> Promise.TypedPromise<{TopData}>,
	Destroy: (self: Leaderboard) -> (),
	new: (serviceKey: string, leaderboardType: LeaderboardType, handleUpsertAndRetrieval: boolean?) -> Leaderboard,
}

type UpsertFunctionType = (Leaderboard) -> ();
export type Leaderboard = typeof(setmetatable({} :: LeaderboardArguments, {} :: Object));

-- Start
local Leaderboards = {}; -- To handle automatic upserting and retrieval of leaderboards
local UserIdsCache = {}; -- To assign userids {username, displayName}

local Leaderboard: Object = {} :: Object;
Leaderboard.__index = Leaderboard;
Leaderboard.UpsertFunction = nil;
Leaderboard.UpdateInterval = 120; -- Default to 2 minutes
Leaderboard.TopAmount = 100; -- Default to 100

function Leaderboard:Start(interval: number, topAmount: number, func: UpsertFunctionType)
	Leaderboard.UpsertFunction = func;
	Leaderboard.UpdateInterval = interval;
	Leaderboard.TopAmount = topAmount;

	task.spawn(function()
		while (true) do
			if (Leaderboard.UpsertFunction) then
				for _, v in pairs(Leaderboards) do
					Leaderboard.UpsertFunction(v);
					v:GetTopData(Leaderboard.TopAmount):andThen(function(data)
						v.LeaderboardUpdated:Fire(data)
					end);
				end;
			end;
			task.wait(Leaderboard.UpdateInterval);
		end;
	end);
end

-- Constants
local SHARD_COUNTS = { -- Feel free to change these based on how many MAU your game does have
	["Daily"] = 10,
	["Weekly"] = 10,
	["Monthly"] = 15,
}
local FALLBACK_EXPIRY_TIMES = {
	["Daily"] = 86400,
	["Weekly"] = 604800,
	["Monthly"] = 2.628e+6,
}

-- Helpers
local function ConstructStore(serviceKey: string, leaderboardType: LeaderboardType): (string, MemoryStoreSortedMap | OrderedDataStore | Shard)
	if (leaderboardType == "Daily" or leaderboardType == "Weekly" or leaderboardType == "Monthly") then
		return "MemoryStore", Shards.new(leaderboardType, serviceKey, SHARD_COUNTS[leaderboardType]);
	end;

	if (leaderboardType == "Yearly") then
		local DateTable = os.date("*t", os.time());
		local CurrentYear = DateTable.year;
		return "OrderedDataStore", DataStoreService:GetOrderedDataStore(`{CurrentYear}:{serviceKey}`);
	end;

	return "OrderedDataStore", DataStoreService:GetOrderedDataStore(serviceKey);
end

local function GetUserInfosFromId(userId: number): string
	userId = tonumber(userId);

	-- First, check if the cache contains the name
	if (UserIdsCache[userId]) then 
		return UserIdsCache[userId];
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

function Leaderboard.new(serviceKey: string, leaderboardType: LeaderboardType, handleUpsertAndRetrieval: boolean?)
	local self = setmetatable({} :: LeaderboardArguments, Leaderboard);

	self.ServiceKey = serviceKey;
	self.Type = leaderboardType;
	self.StoreType, self.Store = ConstructStore(serviceKey, leaderboardType);
	self.FallbackExpiry = FALLBACK_EXPIRY_TIMES[self.Type];
	self.LeaderboardUpdated = Signal.new();

	if (handleUpsertAndRetrieval) then
		Leaderboards[serviceKey] = self;
	end;
	return self;
end

function Leaderboard:GetTopData(amount)
	assert(type(amount) == "number", "Amount must be a number");
	assert(amount <= 100, "You can only get the top 100.");

	local function PromiseRetrieveTopData()
		if (self.StoreType == "MemoryStore") then
			local data = self.Store:GetTopData(amount, Enum.SortDirection.Descending);
			for _, v in pairs(data) do
				local username, displayName = GetUserInfosFromId(v.key);
				v.value = Compression.Decompress(v.value);
				v.username = username;
				v.displayName = displayName;
			end;
			return data;
		else
			local result = self.Store:GetSortedAsync(false, amount);
			local data = result:GetCurrentPage();
			for _, v in pairs(data) do
				local username, displayName = GetUserInfosFromId(v.key);
				v.value = Compression.Decompress(v.value);
				v.username = username;
				v.displayName = displayName;
			end;
			return data;
		end;
	end;

	return Promise.new(function(resolve, reject)
		local success, data = pcall(PromiseRetrieveTopData);

		if (success) then
			resolve(data);
		else
			warn(success, data);
			reject(data);
		end;
	end);
end

function Leaderboard:UpdateData(userId, value) : ()
	assert(type(userId) == "number", "UserId must be a number");
	assert(type(value) == "number", "Value must be a number");
	local CompressedValue = Compression.Compress(value);

	if (self.StoreType == "MemoryStore") then
		self.Store:UpdateData(userId, value);
		return;
	end;

	local Success, Error = pcall(function()
		self.Store:SetAsync(userId, CompressedValue);
	end);
	if (not Success) then
		warn(`Leaderboard had trouble saving: {Error}`);
	end;
end

function Leaderboard:Destroy()
	if (Leaderboards[self.ServiceKey]) then
		Leaderboards[self.ServiceKey] = nil;
	end;
end

return Leaderboard;
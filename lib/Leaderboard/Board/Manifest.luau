--[[
	Manifest system for managing shard configuration in DataStore
]]
local DataStoreService = game:GetService("DataStoreService");

-- Constants
local DEFAULT_RECORD_COUNT = 100;
local OFFLINE_ENVIRONMENT = game.GameId == 0;

-- Only initialize DataStore if not in offline environment
local MANIFEST_DATASTORE: DataStore? = nil;
if (not OFFLINE_ENVIRONMENT) then
	local Success, Result = pcall(function()
		return DataStoreService:GetDataStore("_LeaderboardManifest");
	end);
	if (Success) then
		MANIFEST_DATASTORE = Result;
	else
		warn(`[Manifest] Failed to initialize DataStore: {Result}`);
	end;
end;

--[=[
	@within Manifest
	@interface ShardInfo
	@field shardCount number
	@field keySuffix string
	@field hash string
]=]
export type ShardInfo = {
	shardCount: number,
	keySuffix: string,
	hash: string,
}

--[=[
	@within Manifest
	@interface Manifest
	@field maxItems number
	@field shardInfo ShardInfo
	@field shards {[string]: string}
]=]
export type Manifest = {
	maxItems: number,
	shardInfo: ShardInfo,
	shards: {[string]: string},
}

--- @class Manifest
local Manifest = {};

--[=[
	@within Manifest
	@param boardKey string
	@param shardIndex number
	@return string
	
	Generates a shard key in the format "{boardKey}:shard{shardIndex}"
]=]
local function GetShardKey(boardKey: string, shardIndex: number): string
	return `{boardKey}:shard{shardIndex}`;
end

--[=[
	@within Manifest
	@param maxRecords number
	@return number
	
	Calculates the recommended shard count based on max records.
	Warns if maxRecords exceeds 100,000 or if shardCount > 16 is recommended.
]=]
function Manifest.CalculateShardCount(maxRecords: number): number
	if maxRecords <= 100 then
		return 1;
	elseif maxRecords >= 101 and maxRecords <= 499 then
		return 2;
	elseif maxRecords >= 500 and maxRecords <= 5000 then
		return 3;
	elseif maxRecords >= 5001 and maxRecords <= 10000 then
		return 5;
	elseif maxRecords >= 10001 and maxRecords <= 30000 then
		return 15;
	elseif maxRecords >= 30001 and maxRecords <= 100000 then
		warn(`[Manifest] MaxRecords of {maxRecords} may quickly reach MemoryStore limits. Consider using fewer records or rotating to a new epoch.`);
		return 16;
	else
		warn(`[Manifest] MaxRecords of {maxRecords} exceeds recommended maximum of 100,000. This may quickly reach MemoryStore limits.`);
		return 16;
	end;
end

--[=[
	@within Manifest
	@param boardKey string
	@param shardCount number
	@param maxItems number
	@return Manifest
	
	Creates a new manifest with the specified parameters.
]=]
local function CreateManifest(boardKey: string, shardCount: number, maxItems: number): Manifest
	local shards: {[string]: string} = {};
	for Index = 1, shardCount do
		shards[tostring(Index)] = GetShardKey(boardKey, Index);
	end;

	return {
		maxItems = maxItems,
		shardInfo = {
			shardCount = shardCount,
			keySuffix = ":shard",
			hash = "fnv1a32",
		},
		shards = shards,
	};
end

--[=[
	@within Manifest
	@param boardKey string
	@param shardCount number
	@param maxItems number
	@return (Manifest?, number)
	
	Loads or creates a manifest for the given boardKey.
	Returns the manifest (if created/loaded) and the validated shardCount.
	If manifest exists but shardCount differs, warns and returns existing shardCount.
]=]
function Manifest.LoadOrCreate(boardKey: string, shardCount: number, maxItems: number): (Manifest?, number)
	if (OFFLINE_ENVIRONMENT or not MANIFEST_DATASTORE) then
		return nil, shardCount;
	end;

	local Success, Result = pcall(function()
		return MANIFEST_DATASTORE:GetAsync(boardKey);
	end);

	if (Success and Result) then
		local manifest = Result :: Manifest;
		-- Validate shard count matches
		if (manifest.shardInfo.shardCount ~= shardCount) then
			warn(`[Manifest] Shard count mismatch for "{boardKey}": Existing manifest has {manifest.shardInfo.shardCount} shards, but {shardCount} was requested. Using existing shard count of {manifest.shardInfo.shardCount}. To use a different shard count, rotate to a new epoch by changing the board name.`);
			shardCount = manifest.shardInfo.shardCount;
		end;
		return manifest, shardCount;
	else
		-- Create new manifest
		local manifest = CreateManifest(boardKey, shardCount, maxItems);

		-- Save manifest to DataStore
		local SaveSuccess, SaveResult = pcall(function()
			if (not MANIFEST_DATASTORE) then
				return nil;
			end;
			return MANIFEST_DATASTORE:SetAsync(boardKey, manifest);
		end);

		if (not SaveSuccess) then
			warn(`[Manifest] Failed to save manifest for "{boardKey}": {SaveResult}`);
		end;

		return manifest, shardCount;
	end;
end

Manifest.DEFAULT_RECORD_COUNT = DEFAULT_RECORD_COUNT;
Manifest.GetShardKey = GetShardKey;

return Manifest;


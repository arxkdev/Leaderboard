local Players = game:GetService("Players");
local UserIdsCache = {};

local Processing = {};
local CachedUsernames = {};

local function FetchNameFromAPI(userId: number): string
	local Success, Result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId);
	end);

	return Success, Result;
end;

function UserIdsCache:ProcessIds()
	for UserId in Processing do
		local Success, Result = FetchNameFromAPI(UserId);
		if (Success) then
			CachedUsernames[UserId] = Result;
			Processing[UserId] = nil;
		end;
	end;
end;

function UserIdsCache:GetNameFromUserId(userId: number)
	local player = Players:GetPlayerByUserId(userId);
	if (player) then
		CachedUsernames[userId] = player.Name;
		return player.Name;
	end;

	if (CachedUsernames[userId]) then
		return CachedUsernames[userId];
	else
		local Success, Result = FetchNameFromAPI(userId);
		if (Success) then
			CachedUsernames[userId] = Result;
			return Result;
		end;

		Processing[userId] = true;
		return "Loading...";
	end;
end

task.spawn(function()
	while (true) do
		UserIdsCache:ProcessIds();
		task.wait(10);
	end;
end);

return UserIdsCache;
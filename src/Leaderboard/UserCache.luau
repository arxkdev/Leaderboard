local UserService = game:GetService("UserService");
local UserCache = {};

local TableOfIdsCollected = {};
local CachedDataFromIds = {};

function UserCache:RemoveDupes(tab: {any})
	local hash = {};
	local res = {};
	for _, v in ipairs(tab) do
		if (not hash[v]) then
			res[#res + 1] = v;
			hash[v] = true;
		end;
	end;
	return res;
end

function UserCache:InsertId(id: number)
	if (CachedDataFromIds[id]) then
		return;
	end;
	table.insert(TableOfIdsCollected, tonumber(id));
end

function UserCache:GetDataFromId(id: number)
	local Data = CachedDataFromIds[id];
	if (Data ~= nil and Data[1] ~= nil) then
		return Data[1].Username, Data[1].DisplayName;
	else
		return "Loading...", "Loading...";
	end;
end

task.spawn(function()
    while (task.wait(5)) do
        if (#TableOfIdsCollected > 0) then
            TableOfIdsCollected = UserCache:RemoveDupes(TableOfIdsCollected);
            local SuccessfulIdsConverted = 0;
            local UnsuccessfulIdsConverted = 0;

            for Index = 1, 100 do
                local ID = TableOfIdsCollected[Index];

                if (ID) then
                    print(ID)
                    local Success, Data = pcall(function()
                        return UserService:GetUserInfosByUserIdsAsync({ID});
                    end);
                    if (Success) then
                        CachedDataFromIds[ID] = #Data == 0 and {
                            {
                                Username = "Unknown",
                                DisplayName = "Unknown"
                            }
                        } or Data;
                        table.remove(TableOfIdsCollected, Index);
                        SuccessfulIdsConverted += 1;
                        print("Converted " .. ID .. " to " .. CachedDataFromIds[ID][1].Username);
                    else
                        UnsuccessfulIdsConverted += 1;
                    end;
                end;
            end;
        end;

        task.wait(5);
    end;
end);

return UserCache;
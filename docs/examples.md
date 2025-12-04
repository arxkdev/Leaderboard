---
sidebar_position: 3
---

# Examples

### Automated Example:
```lua
local Leaderboard = require(game:GetService("ReplicatedStorage").Leaderboard);

local Key = 1; -- The key for the leaderboard (change to reset)
local LeaderboardTypes = { -- You must provide keys for the individual boards
	["Hourly"] = {
		Name = `Hourly-{Key}`,
		Automation = true,
		MaxRecords = 100, -- Maximum number of records to store
		DisplayCount = 50, -- Number of records to display (defaults to 50)
		SaveInterval = 30, -- How often to save values (defaults to 30 seconds)
		RefreshInterval = 600, -- How often to refresh records (defaults to 600 seconds / 10 minutes). Increase if you are reaching rate limits frequently.
	},
	["Daily"] = {
		Name = `Daily-{Key}`,
		Automation = true,
		MaxRecords = 100,
		DisplayCount = 50,
		SaveInterval = 30,
		RefreshInterval = 600,
	},
	["Weekly"] = {
		Name = `Weekly-{Key}`,
		Automation = true,
		MaxRecords = 100,
		DisplayCount = 50,
		SaveInterval = 30,
		RefreshInterval = 600,
	},
	["Monthly"] = {
		Name = `Monthly-{Key}`,
		Automation = true,
		MaxRecords = 100,
		DisplayCount = 50,
		SaveInterval = 300,
		RefreshInterval = 1800,
	},
	["AllTime"] = {
		Name = `AllTime-{Key}`,
		Automation = true,
		MaxRecords = 100,
		DisplayCount = 50,
		SaveInterval = 950,
		RefreshInterval = 1800,
	},
};
local MoneyLeaderboard = Leaderboard.new(LeaderboardTypes, true);

local function FunctionToIncrementMoney(userId: number, amount: number)
    -- This is where you would give the user money, just add this line to increment the leaderboard aswell
    MoneyLeaderboard:IncrementValues("All", userId, amount);
end

MoneyLeaderboard.Updated:Connect(function(boards)
    -- This is where you would update the leaderboard GUI
    -- Returns us a table of all the boards that were updated
    for _, board in boards do
        print(`Updating board {board.Type} - with {#board.Data} items!`);
    end;
end)
```

### Non-Automated Example:
```lua
local Leaderboard = require(game:GetService("ReplicatedStorage").Leaderboard);

local INTERVAL = 120; -- 2 minutes
local RECORD_COUNT = 100; -- Amount of records to get per board

local Key = 1; -- The key for the leaderboard (change to reset)
local LeaderboardTypes = { -- You must provide keys for the individual boards
    ["Hourly"] = {
		Name = `Hourly-{Key}`,
	},
    ["Daily"] = {
		Name = `Daily-{Key}`,
	},
    ["Weekly"] = {
		Name = `Weekly-{Key}`,
	},
    ["Monthly"] = {
		Name = `Monthly-{Key}`,
	},
    ["AllTime"] = {
		Name = `AllTime-{Key}`,
	},
};
local MoneyLeaderboard = Leaderboard.new(LeaderboardTypes);

local function FunctionToIncrementMoney(userId: number, amount: number)
    -- This is where you would give the user money, just add this line to increment the leaderboard aswell
    MoneyLeaderboard:IncrementValues("All", userId, amount);
end

local function UpdateLeaderboards()
    -- Add the value to the data
    for _, Player in Players:GetPlayers() do
        FunctionToIncrementMoney(Player.UserId, 100);
    end;

    -- Retrieve the data
    MoneyLeaderboard:GetRecords("All", RECORD_COUNT):andThen(function(data)
        -- This is where you would update the leaderboard GUI
        -- Returns us a table of all the boards that were updated
        for _, board in data do
            print(`Updating board {board.Type} - with {#board.Data} items!`);
        end;
    end);
end

task.spawn(function()
    while (true) do
        UpdateLeaderboards();
        task.wait(INTERVAL);
    end;
end)
```

### Rolling Leaderboard Example:
```lua
local Leaderboard = require(game:GetService("ReplicatedStorage").Leaderboard);

local Key = 1; -- The key for the leaderboard (change to reset)
local Leaderboards = {
	["AllTime"] = {
		Name = `AllTime-{Key}`,
		Automation = true,
		MaxRecords = 100, -- Maximum number of records to store
		DisplayCount = 50, -- Number of records to display (defaults to 50)
		SaveInterval = 30, -- How often to save values (defaults to 30 seconds)
		RefreshInterval = 600, -- How often to refresh records (defaults to 600 seconds / 10 minutes)
	},
    ["10MinutesRolling"] = {60 * 10, `10MinutesRolling-{Key}`}, -- 10 minutes rolling leaderboard
	["15MinutesRolling"] = {60 * 15, `15MinutesRolling-{Key}`}, -- 15 minutes rolling leaderboard
    ["1MinuteRolling"] = {60, `1MinuteRolling-{Key}`}, -- 1 minute rolling leaderboard
};
local MoneyLeaderboard = Leaderboard.new(Leaderboards, true);

local function IncrementMoneyTest()
	-- Test userIds
	local FakeId1, FakeId2 = 100, 101;
	MoneyLeaderboard:IncrementValues(Leaderboards, FakeId1, 100);
	MoneyLeaderboard:IncrementValues(Leaderboards, FakeId2, 100);
end
IncrementMoneyTest();

MoneyLeaderboard.Updated:Connect(function(boards)
	-- Returns us a table of all the boards that were updated
	for _, board in boards do
		print(`Updating board {board.Type} - with {#board.Data} items!`);
	end;
end);
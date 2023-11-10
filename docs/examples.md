---
sidebar_position: 3
---

# Examples

### Automated Example:
```lua
local Leaderboard = require(game:GetService("ReplicatedStorage").Leaderboard)

local Key = 1 -- The key for the leaderboard (change to reset)
local LeaderboardTypes = { -- You must provide keys for the individual boards
	["Hourly"] = `Hourly-{Key}`,
	["Daily"] = `Daily-{Key}`,
	["Weekly"] = `Weekly-{Key}`,
	["Monthly"] = `Monthly-{Key}`,
	["AllTime"] = `AllTime-{Key}`,
};
local MoneyLeaderboard = Leaderboard.new(LeaderboardTypes, {
    -- Settings
    Automation = true,
    Interval = 5,
    RecordCount = 100, -- You can also do {Daily = 50, Weekly = 50, Monthly = 50, AllTime = 100}
})

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
local Leaderboard = require(game:GetService("ReplicatedStorage").Leaderboard)

local INTERVAL = 120; -- 2 minutes
local RECORD_COUNT = 100; -- Amount of records to get per board

local Key = 1 -- The key for the leaderboard (change to reset)
local LeaderboardTypes = { -- You must provide keys for the individual boards
    ["Hourly"] = `Hourly-{Key}`,
    ["Daily"] = `Daily-{Key}`,
    ["Weekly"] = `Weekly-{Key}`,
    ["Monthly"] = `Monthly-{Key}`,
    ["AllTime"] = `AllTime-{Key}`,
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
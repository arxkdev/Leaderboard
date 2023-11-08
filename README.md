# Leaderboard
@arxkdev

### What?
Leaderboard is an intuitive, open-source module designed to effortlessly establish and manage robust non-persistent & persistent leaderboards for your Roblox experiences.

### What can I do with this?
- Create leaderboards for your Roblox experiences
- Pick from a variety of leaderboard types such as <b><i>Hourly, Daily, Weekly, Monthly, All-Time and Yearly</i></b>
- Customize your leaderboard settings to your liking
- Use automation to automatically update your leaderboards
- Easily integrate into your existing codebase with the abstract API

### Why not OrderedDataStore?
You should not be using ODS for non persistent data. It should be persistent data. For years there was a workaround to allow people to create Daily/Weekly/Monthly boards with ODS, a very hacky workaround, but now we have MemoryStoreService which is a much better solution for non persistent data. 

## Examples
### Automated Example:
```lua
local Leaderboard = require(game:GetService("ReplicatedStorage").Leaderboard)

local Key = 1 -- The key for the leaderboard (change to reset)
local LeaderboardTypes = {"Daily", "Weekly", "Monthly", "AllTime"}
local MoneyLeaderboard = Leaderboard.new(`Money_{Key}`, LeaderboardTypes, {
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
local LeaderboardTypes = {"Daily", "Weekly", "Monthly", "AllTime"}
local MoneyLeaderboard = Leaderboard.new(`Money_{Key}`, LeaderboardTypes)

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
    MoneyLeaderboard:RetrieveEntries("All", RECORD_COUNT):andThen(function(data)
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

### Features:
- Custom sharding/partitioning solution for MemoryStoreService to reduce the risk of hitting rate limits
- Abstract API for easy integration into your existing codebase
- Customizable leaderboard settings
- Leaderboard types: Hourly, Daily, Weekly, Monthly, All-Time and Yearly
- Full type support
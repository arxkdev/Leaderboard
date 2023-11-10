-- local ReplicatedStorage = game:GetService("ReplicatedStorage");
-- local Players = game:GetService("Players");

-- local LeaderboardTemplate = ReplicatedStorage:WaitForChild("LeaderboardTemplate");
-- local Lib = ReplicatedStorage:WaitForChild("lib");
-- local Leaderboard = require(Lib.Leaderboard);

-- type TopData = {Leaderboard.TopData};

-- local RollingSettings = {
-- 	{60 * 10}, -- 10 minutes rolling leaderboard
-- 	{60 * 15}, -- 15 minutes rolling leaderboard
-- }

-- -- Constants
-- local Key = 1;
-- local Leaderboards = {"AllTime", "Rolling"};
-- local MoneyLeaderboard = Leaderboard.new(`Money-{Key}`, Leaderboards, {
-- 	Automation = true,
-- 	Interval = 5,
-- 	RecordCount = 100, -- You can also do {Daily = 50, Weekly = 50, Monthly = 50, AllTime = 100}
-- }, RollingSettings);
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Players = game:GetService("Players");

local Lib = ReplicatedStorage:WaitForChild("lib");
local LeaderboardModule = require(Lib.Leaderboard);

local Key = 1;
local AllTimeLeaderboard = LeaderboardModule.new(`AllTime-{Key}`, "AllTime", true);
local DailyLeaderboard = LeaderboardModule.new(`Daily-{Key}`, "Daily", true);
local WeeklyLeaderboard = LeaderboardModule.new(`Weekly-{Key}`, "Weekly", true);

-- Starts with an interval of 5, and the upsert function as described below
LeaderboardModule:Start(5, function(leaderboard)
	-- In here you'd likely get all the current (TotalValues) in their data, and apply
	for _, player in pairs(Players:GetPlayers()) do
		leaderboard:UpdateData(player.UserId, 10000);
	end;
	leaderboard:UpdateData(100, 100);
	leaderboard:UpdateData(101, 1010);
end)

AllTimeLeaderboard.LeaderboardUpdated:Connect(function(leaderboardTop)
	print("AllTime", leaderboardTop);
end)

DailyLeaderboard.LeaderboardUpdated:Connect(function(leaderboardTop)
	print("Daily", leaderboardTop);
end)

WeeklyLeaderboard.LeaderboardUpdated:Connect(function(leaderboardTop)
	print("Weekly", leaderboardTop);
end)

--local function UpdateLeaderboards()
--	-- Set the stats
--	for _, player in pairs(Players:GetPlayers()) do
--		DailyLeaderboard:UpdateData(player.UserId, 10);
--		AllTimeLeaderboard:UpdateData(player.UserId, 10);
--	end;
--	DailyLeaderboard:UpdateData(100, 100);
--	AllTimeLeaderboard:UpdateData(100, 100);

--	-- Retrieve the top list
--	DailyLeaderboard:GetTopData(100):andThen(function(topList)
--		print("DailyTopList", topList);
--	end);
	
--	-- Retrieve the top list all time
--	AllTimeLeaderboard:GetTopData(100):andThen(function(allTimeTopList)
--		print("AllTimeTopList", allTimeTopList);
--	end);
--end

--task.wait(5)
--print("Starting leadeboards")

--task.spawn(function()
--	while (true) do
--		UpdateLeaderboards();
--		task.wait(120);
--	end;
--end)
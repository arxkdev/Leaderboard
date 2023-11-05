local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Players = game:GetService("Players");

local LeaderboardTemplate = ReplicatedStorage:WaitForChild("LeaderboardTemplate");
local Lib = ReplicatedStorage:WaitForChild("lib");
local LeaderboardModule = require(Lib.Leaderboard);

local Key = 1;
local AllTimeLeaderboard = LeaderboardModule.new(`AllTime-{Key}`, "AllTime", true);
local HourlyLeaderboard = LeaderboardModule.new(`Hourly-{Key}`, "Hourly", true);
local DailyLeaderboard = LeaderboardModule.new(`Daily-{Key}`, "Daily", true);
local WeeklyLeaderboard = LeaderboardModule.new(`Weekly-{Key}`, "Weekly", true);
local MonthlyLeaderboard = LeaderboardModule.new(`Monthly-{Key}`, "Monthly", true);

-- Starts with an interval of 5, collec the top 100, and the upsert function as described below
LeaderboardModule:Start(120, 100, function(leaderboard)
	-- In here you'd likely get all the current (TotalValues) in their data, and apply
	for _, player in Players:GetPlayers() do
		leaderboard:UpdateData(player.UserId, 10000);
	end;
	leaderboard:UpdateData(100, 100);
	leaderboard:UpdateData(101, 1010);
end)

local function UpdateBoard(data: {LeaderboardModule.TopData}, model: Model)
	-- Remove current items
	for _, v in model.BoardPart.UI.List:GetChildren() do
		if (not v:IsA("GuiObject")) then continue end;
		v:Destroy();
	end;

	-- Add new items
	for i, v in data do
		local item = LeaderboardTemplate:Clone();
		item.Name = `Item-${i}`;
		item.Rank.Text = v.rank;
		item.Username.Text = `@{v.displayName}`;
		item["Value"].Text = v.value;
		item.Parent = model.BoardPart.UI.List;
	end;
end

AllTimeLeaderboard.LeaderboardUpdated:Connect(function(leaderboardTop)
	print("AllTime", leaderboardTop);
	UpdateBoard(leaderboardTop, workspace.Leaderboards.AllTime);
end)

HourlyLeaderboard.LeaderboardUpdated:Connect(function(leaderboardTop)
	print("Hourly", leaderboardTop);
	UpdateBoard(leaderboardTop, workspace.Leaderboards.Hourly);
end)

DailyLeaderboard.LeaderboardUpdated:Connect(function(leaderboardTop)
	print("Daily", leaderboardTop);
	UpdateBoard(leaderboardTop, workspace.Leaderboards.Daily);
end)

WeeklyLeaderboard.LeaderboardUpdated:Connect(function(leaderboardTop)
	print("Weekly", leaderboardTop);
	UpdateBoard(leaderboardTop, workspace.Leaderboards.Weekly);
end)

MonthlyLeaderboard.LeaderboardUpdated:Connect(function(leaderboardTop)
	print("Monthly", leaderboardTop);
	UpdateBoard(leaderboardTop, workspace.Leaderboards.Monthly);
end)

--local function UpdateLeaderboards()
--	-- Set the stats
--	for _, player in Players:GetPlayers() do
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
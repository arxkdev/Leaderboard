local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Players = game:GetService("Players");
local RunService = game:GetService("RunService");

local LeaderboardTemplate = ReplicatedStorage:WaitForChild("LeaderboardTemplate");
local Leaderboard = require(ReplicatedStorage:WaitForChild("Leaderboard"));

type TopData = {Leaderboard.TopData};

local DEBUG = RunService:IsStudio();

-- Constants
local Key = "1";
local Leaderboards = {
	["Hourly"] = {
		Name = `Money-Hourly-{Key}`,
		Automation = true,
		Interval = 120,
		RecordCount = 100,
	},
	["Daily"] = {
		Name = `Money-Daily-{Key}`,
		Automation = true,
		Interval = 120,
		RecordCount = 100,
	},
	["Weekly"] = {
		Name = `Money-Weekly-{Key}`,
		Automation = true,
		Interval = 120,
		RecordCount = 100,
	},
	["Monthly"] = {
		Name = `Money-Monthly-{Key}`,
		Automation = true,
		Interval = 120,
		RecordCount = 100,
	},
	["AllTime"] = {
		Name = `Money-AllTime-{Key}`,
		Automation = true,
		Interval = 120,
		RecordCount = 100,
	},
};
local MoneyLeaderboard = Leaderboard.new(Leaderboards, true);

local function UpdateBoard(data: TopData, part: BasePart)
	-- Remove current items
	for _, v in part.UI.List:GetChildren() do
		if (not v:IsA("GuiObject")) then continue end;
		v:Destroy();
	end;

	-- Add new items
	for i, v in data do
		local item = LeaderboardTemplate:Clone();
		item.Name = `Item-${i}`;
		item.Rank.Text = v.Rank;
		item.Username.Text = `{v.Username}`;
		item.LayoutOrder = i
		item["Value"].Text = v.Value;
		item.LayoutOrder = v.Rank;
		item.Parent = part.UI.List;
	end;
end

local function IncrementMoneyTest()
	for _, player in Players:GetPlayers() do
		print("Incrementing money test for player", player.UserId);
		MoneyLeaderboard:IncrementValues(Leaderboards, player.UserId, 111);
	end;

	-- Test userIds
	local FakeId1, FakeId2 = 100, 101;
	MoneyLeaderboard:IncrementValues(Leaderboards, FakeId1, 100);
	MoneyLeaderboard:IncrementValues(Leaderboards, FakeId2, 100);

	-- Larger scale test
	for _ = 1, 100 do
		MoneyLeaderboard:IncrementValues(Leaderboards, math.random(1, 10000000), math.random(1, 1500));
	end;
end

MoneyLeaderboard.Updated:Connect(function(boards)
	-- Returns us a table of all the boards that were updated
	for _, board in boards do
		print(`[Money] Updating board {board.Type} - with {#board.Data} entries!`);
		UpdateBoard(board.Data, workspace.Leaderboards["Money"][board.Type]);
	end;
end);
-- MoneyLeaderboard.BoardUpdated:Connect(function(board)
-- 	print(board.Type, board.Data);
-- end);


task.delay(3, function()
	print("Setting money test");
	MoneyLeaderboard:IncrementValues("All", 6271821, 1000);
	task.wait(1);
	print(MoneyLeaderboard:GetRecords("All", 100):expect());
end)


--[[task.delay(10, function()
	print("Incrementing money test");
	IncrementMoneyTest();
	print(MoneyLeaderboard:GetRecords("All", 100):expect());
end)]]

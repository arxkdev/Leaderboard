local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Players = game:GetService("Players");

local LeaderboardTemplate = ReplicatedStorage:WaitForChild("LeaderboardTemplate");
local Leaderboard = require(ReplicatedStorage:WaitForChild("Leaderboard"));

type TopData = {Leaderboard.TopData};

-- Constants
local Key = "1";
local Leaderboards = {
	["Hourly"] = {
		Name = `Wins-Hourly-{Key}`,
		Automation = true,
		Interval = 120,
		RecordCount = 100,
	},
	["Daily"] = {
		Name = `Wins-Daily-{Key}`,
		Automation = true,
		Interval = 120,
		RecordCount = 100,
	},
	["Weekly"] = {
		Name = `Wins-Weekly-{Key}`,
		Automation = true,
		Interval = 120,
		RecordCount = 100,
	},
	["Monthly"] = {
		Name = `Wins-Monthly-{Key}`,
		Automation = true,
		Interval = 120,
		RecordCount = 100,
	},
	["AllTime"] = {
		Name = `Wins-AllTime-{Key}`,
		Automation = true,
		Interval = 120,
		RecordCount = 100,
	},
};
local WinsLeaderboard = Leaderboard.new(Leaderboards, true);

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
		WinsLeaderboard:IncrementValues(Leaderboards, player.UserId, 111);
	end;

	-- Test userIds
	local FakeId1, FakeId2 = 100, 101;
	WinsLeaderboard:IncrementValues(Leaderboards, FakeId1, 100);
	WinsLeaderboard:IncrementValues(Leaderboards, FakeId2, 100);

	-- Larger scale test
	for _ = 1, 10 do
		WinsLeaderboard:IncrementValues(Leaderboards, math.random(1, 10000000), math.random(1, 1500));
	end;
end

WinsLeaderboard.Updated:Connect(function(boards)
	-- Returns us a table of all the boards that were updated
	for _, board in boards do
		print(`[Wins] Updating board {board.Type} - with {#board.Data} entries!`);
		UpdateBoard(board.Data, workspace.Leaderboards["Wins"][board.Type]);
	end;

	-- Increment
	IncrementMoneyTest();
end);
-- WinsLeaderboard.BoardUpdated:Connect(function(board)
-- 	print(board.Type, board.Data);
-- end);
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Players = game:GetService("Players");

local LeaderboardTemplate = ReplicatedStorage:WaitForChild("LeaderboardTemplate");
local Leaderboard = require(ReplicatedStorage:WaitForChild("Leaderboard"));

type TopData = {Leaderboard.TopData};

-- Constants
local Key = "Money10";
local Leaderboards = {
	["Hourly"] = `Hourly-{Key}`,
	["Daily"] = `Daily-{Key}`,
	["Weekly"] = `Weekly-{Key}`,
	["Monthly"] = `Monthly-{Key}`,
	["AllTime"] = `AllTime-{Key}`,

	-- ["10MinutesRolling"] = {60 * 10, `10MinutesRolling-{Key}`}, -- 10 minutes rolling leaderboard
	-- ["15MinutesRolling"] = {60 * 15, `15MinutesRolling-{Key}`}, -- 15 minutes rolling leaderboard
};
local MoneyLeaderboard = Leaderboard.new(Leaderboards, {
	Automation = true,
	Interval = 120,
	RecordCount = 100, -- You can also do {Daily = 50, Weekly = 50, Monthly = 50, AllTime = 100}
});

local function UpdateBoard(data: TopData, model: Model)
	-- Remove current items
	for _, v in model.BoardPart.UI.List:GetChildren() do
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
		item.Parent = model.BoardPart.UI.List;
	end;
end
local function IncrementMoneyTest()
	for _, player in Players:GetPlayers() do
		MoneyLeaderboard:IncrementValues(Leaderboards, player.UserId, 111);
	end;

	-- Test userIds
	local FakeId1, FakeId2 = 100, 101;
	MoneyLeaderboard:IncrementValues(Leaderboards, FakeId1, 100);
	MoneyLeaderboard:IncrementValues(Leaderboards, FakeId2, 100);

	-- Larger scale test
	for _ = 1, 10 do
		MoneyLeaderboard:IncrementValues(Leaderboards, math.random(1, 10000000), math.random(1, 1500));
	end;
end

MoneyLeaderboard.Updated:Connect(function(boards)
	-- Returns us a table of all the boards that were updated
	for _, board in boards do
		print(`[Money] Updating board {board.Type} - with {#board.Data} items!`);
		UpdateBoard(board.Data, workspace.Test1.Leaderboards[board.Type]);
	end;

	-- Increment
	IncrementMoneyTest();
end);
-- MoneyLeaderboard.BoardUpdated:Connect(function(board)
-- 	print(board.Type, board.Data);
-- end);

-- local function UpdateLeaderboards()
-- 	-- Set the stats
-- 	for _, player in Players:GetPlayers() do
-- 		IncrementMoneyStats(player.UserId, 111);
-- 	end;

-- 	-- Test userIds
-- 	IncrementMoneyStats(100, 100);
-- 	IncrementMoneyStats(101, 100);

-- 	-- You can also do MoneyLeaderboard:GetAllTopData("Asc", {Daily = 50, Weekly = 50, Monthly = 50, AllTime = 100});
-- 	MoneyLeaderboard:GetAllTop(VALUES_TO_COLLECT):andThen(function(boards)
-- 		for _, board in boards do
-- 			print(`Updating board {board.Type} - with {#board.Data} items!`);
-- 			UpdateBoard(board.Data, workspace.Leaderboards[board.Type]);
-- 		end;
-- 	end);
-- end

-- task.wait(2);
-- print("Starting leadeboards");

-- task.spawn(function()
-- 	while (true) do
-- 		UpdateLeaderboards();
-- 		task.wait(INTERVAL);
-- 	end;
-- end)
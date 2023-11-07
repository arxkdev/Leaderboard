local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Players = game:GetService("Players");

local LeaderboardTemplate = ReplicatedStorage:WaitForChild("LeaderboardTemplate");
local Lib = ReplicatedStorage:WaitForChild("lib");
local Leaderboard = require(Lib.Leaderboard);

type TopData = {Leaderboard.TopData};

-- Constants
local INTERVAL = 120;
local VALUES_TO_COLLECT = 100;

local Key = 1;
local Leaderboards = {"Hourly", "Daily", "Weekly", "Monthly", "AllTime"};
local MoneyLeaderboard = Leaderboard.new(`Money-{Key}`, Leaderboards);

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
		item.Username.Text = `@{v.DisplayName}`;
		item.LayoutOrder = i
		item["Value"].Text = v.Value;
		item.LayoutOrder = v.Rank;
		item.Parent = model.BoardPart.UI.List;
	end;
end

local function UpdateMoneyLeaderstats(playerId: number, amount: number)
    for _, timeFrame in ipairs(Leaderboards) do
        MoneyLeaderboard:UpdateValue(timeFrame, playerId, amount);
    end;
end

local function UpdateLeaderboards()
	-- Set the stats
	for _, player in Players:GetPlayers() do
		UpdateMoneyLeaderstats(player.UserId, 9999);
	end;
	UpdateMoneyLeaderstats(100, 100);
	UpdateMoneyLeaderstats(101, 100);

	-- You can also do MoneyLeaderboard:GetAllTopData("Asc", {Daily = 50, Weekly = 50, Monthly = 50, AllTime = 100});
	MoneyLeaderboard:AllTopData(VALUES_TO_COLLECT):andThen(function(boards)
		for _, board in pairs(boards) do
			print(`Updating board {board.Type} - with {#board.Data} items`);
			UpdateBoard(board.Data, workspace.Leaderboards[board.Type]);
		end;
	end);
end

task.wait(2);
print("Starting leadeboards");

task.spawn(function()
	while (true) do
		UpdateLeaderboards();
		task.wait(INTERVAL);
	end;
end)
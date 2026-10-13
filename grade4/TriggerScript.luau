
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local triggersFolder = script.Parent

local showQuestion = ReplicatedStorage:WaitForChild("ShowQuestion")
local submitAnswer = ReplicatedStorage:WaitForChild("SubmitAnswer")
local scoreUpdate = ReplicatedStorage:WaitForChild("ScoreUpdate")

local STARTING_SCORE = 100
local MINIMUM_SCORE = 70
local TOTAL_ROUNDS = 5

local scores = {}
local currentRounds = {}
local activeQuestions = {}
local touchDebounce = {}
local finishedPlayers = {}
local questionQueues = {}

local guessingGames = {
	{
		title = "GUESS THE NUMBER (1-10)",
		choices = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10"}
	},
	{
		title = "GUESS THE THING (Pencil/Book/Marker)",
		choices = {"Pencil", "Book", "Marker"}
	},
	{
		title = "GUESS THE ANIMAL (Cat, Dog, Rabbit, Chicken, Elephant)",
		choices = {"Cat", "Dog", "Rabbit", "Chicken", "Elephant"}
	},
	{
		title = "GUESS THE COLOR (Red, Blue, Green, Yellow, Purple)",
		choices = {"Red", "Blue", "Green", "Yellow", "Purple"}
	},
	{
		title = "GUESS THE FOOD (Pizza, Burger, Apple, Banana, Sandwich)",
		choices = {"Pizza", "Burger", "Apple", "Banana", "Sandwich"}
	},
	{
		title = "GUESS THE VEHICLE (Car, Bus, Train, Airplane, Motorcycle)",
		choices = {"Car", "Bus", "Train", "Airplane", "Motorcycle"}
	},
	{
		title = "GUESS THE COUNTRY (Indonesia, Japan, Malaysia, Australia, Brazil)",
		choices = {"Indonesia", "Japan", "Malaysia", "Australia", "Brazil"}
	},
	{
		title = "GUESS THE SHAPE (Circle, Square, Triangle, Rectangle, Star)",
		choices = {"Circle", "Square", "Triangle", "Rectangle", "Star"}
	}
}

-- Shuffle all categories once for each player.
local function shuffleQuestions(player)
	local queue = {}

	for _, gameData in ipairs(guessingGames) do
		table.insert(queue, gameData)
	end

	-- Fisher-Yates shuffle
	for i = #queue, 2, -1 do
		local j = math.random(1, i)
		queue[i], queue[j] = queue[j], queue[i]
	end

	questionQueues[player] = queue
end

-- Get the next category from the shuffled queue.
local function getNextQuestion(player)
	local queue = questionQueues[player]

	if not queue or #queue == 0 then
		return nil
	end

	local gameData = table.remove(queue, 1)

	-- Randomize the secret answer for this category.
	local answer = gameData.choices[
	math.random(1, #gameData.choices)
	]

	return {
		title = gameData.title,
		answer = string.lower(answer)
	}
end

local function initializePlayer(player)
	if scores[player] == nil then
		scores[player] = STARTING_SCORE
		currentRounds[player] = 1
		finishedPlayers[player] = false

		shuffleQuestions(player)

		print("Question queue shuffled for", player.Name)
	end
end

local function setupRoundTrigger(trigger)
	if not trigger:IsA("BasePart") then
		return
	end

	trigger.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		initializePlayer(player)

		if finishedPlayers[player] then return end
		if touchDebounce[player] or activeQuestions[player] then return end

		local roundFolder = trigger:FindFirstAncestorWhichIsA("Folder")
		if not roundFolder then return end

		local roundNumber = tonumber(
			roundFolder.Name:match("^Round(%d+)$")
		)

		if not roundNumber then return end

		-- Only allow the current round.
		if roundNumber ~= currentRounds[player] then
			return
		end

		touchDebounce[player] = true

		local question = getNextQuestion(player)

		if not question then
			touchDebounce[player] = nil

			warn("Question queue is empty for", player.Name)
			return
		end

		activeQuestions[player] = {
			title = question.title,
			answer = question.answer,
			roundNumber = roundNumber
		}

		scoreUpdate:FireClient(
			player,
			"Starting score",
			scores[player],
			false
		)

		showQuestion:FireClient(player, question.title)

		print(
			player.Name,
			"entered Round",
			roundNumber,
			question.title
		)

		task.delay(1, function()
			touchDebounce[player] = nil
		end)
	end)
end

-- Process submitted answers.
submitAnswer.OnServerEvent:Connect(function(player, submittedAnswer)
	local question = activeQuestions[player]

	if not question then return end
	if typeof(submittedAnswer) ~= "string" then return end
	if finishedPlayers[player] then return end

	local answer = string.lower(
		submittedAnswer:match("^%s*(.-)%s*$")
	)

	if answer == "" then return end

	local scoreChange

	if answer == question.answer then
		scoreChange = math.random(5, 10)
	else
		scoreChange = -math.random(5, 10)
	end

	scores[player] = scores[player] + scoreChange

	local score = scores[player]
	local completedRound = question.roundNumber

	activeQuestions[player] = nil
	currentRounds[player] = completedRound + 1

	local message

	if scoreChange > 0 then
		message = "CORRECT! +" .. scoreChange
	else
		message = "WRONG! " .. scoreChange
	end

	if completedRound < TOTAL_ROUNDS then
		message = message .. "\nProceed to Round "
			.. tostring(completedRound + 1)
	else
		message = message .. "\nRound 5 complete! Go to the finish."
	end

	scoreUpdate:FireClient(player, message, score, false)

	print(
		player.Name,
		message,
		"Score:",
		score
	)
end)

-- Finish line.
local finishTrigger = triggersFolder:WaitForChild("FinishTrigger")

finishTrigger.Touched:Connect(function(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	initializePlayer(player)

	if finishedPlayers[player] then return end
	if activeQuestions[player] then return end

	-- Player must complete all five rounds.
	if currentRounds[player] <= TOTAL_ROUNDS then
		scoreUpdate:FireClient(
			player,
			"COMPLETE ALL 5 ROUNDS FIRST!",
			scores[player],
			false
		)
		return
	end

	finishedPlayers[player] = true

	local finalScore = scores[player]

	if finalScore < MINIMUM_SCORE then
		scoreUpdate:FireClient(
			player,
			"FINISH_LOSE",
			finalScore,
			true
		)

		print(player.Name, "LOST at finish. Score:", finalScore)

		-- Kill the player three seconds after reaching the finish.
		task.delay(1, function()
			if player.Character == character
				and humanoid.Parent
				and humanoid.Health > 0 then

				humanoid.Health = 0
			end
		end)
	else
		scoreUpdate:FireClient(
			player,
			"FINISH_WIN",
			finalScore,
			false
		)

		print(player.Name, "WON! Final score:", finalScore)
	end
end)

-- Connect round triggers.
for _, item in ipairs(triggersFolder:GetChildren()) do
	if item:IsA("Folder") or item:IsA("Model") then
		for _, trigger in ipairs(item:GetDescendants()) do
			setupRoundTrigger(trigger)
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	scores[player] = nil
	currentRounds[player] = nil
	activeQuestions[player] = nil
	touchDebounce[player] = nil
	finishedPlayers[player] = nil
	questionQueues[player] = nil
end)

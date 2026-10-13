
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local showQuestion = ReplicatedStorage:WaitForChild("ShowQuestion")
local submitAnswer = ReplicatedStorage:WaitForChild("SubmitAnswer")
local scoreUpdate = ReplicatedStorage:WaitForChild("ScoreUpdate")

local gui = script.Parent
local frame = gui:WaitForChild("QuestionFrame")
local questionLabel = frame:WaitForChild("QuestionLabel")
local answerInput = frame:WaitForChild("AnswerInput")
local submitButton = frame:WaitForChild("SubmitButton")

local resultLabel = frame:WaitForChild("ResultLabel")

local questionOpen = false
local waitingForResult = false

frame.Visible = false

local function freezePlayer(freeze)
	local character = player.Character

	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return
	end

	if freeze then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	else
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
		humanoid.JumpHeight = 7.2
	end
end

showQuestion.OnClientEvent:Connect(function(title)
	questionLabel.Text = title
	answerInput.Text = ""

	submitButton.Text = "SUBMIT"
	submitButton.Active = true
	submitButton.AutoButtonColor = true

	frame.Visible = true
	questionOpen = true
	waitingForResult = false

	freezePlayer(true)
	answerInput:CaptureFocus()
end)

submitButton.Activated:Connect(function()
	if not questionOpen or waitingForResult then
		return
	end

	local answer = answerInput.Text

	if answer:match("^%s*$") then
		questionLabel.Text = "ENTER YOUR GUESS!"
		return
	end

	questionOpen = false
	waitingForResult = true

	submitButton.Text = "CHECKING..."
	submitButton.Active = false
	submitButton.AutoButtonColor = false

	submitAnswer:FireServer(answer)
end)

answerInput.FocusLost:Connect(function(enterPressed)
	if enterPressed and questionOpen and not waitingForResult then
		submitButton:Activate()
	end
end)


scoreUpdate.OnClientEvent:Connect(function(message, score, gameOver)
    if message == "Starting score" then
        return
    end

    -- Final losing screen
    if message == "FINISH_LOSE" then
        questionOpen = false
        waitingForResult = true

        questionLabel.Visible = false
        answerInput.Visible = false
        submitButton.Visible = false

        resultLabel.Text =
            "SORRY, YOU LOSE!\nYOUR SCORE IS " .. tostring(score) .. "!"

        resultLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
        resultLabel.TextSize = 32
        resultLabel.TextScaled = false
        resultLabel.BackgroundTransparency = 1
        resultLabel.Size = UDim2.new(1, -40, 1, -20)
        resultLabel.Position = UDim2.new(0, 20, 0, 10)
        resultLabel.Visible = true

        frame.Visible = true
        freezePlayer(true)
        return
    end

    -- Final winning screen
    if message == "FINISH_WIN" then
        questionOpen = false
        waitingForResult = true

        questionLabel.Visible = false
        answerInput.Visible = false
        submitButton.Visible = false

        resultLabel.Text =
            "CONGRATS!\nYOUR SCORE IS " .. tostring(score) .. "!"

        resultLabel.TextColor3 = Color3.fromRGB(50, 255, 100)
        resultLabel.TextSize = 32
        resultLabel.TextScaled = false
        resultLabel.BackgroundTransparency = 1
        resultLabel.Size = UDim2.new(1, -40, 1, -20)
        resultLabel.Position = UDim2.new(0, 20, 0, 10)
        resultLabel.Visible = true

        frame.Visible = true
        freezePlayer(false)
        return
    end

    -- Normal round result
    resultLabel.Text = message .. "\nScore: " .. tostring(score)
    resultLabel.Visible = true

    submitButton.Text = "CONTINUE"

    task.wait(1.5)

    frame.Visible = false
    resultLabel.Visible = false

    questionLabel.Visible = true
    answerInput.Visible = true
    submitButton.Visible = true

    questionOpen = false
    waitingForResult = false

    freezePlayer(false)
end)


player.CharacterAdded:Connect(function()
	task.wait(0.2)

	if not frame.Visible then
		freezePlayer(false)
	end
end)

-- ==========================================
-- [ Ojson Client ] 0.9 BETA - Bee Swarm Simulator (Auto Detect Max Pollen + Instant Teleport + Circle Farm + Sprinklers 1-7)
-- ==========================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
if not player then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	player = Players.LocalPlayer
end

-- ==========================================
--    SYSTEM WERYFIKACJI UPRAWNIEŃ (WHITELIST)
-- ==========================================
local ALLOWED_USERS = {
	[123456789] = true, -- <-- WPISZ SWOJE USER ID TUTAJ
	["xOJSON2plX"] = true -- <-- LUB SWÓJ NICK TUTAJ
}

local function checkAccess()
	if ALLOWED_USERS[player.UserId] or ALLOWED_USERS[player.Name] then
		return true
	end
	return false
end

local function getSafeGuiParent()
	local success, hui = pcall(function() return gethui and gethui() end)
	if success and hui then return hui end
	local successCore, _ = pcall(function() return CoreGui.Name end)
	if successCore then return CoreGui end
	return player:WaitForChild("PlayerGui", 10)
end

local guiParent = getSafeGuiParent()
if not guiParent then return end

-- Czyszczenie starych instancji
for _, name in ipairs({"OjsonGrimMenu", "OjsonNotification", "OjsonLoadingGui", "OjsonAccessDenied"}) do
	local old = guiParent:FindFirstChild(name)
	if old then old:Destroy() end
end

-- BLOKADA WSTRZYKNIĘCIA JEŚLI BRAK DOSTĘPU (Z PASKIEM CZASOWYM 6 SEKUND)
if not checkAccess() then
	local denyGui = Instance.new("ScreenGui")
	denyGui.Name = "OjsonAccessDenied"
	denyGui.ResetOnSpawn = false
	denyGui.DisplayOrder = 999
	denyGui.Parent = guiParent

	local denyFrame = Instance.new("Frame")
	denyFrame.Size = UDim2.new(0, 340, 0, 145)
	denyFrame.Position = UDim2.new(0.5, -170, 0.5, -72)
	denyFrame.BackgroundColor3 = Color3.fromRGB(15, 12, 22)
	denyFrame.BackgroundTransparency = 0.2
	denyFrame.BorderSizePixel = 0
	denyFrame.Parent = denyGui
	Instance.new("UICorner", denyFrame).CornerRadius = UDim.new(0, 16)

	local denyStroke = Instance.new("UIStroke")
	denyStroke.Color = Color3.fromRGB(239, 68, 68)
	denyStroke.Thickness = 1.8
	denyStroke.Parent = denyFrame

	local denyTitle = Instance.new("TextLabel")
	denyTitle.Size = UDim2.new(1, -24, 0, 28)
	denyTitle.Position = UDim2.new(0, 12, 0, 16)
	denyTitle.Text = "ACCESS DENIED"
	denyTitle.TextColor3 = Color3.fromRGB(239, 68, 68)
	denyTitle.Font = Enum.Font.GothamBold
	denyTitle.TextSize = 15
	denyTitle.BackgroundTransparency = 1
	denyTitle.Parent = denyFrame

	local denyDesc = Instance.new("TextLabel")
	denyDesc.Size = UDim2.new(1, -24, 0, 48)
	denyDesc.Position = UDim2.new(0, 12, 0, 46)
	denyDesc.Text = "Nie masz uprawnień do uruchomienia Ojson Client.\nTwoje ID: " .. tostring(player.UserId)
	denyDesc.TextColor3 = Color3.fromRGB(220, 215, 235)
	denyDesc.Font = Enum.Font.GothamMedium
	denyDesc.TextSize = 11
	denyDesc.TextWrapped = true
	denyDesc.BackgroundTransparency = 1
	denyDesc.Parent = denyFrame

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -24, 0, 4)
	barBg.Position = UDim2.new(0, 12, 1, -18)
	barBg.BackgroundColor3 = Color3.fromRGB(50, 30, 40)
	barBg.BorderSizePixel = 0
	barBg.Parent = denyFrame
	Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(1, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg
	Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

	local duration = 6.0
	TweenService:Create(barFill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = UDim2.new(0, 0, 1, 0)
	}):Play()

	task.delay(duration, function()
		if denyGui and denyGui.Parent then
			denyGui:Destroy()
		end
	end)
	return
end

local vimAvailable, VirtualInputManager = pcall(function()
	return game:GetService("VirtualInputManager")
end)

-- ==========================================
--    ZMIENNE KONFIGURACYJNE
-- ==========================================
local autoFarmEnabled = false
local autoHoldEnabled = false
local autoSprinklersEnabled = false
local sprinklerSlot = "1"
local sprinklerKeyCodes = {
	["1"] = Enum.KeyCode.One,
	["2"] = Enum.KeyCode.Two,
	["3"] = Enum.KeyCode.Three,
	["4"] = Enum.KeyCode.Four,
	["5"] = Enum.KeyCode.Five,
	["6"] = Enum.KeyCode.Six,
	["7"] = Enum.KeyCode.Seven,
}
local sprinklerSlotOptions = {"1", "2", "3", "4", "5", "6", "7"}

local autoCollectTokensEnabled = false
local infJumpEnabled = false
local selectedField = "Dandelion Field"
local farmWalkSpeed = 50
local menuOpen = false
local isConverting = false

local hivePosition = nil
local maxPollenLimit = 50000
local autoDetectMax = true

local customWalkSpeed = 50
local customJumpPower = 80
local walkSpeedEnabled = false
local jumpPowerEnabled = false

local currentStatusText = "Ojson Client"

local fieldNames = {
	"Bamboo Field", "Blue Flower Field", "Cactus Field", "Clover Field",
	"Dandelion Field", "Mountain Top Field", "Mushroom Field", "Pepper Patch",
	"Pineapple Patch", "Pine Tree Forest", "Pumpkin Patch", "Rose Field",
	"Spider Field", "Sunflower Field"
}

local fieldPositions = {
	["Bamboo Field"] = Vector3.new(134.01, 20, -33.70),
	["Blue Flower Field"] = Vector3.new(110, 4, 100),
	["Cactus Field"] = Vector3.new(-196.53, 68, -103.07),
	["Clover Field"] = Vector3.new(150, 34, 190),
	["Dandelion Field"] = Vector3.new(-30, 4, 220),
	["Mountain Top Field"] = Vector3.new(75, 176, -165),
	["Mushroom Field"] = Vector3.new(-90, 4, 110),
	["Pepper Patch"] = Vector3.new(-480, 124, 530),
	["Pineapple Patch"] = Vector3.new(255, 68, -210),
	["Pine Tree Forest"] = Vector3.new(-320, 68, -190),
	["Pumpkin Patch"] = Vector3.new(-195, 68, -185),
	["Rose Field"] = Vector3.new(-330, 20, 120),
	["Spider Field"] = Vector3.new(-30, 20, -10),
	["Sunflower Field"] = Vector3.new(-210, 4, 170)
}

-- Kolory skryptu
local C_BG = Color3.fromRGB(15, 12, 22)
local C_CARD = Color3.fromRGB(24, 18, 33)
local C_ACCENT = Color3.fromRGB(139, 92, 246)
local C_TEXT = Color3.fromRGB(255, 255, 255)
local C_TEXT_MUTED = Color3.fromRGB(160, 150, 185)
local C_STROKE = Color3.fromRGB(65, 48, 92)

-- Pozycje Dynamicznej Wyspy
local POS_IDLE = UDim2.new(0.5, -100, 0, 70)
local POS_ACTIVE = UDim2.new(0.5, -100, 0, 115)

-- ==========================================
--    DYNAMICZNA WYSPA (Z PULSOWANIEM)
-- ==========================================
local notifGui = Instance.new("ScreenGui")
notifGui.Name = "OjsonNotification"
notifGui.ResetOnSpawn = false
notifGui.DisplayOrder = 102
notifGui.Enabled = false
notifGui.Parent = guiParent

local islandContainer = Instance.new("Frame")
islandContainer.Size = UDim2.new(0, 200, 0, 36)
islandContainer.Position = POS_IDLE
islandContainer.BackgroundTransparency = 1
islandContainer.Parent = notifGui

local timeLabel = Instance.new("TextLabel")
timeLabel.Size = UDim2.new(0, 55, 1, 0)
timeLabel.Position = UDim2.new(0, -60, 0, 0)
timeLabel.BackgroundTransparency = 1
timeLabel.TextColor3 = C_TEXT
timeLabel.Font = Enum.Font.GothamBold
timeLabel.TextSize = 12
timeLabel.TextXAlignment = Enum.TextXAlignment.Right
timeLabel.Text = os.date("%H:%M")
timeLabel.Parent = islandContainer

task.spawn(function()
	while task.wait(10) do
		if timeLabel and timeLabel.Parent then
			timeLabel.Text = os.date("%H:%M")
		end
	end
end)

local signalContainer = Instance.new("Frame")
signalContainer.Size = UDim2.new(0, 20, 0, 16)
signalContainer.Position = UDim2.new(1, 10, 0.5, -8)
signalContainer.BackgroundTransparency = 1
signalContainer.Parent = islandContainer

for i = 1, 4 do
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 3, 0, i * 4)
	bar.Position = UDim2.new(0, (i - 1) * 5, 1, -(i * 4))
	bar.BackgroundColor3 = C_ACCENT
	bar.BorderSizePixel = 0
	bar.Parent = signalContainer
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
end

local notifFrame = Instance.new("Frame")
notifFrame.Size = UDim2.new(1, 0, 1, 0)
notifFrame.Position = UDim2.new(0, 0, 0, 0)
notifFrame.BackgroundColor3 = C_BG
notifFrame.BackgroundTransparency = 0.35
notifFrame.BorderSizePixel = 0
notifFrame.Parent = islandContainer
Instance.new("UICorner", notifFrame).CornerRadius = UDim.new(1, 0)

local notifStroke = Instance.new("UIStroke")
notifStroke.Color = C_STROKE
notifStroke.Thickness = 1.2
notifStroke.Parent = notifFrame

local islandPulseTween = TweenService:Create(notifFrame, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
	BackgroundTransparency = 0.20
})
islandPulseTween:Play()

local spinner = Instance.new("Frame")
spinner.Size = UDim2.new(0, 14, 0, 14)
spinner.Position = UDim2.new(0, 10, 0.5, -7)
spinner.BackgroundTransparency = 1
spinner.Parent = notifFrame

local spinnerRing = Instance.new("Frame")
spinnerRing.Size = UDim2.new(1, 0, 1, 0)
spinnerRing.BackgroundColor3 = C_ACCENT
spinnerRing.BackgroundTransparency = 0.2
spinnerRing.Parent = spinner
Instance.new("UICorner", spinnerRing).CornerRadius = UDim.new(1, 0)

local spinnerInner = Instance.new("Frame")
spinnerInner.Size = UDim2.new(0, 8, 0, 8)
spinnerInner.Position = UDim2.new(0.5, -4, 0.5, -4)
spinnerInner.BackgroundColor3 = C_BG
spinnerInner.Parent = spinner
Instance.new("UICorner", spinnerInner).CornerRadius = UDim.new(1, 0)

task.spawn(function()
	while task.wait(0.02) do
		if spinner then spinner.Rotation = spinner.Rotation + 10 end
	end
end)

local notifText = Instance.new("TextLabel")
notifText.Size = UDim2.new(1, -32, 1, 0)
notifText.Position = UDim2.new(0, 30, 0, 0)
notifText.Text = "Ojson Client"
notifText.TextColor3 = C_TEXT
notifText.BackgroundTransparency = 1
notifText.Font = Enum.Font.GothamBold
notifText.TextSize = 11
notifText.TextXAlignment = Enum.TextXAlignment.Left
notifText.Parent = notifFrame

local function setClientStatus(txt)
	currentStatusText = txt
	if notifText and notifText.Parent then
		notifText.Text = txt
	end
end

local notifToken = 0
local function showNotification(text, stateType)
	notifToken = notifToken + 1
	local currentToken = notifToken

	if notifText then notifText.Text = text end
	if timeLabel then timeLabel.Visible = false end
	if signalContainer then signalContainer.Visible = false end

	local targetColor = C_ACCENT
	if stateType == true then
		targetColor = Color3.fromRGB(34, 197, 94)
	elseif stateType == false then
		targetColor = Color3.fromRGB(239, 68, 68)
	end
	TweenService:Create(spinnerRing, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()

	spinner.Size = UDim2.new(0, 20, 0, 20)
	spinner.Position = UDim2.new(0, 7, 0.5, -10)
	TweenService:Create(spinner, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(0, 10, 0.5, -7)
	}):Play()

	TweenService:Create(islandContainer, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = POS_ACTIVE
	}):Play()

	task.delay(2.5, function()
		if notifToken == currentToken and islandContainer and islandContainer.Parent then
			if notifText then notifText.Text = currentStatusText end
			if timeLabel then timeLabel.Visible = true end
			if signalContainer then signalContainer.Visible = true end
			TweenService:Create(spinnerRing, TweenInfo.new(0.25), {BackgroundColor3 = C_ACCENT}):Play()
			TweenService:Create(islandContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = POS_IDLE
			}):Play()
		end
	end)
end

-- ==========================================
--    GŁÓWNE OKNO MENU (GUI 1) Z ANIMACJĄ
-- ==========================================
local menuGui = Instance.new("ScreenGui")
menuGui.Name = "OjsonGrimMenu"
menuGui.ResetOnSpawn = false
menuGui.DisplayOrder = 101
menuGui.Parent = guiParent

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 940, 0, 570)
mainFrame.Position = UDim2.new(0.5, -470, 0.5, -285)
mainFrame.BackgroundColor3 = C_BG
mainFrame.BackgroundTransparency = 0.35
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = false
mainFrame.Visible = false
mainFrame.Parent = menuGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 18)

local function setMenuVisible(state)
	if state then
		mainFrame.Visible = true
		mainFrame.Size = UDim2.new(0, 800, 0, 480)
		mainFrame.BackgroundTransparency = 1
		TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 940, 0, 570),
			BackgroundTransparency = 0.35
		}):Play()
	else
		local tw = TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 800, 0, 480),
			BackgroundTransparency = 1
		})
		tw:Play()
		tw.Completed:Connect(function()
			if not menuOpen then
				mainFrame.Visible = false
			end
		end)
	end
end

local mainBlurEffect = Instance.new("Frame")
mainBlurEffect.Size = UDim2.new(1, 0, 1, 0)
mainBlurEffect.BackgroundColor3 = Color3.fromRGB(15, 10, 25)
mainBlurEffect.BackgroundTransparency = 0.55
mainBlurEffect.ZIndex = 0
mainBlurEffect.Parent = mainFrame
Instance.new("UICorner", mainBlurEffect).CornerRadius = UDim.new(0, 18)

local menuToggleIndicator = Instance.new("TextLabel")
menuToggleIndicator.Size = UDim2.new(0, 240, 0, 24)
menuToggleIndicator.Position = UDim2.new(1, -252, 1, -32)
menuToggleIndicator.Text = "open/close menu: RightCtrl"
menuToggleIndicator.TextColor3 = C_TEXT_MUTED
menuToggleIndicator.BackgroundTransparency = 1
menuToggleIndicator.Font = Enum.Font.GothamMedium
menuToggleIndicator.TextSize = 10
menuToggleIndicator.TextXAlignment = Enum.TextXAlignment.Right
menuToggleIndicator.ZIndex = 2
menuToggleIndicator.Parent = mainFrame

local rightDrawer
local sliderDrawer
local inputDrawer

local function showDrawerInstant(drawer, show)
	if not drawer then return end
	if show then
		drawer.Visible = true
		drawer.Position = UDim2.new(0.5, 478, 0.5, -285)
		drawer.BackgroundTransparency = 0.35
	else
		drawer.Visible = false
	end
end

local function animateDrawer(drawer, open)
	showDrawerInstant(drawer, open)
end

-- Panel listowy (GUI 2)
rightDrawer = Instance.new("Frame")
rightDrawer.Size = UDim2.new(0, 240, 0, 570)
rightDrawer.Position = UDim2.new(0.5, 478, 0.5, -285)
rightDrawer.BackgroundColor3 = C_BG
rightDrawer.BackgroundTransparency = 0.35
rightDrawer.BorderSizePixel = 0
rightDrawer.Visible = false
rightDrawer.ZIndex = 70
rightDrawer.Parent = menuGui
Instance.new("UICorner", rightDrawer).CornerRadius = UDim.new(0, 18)

local rdBlur = Instance.new("Frame")
rdBlur.Size = UDim2.new(1, 0, 1, 0)
rdBlur.BackgroundColor3 = Color3.fromRGB(15, 10, 25)
rdBlur.BackgroundTransparency = 0.55
rdBlur.ZIndex = 69
rdBlur.Parent = rightDrawer
Instance.new("UICorner", rdBlur).CornerRadius = UDim.new(0, 18)

local rdTitle = Instance.new("TextLabel")
rdTitle.Size = UDim2.new(1, -50, 0, 30)
rdTitle.Position = UDim2.new(0, 14, 0, 14)
rdTitle.Text = "Select Field"
rdTitle.TextColor3 = C_TEXT
rdTitle.Font = Enum.Font.GothamBold
rdTitle.TextSize = 13
rdTitle.TextXAlignment = Enum.TextXAlignment.Left
rdTitle.BackgroundTransparency = 1
rdTitle.ZIndex = 72
rdTitle.Parent = rightDrawer

local rdCloseBtn = Instance.new("TextButton")
rdCloseBtn.Size = UDim2.new(0, 28, 0, 28)
rdCloseBtn.Position = UDim2.new(1, -38, 0, 12)
rdCloseBtn.BackgroundTransparency = 1
rdCloseBtn.Text = "(x)"
rdCloseBtn.TextColor3 = C_TEXT_MUTED
rdCloseBtn.Font = Enum.Font.GothamBold
rdCloseBtn.TextSize = 13
rdCloseBtn.ZIndex = 73
rdCloseBtn.Parent = rightDrawer

rdCloseBtn.MouseButton1Click:Connect(function()
	showDrawerInstant(rightDrawer, false)
end)

local rdScroll = Instance.new("ScrollingFrame")
rdScroll.Size = UDim2.new(1, -12, 1, -60)
rdScroll.Position = UDim2.new(0, 6, 0, 52)
rdScroll.BackgroundTransparency = 1
rdScroll.ScrollBarThickness = 3
rdScroll.ZIndex = 72
rdScroll.Parent = rightDrawer
local rdLayout = Instance.new("UIListLayout")
rdLayout.SortOrder = Enum.SortOrder.LayoutOrder
rdLayout.Padding = UDim.new(0, 6)
rdLayout.Parent = rdScroll

-- Panel suwaka
sliderDrawer = Instance.new("Frame")
sliderDrawer.Size = UDim2.new(0, 240, 0, 110)
sliderDrawer.Position = UDim2.new(0.5, 478, 0.5, -285)
sliderDrawer.BackgroundColor3 = C_BG
sliderDrawer.BackgroundTransparency = 0.35
sliderDrawer.BorderSizePixel = 0
sliderDrawer.Visible = false
sliderDrawer.ZIndex = 70
sliderDrawer.Parent = menuGui
Instance.new("UICorner", sliderDrawer).CornerRadius = UDim.new(0, 18)

local sdBlur = Instance.new("Frame")
sdBlur.Size = UDim2.new(1, 0, 1, 0)
sdBlur.BackgroundColor3 = Color3.fromRGB(15, 10, 25)
sdBlur.BackgroundTransparency = 0.55
sdBlur.ZIndex = 69
sdBlur.Parent = sliderDrawer
Instance.new("UICorner", sdBlur).CornerRadius = UDim.new(0, 18)

local sdTitle = Instance.new("TextLabel")
sdTitle.Size = UDim2.new(1, -50, 0, 24)
sdTitle.Position = UDim2.new(0, 14, 0, 12)
sdTitle.Text = "JumpPower"
sdTitle.TextColor3 = C_TEXT
sdTitle.Font = Enum.Font.GothamBold
sdTitle.TextSize = 13
sdTitle.TextXAlignment = Enum.TextXAlignment.Left
sdTitle.BackgroundTransparency = 1
sdTitle.ZIndex = 72
sdTitle.Parent = sliderDrawer

local sdCloseBtn = Instance.new("TextButton")
sdCloseBtn.Size = UDim2.new(0, 26, 0, 26)
sdCloseBtn.Position = UDim2.new(1, -36, 0, 11)
sdCloseBtn.BackgroundTransparency = 1
sdCloseBtn.Text = "(x)"
sdCloseBtn.TextColor3 = C_TEXT_MUTED
sdCloseBtn.Font = Enum.Font.GothamBold
sdCloseBtn.TextSize = 13
sdCloseBtn.ZIndex = 73
sdCloseBtn.Parent = sliderDrawer

sdCloseBtn.MouseButton1Click:Connect(function()
	showDrawerInstant(sliderDrawer, false)
end)

local sdValueLbl = Instance.new("TextLabel")
sdValueLbl.Size = UDim2.new(0, 60, 0, 24)
sdValueLbl.Position = UDim2.new(1, -100, 0, 12)
sdValueLbl.Text = "80"
sdValueLbl.TextColor3 = C_ACCENT
sdValueLbl.Font = Enum.Font.GothamBold
sdValueLbl.TextSize = 13
sdValueLbl.TextXAlignment = Enum.TextXAlignment.Right
sdValueLbl.BackgroundTransparency = 1
sdValueLbl.ZIndex = 72
sdValueLbl.Parent = sliderDrawer

local sliderTrack = Instance.new("Frame")
sliderTrack.Size = UDim2.new(1, -28, 0, 8)
sliderTrack.Position = UDim2.new(0, 14, 0, 65)
sliderTrack.BackgroundColor3 = C_CARD
sliderTrack.BorderSizePixel = 0
sliderTrack.ZIndex = 72
sliderTrack.Parent = sliderDrawer
Instance.new("UICorner", sliderTrack).CornerRadius = UDim.new(1, 0)

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(0.5, 0, 1, 0)
sliderFill.BackgroundColor3 = C_ACCENT
sliderFill.BorderSizePixel = 0
sliderFill.ZIndex = 73
sliderFill.Parent = sliderTrack
Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

local sliderThumb = Instance.new("Frame")
sliderThumb.Size = UDim2.new(0, 14, 0, 14)
sliderThumb.AnchorPoint = Vector2.new(0.5, 0.5)
sliderThumb.Position = UDim2.new(0.5, 0, 0.5, 0)
sliderThumb.BackgroundColor3 = C_TEXT
sliderThumb.BorderSizePixel = 0
sliderThumb.ZIndex = 74
sliderThumb.Parent = sliderTrack
Instance.new("UICorner", sliderThumb).CornerRadius = UDim.new(1, 0)

local sliderMin, sliderMax = 16, 250
local activeSliderCallback = nil

local function updateSliderVisual(val)
	local percent = math.clamp((val - sliderMin) / (sliderMax - sliderMin), 0, 1)
	sliderFill.Size = UDim2.new(percent, 0, 1, 0)
	sliderThumb.Position = UDim2.new(percent, 0, 0.5, 0)
	sdValueLbl.Text = tostring(math.floor(val))
end

local sliding = false
sliderTrack.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		sliding = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		sliding = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local pos = input.Position.X
		local absPos = sliderTrack.AbsolutePosition.X
		local absSize = sliderTrack.AbsoluteSize.X
		local percent = math.clamp((pos - absPos) / absSize, 0, 1)
		local val = sliderMin + percent * (sliderMax - sliderMin)
		updateSliderVisual(val)
		if activeSliderCallback then
			activeSliderCallback(math.floor(val))
		end
	end
end)

-- Panel ustawień Auto Farm (przycisk Field: ... + Max Pollen Limit + Save)
inputDrawer = Instance.new("Frame")
inputDrawer.Size = UDim2.new(0, 240, 0, 174)
inputDrawer.Position = UDim2.new(0.5, 478, 0.5, -285)
inputDrawer.BackgroundColor3 = C_BG
inputDrawer.BackgroundTransparency = 0.35
inputDrawer.BorderSizePixel = 0
inputDrawer.Visible = false
inputDrawer.ZIndex = 70
inputDrawer.Parent = menuGui
Instance.new("UICorner", inputDrawer).CornerRadius = UDim.new(0, 18)

local idBlur = Instance.new("Frame")
idBlur.Size = UDim2.new(1, 0, 1, 0)
idBlur.BackgroundColor3 = Color3.fromRGB(15, 10, 25)
idBlur.BackgroundTransparency = 0.55
idBlur.ZIndex = 69
idBlur.Parent = inputDrawer
Instance.new("UICorner", idBlur).CornerRadius = UDim.new(0, 18)

local idTitle = Instance.new("TextLabel")
idTitle.Size = UDim2.new(1, -50, 0, 24)
idTitle.Position = UDim2.new(0, 14, 0, 12)
idTitle.Text = "Max Pollen Limit"
idTitle.TextColor3 = C_TEXT
idTitle.Font = Enum.Font.GothamBold
idTitle.TextSize = 13
idTitle.TextXAlignment = Enum.TextXAlignment.Left
idTitle.BackgroundTransparency = 1
idTitle.ZIndex = 72
idTitle.Parent = inputDrawer

local idCloseBtn = Instance.new("TextButton")
idCloseBtn.Size = UDim2.new(0, 26, 0, 26)
idCloseBtn.Position = UDim2.new(1, -36, 0, 11)
idCloseBtn.BackgroundTransparency = 1
idCloseBtn.Text = "(x)"
idCloseBtn.TextColor3 = C_TEXT_MUTED
idCloseBtn.Font = Enum.Font.GothamBold
idCloseBtn.TextSize = 13
idCloseBtn.ZIndex = 73
idCloseBtn.Parent = inputDrawer

idCloseBtn.MouseButton1Click:Connect(function()
	showDrawerInstant(inputDrawer, false)
end)

local fieldPickerBtn = Instance.new("TextButton")
fieldPickerBtn.Size = UDim2.new(1, -28, 0, 32)
fieldPickerBtn.Position = UDim2.new(0, 14, 0, 44)
fieldPickerBtn.BackgroundColor3 = C_CARD
fieldPickerBtn.BackgroundTransparency = 0.25
fieldPickerBtn.Text = ""
fieldPickerBtn.Active = true
fieldPickerBtn.ZIndex = 72
fieldPickerBtn.Parent = inputDrawer
Instance.new("UICorner", fieldPickerBtn).CornerRadius = UDim.new(0, 8)

local fieldPickerStroke = Instance.new("UIStroke")
fieldPickerStroke.Color = C_STROKE
fieldPickerStroke.Thickness = 1.2
fieldPickerStroke.Parent = fieldPickerBtn

local fieldPickerLbl = Instance.new("TextLabel")
fieldPickerLbl.Size = UDim2.new(1, -16, 1, 0)
fieldPickerLbl.Position = UDim2.new(0, 10, 0, 0)
fieldPickerLbl.Text = "Field: " .. selectedField
fieldPickerLbl.TextColor3 = C_TEXT
fieldPickerLbl.Font = Enum.Font.GothamBold
fieldPickerLbl.TextSize = 11
fieldPickerLbl.TextXAlignment = Enum.TextXAlignment.Left
fieldPickerLbl.BackgroundTransparency = 1
fieldPickerLbl.ZIndex = 73
fieldPickerLbl.Parent = fieldPickerBtn

local textBox = Instance.new("TextBox")
textBox.Size = UDim2.new(1, -28, 0, 34)
textBox.Position = UDim2.new(0, 14, 0, 84)
textBox.BackgroundColor3 = C_CARD
textBox.BackgroundTransparency = 0.3
textBox.Text = "Auto"
textBox.TextColor3 = C_TEXT
textBox.Font = Enum.Font.GothamBold
textBox.TextSize = 13
textBox.ZIndex = 72
textBox.Parent = inputDrawer
Instance.new("UICorner", textBox).CornerRadius = UDim.new(0, 8)

local confirmBtn = Instance.new("TextButton")
confirmBtn.Size = UDim2.new(1, -28, 0, 30)
confirmBtn.Position = UDim2.new(0, 14, 0, 126)
confirmBtn.BackgroundColor3 = C_ACCENT
confirmBtn.BackgroundTransparency = 0.2
confirmBtn.Text = "Save"
confirmBtn.TextColor3 = C_TEXT
confirmBtn.Font = Enum.Font.GothamBold
confirmBtn.TextSize = 12
confirmBtn.ZIndex = 72
confirmBtn.Parent = inputDrawer
Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(0, 8)

local activeInputCallback = nil
confirmBtn.MouseButton1Click:Connect(function()
	local txt = textBox.Text
	if txt == "Auto" or txt == "auto" then
		autoDetectMax = true
		if activeInputCallback then activeInputCallback("Auto") end
	else
		local num = tonumber(txt)
		if num then
			autoDetectMax = false
			maxPollenLimit = num
			if activeInputCallback then activeInputCallback(num) end
		end
	end
	showDrawerInstant(inputDrawer, false)
end)

textBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		local txt = textBox.Text
		if txt == "Auto" or txt == "auto" then
			autoDetectMax = true
			if activeInputCallback then activeInputCallback("Auto") end
		else
			local num = tonumber(txt)
			if num then
				autoDetectMax = false
				maxPollenLimit = num
				if activeInputCallback then activeInputCallback(num) end
			end
		end
		showDrawerInstant(inputDrawer, false)
	end
end)

local function openSliderDrawer(titleText, minVal, maxVal, currentVal, onCallback)
	sdTitle.Text = titleText
	sliderMin = minVal
	sliderMax = maxVal
	activeSliderCallback = onCallback
	updateSliderVisual(currentVal)

	showDrawerInstant(rightDrawer, false)
	showDrawerInstant(inputDrawer, false)
	showDrawerInstant(sliderDrawer, true)
end

local function openRightDrawer(titleText, items, currentVal, onSelect)
	rdTitle.Text = titleText
	for _, c in ipairs(rdScroll:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end

	for i, item in ipairs(items) do
		local optBtn = Instance.new("TextButton")
		optBtn.Size = UDim2.new(1, -10, 0, 36)
		optBtn.BackgroundColor3 = C_CARD
		optBtn.BackgroundTransparency = 0.3
		optBtn.Text = ""
		optBtn.Active = true
		optBtn.ZIndex = 75
		optBtn.LayoutOrder = i
		optBtn.Parent = rdScroll
		Instance.new("UICorner", optBtn).CornerRadius = UDim.new(0, 8)

		local optLbl = Instance.new("TextLabel")
		optLbl.Size = UDim2.new(1, -16, 1, 0)
		optLbl.Position = UDim2.new(0, 12, 0, 0)
		optLbl.Text = tostring(item)
		optLbl.TextColor3 = (tostring(item) == tostring(currentVal)) and C_ACCENT or C_TEXT
		optLbl.Font = Enum.Font.GothamBold
		optLbl.TextSize = 11
		optLbl.TextXAlignment = Enum.TextXAlignment.Left
		optLbl.BackgroundTransparency = 1
		optLbl.ZIndex = 76
		optLbl.Parent = optBtn

		optBtn.MouseButton1Click:Connect(function()
			onSelect(item)
		end)
	end
	rdScroll.CanvasSize = UDim2.new(0, 0, 0, #items * 42)
	showDrawerInstant(sliderDrawer, false)
	showDrawerInstant(inputDrawer, false)
	showDrawerInstant(rightDrawer, true)
end

fieldPickerBtn.MouseButton1Click:Connect(function()
	showDrawerInstant(inputDrawer, false)
	showDrawerInstant(sliderDrawer, false)
	openRightDrawer("Select Field", fieldNames, selectedField, function(chosen)
		selectedField = chosen
		fieldPickerLbl.Text = "Field: " .. selectedField
		showNotification("Field: " .. selectedField, nil)
		showDrawerInstant(rightDrawer, false)
		showDrawerInstant(inputDrawer, true)
	end)
end)

-- ==========================================
--    SIDEBAR (Z KWADRATOWYM LOGO "G")
-- ==========================================
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 200, 1, 0)
sidebar.BackgroundTransparency = 1
sidebar.BorderSizePixel = 0
sidebar.ZIndex = 2
sidebar.Parent = mainFrame

local brandCard = Instance.new("Frame")
brandCard.Size = UDim2.new(1, -24, 0, 48)
brandCard.Position = UDim2.new(0, 12, 0, 16)
brandCard.BackgroundTransparency = 1
brandCard.ZIndex = 2
brandCard.Parent = sidebar

local brandIcon = Instance.new("Frame")
brandIcon.Size = UDim2.new(0, 36, 0, 36)
brandIcon.Position = UDim2.new(0, 0, 0, 6)
brandIcon.BackgroundColor3 = C_ACCENT
brandIcon.ZIndex = 2
brandIcon.Parent = brandCard
Instance.new("UICorner", brandIcon).CornerRadius = UDim.new(0, 8)

local brandIconText = Instance.new("TextLabel")
brandIconText.Size = UDim2.new(1, 0, 1, 0)
brandIconText.BackgroundTransparency = 1
brandIconText.Text = "G"
brandIconText.TextColor3 = C_TEXT
brandIconText.Font = Enum.Font.GothamBold
brandIconText.TextSize = 18
brandIconText.ZIndex = 3
brandIconText.Parent = brandIcon

local brandTitle = Instance.new("TextLabel")
brandTitle.Size = UDim2.new(1, -44, 0, 20)
brandTitle.Position = UDim2.new(0, 44, 0, 6)
brandTitle.Text = "Ojson Client"
brandTitle.TextColor3 = C_TEXT
brandTitle.Font = Enum.Font.GothamBold
brandTitle.TextSize = 13
brandTitle.TextXAlignment = Enum.TextXAlignment.Left
brandTitle.BackgroundTransparency = 1
brandTitle.ZIndex = 2
brandTitle.Parent = brandCard

local brandVer = Instance.new("TextLabel")
brandVer.Size = UDim2.new(1, -44, 0, 16)
brandVer.Position = UDim2.new(0, 44, 0, 26)
brandVer.Text = "Version: 0.9 BETA"
brandVer.TextColor3 = C_TEXT_MUTED
brandVer.Font = Enum.Font.GothamMedium
brandVer.TextSize = 10
brandVer.TextXAlignment = Enum.TextXAlignment.Left
brandVer.BackgroundTransparency = 1
brandVer.ZIndex = 2
brandVer.Parent = brandCard

local featuresLabel = Instance.new("TextLabel")
featuresLabel.Size = UDim2.new(1, -20, 0, 20)
featuresLabel.Position = UDim2.new(0, 16, 0, 76)
featuresLabel.Text = "FEATURES"
featuresLabel.TextColor3 = Color3.fromRGB(120, 110, 140)
featuresLabel.BackgroundTransparency = 1
featuresLabel.Font = Enum.Font.GothamBold
featuresLabel.TextSize = 10
featuresLabel.TextXAlignment = Enum.TextXAlignment.Left
featuresLabel.ZIndex = 2
featuresLabel.Parent = sidebar

local navContainer = Instance.new("Frame")
navContainer.Size = UDim2.new(1, 0, 1, -170)
navContainer.Position = UDim2.new(0, 0, 0, 100)
navContainer.BackgroundTransparency = 1
navContainer.ZIndex = 2
navContainer.Parent = sidebar

local navLayout = Instance.new("UIListLayout")
navLayout.SortOrder = Enum.SortOrder.LayoutOrder
navLayout.Padding = UDim.new(0, 4)
navLayout.Parent = navContainer

local userCard = Instance.new("Frame")
userCard.Size = UDim2.new(1, -24, 0, 50)
userCard.Position = UDim2.new(0, 12, 1, -62)
userCard.BackgroundColor3 = C_CARD
userCard.BackgroundTransparency = 0.3
userCard.BorderSizePixel = 0
userCard.ZIndex = 2
userCard.Parent = sidebar
Instance.new("UICorner", userCard).CornerRadius = UDim.new(0, 12)

local userAvatar = Instance.new("Frame")
userAvatar.Size = UDim2.new(0, 32, 0, 32)
userAvatar.Position = UDim2.new(0, 9, 0, 9)
userAvatar.BackgroundColor3 = C_ACCENT
userAvatar.ZIndex = 2
userAvatar.Parent = userCard
Instance.new("UICorner", userAvatar).CornerRadius = UDim.new(1, 0)

local avatarTxt = Instance.new("TextLabel")
avatarTxt.Size = UDim2.new(1, 0, 1, 0)
avatarTxt.BackgroundTransparency = 1
avatarTxt.Text = string.sub(player.Name, 1, 1)
avatarTxt.TextColor3 = C_TEXT
avatarTxt.Font = Enum.Font.GothamBold
avatarTxt.TextSize = 14
avatarTxt.ZIndex = 2
avatarTxt.Parent = userAvatar

local userName = Instance.new("TextLabel")
userName.Size = UDim2.new(1, -50, 0, 16)
userName.Position = UDim2.new(0, 48, 0, 10)
userName.Text = player.Name
userName.TextColor3 = C_TEXT
userName.BackgroundTransparency = 1
userName.Font = Enum.Font.GothamBold
userName.TextSize = 11
userName.TextXAlignment = Enum.TextXAlignment.Left
userName.ZIndex = 2
userName.Parent = userCard

local userUid = Instance.new("TextLabel")
userUid.Size = UDim2.new(1, -50, 0, 14)
userUid.Position = UDim2.new(0, 48, 0, 26)
userUid.Text = "UID:" .. tostring(player.UserId) .. " • Verified"
userUid.TextColor3 = C_TEXT_MUTED
userUid.BackgroundTransparency = 1
userUid.Font = Enum.Font.GothamMedium
userUid.TextSize = 10
userUid.TextXAlignment = Enum.TextXAlignment.Left
userUid.ZIndex = 2
userUid.Parent = userCard

-- ==========================================
--    CONTENT AREA
-- ==========================================
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -200, 1, 0)
contentArea.Position = UDim2.new(0, 200, 0, 0)
contentArea.BackgroundTransparency = 1
contentArea.ZIndex = 2
contentArea.Parent = mainFrame

local topBarCard = Instance.new("Frame")
topBarCard.Size = UDim2.new(1, -28, 0, 50)
topBarCard.Position = UDim2.new(0, 14, 0, 14)
topBarCard.BackgroundColor3 = C_CARD
topBarCard.BackgroundTransparency = 0.3
topBarCard.BorderSizePixel = 0
topBarCard.ZIndex = 2
topBarCard.Parent = contentArea
Instance.new("UICorner", topBarCard).CornerRadius = UDim.new(0, 12)

local activeCategoryLabel = Instance.new("TextLabel")
activeCategoryLabel.Size = UDim2.new(1, -32, 1, 0)
activeCategoryLabel.Position = UDim2.new(0, 16, 0, 0)
activeCategoryLabel.Text = "Combat / Farm  •  Active settings"
activeCategoryLabel.TextColor3 = C_TEXT
activeCategoryLabel.BackgroundTransparency = 1
activeCategoryLabel.Font = Enum.Font.GothamBold
activeCategoryLabel.TextSize = 12
activeCategoryLabel.TextXAlignment = Enum.TextXAlignment.Left
activeCategoryLabel.ZIndex = 2
activeCategoryLabel.Parent = topBarCard

local tabsHolder = Instance.new("Frame")
tabsHolder.Size = UDim2.new(1, -28, 1, -80)
tabsHolder.Position = UDim2.new(0, 14, 0, 72)
tabsHolder.BackgroundTransparency = 1
tabsHolder.ZIndex = 2
tabsHolder.Parent = contentArea

local function createTabContentFrame()
	local sf = Instance.new("ScrollingFrame")
	sf.Size = UDim2.new(1, 0, 1, 0)
	sf.BackgroundTransparency = 1
	sf.Visible = false
	sf.CanvasSize = UDim2.new(0, 0, 0, 480)
	sf.ScrollBarThickness = 3
	sf.ZIndex = 2
	sf.Parent = tabsHolder

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 345, 0, 64)
	grid.CellPadding = UDim2.new(0, 12, 0, 12)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = sf
	return sf
end

local combatTab = createTabContentFrame()
combatTab.Visible = true
local movementTab = createTabContentFrame()
local configTab = createTabContentFrame()
local otherTab = createTabContentFrame()

local tabButtons = {}
local function createNavButton(name, order, targetTab)
	local isActive = (targetTab == combatTab)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -20, 0, 38)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.LayoutOrder = order
	btn.ZIndex = 2
	btn.Parent = navContainer
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -20, 1, 0)
	lbl.Position = UDim2.new(0, 14, 0, 0)
	lbl.Text = name
	lbl.TextColor3 = isActive and C_ACCENT or C_TEXT
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 2
	lbl.Parent = btn

	tabButtons[targetTab] = {Button = btn, Label = lbl}

	btn.MouseButton1Click:Connect(function()
		combatTab.Visible = false
		movementTab.Visible = false
		configTab.Visible = false
		otherTab.Visible = false

		targetTab.Visible = true
		activeCategoryLabel.Text = name .. "  •  Active settings"

		for t, tbl in pairs(tabButtons) do
			if t == targetTab then
				TweenService:Create(tbl.Label, TweenInfo.new(0.2), {TextColor3 = C_ACCENT}):Play()
			else
				TweenService:Create(tbl.Label, TweenInfo.new(0.2), {TextColor3 = C_TEXT}):Play()
			end
		end
	end)
end

createNavButton("Combat / Farm", 1, combatTab)
createNavButton("Movement", 2, movementTab)
createNavButton("Field & Hive", 3, configTab)
createNavButton("Other", 4, otherTab)

local function createFeatureCard(title, desc, defaultState, callback, parent)
	local card = Instance.new("TextButton")
	card.Size = UDim2.new(0, 345, 0, 64)
	card.BackgroundColor3 = C_CARD
	card.BackgroundTransparency = 0.35
	card.AutoButtonColor = false
	card.Text = ""
	card.ZIndex = 2
	card.Parent = parent
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

	local stroke = Instance.new("UIStroke")
	stroke.Color = defaultState and C_ACCENT or C_STROKE
	stroke.Thickness = defaultState and 1.6 or 1.2
	stroke.Parent = card

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -20, 0, 20)
	titleLbl.Position = UDim2.new(0, 14, 0, 12)
	titleLbl.Text = title
	titleLbl.TextColor3 = defaultState and C_ACCENT or C_TEXT
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 12
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.ZIndex = 2
	titleLbl.Parent = card

	local descLbl = Instance.new("TextLabel")
	descLbl.Size = UDim2.new(1, -20, 0, 18)
	descLbl.Position = UDim2.new(0, 14, 0, 32)
	descLbl.Text = desc
	descLbl.TextColor3 = defaultState and C_ACCENT or C_TEXT_MUTED
	descLbl.BackgroundTransparency = 1
	descLbl.Font = Enum.Font.GothamMedium
	descLbl.TextSize = 10
	descLbl.TextXAlignment = Enum.TextXAlignment.Left
	descLbl.ZIndex = 2
	descLbl.Parent = card

	local state = defaultState
	card.MouseButton1Click:Connect(function()
		state = not state
		local targetStroke = state and C_ACCENT or C_STROKE
		local targetThick = state and 1.6 or 1.2
		local targetText = state and C_ACCENT or C_TEXT
		local targetDesc = state and C_ACCENT or C_TEXT_MUTED

		TweenService:Create(stroke, TweenInfo.new(0.2), {Color = targetStroke, Thickness = targetThick}):Play()
		TweenService:Create(titleLbl, TweenInfo.new(0.2), {TextColor3 = targetText}):Play()
		TweenService:Create(descLbl, TweenInfo.new(0.2), {TextColor3 = targetDesc}):Play()

		callback(state)
		showNotification(title, state)
	end)
end

local function createToggleDropdownCard(title, desc, currentVal, optionsList, defaultState, onToggle, onSelect, parent)
	local card = Instance.new("TextButton")
	card.Size = UDim2.new(0, 345, 0, 64)
	card.BackgroundColor3 = C_CARD
	card.BackgroundTransparency = 0.35
	card.AutoButtonColor = false
	card.Text = ""
	card.ZIndex = 2
	card.Parent = parent
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

	local stroke = Instance.new("UIStroke")
	stroke.Color = defaultState and C_ACCENT or C_STROKE
	stroke.Thickness = defaultState and 1.6 or 1.2
	stroke.Parent = card

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -40, 0, 20)
	titleLbl.Position = UDim2.new(0, 14, 0, 12)
	titleLbl.Text = title .. " [" .. tostring(currentVal) .. "]"
	titleLbl.TextColor3 = defaultState and C_ACCENT or C_TEXT
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 12
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.ZIndex = 2
	titleLbl.Parent = card

	local descLbl = Instance.new("TextLabel")
	descLbl.Size = UDim2.new(1, -40, 0, 18)
	descLbl.Position = UDim2.new(0, 14, 0, 32)
	descLbl.Text = desc
	descLbl.TextColor3 = defaultState and C_ACCENT or C_TEXT_MUTED
	descLbl.BackgroundTransparency = 1
	descLbl.Font = Enum.Font.GothamMedium
	descLbl.TextSize = 10
	descLbl.TextXAlignment = Enum.TextXAlignment.Left
	descLbl.ZIndex = 2
	descLbl.Parent = card

	local dotsBtn = Instance.new("TextButton")
	dotsBtn.Size = UDim2.new(0, 30, 0, 40)
	dotsBtn.Position = UDim2.new(1, -36, 0.5, -20)
	dotsBtn.BackgroundTransparency = 1
	dotsBtn.Text = ""
	dotsBtn.ZIndex = 3
	dotsBtn.Parent = card

	local dotsContainer = Instance.new("Frame")
	dotsContainer.Size = UDim2.new(0, 10, 0, 24)
	dotsContainer.Position = UDim2.new(0.5, -5, 0.5, -12)
	dotsContainer.BackgroundTransparency = 1
	dotsContainer.ZIndex = 3
	dotsContainer.Parent = dotsBtn
	for d = 1, 3 do
		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 3, 0, 3)
		dot.Position = UDim2.new(0, 3, 0, (d - 1) * 7 + 3)
		dot.BackgroundColor3 = C_TEXT_MUTED
		dot.BorderSizePixel = 0
		dot.ZIndex = 3
		dot.Parent = dotsContainer
		Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	end

	local state = defaultState
	local chosenVal = currentVal

	card.MouseButton1Click:Connect(function()
		local mousePos = UserInputService:GetMouseLocation()
		local absPos = dotsBtn.AbsolutePosition
		local absSize = dotsBtn.AbsoluteSize
		if mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X and
		   mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y then
			return
		end

		state = not state
		local targetStroke = state and C_ACCENT or C_STROKE
		local targetThick = state and 1.6 or 1.2
		local targetText = state and C_ACCENT or C_TEXT
		local targetDesc = state and C_ACCENT or C_TEXT_MUTED

		TweenService:Create(stroke, TweenInfo.new(0.2), {Color = targetStroke, Thickness = targetThick}):Play()
		TweenService:Create(titleLbl, TweenInfo.new(0.2), {TextColor3 = targetText}):Play()
		TweenService:Create(descLbl, TweenInfo.new(0.2), {TextColor3 = targetDesc}):Play()

		onToggle(state)
		showNotification(title, state)
	end)

	dotsBtn.MouseButton1Click:Connect(function()
		openRightDrawer(title .. " Key (1-7)", optionsList, chosenVal, function(chosen)
			chosenVal = chosen
			titleLbl.Text = title .. " [" .. tostring(chosenVal) .. "]"
			onSelect(chosen)
			showDrawerInstant(rightDrawer, false)
		end)
	end)

	return card, titleLbl
end

local function createToggleInputCard(title, desc, currentVal, defaultState, onToggle, onInputConfirm, parent)
	local card = Instance.new("TextButton")
	card.Size = UDim2.new(0, 345, 0, 64)
	card.BackgroundColor3 = C_CARD
	card.BackgroundTransparency = 0.35
	card.AutoButtonColor = false
	card.Text = ""
	card.ZIndex = 2
	card.Parent = parent
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

	local stroke = Instance.new("UIStroke")
	stroke.Color = defaultState and C_ACCENT or C_STROKE
	stroke.Thickness = defaultState and 1.6 or 1.2
	stroke.Parent = card

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -40, 0, 20)
	titleLbl.Position = UDim2.new(0, 14, 0, 12)
	titleLbl.Text = title .. " (Max: Auto)"
	titleLbl.TextColor3 = defaultState and C_ACCENT or C_TEXT
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 12
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.ZIndex = 2
	titleLbl.Parent = card

	local descLbl = Instance.new("TextLabel")
	descLbl.Size = UDim2.new(1, -40, 0, 18)
	descLbl.Position = UDim2.new(0, 14, 0, 32)
	descLbl.Text = desc
	descLbl.TextColor3 = defaultState and C_ACCENT or C_TEXT_MUTED
	descLbl.BackgroundTransparency = 1
	descLbl.Font = Enum.Font.GothamMedium
	descLbl.TextSize = 10
	descLbl.TextXAlignment = Enum.TextXAlignment.Left
	descLbl.ZIndex = 2
	descLbl.Parent = card

	local dotsBtn = Instance.new("TextButton")
	dotsBtn.Size = UDim2.new(0, 30, 0, 40)
	dotsBtn.Position = UDim2.new(1, -36, 0.5, -20)
	dotsBtn.BackgroundTransparency = 1
	dotsBtn.Text = ""
	dotsBtn.ZIndex = 3
	dotsBtn.Parent = card

	local dotsContainer = Instance.new("Frame")
	dotsContainer.Size = UDim2.new(0, 10, 0, 24)
	dotsContainer.Position = UDim2.new(0.5, -5, 0.5, -12)
	dotsContainer.BackgroundTransparency = 1
	dotsContainer.ZIndex = 3
	dotsContainer.Parent = dotsBtn
	for d = 1, 3 do
		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 3, 0, 3)
		dot.Position = UDim2.new(0, 3, 0, (d - 1) * 7 + 3)
		dot.BackgroundColor3 = C_TEXT_MUTED
		dot.BorderSizePixel = 0
		dot.ZIndex = 3
		dot.Parent = dotsContainer
		Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	end

	local state = defaultState

	card.MouseButton1Click:Connect(function()
		local mousePos = UserInputService:GetMouseLocation()
		local absPos = dotsBtn.AbsolutePosition
		local absSize = dotsBtn.AbsoluteSize
		if mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X and
		   mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y then
			return
		end

		state = not state
		local targetStroke = state and C_ACCENT or C_STROKE
		local targetThick = state and 1.6 or 1.2
		local targetText = state and C_ACCENT or C_TEXT
		local targetDesc = state and C_ACCENT or C_TEXT_MUTED

		TweenService:Create(stroke, TweenInfo.new(0.2), {Color = targetStroke, Thickness = targetThick}):Play()
		TweenService:Create(titleLbl, TweenInfo.new(0.2), {TextColor3 = targetText}):Play()
		TweenService:Create(descLbl, TweenInfo.new(0.2), {TextColor3 = targetDesc}):Play()

		onToggle(state)
		showNotification(title, state)
	end)

	dotsBtn.MouseButton1Click:Connect(function()
		showDrawerInstant(rightDrawer, false)
		showDrawerInstant(sliderDrawer, false)
		showDrawerInstant(inputDrawer, true)
		fieldPickerLbl.Text = "Field: " .. selectedField
		textBox.Text = autoDetectMax and "Auto" or tostring(maxPollenLimit)
		activeInputCallback = function(val)
			if val == "Auto" then
				titleLbl.Text = title .. " (Max: Auto)"
			else
				titleLbl.Text = title .. " (Max: " .. tostring(val) .. ")"
			end
			onInputConfirm(val)
		end
	end)

	return card, titleLbl
end

local function createToggleSliderCard(title, desc, minVal, maxVal, currentVal, defaultState, onToggle, onSliderChange, parent)
	local card = Instance.new("TextButton")
	card.Size = UDim2.new(0, 345, 0, 64)
	card.BackgroundColor3 = C_CARD
	card.BackgroundTransparency = 0.35
	card.AutoButtonColor = false
	card.Text = ""
	card.ZIndex = 2
	card.Parent = parent
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

	local stroke = Instance.new("UIStroke")
	stroke.Color = defaultState and C_ACCENT or C_STROKE
	stroke.Thickness = defaultState and 1.6 or 1.2
	stroke.Parent = card

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -40, 0, 20)
	titleLbl.Position = UDim2.new(0, 14, 0, 12)
	titleLbl.Text = title .. ": " .. tostring(currentVal)
	titleLbl.TextColor3 = defaultState and C_ACCENT or C_TEXT
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 12
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.ZIndex = 2
	titleLbl.Parent = card

	local descLbl = Instance.new("TextLabel")
	descLbl.Size = UDim2.new(1, -40, 0, 18)
	descLbl.Position = UDim2.new(0, 14, 0, 32)
	descLbl.Text = desc
	descLbl.TextColor3 = defaultState and C_ACCENT or C_TEXT_MUTED
	descLbl.BackgroundTransparency = 1
	descLbl.Font = Enum.Font.GothamMedium
	descLbl.TextSize = 10
	descLbl.TextXAlignment = Enum.TextXAlignment.Left
	descLbl.ZIndex = 2
	descLbl.Parent = card

	local dotsBtn = Instance.new("TextButton")
	dotsBtn.Size = UDim2.new(0, 30, 0, 40)
	dotsBtn.Position = UDim2.new(1, -36, 0.5, -20)
	dotsBtn.BackgroundTransparency = 1
	dotsBtn.Text = ""
	dotsBtn.ZIndex = 3
	dotsBtn.Parent = card

	local dotsContainer = Instance.new("Frame")
	dotsContainer.Size = UDim2.new(0, 10, 0, 24)
	dotsContainer.Position = UDim2.new(0.5, -5, 0.5, -12)
	dotsContainer.BackgroundTransparency = 1
	dotsContainer.ZIndex = 3
	dotsContainer.Parent = dotsBtn
	for d = 1, 3 do
		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 3, 0, 3)
		dot.Position = UDim2.new(0, 3, 0, (d - 1) * 7 + 3)
		dot.BackgroundColor3 = C_TEXT_MUTED
		dot.BorderSizePixel = 0
		dot.ZIndex = 3
		dot.Parent = dotsContainer
		Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	end

	local state = defaultState

	card.MouseButton1Click:Connect(function()
		local mousePos = UserInputService:GetMouseLocation()
		local absPos = dotsBtn.AbsolutePosition
		local absSize = dotsBtn.AbsoluteSize
		if mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X and
		   mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y then
			return
		end

		state = not state
		local targetStroke = state and C_ACCENT or C_STROKE
		local targetThick = state and 1.6 or 1.2
		local targetText = state and C_ACCENT or C_TEXT
		local targetDesc = state and C_ACCENT or C_TEXT_MUTED

		TweenService:Create(stroke, TweenInfo.new(0.2), {Color = targetStroke, Thickness = targetThick}):Play()
		TweenService:Create(titleLbl, TweenInfo.new(0.2), {TextColor3 = targetText}):Play()
		TweenService:Create(descLbl, TweenInfo.new(0.2), {TextColor3 = targetDesc}):Play()

		onToggle(state)
		showNotification(title, state)
	end)

	dotsBtn.MouseButton1Click:Connect(function()
		openSliderDrawer(title, minVal, maxVal, currentVal, function(val)
			currentVal = val
			titleLbl.Text = title .. ": " .. tostring(currentVal)
			onSliderChange(val)
		end)
	end)

	return card, titleLbl
end

-- ==========================================
--    ELEMENTY W ZAKŁADKACH
-- ==========================================
createToggleInputCard("Auto Farm Field", "Auto detects max pollen & farms", maxPollenLimit, autoFarmEnabled, function(s)
	autoFarmEnabled = s
	if not s then
		setClientStatus("Ojson Client")
	end
end, function(val)
	if val == "Auto" then
		autoDetectMax = true
		showNotification("Max Pollen: Auto Detect", nil)
	else
		autoDetectMax = false
		maxPollenLimit = val
		showNotification("Max Pollen: " .. val, nil)
	end
end, combatTab)

createFeatureCard("Auto Hold Mouse", "Holds left click in background", autoHoldEnabled, function(s)
	autoHoldEnabled = s
	if not autoHoldEnabled and vimAvailable then
		pcall(function() VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0) end)
	end
end, combatTab)

createToggleDropdownCard("Auto Use Sprinklers", "Presses sprinkler slot (1-7)", sprinklerSlot, sprinklerSlotOptions, autoSprinklersEnabled, function(s)
	autoSprinklersEnabled = s
end, function(chosenSlot)
	sprinklerSlot = tostring(chosenSlot)
	showNotification("Sprinkler Slot: " .. sprinklerSlot, nil)
end, combatTab)

createFeatureCard("Infinite Jump", "Jump repeatedly in mid-air", infJumpEnabled, function(s)
	infJumpEnabled = s
end, movementTab)

createToggleSliderCard("Fast WalkSpeed", "Increases movement speed", 16, 150, customWalkSpeed, walkSpeedEnabled, function(s)
	walkSpeedEnabled = s
	local char = player.Character
	if not s and char and char:FindFirstChildOfClass("Humanoid") then
		char.Humanoid.WalkSpeed = 16
	end
end, function(val)
	customWalkSpeed = val
	if walkSpeedEnabled then
		local char = player.Character
		if char and char:FindFirstChildOfClass("Humanoid") then
			char.Humanoid.WalkSpeed = val
		end
	end
	showNotification("WalkSpeed: " .. val, nil)
end, movementTab)

createToggleSliderCard("High JumpPower", "Increases jump height", 50, 300, customJumpPower, jumpPowerEnabled, function(s)
	jumpPowerEnabled = s
	local char = player.Character
	if not s and char and char:FindFirstChildOfClass("Humanoid") then
		char.Humanoid.JumpPower = 50
	end
end, function(val)
	customJumpPower = val
	if jumpPowerEnabled then
		local char = player.Character
		if char and char:FindFirstChildOfClass("Humanoid") then
			char.Humanoid.JumpPower = val
		end
	end
	showNotification("JumpPower: " .. val, nil)
end, movementTab)

-- Zakładka 3: Field & Hive
local saveHiveBtn = Instance.new("TextButton")
saveHiveBtn.Size = UDim2.new(0, 345, 0, 64)
saveHiveBtn.BackgroundColor3 = C_CARD
saveHiveBtn.BackgroundTransparency = 0.35
saveHiveBtn.Text = ""
saveHiveBtn.ZIndex = 2
saveHiveBtn.Parent = configTab
Instance.new("UICorner", saveHiveBtn).CornerRadius = UDim.new(0, 12)
local shStroke = Instance.new("UIStroke")
shStroke.Color = C_STROKE
shStroke.Thickness = 1.2
shStroke.Parent = saveHiveBtn

local shLabel = Instance.new("TextLabel")
shLabel.Size = UDim2.new(1, -20, 1, 0)
shLabel.Position = UDim2.new(0, 14, 0, 0)
shLabel.Text = "SAVE HIVE POSITION"
shLabel.TextColor3 = C_TEXT
shLabel.BackgroundTransparency = 1
shLabel.Font = Enum.Font.GothamBold
shLabel.TextSize = 12
shLabel.TextXAlignment = Enum.TextXAlignment.Left
shLabel.ZIndex = 2
shLabel.Parent = saveHiveBtn

saveHiveBtn.MouseButton1Click:Connect(function()
	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		hivePosition = char.HumanoidRootPart.CFrame
		shLabel.Text = "HIVE SAVED!"
		showNotification("Hive Position Saved", nil)
		task.delay(2, function()
			shLabel.Text = "SAVE HIVE POSITION"
		end)
	end
end)

-- Zakładka 4: Other (Keybinds)
local keybindCard = Instance.new("Frame")
keybindCard.Size = UDim2.new(0, 345, 0, 64)
keybindCard.BackgroundColor3 = C_CARD
keybindCard.BackgroundTransparency = 0.35
keybindCard.ZIndex = 2
keybindCard.Parent = otherTab
Instance.new("UICorner", keybindCard).CornerRadius = UDim.new(0, 12)
local kbStroke = Instance.new("UIStroke")
kbStroke.Color = C_STROKE
kbStroke.Thickness = 1.2
kbStroke.Parent = keybindCard

local kbTitle = Instance.new("TextLabel")
kbTitle.Size = UDim2.new(1, -20, 0, 20)
kbTitle.Position = UDim2.new(0, 14, 0, 12)
kbTitle.Text = "Menu Keybind"
kbTitle.TextColor3 = C_TEXT
kbTitle.BackgroundTransparency = 1
kbTitle.Font = Enum.Font.GothamBold
kbTitle.TextSize = 12
kbTitle.TextXAlignment = Enum.TextXAlignment.Left
kbTitle.ZIndex = 2
kbTitle.Parent = keybindCard

local kbDesc = Instance.new("TextLabel")
kbDesc.Size = UDim2.new(1, -20, 0, 18)
kbDesc.Position = UDim2.new(0, 14, 0, 32)
kbDesc.Text = "Right Control (Toggle Menu)"
kbDesc.TextColor3 = C_ACCENT
kbDesc.BackgroundTransparency = 1
kbDesc.Font = Enum.Font.GothamMedium
kbDesc.TextSize = 10
kbDesc.TextXAlignment = Enum.TextXAlignment.Left
kbDesc.ZIndex = 2
kbDesc.Parent = keybindCard

-- ==========================================
--    EKRAN ŁADOWANIA (Z KWADRATOWYM LOGO "G")
-- ==========================================
local loadGui = Instance.new("ScreenGui")
loadGui.Name = "OjsonLoadingGui"
loadGui.ResetOnSpawn = false
loadGui.DisplayOrder = 105
loadGui.Parent = guiParent

local loadFrame = Instance.new("Frame")
loadFrame.Size = UDim2.new(0, 320, 0, 160)
loadFrame.Position = UDim2.new(0.5, -160, 0.5, -80)
loadFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
loadFrame.BackgroundTransparency = 0.65
loadFrame.BorderSizePixel = 0
loadFrame.Parent = loadGui
Instance.new("UICorner", loadFrame).CornerRadius = UDim.new(0, 18)

local loadStroke = Instance.new("UIStroke")
loadStroke.Color = Color3.fromRGB(255, 255, 255)
loadStroke.Transparency = 0.4
loadStroke.Thickness = 1.8
loadStroke.Parent = loadFrame

local loadPulseTween = TweenService:Create(loadFrame, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
	BackgroundTransparency = 0.50
})
loadPulseTween:Play()

local loadIcon = Instance.new("Frame")
loadIcon.Size = UDim2.new(0, 44, 0, 44)
loadIcon.Position = UDim2.new(0.5, -22, 0, 20)
loadIcon.BackgroundColor3 = C_ACCENT
loadIcon.ZIndex = 2
loadIcon.Parent = loadFrame
Instance.new("UICorner", loadIcon).CornerRadius = UDim.new(0, 10)

local loadIconText = Instance.new("TextLabel")
loadIconText.Size = UDim2.new(1, 0, 1, 0)
loadIconText.BackgroundTransparency = 1
loadIconText.Text = "G"
loadIconText.TextColor3 = C_TEXT
loadIconText.Font = Enum.Font.GothamBold
loadIconText.TextSize = 22
loadIconText.ZIndex = 3
loadIconText.Parent = loadIcon

local loadTitle = Instance.new("TextLabel")
loadTitle.Size = UDim2.new(1, 0, 0, 24)
loadTitle.Position = UDim2.new(0, 0, 0, 72)
loadTitle.Text = "Ojson Client"
loadTitle.TextColor3 = Color3.fromRGB(20, 20, 25)
loadTitle.Font = Enum.Font.GothamBold
loadTitle.TextSize = 16
loadTitle.TextXAlignment = Enum.TextXAlignment.Center
loadTitle.BackgroundTransparency = 1
loadTitle.ZIndex = 2
loadTitle.Parent = loadFrame

local loadStatus = Instance.new("TextLabel")
loadStatus.Size = UDim2.new(1, 0, 0, 20)
loadStatus.Position = UDim2.new(0, 0, 0, 98)
loadStatus.Text = "Launching in 5s..."
loadStatus.TextColor3 = Color3.fromRGB(80, 75, 95)
loadStatus.Font = Enum.Font.GothamMedium
loadStatus.TextSize = 11
loadStatus.TextXAlignment = Enum.TextXAlignment.Center
loadStatus.BackgroundTransparency = 1
loadStatus.ZIndex = 2
loadStatus.Parent = loadFrame

local progressBarBg = Instance.new("Frame")
progressBarBg.Size = UDim2.new(1, -48, 0, 6)
progressBarBg.Position = UDim2.new(0, 24, 1, -22)
progressBarBg.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
progressBarBg.BackgroundTransparency = 0.5
progressBarBg.BorderSizePixel = 0
progressBarBg.ZIndex = 2
progressBarBg.Parent = loadFrame
Instance.new("UICorner", progressBarBg).CornerRadius = UDim.new(1, 0)

local progressBarFill = Instance.new("Frame")
progressBarFill.Size = UDim2.new(0, 0, 1, 0)
progressBarFill.BackgroundColor3 = C_ACCENT
progressBarFill.BorderSizePixel = 0
progressBarFill.ZIndex = 3
progressBarFill.Parent = progressBarBg
Instance.new("UICorner", progressBarFill).CornerRadius = UDim.new(1, 0)

task.spawn(function()
	local totalTime = 5
	for i = totalTime, 1, -1 do
		if loadStatus then loadStatus.Text = "Launching in " .. i .. "s..." end
		TweenService:Create(progressBarFill, TweenInfo.new(1, Enum.EasingStyle.Linear), {
			Size = UDim2.new((totalTime - i + 1) / totalTime, 0, 1, 0)
		}):Play()
		task.wait(1)
	end
	if loadStatus then loadStatus.Text = "Ready!" end
	task.wait(0.3)

	if loadPulseTween then loadPulseTween:Cancel() end
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(loadFrame, tweenInfo, {BackgroundTransparency = 1}):Play()
	TweenService:Create(loadTitle, tweenInfo, {TextTransparency = 1}):Play()
	TweenService:Create(loadStatus, tweenInfo, {TextTransparency = 1}):Play()
	TweenService:Create(loadIcon, tweenInfo, {BackgroundTransparency = 1}):Play()
	TweenService:Create(loadIconText, tweenInfo, {TextTransparency = 1}):Play()
	TweenService:Create(progressBarBg, tweenInfo, {BackgroundTransparency = 1}):Play()
	TweenService:Create(progressBarFill, tweenInfo, {BackgroundTransparency = 1}):Play()

	task.wait(0.5)
	if loadGui then loadGui:Destroy() end

	menuOpen = true
	setMenuVisible(true)
	if notifGui then notifGui.Enabled = true end
end)

-- ==========================================
--    LOGIKA GRY (TŁO) - AUTO DETECT MAX + TELEPORT + KRĘCENIE + SPRINKLERS 1-7
-- ==========================================
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.RightControl then
		menuOpen = not menuOpen
		setMenuVisible(menuOpen)
		if not menuOpen then
			showDrawerInstant(rightDrawer, false)
			showDrawerInstant(sliderDrawer, false)
			showDrawerInstant(inputDrawer, false)
		end
	elseif input.KeyCode == Enum.KeyCode.Space and infJumpEnabled then
		local char = player.Character
		if char and char:FindFirstChildOfClass("Humanoid") then
			char.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end)

local cachedPollen = 0
local cachedMaxPollen = 50000

local function getPollenData()
	local pVal = cachedPollen
	local mVal = cachedMaxPollen
	local pGui = player:FindFirstChild("PlayerGui")
	if not pGui then return pVal, mVal end
	pcall(function()
		for _, gui in ipairs(pGui:GetDescendants()) do
			if gui:IsA("TextLabel") and gui.Parent and gui.Parent.Name == "Bar" and string.find(gui.Text, "/") then
				local clean = string.gsub(gui.Text, ",", "")
				local current, maxVal = string.match(clean, "(%d+)%s*/%s*(%d+)")
				if current and maxVal and tonumber(maxVal) > 1000 then
					pVal = tonumber(current) or cachedPollen
					mVal = tonumber(maxVal) or cachedMaxPollen
					cachedPollen = pVal
					cachedMaxPollen = mVal
					break
				end
			end
		end
	end)
	return pVal, mVal
end

local function teleportTo(targetVector)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	local hrp = char.HumanoidRootPart
	hrp.Anchored = false
	hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	hrp.CFrame = CFrame.new(targetVector)
end

local lastSprinklerTime = 0
local lastSprinklerField = nil

local function tryPlaceSprinkler(force)
	if not autoSprinklersEnabled or isConverting or not vimAvailable then return end
	local now = os.clock()
	local fieldChanged = (lastSprinklerField ~= selectedField)
	if not force and not fieldChanged and (now - lastSprinklerTime) < 60 then
		return
	end

	local keyCode = sprinklerKeyCodes[sprinklerSlot] or Enum.KeyCode.One

	pcall(function()
		VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
		task.wait(0.08)
		VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
		lastSprinklerTime = os.clock()
		lastSprinklerField = selectedField
	end)
end

local function runAutoFarmExtras(targetPos, hrp, hum)
	if autoCollectTokensEnabled then
		-- Zarezerwowane pod moduł Auto Collect Tokens
	end
end

task.spawn(function()
	while task.wait(0.4) do
		local curr, maxDetected = getPollenData()
		local activeLimit = autoDetectMax and maxDetected or maxPollenLimit

		if autoFarmEnabled then
			if curr >= activeLimit and hivePosition and not isConverting then
				isConverting = true
				setClientStatus("put honey in the hive")
				showNotification("Backpack Full! Teleporting", nil)

				teleportTo(hivePosition.Position + Vector3.new(0, 3, 0))

				task.wait(0.8)
				if vimAvailable then
					pcall(function()
						VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
						task.wait(0.1)
						VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
					end)
				end
				while autoFarmEnabled and getPollenData() > 50 do
					setClientStatus("put honey in the hive")
					task.wait(1)
				end
				showNotification("Empty! Teleporting to Field", nil)
				task.wait(0.5)

				local targetFieldVec = fieldPositions[selectedField]
				if targetFieldVec then
					teleportTo(targetFieldVec + Vector3.new(0, 3, 0))
					task.wait(0.2)
					tryPlaceSprinkler(true)
				end
				isConverting = false
			elseif not isConverting then
				setClientStatus("Farming")
				tryPlaceSprinkler(false)
			end
		end
	end
end)

task.spawn(function()
	local angle = 0
	while task.wait(0.05) do
		if autoFarmEnabled and not isConverting then
			local char = player.Character
			if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChildOfClass("Humanoid") then
				local hrp = char.HumanoidRootPart
				local hum = char.Humanoid
				local targetPos = fieldPositions[selectedField]

				if targetPos then
					if (hrp.Position - targetPos).Magnitude > 65 then
						teleportTo(targetPos + Vector3.new(0, 3, 0))
						task.wait(0.15)
						tryPlaceSprinkler(true)
					else
						if hrp.Anchored then hrp.Anchored = false end
						if not walkSpeedEnabled then
							hum.WalkSpeed = farmWalkSpeed
						else
							hum.WalkSpeed = customWalkSpeed
						end
						if jumpPowerEnabled then
							hum.JumpPower = customJumpPower
						end

						angle = angle + 0.08
						local radius = 18
						local offsetX = math.cos(angle) * radius
						local offsetZ = math.sin(angle) * radius
						hum:MoveTo(targetPos + Vector3.new(offsetX, 0, offsetZ))

						runAutoFarmExtras(targetPos, hrp, hum)
					end
				end
			end
		end
	end
end)

task.spawn(function()
	while task.wait(0.15) do
		local char = player.Character
		if char and char:FindFirstChildOfClass("Humanoid") and not autoFarmEnabled then
			local hum = char.Humanoid
			if walkSpeedEnabled then hum.WalkSpeed = customWalkSpeed end
			if jumpPowerEnabled then hum.JumpPower = customJumpPower end
		end

		if autoHoldEnabled and not isConverting and vimAvailable then
			pcall(function() VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0) end)
		end
	end
end)

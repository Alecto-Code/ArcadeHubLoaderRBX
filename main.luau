--[[
    =============================================================================
    GARDEN SUITE PRO - ULTIMATE CONTROL PANEL (V2.1)
    Architecture: Modular Tab System, Low-Overhead State Manager & Premium UI
    =============================================================================
--]]

task.wait(0.5)

-- // Services // --
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService    = game:GetService("UserInputService")
local Players             = game:GetService("Players")
local CoreGui             = game:GetService("CoreGui")
local TweenService        = game:GetService("TweenService")
local RunService          = game:GetService("RunService")
local Lighting            = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- // Safe GUI Parent Resolution // --
local function getGuiParent(): Instance
	local success, _ = pcall(function()
		local t = CoreGui.Name
	end)
	if success then
		return CoreGui
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end

-- // Clean Previous Instances // --
local parentGui = getGuiParent()
local oldGui = parentGui:FindFirstChild("GardenSuiteGUI")
if oldGui then
	oldGui:Destroy()
end

-- // Global State Manager // --
local State = {
	InstantInteract  = false,
	AutoSpamE        = false,
	AutoDrop         = false,
	AntiLagPlants    = false,
	ClearTextures    = false,
}

-- // Original Data Buffers (For Restore) // --
local OriginalPlantData       = {}
local OriginalTextures        = {}
local OriginalLightingEffects = {}
local PromptConnections       = {}

-- =============================================================================
-- LOGIKA FITUR (FEATURE MODULES)
-- =============================================================================

-- 1. Instant Interact Logic
local function applyInstantPrompt(prompt: Instance)
	if prompt:IsA("ProximityPrompt") then
		if State.InstantInteract then
			if not prompt:GetAttribute("OriginalDuration") then
				prompt:SetAttribute("OriginalDuration", prompt.HoldDuration)
			end
			prompt.HoldDuration = 0
		else
			local original = prompt:GetAttribute("OriginalDuration")
			if original then
				prompt.HoldDuration = original
			end
		end
	end
end

local function toggleInstantInteract(enabled: boolean)
	State.InstantInteract = enabled
	for _, desc in ipairs(workspace:GetDescendants()) do
		applyInstantPrompt(desc)
	end
end

PromptConnections.DescendantAdded = workspace.DescendantAdded:Connect(function(descendant)
	if State.InstantInteract then
		task.wait(0.05)
		applyInstantPrompt(descendant)
	end
end)

-- 2. Auto Input Loops (Spam E & Drop)
task.spawn(function()
	while true do
		if State.AutoSpamE then
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
			task.wait(0.02)
			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
			task.wait(0.03)
		else
			task.wait(0.1)
		end
	end
end)

task.spawn(function()
	while true do
		if State.AutoDrop then
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
			task.wait(0.02)
			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
			task.wait(0.03)
		else
			task.wait(0.1)
		end
	end
end)

-- 3. Anti-Lag Plants Logic
local function minimizePlant(plantModel: Instance)
	if not plantModel:IsA("Model") then return end
	for _, child in ipairs(plantModel:GetDescendants()) do
		if child:IsA("BasePart") or child:IsA("MeshPart") then
			if not OriginalPlantData[child] then
				OriginalPlantData[child] = {
					Size = child.Size,
					Transparency = child.Transparency,
					CanCollide = child.CanCollide
				}
			end
			child.Size = Vector3.zero
			child.Transparency = 1
			child.CanCollide = false
		elseif child:IsA("Decal") or child:IsA("Texture") then
			if not OriginalPlantData[child] then
				OriginalPlantData[child] = { Transparency = child.Transparency }
			end
			child.Transparency = 1
		end
	end
end

local function restorePlants()
	for child, data in pairs(OriginalPlantData) do
		if child and child.Parent then
			if child:IsA("BasePart") or child:IsA("MeshPart") then
				child.Size = data.Size
				child.Transparency = data.Transparency
				child.CanCollide = data.CanCollide
			elseif child:IsA("Decal") or child:IsA("Texture") then
				child.Transparency = data.Transparency
			end
		end
	end
	table.clear(OriginalPlantData)
end

local function toggleAntiLagPlants(enabled: boolean)
	State.AntiLagPlants = enabled
	local gardens = workspace:FindFirstChild("Gardens")
	if not gardens then return end

	if enabled then
		for _, plot in ipairs(gardens:GetChildren()) do
			local plants = plot:FindFirstChild("Plants")
			if plants then
				for _, plant in ipairs(plants:GetChildren()) do
					minimizePlant(plant)
				end
			end
		end
	else
		restorePlants()
	end
end

-- 4. Clear Textures & Map Effects Logic
local function toggleClearTextures(enabled: boolean)
	State.ClearTextures = enabled
	if enabled then
		for _, v in ipairs(workspace:GetDescendants()) do
			if v:IsA("BasePart") and not v:IsA("MeshPart") then
				OriginalTextures[v] = { Material = v.Material }
				v.Material = Enum.Material.SmoothPlastic
			elseif v:IsA("Texture") or v:IsA("Decal") then
				OriginalTextures[v] = { Parent = v.Parent }
				v.Parent = nil
			end
		end
		for _, effect in ipairs(Lighting:GetChildren()) do
			if effect:IsA("PostEffect") or effect:IsA("Sky") or string.find(effect.Name, "Effect") or string.find(effect.Name, "SunRays") then
				OriginalLightingEffects[effect] = { Parent = effect.Parent }
				effect.Parent = nil
			end
		end
	else
		for obj, data in pairs(OriginalTextures) do
			if obj and typeof(obj) == "Instance" then
				if obj:IsA("BasePart") then
					obj.Material = data.Material
				else
					obj.Parent = data.Parent
				end
			end
		end
		table.clear(OriginalTextures)

		for effect, data in pairs(OriginalLightingEffects) do
			if effect and typeof(effect) == "Instance" then
				effect.Parent = data.Parent
			end
		end
		table.clear(OriginalLightingEffects)
	end
end

-- =============================================================================
-- MODERN GUI BUILDER (THEMED UI DESIGN SYSTEM)
-- =============================================================================

local THEME = {
	Background  = Color3.fromRGB(20, 22, 28),
	Header      = Color3.fromRGB(28, 31, 40),
	Sidebar     = Color3.fromRGB(24, 27, 35),
	Card        = Color3.fromRGB(32, 36, 46),
	CardStroke  = Color3.fromRGB(48, 54, 68),
	AccentGreen = Color3.fromRGB(52, 168, 107),
	AccentRed   = Color3.fromRGB(215, 68, 68),
	TextMain    = Color3.fromRGB(240, 243, 250),
	TextSub     = Color3.fromRGB(140, 146, 165),
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GardenSuiteGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parentGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.fromOffset(360, 260)
MainFrame.Position = UDim2.new(0.5, -180, 0.5, -130)
MainFrame.BackgroundColor3 = THEME.Background
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = THEME.CardStroke
MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

-- // Header Bar & Dragging // --
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 36)
Header.BackgroundColor3 = THEME.Header
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(0.6, 0, 1, 0)
Title.Position = UDim2.fromOffset(12, 0)
Title.BackgroundTransparency = 1
Title.Text = "GARDEN SUITE PRO"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextColor3 = THEME.TextMain
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local FpsLabel = Instance.new("TextLabel")
FpsLabel.Name = "FpsLabel"
FpsLabel.Size = UDim2.new(0.25, 0, 1, 0)
FpsLabel.Position = UDim2.new(0.6, -30, 0, 0)
FpsLabel.BackgroundTransparency = 1
FpsLabel.Text = "FPS: --"
FpsLabel.Font = Enum.Font.GothamMedium
FpsLabel.TextSize = 11
FpsLabel.TextColor3 = THEME.AccentGreen
FpsLabel.TextXAlignment = Enum.TextXAlignment.Right
FpsLabel.Parent = Header

local MinBtn = Instance.new("TextButton")
MinBtn.Name = "MinBtn"
MinBtn.Size = UDim2.fromOffset(26, 26)
MinBtn.Position = UDim2.new(1, -31, 0.5, -13)
MinBtn.BackgroundColor3 = THEME.Card
MinBtn.Text = "-"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.TextColor3 = THEME.TextMain
MinBtn.BorderSizePixel = 0
MinBtn.Parent = Header
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

-- Dragging Logic
local dragging, dragStart, startPos
Header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = MainFrame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- // Body Content Area & Sidebar Navigation // --
local Body = Instance.new("Frame")
Body.Name = "Body"
Body.Size = UDim2.new(1, 0, 1, -36)
Body.Position = UDim2.fromOffset(0, 36)
Body.BackgroundTransparency = 1
Body.Parent = MainFrame

local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 100, 1, 0)
Sidebar.BackgroundColor3 = THEME.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Body

local SidebarList = Instance.new("UIListLayout")
SidebarList.Padding = UDim.new(0, 4)
SidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarList.Parent = Sidebar
local SidebarPad = Instance.new("UIPadding")
SidebarPad.PaddingTop = UDim.new(0, 8)
SidebarPad.Parent = Sidebar

local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -100, 1, 0)
ContentArea.Position = UDim2.fromOffset(100, 0)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = Body

-- // Tab Manager // --
local Tabs = {}
local TabButtons = {}
local activeTab = nil

local function createTab(tabName: string): ScrollingFrame
	local tabBtn = Instance.new("TextButton")
	tabBtn.Name = "Tab_" .. tabName
	tabBtn.Size = UDim2.new(0, 88, 0, 30)
	tabBtn.BackgroundColor3 = THEME.Card
	tabBtn.BackgroundTransparency = 0.5
	tabBtn.Text = tabName
	tabBtn.Font = Enum.Font.GothamMedium
	tabBtn.TextSize = 11
	tabBtn.TextColor3 = THEME.TextSub
	tabBtn.BorderSizePixel = 0
	tabBtn.Parent = Sidebar
	Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 6)

	local tabContent = Instance.new("ScrollingFrame")
	tabContent.Name = "Content_" .. tabName
	tabContent.Size = UDim2.new(1, 0, 1, 0)
	tabContent.BackgroundTransparency = 1
	tabContent.BorderSizePixel = 0
	tabContent.CanvasSize = UDim2.fromOffset(0, 0)
	tabContent.ScrollBarThickness = 3
	tabContent.ScrollBarImageColor3 = THEME.CardStroke
	tabContent.Visible = false
	tabContent.Parent = ContentArea

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = tabContent
	
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = tabContent

	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		tabContent.CanvasSize = UDim2.fromOffset(0, list.AbsoluteContentSize.Y + 16)
	end)

	tabBtn.MouseButton1Click:Connect(function()
		for name, content in pairs(Tabs) do
			content.Visible = (name == tabName)
		end
		for name, button in pairs(TabButtons) do
			if name == tabName then
				button.BackgroundTransparency = 0
				button.TextColor3 = THEME.TextMain
			else
				button.BackgroundTransparency = 0.5
				button.TextColor3 = THEME.TextSub
			end
		end
	end)

	Tabs[tabName] = tabContent
	TabButtons[tabName] = tabBtn

	if not activeTab then
		activeTab = tabName
		tabContent.Visible = true
		tabBtn.BackgroundTransparency = 0
		tabBtn.TextColor3 = THEME.TextMain
	end

	return tabContent
end

-- // Component Builder: Toggle Card // --
local function addToggleCard(tabContainer: ScrollingFrame, title: string, desc: string, defaultState: boolean, callback: (boolean) -> ())
	local card = Instance.new("Frame")
	card.Name = "Card_" .. title
	card.Size = UDim2.new(0, 240, 0, 44)
	card.BackgroundColor3 = THEME.Card
	card.BorderSizePixel = 0
	card.Parent = tabContainer
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 7)
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME.CardStroke
	stroke.Thickness = 1
	stroke.Parent = card

	local cardTitle = Instance.new("TextLabel")
	cardTitle.Size = UDim2.new(0.7, 0, 0, 18)
	cardTitle.Position = UDim2.fromOffset(10, 5)
	cardTitle.BackgroundTransparency = 1
	cardTitle.Text = title
	cardTitle.Font = Enum.Font.GothamBold
	cardTitle.TextSize = 11
	cardTitle.TextColor3 = THEME.TextMain
	cardTitle.TextXAlignment = Enum.TextXAlignment.Left
	cardTitle.Parent = card

	local cardDesc = Instance.new("TextLabel")
	cardDesc.Size = UDim2.new(0.7, 0, 0, 14)
	cardDesc.Position = UDim2.fromOffset(10, 23)
	cardDesc.BackgroundTransparency = 1
	cardDesc.Text = desc
	cardDesc.Font = Enum.Font.Gotham
	cardDesc.TextSize = 9
	cardDesc.TextColor3 = THEME.TextSub
	cardDesc.TextXAlignment = Enum.TextXAlignment.Left
	cardDesc.Parent = card

	-- Toggle Switch
	local switchBtn = Instance.new("TextButton")
	switchBtn.Size = UDim2.fromOffset(40, 20)
	switchBtn.Position = UDim2.new(1, -50, 0.5, -10)
	switchBtn.BackgroundColor3 = defaultState and THEME.AccentGreen or THEME.CardStroke
	switchBtn.Text = ""
	switchBtn.BorderSizePixel = 0
	switchBtn.Parent = card
	Instance.new("UICorner", switchBtn).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(16, 16)
	knob.Position = defaultState and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.Parent = switchBtn
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local currentState = defaultState

	switchBtn.MouseButton1Click:Connect(function()
		currentState = not currentState
		local targetPos = currentState and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2)
		local targetColor = currentState and THEME.AccentGreen or THEME.CardStroke

		TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = targetPos }):Play()
		TweenService:Create(switchBtn, TweenInfo.new(0.15), { BackgroundColor3 = targetColor }):Play()

		callback(currentState)
	end)
end

-- =============================================================================
-- POPULASI TAB & CONTROL INITIALIZATION
-- =============================================================================

local mainTab    = createTab("Main")
local visualTab  = createTab("Visuals")
local settingsTab= createTab("Settings")

-- Main Tab Controls
addToggleCard(mainTab, "Instant Interact", "Bypass hold duration prompt", State.InstantInteract, toggleInstantInteract)
addToggleCard(mainTab, "Auto Spam E", "Simulate rapid E key press", State.AutoSpamE, function(s) State.AutoSpamE = s end)
addToggleCard(mainTab, "Auto Drop Item", "Simulate rapid Backspace press", State.AutoDrop, function(s) State.AutoDrop = s end)

-- Visuals Tab Controls
addToggleCard(visualTab, "Anti-Lag Plants", "Hide plant meshes to save RAM", State.AntiLagPlants, toggleAntiLagPlants)
addToggleCard(visualTab, "Clear Textures", "SmoothPlastic map & clear sky", State.ClearTextures, toggleClearTextures)

-- Settings Tab (Hotkey info)
local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(0, 240, 0, 60)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Garden Suite Pro v2.1\nReady for upcoming Modules.\nToggle GUI: RightControl"
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 10
infoLabel.TextColor3 = THEME.TextSub
infoLabel.Parent = settingsTab

-- =============================================================================
-- PERFORMANCE RUNNERS (FPS & MINIMIZATION)
-- =============================================================================

-- FPS Counter via Moving Average (Zero Memory Allocation)
local currentFps = 60
RunService.Heartbeat:Connect(function(dt)
	currentFps = currentFps * 0.9 + (1 / dt) * 0.1
	FpsLabel.Text = string.format("FPS: %d", math.floor(currentFps))
end)

-- Minimize Button Logic
local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	if isMinimized then
		Body.Visible = false
		MainFrame:TweenSize(UDim2.fromOffset(360, 36), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.2, true)
		MinBtn.Text = "+"
	else
		MainFrame:TweenSize(UDim2.fromOffset(360, 260), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.2, true, function()
			Body.Visible = true
		end)
		MinBtn.Text = "-"
	end
end)

-- Hotkey Toggle ScreenGui
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightControl then
		ScreenGui.Enabled = not ScreenGui.Enabled
	end
end)

print("[Garden Suite Pro]: UI Engine Loaded Successfully (Price Tag Removed).")
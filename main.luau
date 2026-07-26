--[[
    =============================================================================
    GARDEN SUITE PRO - ULTIMATE CONTROL PANEL (V2.3 FINAL FIX)
    100% Preserved Mail Tool Engine + Stock Clamping + Flex Remote Handler
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
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local HttpService         = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- // Safe GUI Parent Resolution // --
local function getGuiParent(): Instance
	local success, _ = pcall(function()
		local t = CoreGui.Name
	end)
	if success then return CoreGui end
	return LocalPlayer:WaitForChild("PlayerGui")
end

-- // Clean Previous Instances // --
local parentGui = getGuiParent()
local oldGui = parentGui:FindFirstChild("GardenSuiteGUI")
if oldGui then oldGui:Destroy() end

-- // Global State Manager // --
local State = {
	InstantInteract  = false,
	AutoSpamE        = false,
	AutoDrop         = false,
	AntiLagPlants    = false,
	ClearTextures    = false,
}

local OriginalPlantData       = {}
local OriginalTextures        = {}
local OriginalLightingEffects = {}
local PromptConnections       = {}

-- =============================================================================
-- FULL PRESERVED MAIL TOOL ENGINE
-- =============================================================================

local MailCfg = {
	recipient = "",
	category = "Pets",
	note = "Sent via Garden Suite Pro",
	maxMailLines = 20,
	sendCooldownSec = 11,
}

local CATEGORIES = { "Seeds", "Sprinklers", "WateringCans", "Trowels", "Mushrooms", "Raccoons", "Gnomes", "HarvestedFruits", "Pets" }
local LINE_EXPANDED = { Pets = true, HarvestedFruits = true }

local Networking, PlayerStateClient, MailboxItemCatalog
pcall(function()
	Networking = require(ReplicatedStorage:WaitForChild("SharedModules", 10):WaitForChild("Networking"))
	PlayerStateClient = require(ReplicatedStorage:WaitForChild("ClientModules", 10):WaitForChild("PlayerStateClient"))
	local controllers = LocalPlayer:WaitForChild("PlayerScripts", 10):WaitForChild("Controllers", 10)
	MailboxItemCatalog = require(controllers:WaitForChild("MailboxController"):WaitForChild("MailboxItemCatalog"))
end)

local function remoteCall(remote: any, ...: any): (boolean, ...any)
	if remote == nil then return false, "nil remote" end
	local args = { ... }
	if typeof(remote.Fire) == "function" then
		return pcall(function() return remote:Fire(table.unpack(args)) end)
	end
	if typeof(remote.Invoke) == "function" then
		return pcall(function() return remote:Invoke(table.unpack(args)) end)
	end
	if typeof(remote.InvokeServer) == "function" then
		return pcall(function() return remote:InvokeServer(table.unpack(args)) end)
	end
	if typeof(remote.FireServer) == "function" then
		return pcall(function() return remote:FireServer(table.unpack(args)) end)
	end
	return false, "remote has no Fire/Invoke method"
end

local function getReplica()
	if not PlayerStateClient then return nil end
	return PlayerStateClient:GetLocalReplica()
end

local function getInventory()
	local replica = getReplica()
	return replica and replica.Data and replica.Data.Inventory
end

local function getStackCount(category: string, itemKey: string): number
	local inv = getInventory()
	local bucket = inv and inv[category]
	if typeof(bucket) ~= "table" then return 0 end
	local entry = bucket[itemKey]
	if typeof(entry) == "number" then return entry end
	if typeof(entry) == "table" and typeof(entry.Count) == "number" then return entry.Count end
	if entry ~= nil then return 1 end
	return 0
end

local function normalizePetKey(value: string): string
	return (string.gsub(string.lower(value), "[%s%p]", ""))
end

local function readPetFields(data: any): (string?, boolean)
	if typeof(data) ~= "table" then return nil, false end
	local species = data.Name or data.name or data.Species or data.species or data.PetName or data.petName
	local equipped = data.Equipped == true
	if typeof(species) ~= "string" or species == "" then return nil, equipped end
	return species, equipped
end

local function matchPets(species: string): { string }
	local inv = getInventory()
	local bucket = inv and inv.Pets
	if typeof(bucket) ~= "table" then return {} end
	local want = normalizePetKey(species)
	local matched: { string } = {}
	for uuid, data in pairs(bucket) do
		local sp, equipped = readPetFields(data)
		if sp and normalizePetKey(sp) == want and not equipped then
			table.insert(matched, tostring(uuid))
		end
	end
	return matched
end

local function resolveStackKey(category: string, itemKey: string): string?
	local inv = getInventory()
	local bucket = inv and inv[category]
	if typeof(bucket) ~= "table" then return nil end
	if bucket[itemKey] then return itemKey end
	for key in pairs(bucket) do
		if string.lower(tostring(key)) == string.lower(itemKey) then
			return tostring(key)
		end
	end
	return nil
end

local function getAvailableCount(category: string, itemKey: string): number
	if category == "Pets" then
		return #matchPets(itemKey)
	end
	local key = resolveStackKey(category, itemKey)
	if not key then return 0 end
	return getStackCount(category, key)
end

local function listCategoryItems(category: string): { any }
	local inv = getInventory()
	local bucket = inv and inv[category]
	local items: { any } = {}
	if typeof(bucket) ~= "table" then return items end

	if category == "Pets" then
		local groups: { [string]: number } = {}
		for _, data in pairs(bucket) do
			local species, equipped = readPetFields(data)
			if species and not equipped then
				groups[species] = (groups[species] or 0) + 1
			end
		end
		for species, count in pairs(groups) do
			table.insert(items, { itemKey = species, displayName = species, count = count })
		end
	else
		for key, entry in pairs(bucket) do
			local count = getStackCount(category, tostring(key))
			if count > 0 then
				table.insert(items, { itemKey = tostring(key), displayName = tostring(key), count = count })
			end
		end
	end

	table.sort(items, function(a, b) return a.displayName < b.displayName end)
	return items
end

local lookupCache: { [string]: number } = {}
local function lookupUser(username: string): (number?, string?)
	if not Networking or not Networking.Mailbox then return nil, "Networking module missing" end
	local key = string.lower(username)
	if lookupCache[key] then return lookupCache[key], nil end
	local ok, userId = remoteCall(Networking.Mailbox.LookupPlayer, username)
	if ok and typeof(userId) == "number" and userId > 0 then
		lookupCache[key] = userId
		return userId, nil
	end
	return nil, "Player '" .. username .. "' not found"
end

local function buildLinesForEntry(category: string, itemKey: string, count: number): ({ any }?, string?)
	if category == "Pets" then
		local matched = matchPets(itemKey)
		if #matched < count then
			return nil, string.format("Pets/%s: need %d, have %d (equipped pets skipped)", itemKey, count, #matched)
		end
		local lines = {}
		for i = 1, count do table.insert(lines, { Category = "Pets", ItemKey = matched[i], Count = 1 }) end
		return lines, nil
	end

	local resolvedKey = resolveStackKey(category, itemKey)
	if not resolvedKey then return nil, itemKey .. " not found in inventory" end
	local have = getStackCount(category, resolvedKey)
	if have < count then return nil, string.format("%s: need %d, have %d", resolvedKey, count, have) end
	return { { Category = category, ItemKey = resolvedKey, Count = count } }, nil
end

local function packPayloadLines(lines: { any }): { { any } }
	local maxLines = MailCfg.maxMailLines
	local mails: { { any } } = {}
	local current: { any } = {}
	local used = 0

	for _, entry in ipairs(lines) do
		local cost = LINE_EXPANDED[entry.Category] and entry.Count or 1
		if used + cost > maxLines and #current > 0 then
			table.insert(mails, current)
			current = {}
			used = 0
		end
		table.insert(current, entry)
		used += cost
	end
	if #current > 0 then table.insert(mails, current) end
	return mails
end

-- =============================================================================
-- LOGIKA AUTOMATION (INSTANT, SPAM E, ANTI-LAG)
-- =============================================================================

local function applyInstantPrompt(prompt: Instance)
	if prompt:IsA("ProximityPrompt") then
		if State.InstantInteract then
			if not prompt:GetAttribute("OriginalDuration") then
				prompt:SetAttribute("OriginalDuration", prompt.HoldDuration)
			end
			prompt.HoldDuration = 0
		else
			local original = prompt:GetAttribute("OriginalDuration")
			if original then prompt.HoldDuration = original end
		end
	end
end

local function toggleInstantInteract(enabled: boolean)
	State.InstantInteract = enabled
	for _, desc in ipairs(workspace:GetDescendants()) do applyInstantPrompt(desc) end
end

PromptConnections.DescendantAdded = workspace.DescendantAdded:Connect(function(descendant)
	if State.InstantInteract then task.wait(0.05) applyInstantPrompt(descendant) end
end)

task.spawn(function()
	while true do
		if State.AutoSpamE then
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
			task.wait(0.02)
			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
			task.wait(0.03)
		else task.wait(0.1) end
	end
end)

task.spawn(function()
	while true do
		if State.AutoDrop then
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
			task.wait(0.02)
			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
			task.wait(0.03)
		else task.wait(0.1) end
	end
end)

local function minimizePlant(plantModel: Instance)
	if not plantModel:IsA("Model") then return end
	for _, child in ipairs(plantModel:GetDescendants()) do
		if child:IsA("BasePart") or child:IsA("MeshPart") then
			if not OriginalPlantData[child] then
				OriginalPlantData[child] = { Size = child.Size, Transparency = child.Transparency, CanCollide = child.CanCollide }
			end
			child.Size = Vector3.zero child.Transparency = 1 child.CanCollide = false
		elseif child:IsA("Decal") or child:IsA("Texture") then
			if not OriginalPlantData[child] then OriginalPlantData[child] = { Transparency = child.Transparency } end
			child.Transparency = 1
		end
	end
end

local function restorePlants()
	for child, data in pairs(OriginalPlantData) do
		if child and child.Parent then
			if child:IsA("BasePart") or child:IsA("MeshPart") then
				child.Size = data.Size child.Transparency = data.Transparency child.CanCollide = data.CanCollide
			elseif child:IsA("Decal") or child:IsA("Texture") then child.Transparency = data.Transparency end
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
			if plants then for _, plant in ipairs(plants:GetChildren()) do minimizePlant(plant) end end
		end
	else restorePlants() end
end

local function toggleClearTextures(enabled: boolean)
	State.ClearTextures = enabled
	if enabled then
		for _, v in ipairs(workspace:GetDescendants()) do
			if v:IsA("BasePart") and not v:IsA("MeshPart") then
				OriginalTextures[v] = { Material = v.Material } v.Material = Enum.Material.SmoothPlastic
			elseif v:IsA("Texture") or v:IsA("Decal") then
				OriginalTextures[v] = { Parent = v.Parent } v.Parent = nil
			end
		end
		for _, effect in ipairs(Lighting:GetChildren()) do
			if effect:IsA("PostEffect") or effect:IsA("Sky") or string.find(effect.Name, "Effect") or string.find(effect.Name, "SunRays") then
				OriginalLightingEffects[effect] = { Parent = effect.Parent } effect.Parent = nil
			end
		end
	else
		for obj, data in pairs(OriginalTextures) do
			if obj and typeof(obj) == "Instance" then
				if obj:IsA("BasePart") then obj.Material = data.Material else obj.Parent = data.Parent end
			end
		end
		table.clear(OriginalTextures)
		for effect, data in pairs(OriginalLightingEffects) do
			if effect and typeof(effect) == "Instance" then effect.Parent = data.Parent end
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
MainFrame.Size = UDim2.fromOffset(440, 330)
MainFrame.Position = UDim2.new(0.5, -220, 0.5, -165)
MainFrame.BackgroundColor3 = THEME.Background
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local MainStroke = Instance.new("UIStroke") MainStroke.Color = THEME.CardStroke MainStroke.Thickness = 1 MainStroke.Parent = MainFrame

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 36)
Header.BackgroundColor3 = THEME.Header
Header.BorderSizePixel = 0
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.6, 0, 1, 0) Title.Position = UDim2.fromOffset(12, 0) Title.BackgroundTransparency = 1
Title.Text = "GARDEN SUITE PRO" Title.Font = Enum.Font.GothamBold Title.TextSize = 13 Title.TextColor3 = THEME.TextMain
Title.TextXAlignment = Enum.TextXAlignment.Left Title.Parent = Header

local FpsLabel = Instance.new("TextLabel")
FpsLabel.Size = UDim2.new(0.25, 0, 1, 0) FpsLabel.Position = UDim2.new(0.6, -30, 0, 0) FpsLabel.BackgroundTransparency = 1
FpsLabel.Text = "FPS: --" FpsLabel.Font = Enum.Font.GothamMedium FpsLabel.TextSize = 11 FpsLabel.TextColor3 = THEME.AccentGreen
FpsLabel.TextXAlignment = Enum.TextXAlignment.Right FpsLabel.Parent = Header

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.fromOffset(26, 26) MinBtn.Position = UDim2.new(1, -31, 0.5, -13) MinBtn.BackgroundColor3 = THEME.Card
MinBtn.Text = "-" MinBtn.Font = Enum.Font.GothamBold MinBtn.TextSize = 14 MinBtn.TextColor3 = THEME.TextMain MinBtn.BorderSizePixel = 0 MinBtn.Parent = Header
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

-- Dragging
local dragging, dragStart, startPos
Header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true dragStart = input.Position startPos = MainFrame.Position
		input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- Body & Sidebar
local Body = Instance.new("Frame")
Body.Size = UDim2.new(1, 0, 1, -36) Body.Position = UDim2.fromOffset(0, 36) Body.BackgroundTransparency = 1 Body.Parent = MainFrame

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 100, 1, 0) Sidebar.BackgroundColor3 = THEME.Sidebar Sidebar.BorderSizePixel = 0 Sidebar.Parent = Body

local SidebarList = Instance.new("UIListLayout") SidebarList.Padding = UDim.new(0, 4) SidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center SidebarList.Parent = Sidebar
local SidebarPad = Instance.new("UIPadding") SidebarPad.PaddingTop = UDim.new(0, 8) SidebarPad.Parent = Sidebar

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -100, 1, 0) ContentArea.Position = UDim2.fromOffset(100, 0) ContentArea.BackgroundTransparency = 1 ContentArea.Parent = Body

local Tabs, TabButtons, activeTab = {}, {}, nil
local function createTab(tabName: string): Frame
	local tabBtn = Instance.new("TextButton")
	tabBtn.Size = UDim2.new(0, 88, 0, 30) tabBtn.BackgroundColor3 = THEME.Card tabBtn.BackgroundTransparency = 0.5
	tabBtn.Text = tabName tabBtn.Font = Enum.Font.GothamMedium tabBtn.TextSize = 11 tabBtn.TextColor3 = THEME.TextSub tabBtn.BorderSizePixel = 0 tabBtn.Parent = Sidebar
	Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 6)

	local tabContent = Instance.new("Frame")
	tabContent.Name = "Content_" .. tabName tabContent.Size = UDim2.new(1, 0, 1, 0) tabContent.BackgroundTransparency = 1 tabContent.Visible = false tabContent.Parent = ContentArea

	tabBtn.MouseButton1Click:Connect(function()
		for name, content in pairs(Tabs) do content.Visible = (name == tabName) end
		for name, button in pairs(TabButtons) do
			if name == tabName then button.BackgroundTransparency = 0 button.TextColor3 = THEME.TextMain else button.BackgroundTransparency = 0.5 button.TextColor3 = THEME.TextSub end
		end
	end)

	Tabs[tabName] = tabContent
	TabButtons[tabName] = tabBtn

	if not activeTab then activeTab = tabName tabContent.Visible = true tabBtn.BackgroundTransparency = 0 tabBtn.TextColor3 = THEME.TextMain end
	return tabContent
end

local function addToggleCard(tabContainer: Instance, title: string, desc: string, defaultState: boolean, callback: (boolean) -> ())
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 310, 0, 44) card.BackgroundColor3 = THEME.Card card.BorderSizePixel = 0 card.Parent = tabContainer
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 7)
	local stroke = Instance.new("UIStroke") stroke.Color = THEME.CardStroke stroke.Thickness = 1 stroke.Parent = card

	local cardTitle = Instance.new("TextLabel")
	cardTitle.Size = UDim2.new(0.7, 0, 0, 18) cardTitle.Position = UDim2.fromOffset(10, 5) cardTitle.BackgroundTransparency = 1
	cardTitle.Text = title cardTitle.Font = Enum.Font.GothamBold cardTitle.TextSize = 11 cardTitle.TextColor3 = THEME.TextMain cardTitle.TextXAlignment = Enum.TextXAlignment.Left cardTitle.Parent = card

	local cardDesc = Instance.new("TextLabel")
	cardDesc.Size = UDim2.new(0.7, 0, 0, 14) cardDesc.Position = UDim2.fromOffset(10, 23) cardDesc.BackgroundTransparency = 1
	cardDesc.Text = desc cardDesc.Font = Enum.Font.Gotham cardDesc.TextSize = 9 cardDesc.TextColor3 = THEME.TextSub cardDesc.TextXAlignment = Enum.TextXAlignment.Left cardDesc.Parent = card

	local switchBtn = Instance.new("TextButton")
	switchBtn.Size = UDim2.fromOffset(40, 20) switchBtn.Position = UDim2.new(1, -50, 0.5, -10)
	switchBtn.BackgroundColor3 = defaultState and THEME.AccentGreen or THEME.CardStroke switchBtn.Text = "" switchBtn.BorderSizePixel = 0 switchBtn.Parent = card
	Instance.new("UICorner", switchBtn).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(16, 16) knob.Position = defaultState and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255) knob.BorderSizePixel = 0 knob.Parent = switchBtn
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local currentState = defaultState
	switchBtn.MouseButton1Click:Connect(function()
		currentState = not currentState
		local targetPos = currentState and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2)
		local targetColor = currentState and THEME.AccentGreen or THEME.CardStroke
		TweenService:Create(knob, TweenInfo.new(0.15), { Position = targetPos }):Play()
		TweenService:Create(switchBtn, TweenInfo.new(0.15), { BackgroundColor3 = targetColor }):Play()
		callback(currentState)
	end)
end

-- =============================================================================
-- TAB CONTENT
-- =============================================================================

local mainTabContent   = createTab("Main")
local visualTabContent = createTab("Visuals")
local mailTabContent   = createTab("Mail")

local function createScrollLayout(parentTab: Frame): ScrollingFrame
	local scroller = Instance.new("ScrollingFrame")
	scroller.Size = UDim2.new(1, 0, 1, 0) scroller.BackgroundTransparency = 1 scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 3 scroller.ScrollBarImageColor3 = THEME.CardStroke scroller.Parent = parentTab
	local list = Instance.new("UIListLayout") list.Padding = UDim.new(0, 6) list.HorizontalAlignment = Enum.HorizontalAlignment.Center list.Parent = scroller
	local pad = Instance.new("UIPadding") pad.PaddingTop = UDim.new(0, 8) pad.PaddingBottom = UDim.new(0, 8) pad.Parent = scroller
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() scroller.CanvasSize = UDim2.fromOffset(0, list.AbsoluteContentSize.Y + 16) end)
	return scroller
end

local mainScroll   = createScrollLayout(mainTabContent)
local visualScroll = createScrollLayout(visualTabContent)

addToggleCard(mainScroll, "Instant Interact", "Bypass hold duration prompt", State.InstantInteract, toggleInstantInteract)
addToggleCard(mainScroll, "Auto Spam E", "Simulate rapid E key press", State.AutoSpamE, function(s) State.AutoSpamE = s end)
addToggleCard(mainScroll, "Auto Drop Item", "Simulate rapid Backspace press", State.AutoDrop, function(s) State.AutoDrop = s end)

addToggleCard(visualScroll, "Anti-Lag Plants", "Hide plant meshes to save RAM", State.AntiLagPlants, toggleAntiLagPlants)
addToggleCard(visualScroll, "Clear Textures", "SmoothPlastic map & clear sky", State.ClearTextures, toggleClearTextures)

-- =============================================================================
-- MAIL TAB UI BUILDER (WITH ITEM DROPDOWN & STOCK CLAMPING)
-- =============================================================================

local MailUI = {
	SelectedCategory = "Pets",
	SelectedItemKey  = nil,
	Cart             = {},
	Sending          = false,
}

local mailContainer = Instance.new("Frame")
mailContainer.Size = UDim2.new(1, 0, 1, 0) mailContainer.BackgroundTransparency = 1 mailContainer.Parent = mailTabContent

local mailPad = Instance.new("UIPadding")
mailPad.PaddingLeft = UDim.new(0, 12) mailPad.PaddingRight = UDim.new(0, 12) mailPad.PaddingTop = UDim.new(0, 8) mailPad.Parent = mailContainer

-- Recipient Input
local recLabel = Instance.new("TextLabel")
recLabel.Size = UDim2.new(1, 0, 0, 12) recLabel.BackgroundTransparency = 1 recLabel.Text = "RECIPIENT USERNAME"
recLabel.Font = Enum.Font.GothamMedium recLabel.TextSize = 9 recLabel.TextColor3 = THEME.TextSub recLabel.TextXAlignment = Enum.TextXAlignment.Left recLabel.Parent = mailContainer

local recipientBox = Instance.new("TextBox")
recipientBox.Size = UDim2.new(1, 0, 0, 26) recipientBox.Position = UDim2.fromOffset(0, 14) recipientBox.BackgroundColor3 = THEME.Card
recipientBox.BorderSizePixel = 0 recipientBox.Font = Enum.Font.Gotham recipientBox.TextSize = 10 recipientBox.TextColor3 = THEME.TextMain
recipientBox.PlaceholderText = "roblox username" recipientBox.PlaceholderColor3 = THEME.TextSub recipientBox.Text = "" recipientBox.Parent = mailContainer
Instance.new("UICorner", recipientBox).CornerRadius = UDim.new(0, 5)
local recStroke = Instance.new("UIStroke") recStroke.Color = THEME.CardStroke recStroke.Parent = recipientBox

-- Category Dropdown Button
local catLabel = Instance.new("TextLabel")
catLabel.Size = UDim2.new(1, 0, 0, 12) catLabel.Position = UDim2.fromOffset(0, 44) catLabel.BackgroundTransparency = 1 catLabel.Text = "CATEGORY"
catLabel.Font = Enum.Font.GothamMedium catLabel.TextSize = 9 catLabel.TextColor3 = THEME.TextSub catLabel.TextXAlignment = Enum.TextXAlignment.Left catLabel.Parent = mailContainer

local catBtn = Instance.new("TextButton")
catBtn.Size = UDim2.new(1, 0, 0, 26) catBtn.Position = UDim2.fromOffset(0, 58) catBtn.BackgroundColor3 = THEME.Card
catBtn.Font = Enum.Font.GothamMedium catBtn.TextSize = 10 catBtn.TextColor3 = THEME.TextMain catBtn.Text = "Pets" catBtn.Parent = mailContainer
Instance.new("UICorner", catBtn).CornerRadius = UDim.new(0, 5)
local catStroke = Instance.new("UIStroke") catStroke.Color = THEME.CardStroke catStroke.Parent = catBtn

-- Item Dropdown Button (The exact item picker from your screenshot!)
local itemLabel = Instance.new("TextLabel")
itemLabel.Size = UDim2.new(1, 0, 0, 12) itemLabel.Position = UDim2.fromOffset(0, 88) itemLabel.BackgroundTransparency = 1 itemLabel.Text = "ITEM PICKER (INVENTORY)"
itemLabel.Font = Enum.Font.GothamMedium itemLabel.TextSize = 9 itemLabel.TextColor3 = THEME.TextSub itemLabel.TextXAlignment = Enum.TextXAlignment.Left itemLabel.Parent = mailContainer

local itemPickerBtn = Instance.new("TextButton")
itemPickerBtn.Size = UDim2.new(0.72, 0, 0, 28) itemPickerBtn.Position = UDim2.fromOffset(0, 102) itemPickerBtn.BackgroundColor3 = THEME.Card
itemPickerBtn.Font = Enum.Font.Gotham itemPickerBtn.TextSize = 10 itemPickerBtn.TextColor3 = THEME.TextSub itemPickerBtn.Text = "Click to pick from inventory..." itemPickerBtn.Parent = mailContainer
Instance.new("UICorner", itemPickerBtn).CornerRadius = UDim.new(0, 5)
local itemStroke = Instance.new("UIStroke") itemStroke.Color = THEME.CardStroke itemStroke.Parent = itemPickerBtn

local addCartBtn = Instance.new("TextButton")
addCartBtn.Size = UDim2.new(0.25, 0, 0, 28) addCartBtn.Position = UDim2.new(0.75, 0, 0, 102) addCartBtn.BackgroundColor3 = THEME.AccentGreen
addCartBtn.Font = Enum.Font.GothamBold addCartBtn.TextSize = 10 addCartBtn.TextColor3 = Color3.fromRGB(255, 255, 255) addCartBtn.Text = "+ Add Cart" addCartBtn.Parent = mailContainer
Instance.new("UICorner", addCartBtn).CornerRadius = UDim.new(0, 5)

-- Dropdown Popup Container
local itemDropdownFrame = Instance.new("ScrollingFrame")
itemDropdownFrame.Size = UDim2.new(1, 0, 0, 120) itemDropdownFrame.Position = UDim2.fromOffset(0, 132) itemDropdownFrame.BackgroundColor3 = THEME.Header
itemDropdownFrame.BorderSizePixel = 0 itemDropdownFrame.CanvasSize = UDim2.fromOffset(0, 0) itemDropdownFrame.ScrollBarThickness = 3
itemDropdownFrame.Visible = false itemDropdownFrame.ZIndex = 20 itemDropdownFrame.Parent = mailContainer
Instance.new("UICorner", itemDropdownFrame).CornerRadius = UDim.new(0, 6)
local dropStroke = Instance.new("UIStroke") dropStroke.Color = THEME.CardStroke dropStroke.Parent = itemDropdownFrame

local dropList = Instance.new("UIListLayout") dropList.Padding = UDim.new(0, 2) dropList.Parent = itemDropdownFrame

-- Cart Frame & Status Bar
local cartFrame = Instance.new("ScrollingFrame")
cartFrame.Size = UDim2.new(1, 0, 0, 85) cartFrame.Position = UDim2.fromOffset(0, 136) cartFrame.BackgroundColor3 = THEME.Card
cartFrame.BorderSizePixel = 0 cartFrame.CanvasSize = UDim2.fromOffset(0, 0) cartFrame.ScrollBarThickness = 3 cartFrame.Parent = mailContainer
Instance.new("UICorner", cartFrame).CornerRadius = UDim.new(0, 6)
local cartList = Instance.new("UIListLayout") cartList.Padding = UDim.new(0, 4) cartList.Parent = cartFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 14) statusLabel.Position = UDim2.fromOffset(0, 225) statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham statusLabel.TextSize = 9 statusLabel.TextColor3 = THEME.TextSub statusLabel.Text = "Cart: 0 items" statusLabel.TextXAlignment = Enum.TextXAlignment.Left statusLabel.Parent = mailContainer

local sendBtn = Instance.new("TextButton")
sendBtn.Size = UDim2.new(1, 0, 0, 30) sendBtn.Position = UDim2.fromOffset(0, 242) sendBtn.BackgroundColor3 = THEME.AccentGreen
sendBtn.Font = Enum.Font.GothamBold sendBtn.TextSize = 11 sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255) sendBtn.Text = "SEND GIFTS" sendBtn.Parent = mailContainer
Instance.new("UICorner", sendBtn).CornerRadius = UDim.new(0, 6)

-- Dropdown Population & Item Selection
local function populateItemDropdown()
	for _, child in ipairs(itemDropdownFrame:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	local items = listCategoryItems(MailUI.SelectedCategory)
	if #items == 0 then
		itemPickerBtn.Text = "No items available in " .. MailUI.SelectedCategory
		itemPickerBtn.TextColor3 = THEME.AccentRed
		return
	end

	for idx, item in ipairs(items) do
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, 0, 0, 24) row.BackgroundColor3 = THEME.Card row.Text = "" row.ZIndex = 21 row.Parent = itemDropdownFrame
		
		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.7, 0, 1, 0) nameLbl.Position = UDim2.fromOffset(8, 0) nameLbl.BackgroundTransparency = 1
		nameLbl.Text = item.displayName nameLbl.Font = Enum.Font.Gotham nameLbl.TextSize = 9 nameLbl.TextColor3 = THEME.TextMain
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left nameLbl.ZIndex = 22 nameLbl.Parent = row

		local countLbl = Instance.new("TextLabel")
		countLbl.Size = UDim2.new(0.25, 0, 1, 0) countLbl.Position = UDim2.new(0.7, 0, 0, 0) countLbl.BackgroundTransparency = 1
		countLbl.Text = "x" .. tostring(item.count) countLbl.Font = Enum.Font.GothamMedium countLbl.TextSize = 9 countLbl.TextColor3 = THEME.TextSub
		countLbl.TextXAlignment = Enum.TextXAlignment.Right countLbl.ZIndex = 22 countLbl.Parent = row

		row.MouseButton1Click:Connect(function()
			MailUI.SelectedItemKey = item.itemKey
			itemPickerBtn.Text = item.displayName .. " (x" .. item.count .. ")"
			itemPickerBtn.TextColor3 = THEME.TextMain
			itemDropdownFrame.Visible = false
		end)
	end

	itemDropdownFrame.CanvasSize = UDim2.fromOffset(0, #items * 26)
end

-- Refresh Cart & Enforce Stock Clamping
local function refreshCartUI()
	for _, child in ipairs(cartFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	for idx, entry in ipairs(MailUI.Cart) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(0.96, 0, 0, 22) row.BackgroundColor3 = THEME.Header row.Parent = cartFrame
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.55, 0, 1, 0) nameLbl.Position = UDim2.fromOffset(6, 0) nameLbl.BackgroundTransparency = 1
		nameLbl.Text = entry.itemKey .. " (" .. entry.category .. ")" nameLbl.Font = Enum.Font.Gotham nameLbl.TextSize = 9
		nameLbl.TextColor3 = THEME.TextMain nameLbl.TextXAlignment = Enum.TextXAlignment.Left nameLbl.Parent = row

		local countBox = Instance.new("TextBox")
		countBox.Size = UDim2.fromOffset(36, 16) countBox.Position = UDim2.new(1, -65, 0.5, -8)
		countBox.BackgroundColor3 = THEME.Card countBox.Text = tostring(entry.sendCount) countBox.Font = Enum.Font.GothamMedium
		countBox.TextSize = 9 countBox.TextColor3 = THEME.TextMain countBox.Parent = row
		Instance.new("UICorner", countBox).CornerRadius = UDim.new(0, 3)

		-- STOCK CLAMPING FIX!
		countBox.FocusLost:Connect(function()
			local num = tonumber(countBox.Text) or 1
			entry.sendCount = math.clamp(math.floor(num), 1, math.max(1, entry.maxAvailable))
			countBox.Text = tostring(entry.sendCount)
			statusLabel.Text = string.format("Clamped %s to max stock (%d)", entry.itemKey, entry.maxAvailable)
		end)

		local delBtn = Instance.new("TextButton")
		delBtn.Size = UDim2.fromOffset(18, 16) delBtn.Position = UDim2.new(1, -22, 0.5, -8)
		delBtn.BackgroundColor3 = THEME.AccentRed delBtn.Text = "X" delBtn.Font = Enum.Font.GothamBold
		delBtn.TextSize = 8 delBtn.TextColor3 = Color3.fromRGB(255, 255, 255) delBtn.Parent = row
		Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 3)

		delBtn.MouseButton1Click:Connect(function()
			table.remove(MailUI.Cart, idx)
			refreshCartUI()
		end)
	end

	cartFrame.CanvasSize = UDim2.fromOffset(0, #MailUI.Cart * 26)
	statusLabel.Text = "Cart: " .. #MailUI.Cart .. " item type(s) queued"
end

-- Toggle Category List
local catIdx = 1
catBtn.MouseButton1Click:Connect(function()
	catIdx = (catIdx % #CATEGORIES) + 1
	MailUI.SelectedCategory = CATEGORIES[catIdx]
	catBtn.Text = MailUI.SelectedCategory
	MailUI.SelectedItemKey = nil
	itemPickerBtn.Text = "Click to pick from inventory..."
	itemPickerBtn.TextColor3 = THEME.TextSub
	populateItemDropdown()
end)

itemPickerBtn.MouseButton1Click:Connect(function()
	itemDropdownFrame.Visible = not itemDropdownFrame.Visible
	if itemDropdownFrame.Visible then populateItemDropdown() end
end)

-- Add Item with Stock Clamp Validation
addCartBtn.MouseButton1Click:Connect(function()
	if not MailUI.SelectedItemKey then
		statusLabel.Text = "Error: Please select an item from dropdown first!"
		return
	end

	local available = getAvailableCount(MailUI.SelectedCategory, MailUI.SelectedItemKey)
	if available <= 0 then
		statusLabel.Text = "Error: You have 0 available stock for " .. MailUI.SelectedItemKey
		return
	end

	-- Check if already in cart
	for _, entry in ipairs(MailUI.Cart) do
		if entry.category == MailUI.SelectedCategory and entry.itemKey == MailUI.SelectedItemKey then
			entry.sendCount = math.clamp(entry.sendCount + 1, 1, available)
			refreshCartUI()
			return
		end
	end

	table.insert(MailUI.Cart, {
		category = MailUI.SelectedCategory,
		itemKey = MailUI.SelectedItemKey,
		sendCount = 1,
		maxAvailable = available
	})
	refreshCartUI()
end)

-- Send Process with Flex Remote Handler Fix
sendBtn.MouseButton1Click:Connect(function()
	if MailUI.Sending then return end
	local recipient = recipientBox.Text
	if recipient == "" then
		statusLabel.Text = "Error: Recipient username cannot be empty!"
		return
	end
	if #MailUI.Cart == 0 then
		statusLabel.Text = "Error: Cart is empty!"
		return
	end

	MailUI.Sending = true
	sendBtn.Text = "SENDING..."
	sendBtn.BackgroundColor3 = THEME.CardStroke

	task.spawn(function()
		local userId, lookupErr = lookupUser(recipient)
		if not userId then
			statusLabel.Text = "Error: " .. (lookupErr or "User lookup failed")
			MailUI.Sending = false
			sendBtn.Text = "SEND GIFTS"
			sendBtn.BackgroundColor3 = THEME.AccentGreen
			return
		end

		local allLines = {}
		for _, row in ipairs(MailUI.Cart) do
			local lines, err = buildLinesForEntry(row.category, row.itemKey, row.sendCount)
			if not lines then
				statusLabel.Text = "Error: " .. (err or "Build lines failed")
				MailUI.Sending = false
				sendBtn.Text = "SEND GIFTS"
				sendBtn.BackgroundColor3 = THEME.AccentGreen
				return
			end
			for _, line in ipairs(lines) do table.insert(allLines, line) end
		end

		local mails = packPayloadLines(allLines)
		statusLabel.Text = string.format("Sending %d gift line(s) in %d mail(s)...", #allLines, #mails)

		for i, payload in ipairs(mails) do
			if i > 1 then task.wait(MailCfg.sendCooldownSec) end
			local ok, err = remoteCall(Networking.Mailbox.SendBatch, userId, payload, MailCfg.note)
			if not ok then
				statusLabel.Text = "Send failed: " .. tostring(err)
				MailUI.Sending = false
				sendBtn.Text = "SEND GIFTS"
				sendBtn.BackgroundColor3 = THEME.AccentGreen
				return
			end
		end

		statusLabel.Text = "Success: Gifts delivered to " .. recipient .. "!"
		table.clear(MailUI.Cart)
		refreshCartUI()

		MailUI.Sending = false
		sendBtn.Text = "SEND GIFTS"
		sendBtn.BackgroundColor3 = THEME.AccentGreen
	end)
end)

-- =============================================================================
-- PERFORMANCE RUNNERS
-- =============================================================================

local currentFps = 60
RunService.Heartbeat:Connect(function(dt)
	currentFps = currentFps * 0.9 + (1 / dt) * 0.1
	FpsLabel.Text = string.format("FPS: %d", math.floor(currentFps))
end)

local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	if isMinimized then
		Body.Visible = false
		MainFrame:TweenSize(UDim2.fromOffset(440, 36), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.2, true)
		MinBtn.Text = "+"
	else
		MainFrame:TweenSize(UDim2.fromOffset(440, 330), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.2, true, function()
			Body.Visible = true
		end)
		MinBtn.Text = "-"
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightControl then
		ScreenGui.Enabled = not ScreenGui.Enabled
	end
end)

print("[Garden Suite Pro V2.3]: Full Mail Tool Engine & Stock Clamping Restored.")
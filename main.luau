--[[
    =============================================================================
    GARDEN SUITE PRO - V3.0 ULTRA-PREMIUM EDITION (FLUENT / RAYFIELD STYLE)
    Redesigned Aesthetics + 100% Preserved Full Mail Tool & Automation Engine
    =============================================================================
--]]

task.wait(0.3)

-- // Services // --
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService    = game:GetService("UserInputService")
local Players             = game:GetService("Players")
local CoreGui             = game:GetService("CoreGui")
local TweenService        = game:GetService("TweenService")
local RunService          = game:GetService("RunService")
local Lighting            = game:GetService("Lighting")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")

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
local oldGui = parentGui:FindFirstChild("GardenSuiteGUI_V3")
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
-- FULL PRESERVED ENGINE (MAIL & AUTOMATION)
-- =============================================================================

local MailCfg = {
	recipient = "",
	category = "Pets",
	note = "Sent via Garden Suite Pro V3",
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
	if typeof(remote.Fire) == "function" then return pcall(function() return remote:Fire(table.unpack(args)) end) end
	if typeof(remote.Invoke) == "function" then return pcall(function() return remote:Invoke(table.unpack(args)) end) end
	if typeof(remote.InvokeServer) == "function" then return pcall(function() return remote:InvokeServer(table.unpack(args)) end) end
	if typeof(remote.FireServer) == "function" then return pcall(function() return remote:FireServer(table.unpack(args)) end) end
	return false, "remote invalid"
end

local function getInventory()
	if not PlayerStateClient then return nil end
	local ok, replica = pcall(function() return PlayerStateClient:GetLocalReplica() end)
	return ok and replica and replica.Data and replica.Data.Inventory
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
		if string.lower(tostring(key)) == string.lower(itemKey) then return tostring(key) end
	end
	return nil
end

local function getAvailableCount(category: string, itemKey: string): number
	if category == "Pets" then return #matchPets(itemKey) end
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
			if species and not equipped then groups[species] = (groups[species] or 0) + 1 end
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
		if #matched < count then return nil, string.format("Pets/%s: need %d, have %d", itemKey, count, #matched) end
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

-- Automations
local function applyInstantPrompt(prompt: Instance)
	if prompt:IsA("ProximityPrompt") then
		if State.InstantInteract then
			if not prompt:GetAttribute("OriginalDuration") then prompt:SetAttribute("OriginalDuration", prompt.HoldDuration) end
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
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game) task.wait(0.02)
			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game) task.wait(0.03)
		else task.wait(0.1) end
	end
end)

task.spawn(function()
	while true do
		if State.AutoDrop then
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game) task.wait(0.02)
			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game) task.wait(0.03)
		else task.wait(0.1) end
	end
end)

local function minimizePlant(plantModel: Instance)
	if not plantModel:IsA("Model") then return end
	for _, child in ipairs(plantModel:GetDescendants()) do
		if child:IsA("BasePart") or child:IsA("MeshPart") then
			if not OriginalPlantData[child] then OriginalPlantData[child] = { Size = child.Size, Transparency = child.Transparency, CanCollide = child.CanCollide } end
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
			if child:IsA("BasePart") or child:IsA("MeshPart") then child.Size = data.Size child.Transparency = data.Transparency child.CanCollide = data.CanCollide
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
			if v:IsA("BasePart") and not v:IsA("MeshPart") then OriginalTextures[v] = { Material = v.Material } v.Material = Enum.Material.SmoothPlastic
			elseif v:IsA("Texture") or v:IsA("Decal") then OriginalTextures[v] = { Parent = v.Parent } v.Parent = nil end
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
-- ULTRA-PREMIUM UI DESIGN SYSTEM (FLUENT STYLE)
-- =============================================================================

local THEME = {
	WindowBg    = Color3.fromRGB(13, 15, 20),
	HeaderBg    = Color3.fromRGB(18, 21, 28),
	SidebarBg   = Color3.fromRGB(16, 18, 24),
	CardBg      = Color3.fromRGB(22, 25, 34),
	CardHover   = Color3.fromRGB(28, 32, 44),
	Stroke      = Color3.fromRGB(38, 43, 58),
	StrokeFocus = Color3.fromRGB(99, 102, 241), -- Indigo Glow
	Accent      = Color3.fromRGB(16, 185, 129), -- Emerald
	AccentIndigo= Color3.fromRGB(99, 102, 241),
	TextMain    = Color3.fromRGB(243, 244, 246),
	TextSub     = Color3.fromRGB(156, 163, 175),
	TextMuted   = Color3.fromRGB(107, 114, 128),
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GardenSuiteGUI_V3"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parentGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.fromOffset(480, 340)
MainFrame.Position = UDim2.new(0.5, -240, 0.5, -170)
MainFrame.BackgroundColor3 = THEME.WindowBg
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
local MainStroke = Instance.new("UIStroke") MainStroke.Color = THEME.Stroke MainStroke.Thickness = 1.5 MainStroke.Parent = MainFrame

-- Top Header Bar
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = THEME.HeaderBg
Header.BorderSizePixel = 0
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

local TitleLogo = Instance.new("TextLabel")
TitleLogo.Size = UDim2.new(0.6, 0, 1, 0) TitleLogo.Position = UDim2.fromOffset(14, 0) TitleLogo.BackgroundTransparency = 1
TitleLogo.Text = "GARDEN SUITE <font color='#6366F1'>PRO</font>" TitleLogo.RichText = true TitleLogo.Font = Enum.Font.GothamBold TitleLogo.TextSize = 13
TitleLogo.TextColor3 = THEME.TextMain TitleLogo.TextXAlignment = Enum.TextXAlignment.Left TitleLogo.Parent = Header

-- FPS Badge Pill
local FpsPill = Instance.new("Frame")
FpsPill.Size = UDim2.fromOffset(70, 22) FpsPill.Position = UDim2.new(1, -110, 0.5, -11) FpsPill.BackgroundColor3 = THEME.CardBg FpsPill.Parent = Header
Instance.new("UICorner", FpsPill).CornerRadius = UDim.new(1, 0)
local FpsStroke = Instance.new("UIStroke") FpsStroke.Color = THEME.Stroke FpsStroke.Parent = FpsPill

local FpsText = Instance.new("TextLabel")
FpsText.Size = UDim2.new(1, 0, 1, 0) FpsText.BackgroundTransparency = 1 FpsText.Text = "60 FPS" FpsText.Font = Enum.Font.GothamBold FpsText.TextSize = 10
FpsText.TextColor3 = THEME.Accent FpsText.Parent = FpsPill

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(26, 26) CloseBtn.Position = UDim2.new(1, -34, 0.5, -13) CloseBtn.BackgroundColor3 = THEME.CardBg
CloseBtn.Text = "✕" CloseBtn.Font = Enum.Font.GothamBold CloseBtn.TextSize = 12 CloseBtn.TextColor3 = THEME.TextSub CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

CloseBtn.MouseEnter:Connect(function() CloseBtn.TextColor3 = Color3.fromRGB(239, 68, 68) end)
CloseBtn.MouseLeave:Connect(function() CloseBtn.TextColor3 = THEME.TextSub end)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui.Enabled = false end)

-- Window Dragging Logic
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

-- Main Workspace Layout
local Body = Instance.new("Frame")
Body.Size = UDim2.new(1, 0, 1, -40) Body.Position = UDim2.fromOffset(0, 40) Body.BackgroundTransparency = 1 Body.Parent = MainFrame

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 115, 1, 0) Sidebar.BackgroundColor3 = THEME.SidebarBg Sidebar.BorderSizePixel = 0 Sidebar.Parent = Body

local SidebarList = Instance.new("UIListLayout") SidebarList.Padding = UDim.new(0, 6) SidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center SidebarList.Parent = Sidebar
local SidebarPad = Instance.new("UIPadding") SidebarPad.PaddingTop = UDim.new(0, 10) SidebarPad.Parent = Sidebar

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -115, 1, 0) ContentArea.Position = UDim2.fromOffset(115, 0) ContentArea.BackgroundTransparency = 1 ContentArea.Parent = Body

-- Dynamic Tab Navigation
local Tabs, TabButtons, activeTab = {}, {}, nil
local function createTab(tabName: string, iconSymbol: string): Frame
	local tabBtn = Instance.new("TextButton")
	tabBtn.Size = UDim2.new(0, 100, 0, 32) tabBtn.BackgroundColor3 = THEME.CardBg tabBtn.BackgroundTransparency = 0.6
	tabBtn.Text = "  " .. iconSymbol .. "  " .. tabName tabBtn.Font = Enum.Font.GothamMedium tabBtn.TextSize = 11 tabBtn.TextColor3 = THEME.TextSub
	tabBtn.TextXAlignment = Enum.TextXAlignment.Left tabBtn.BorderSizePixel = 0 tabBtn.Parent = Sidebar
	Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 7)

	local tabContent = Instance.new("Frame")
	tabContent.Name = "Content_" .. tabName tabContent.Size = UDim2.new(1, 0, 1, 0) tabContent.BackgroundTransparency = 1 tabContent.Visible = false tabContent.Parent = ContentArea

	tabBtn.MouseButton1Click:Connect(function()
		for name, content in pairs(Tabs) do content.Visible = (name == tabName) end
		for name, button in pairs(TabButtons) do
			if name == tabName then
				TweenService:Create(button, TweenInfo.new(0.15), { BackgroundTransparency = 0, TextColor3 = THEME.TextMain, BackgroundColor3 = THEME.AccentIndigo }):Play()
			else
				TweenService:Create(button, TweenInfo.new(0.15), { BackgroundTransparency = 0.6, TextColor3 = THEME.TextSub, BackgroundColor3 = THEME.CardBg }):Play()
			end
		end
	end)

	Tabs[tabName] = tabContent
	TabButtons[tabName] = tabBtn

	if not activeTab then
		activeTab = tabName tabContent.Visible = true
		tabBtn.BackgroundTransparency = 0 tabBtn.TextColor3 = THEME.TextMain tabBtn.BackgroundColor3 = THEME.AccentIndigo
	end
	return tabContent
end

local function addToggleCard(tabContainer: Instance, title: string, desc: string, defaultState: boolean, callback: (boolean) -> ())
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 340, 0, 48) card.BackgroundColor3 = THEME.CardBg card.BorderSizePixel = 0 card.Parent = tabContainer
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
	local stroke = Instance.new("UIStroke") stroke.Color = THEME.Stroke stroke.Thickness = 1 stroke.Parent = card

	local cardTitle = Instance.new("TextLabel")
	cardTitle.Size = UDim2.new(0.7, 0, 0, 20) cardTitle.Position = UDim2.fromOffset(12, 6) cardTitle.BackgroundTransparency = 1
	cardTitle.Text = title cardTitle.Font = Enum.Font.GothamBold cardTitle.TextSize = 11 cardTitle.TextColor3 = THEME.TextMain cardTitle.TextXAlignment = Enum.TextXAlignment.Left cardTitle.Parent = card

	local cardDesc = Instance.new("TextLabel")
	cardDesc.Size = UDim2.new(0.7, 0, 0, 14) cardDesc.Position = UDim2.fromOffset(12, 26) cardDesc.BackgroundTransparency = 1
	cardDesc.Text = desc cardDesc.Font = Enum.Font.Gotham cardDesc.TextSize = 9 cardDesc.TextColor3 = THEME.TextSub cardDesc.TextXAlignment = Enum.TextXAlignment.Left cardDesc.Parent = card

	local switchBtn = Instance.new("TextButton")
	switchBtn.Size = UDim2.fromOffset(42, 22) switchBtn.Position = UDim2.new(1, -54, 0.5, -11)
	switchBtn.BackgroundColor3 = defaultState and THEME.Accent or THEME.Stroke switchBtn.Text = "" switchBtn.BorderSizePixel = 0 switchBtn.Parent = card
	Instance.new("UICorner", switchBtn).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(16, 16) knob.Position = defaultState and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255) knob.BorderSizePixel = 0 knob.Parent = switchBtn
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local currentState = defaultState
	switchBtn.MouseButton1Click:Connect(function()
		currentState = not currentState
		local targetPos = currentState and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)
		local targetColor = currentState and THEME.Accent or THEME.Stroke
		TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = targetPos }):Play()
		TweenService:Create(switchBtn, TweenInfo.new(0.15), { BackgroundColor3 = targetColor }):Play()
		callback(currentState)
	end)
end

-- =============================================================================
-- CREATING TABS & CONTENT
-- =============================================================================

local mainTabContent   = createTab("Main", "⚡")
local visualTabContent = createTab("Visuals", "👁")
local mailTabContent   = createTab("Mail Tool", "📦")

local function createScrollLayout(parentTab: Frame): ScrollingFrame
	local scroller = Instance.new("ScrollingFrame")
	scroller.Size = UDim2.new(1, 0, 1, 0) scroller.BackgroundTransparency = 1 scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 3 scroller.ScrollBarImageColor3 = THEME.Stroke scroller.Parent = parentTab
	local list = Instance.new("UIListLayout") list.Padding = UDim.new(0, 8) list.HorizontalAlignment = Enum.HorizontalAlignment.Center list.Parent = scroller
	local pad = Instance.new("UIPadding") pad.PaddingTop = UDim.new(0, 10) pad.PaddingBottom = UDim.new(0, 10) pad.Parent = scroller
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() scroller.CanvasSize = UDim2.fromOffset(0, list.AbsoluteContentSize.Y + 20) end)
	return scroller
end

local mainScroll   = createScrollLayout(mainTabContent)
local visualScroll = createScrollLayout(visualTabContent)

addToggleCard(mainScroll, "Instant Interact", "Bypass hold duration prompt on all prompts", State.InstantInteract, toggleInstantInteract)
addToggleCard(mainScroll, "Auto Spam E", "Rapidly simulate pressing key E", State.AutoSpamE, function(s) State.AutoSpamE = s end)
addToggleCard(mainScroll, "Auto Drop Item", "Rapidly simulate pressing Backspace", State.AutoDrop, function(s) State.AutoDrop = s end)

addToggleCard(visualScroll, "Anti-Lag Plants", "Minimize plant models to increase performance", State.AntiLagPlants, toggleAntiLagPlants)
addToggleCard(visualScroll, "Clear Map Textures", "SmoothPlastic map & clear sky/effects", State.ClearTextures, toggleClearTextures)

-- =============================================================================
-- REDESIGNED ULTRA-PREMIUM MAIL TOOL UI
-- =============================================================================

local MailUI = { SelectedCategory = "Pets", SelectedItemKey = nil, Cart = {}, Sending = false }

local mailContainer = Instance.new("Frame")
mailContainer.Size = UDim2.new(1, 0, 1, 0) mailContainer.BackgroundTransparency = 1 mailContainer.Parent = mailTabContent

local mailPad = Instance.new("UIPadding")
mailPad.PaddingLeft = UDim.new(0, 14) mailPad.PaddingRight = UDim.new(0, 14) mailPad.PaddingTop = UDim.new(0, 10) mailPad.Parent = mailContainer

-- Recipient Input Field (Glowing Focus)
local recCard = Instance.new("Frame")
recCard.Size = UDim2.new(1, 0, 0, 36) recCard.BackgroundColor3 = THEME.CardBg recCard.Parent = mailContainer
Instance.new("UICorner", recCard).CornerRadius = UDim.new(0, 7)
local recStroke = Instance.new("UIStroke") recStroke.Color = THEME.Stroke recStroke.Parent = recCard

local recipientBox = Instance.new("TextBox")
recipientBox.Size = UDim2.new(1, -20, 1, 0) recipientBox.Position = UDim2.fromOffset(10, 0) recipientBox.BackgroundTransparency = 1
recipientBox.Font = Enum.Font.GothamMedium recipientBox.TextSize = 11 recipientBox.TextColor3 = THEME.TextMain
recipientBox.PlaceholderText = "Enter Recipient Roblox Username..." recipientBox.PlaceholderColor3 = THEME.TextMuted recipientBox.Text = "" recipientBox.Parent = recCard

recipientBox.Focused:Connect(function() TweenService:Create(recStroke, TweenInfo.new(0.2), { Color = THEME.StrokeFocus }):Play() end)
recipientBox.FocusLost:Connect(function() TweenService:Create(recStroke, TweenInfo.new(0.2), { Color = THEME.Stroke }):Play() end)

-- Category Horizontal Selector Pill Buttons
local catRow = Instance.new("Frame")
catRow.Size = UDim2.new(1, 0, 0, 26) catRow.Position = UDim2.fromOffset(0, 42) catRow.BackgroundTransparency = 1 catRow.Parent = mailContainer

local catScroll = Instance.new("ScrollingFrame")
catScroll.Size = UDim2.new(1, 0, 1, 0) catScroll.BackgroundTransparency = 1 catScroll.ScrollBarThickness = 0 catScroll.CanvasSize = UDim2.fromOffset(0, 0) catScroll.Parent = catRow
local catList = Instance.new("UIListLayout") catList.FillDirection = Enum.FillDirection.Horizontal catList.Padding = UDim.new(0, 6) catList.Parent = catScroll

local function renderCategoryPills()
	for _, child in ipairs(catScroll:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
	for _, cat in ipairs(CATEGORIES) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.fromOffset(80, 24) btn.BackgroundColor3 = (cat == MailUI.SelectedCategory) and THEME.AccentIndigo or THEME.CardBg
		btn.Text = cat btn.Font = Enum.Font.GothamMedium btn.TextSize = 10 btn.TextColor3 = (cat == MailUI.SelectedCategory) and THEME.TextMain or THEME.TextSub btn.Parent = catScroll
		Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

		btn.MouseButton1Click:Connect(function()
			MailUI.SelectedCategory = cat
			MailUI.SelectedItemKey = nil
			renderCategoryPills()
		end)
	end
	catScroll.CanvasSize = UDim2.fromOffset(#CATEGORIES * 86, 0)
end
renderCategoryPills()

-- Item Picker Card (Big Clickable Action Card)
local itemPickerCard = Instance.new("Frame")
itemPickerCard.Size = UDim2.new(0.72, 0, 0, 36) itemPickerCard.Position = UDim2.fromOffset(0, 74) itemPickerCard.BackgroundColor3 = THEME.CardBg itemPickerCard.Parent = mailContainer
Instance.new("UICorner", itemPickerCard).CornerRadius = UDim.new(0, 7)
local itemCardStroke = Instance.new("UIStroke") itemCardStroke.Color = THEME.Stroke itemCardStroke.Parent = itemPickerCard

local itemBtnText = Instance.new("TextButton")
itemBtnText.Size = UDim2.new(1, -20, 1, 0) itemBtnText.Position = UDim2.fromOffset(10, 0) itemBtnText.BackgroundTransparency = 1
itemBtnText.Font = Enum.Font.GothamMedium itemBtnText.TextSize = 10 itemBtnText.TextColor3 = THEME.TextSub itemBtnText.Text = "Click to select item from inventory..."
itemBtnText.TextXAlignment = Enum.TextXAlignment.Left itemBtnText.Parent = itemPickerCard

local addCartBtn = Instance.new("TextButton")
addCartBtn.Size = UDim2.new(0.25, 0, 0, 36) addCartBtn.Position = UDim2.new(0.75, 0, 0, 74) addCartBtn.BackgroundColor3 = THEME.Accent
addCartBtn.Font = Enum.Font.GothamBold addCartBtn.TextSize = 11 addCartBtn.TextColor3 = Color3.fromRGB(255, 255, 255) addCartBtn.Text = "+ Add Cart" addCartBtn.Parent = mailContainer
Instance.new("UICorner", addCartBtn).CornerRadius = UDim.new(0, 7)

-- Item Picker Dropdown Modal Overlay
local itemDropdownFrame = Instance.new("ScrollingFrame")
itemDropdownFrame.Size = UDim2.new(1, 0, 0, 110) itemDropdownFrame.Position = UDim2.fromOffset(0, 116) itemDropdownFrame.BackgroundColor3 = THEME.HeaderBg
itemDropdownFrame.BorderSizePixel = 0 itemDropdownFrame.CanvasSize = UDim2.fromOffset(0, 0) itemDropdownFrame.ScrollBarThickness = 3
itemDropdownFrame.Visible = false itemDropdownFrame.ZIndex = 30 itemDropdownFrame.Parent = mailContainer
Instance.new("UICorner", itemDropdownFrame).CornerRadius = UDim.new(0, 8)
local dropStroke = Instance.new("UIStroke") dropStroke.Color = THEME.StrokeFocus dropStroke.Thickness = 1.5 dropStroke.Parent = itemDropdownFrame
local dropList = Instance.new("UIListLayout") dropList.Padding = UDim.new(0, 4) dropList.Parent = itemDropdownFrame
local dropPad = Instance.new("UIPadding") dropPad.PaddingTop = UDim.new(0, 4) dropPad.PaddingLeft = UDim.new(0, 4) dropPad.Parent = itemDropdownFrame

local function populateItemDropdown()
	for _, child in ipairs(itemDropdownFrame:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
	local items = listCategoryItems(MailUI.SelectedCategory)
	if #items == 0 then
		itemBtnText.Text = "No items in category: " .. MailUI.SelectedCategory
		itemBtnText.TextColor3 = Color3.fromRGB(239, 68, 68)
		return
	end

	for _, item in ipairs(items) do
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(0.96, 0, 0, 26) row.BackgroundColor3 = THEME.CardBg row.Text = "" row.ZIndex = 31 row.Parent = itemDropdownFrame
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.65, 0, 1, 0) nameLbl.Position = UDim2.fromOffset(8, 0) nameLbl.BackgroundTransparency = 1
		nameLbl.Text = item.displayName nameLbl.Font = Enum.Font.GothamMedium nameLbl.TextSize = 10 nameLbl.TextColor3 = THEME.TextMain
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left nameLbl.ZIndex = 32 nameLbl.Parent = row

		local countBadge = Instance.new("TextLabel")
		countBadge.Size = UDim2.new(0.28, 0, 0, 18) countBadge.Position = UDim2.new(0.7, 0, 0.5, -9) countBadge.BackgroundColor3 = THEME.HeaderBg
		countBadge.Text = "Stock: " .. item.count countBadge.Font = Enum.Font.GothamBold countBadge.TextSize = 9 countBadge.TextColor3 = THEME.Accent
		countBadge.ZIndex = 32 countBadge.Parent = row
		Instance.new("UICorner", countBadge).CornerRadius = UDim.new(0, 4)

		row.MouseButton1Click:Connect(function()
			MailUI.SelectedItemKey = item.itemKey
			itemBtnText.Text = item.displayName .. " (Stock: " .. item.count .. ")"
			itemBtnText.TextColor3 = THEME.TextMain
			itemDropdownFrame.Visible = false
		end)
	end
	itemDropdownFrame.CanvasSize = UDim2.fromOffset(0, #items * 30)
end

itemBtnText.MouseButton1Click:Connect(function()
	itemDropdownFrame.Visible = not itemDropdownFrame.Visible
	if itemDropdownFrame.Visible then populateItemDropdown() end
end)

-- Cart UI Scrolling Box
local cartFrame = Instance.new("ScrollingFrame")
cartFrame.Size = UDim2.new(1, 0, 0, 90) cartFrame.Position = UDim2.fromOffset(0, 118) cartFrame.BackgroundColor3 = THEME.CardBg
cartFrame.BorderSizePixel = 0 cartFrame.CanvasSize = UDim2.fromOffset(0, 0) cartFrame.ScrollBarThickness = 3 cartFrame.Parent = mailContainer
Instance.new("UICorner", cartFrame).CornerRadius = UDim.new(0, 8)
local cartFrameStroke = Instance.new("UIStroke") cartFrameStroke.Color = THEME.Stroke cartFrameStroke.Parent = cartFrame

local cartList = Instance.new("UIListLayout") cartList.Padding = UDim.new(0, 4) cartList.Parent = cartFrame
local cartPadIn = Instance.new("UIPadding") cartPadIn.PaddingTop = UDim.new(0, 6) cartPadIn.PaddingLeft = UDim.new(0, 6) cartPadIn.Parent = cartFrame

local function refreshCartUI()
	for _, child in ipairs(cartFrame:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
	for idx, entry in ipairs(MailUI.Cart) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(0.96, 0, 0, 26) row.BackgroundColor3 = THEME.HeaderBg row.Parent = cartFrame
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.55, 0, 1, 0) nameLbl.Position = UDim2.fromOffset(8, 0) nameLbl.BackgroundTransparency = 1
		nameLbl.Text = entry.itemKey .. " [" .. entry.category .. "]" nameLbl.Font = Enum.Font.GothamMedium nameLbl.TextSize = 9
		nameLbl.TextColor3 = THEME.TextMain nameLbl.TextXAlignment = Enum.TextXAlignment.Left nameLbl.Parent = row

		local countBox = Instance.new("TextBox")
		countBox.Size = UDim2.fromOffset(40, 18) countBox.Position = UDim2.new(1, -70, 0.5, -9)
		countBox.BackgroundColor3 = THEME.CardBg countBox.Text = tostring(entry.sendCount) countBox.Font = Enum.Font.GothamBold
		countBox.TextSize = 10 countBox.TextColor3 = THEME.Accent countBox.Parent = row
		Instance.new("UICorner", countBox).CornerRadius = UDim.new(0, 4)

		-- Strict Stock Clamping Logic
		countBox.FocusLost:Connect(function()
			local num = tonumber(countBox.Text) or 1
			entry.sendCount = math.clamp(math.floor(num), 1, math.max(1, entry.maxAvailable))
			countBox.Text = tostring(entry.sendCount)
		end)

		local delBtn = Instance.new("TextButton")
		delBtn.Size = UDim2.fromOffset(20, 18) delBtn.Position = UDim2.new(1, -24, 0.5, -9)
		delBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68) delBtn.Text = "✕" delBtn.Font = Enum.Font.GothamBold
		delBtn.TextSize = 9 delBtn.TextColor3 = Color3.fromRGB(255, 255, 255) delBtn.Parent = row
		Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 4)

		delBtn.MouseButton1Click:Connect(function() table.remove(MailUI.Cart, idx) refreshCartUI() end)
	end
	cartFrame.CanvasSize = UDim2.fromOffset(0, #MailUI.Cart * 30)
end

addCartBtn.MouseButton1Click:Connect(function()
	if not MailUI.SelectedItemKey then return end
	local available = getAvailableCount(MailUI.SelectedCategory, MailUI.SelectedItemKey)
	if available <= 0 then return end

	for _, entry in ipairs(MailUI.Cart) do
		if entry.category == MailUI.SelectedCategory and entry.itemKey == MailUI.SelectedItemKey then
			entry.sendCount = math.clamp(entry.sendCount + 1, 1, available)
			refreshCartUI()
			return
		end
	end
	table.insert(MailUI.Cart, { category = MailUI.SelectedCategory, itemKey = MailUI.SelectedItemKey, sendCount = 1, maxAvailable = available })
	refreshCartUI()
end)

-- Status Badge & Action Send Button
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 16) statusLabel.Position = UDim2.fromOffset(0, 214) statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium statusLabel.TextSize = 9 statusLabel.TextColor3 = THEME.TextSub statusLabel.Text = "Cart Ready (0 Items)" statusLabel.TextXAlignment = Enum.TextXAlignment.Left statusLabel.Parent = mailContainer

local sendBtn = Instance.new("TextButton")
sendBtn.Size = UDim2.new(1, 0, 0, 32) sendBtn.Position = UDim2.fromOffset(0, 234) sendBtn.BackgroundColor3 = THEME.Accent
sendBtn.Font = Enum.Font.GothamBold sendBtn.TextSize = 11 sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255) sendBtn.Text = "SEND GIFTS" sendBtn.Parent = mailContainer
Instance.new("UICorner", sendBtn).CornerRadius = UDim.new(0, 8)

sendBtn.MouseButton1Click:Connect(function()
	if MailUI.Sending then return end
	local recipient = recipientBox.Text
	if recipient == "" or #MailUI.Cart == 0 then return end

	MailUI.Sending = true sendBtn.Text = "SENDING..." sendBtn.BackgroundColor3 = THEME.Stroke
	task.spawn(function()
		local userId, lookupErr = lookupUser(recipient)
		if not userId then
			statusLabel.Text = "Error: " .. (lookupErr or "Lookup failed")
			MailUI.Sending = false sendBtn.Text = "SEND GIFTS" sendBtn.BackgroundColor3 = THEME.Accent
			return
		end

		local allLines = {}
		for _, row in ipairs(MailUI.Cart) do
			local lines, err = buildLinesForEntry(row.category, row.itemKey, row.sendCount)
			if not lines then
				statusLabel.Text = "Error: " .. (err or "Build lines failed")
				MailUI.Sending = false sendBtn.Text = "SEND GIFTS" sendBtn.BackgroundColor3 = THEME.Accent
				return
			end
			for _, line in ipairs(lines) do table.insert(allLines, line) end
		end

		local mails = packPayloadLines(allLines)
		statusLabel.Text = string.format("Delivering %d items in %d mails...", #allLines, #mails)

		for i, payload in ipairs(mails) do
			if i > 1 then task.wait(MailCfg.sendCooldownSec) end
			local ok, err = remoteCall(Networking.Mailbox.SendBatch, userId, payload, MailCfg.note)
			if not ok then
				statusLabel.Text = "Error: " .. tostring(err)
				MailUI.Sending = false sendBtn.Text = "SEND GIFTS" sendBtn.BackgroundColor3 = THEME.Accent
				return
			end
		end

		statusLabel.Text = "Gifts successfully delivered to " .. recipient .. "!"
		table.clear(MailUI.Cart)
		refreshCartUI()
		MailUI.Sending = false sendBtn.Text = "SEND GIFTS" sendBtn.BackgroundColor3 = THEME.Accent
	end)
end)

-- =============================================================================
-- PERFORMANCE CONTROLLER
-- =============================================================================

local currentFps = 60
RunService.Heartbeat:Connect(function(dt)
	currentFps = currentFps * 0.9 + (1 / dt) * 0.1
	FpsText.Text = string.format("%d FPS", math.floor(currentFps))
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightControl then ScreenGui.Enabled = not ScreenGui.Enabled end
end)

print("[Garden Suite Pro V3.0]: Ultra-Premium UI Loaded.")
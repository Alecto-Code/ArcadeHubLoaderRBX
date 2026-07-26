--[[
    =============================================================================
    ArcadeHUB — V1.0 (CUSTOM NAPOLEON / ARCADE UI STYLE)
    Design: Dark Modern, Sidebar Search, Left-Indicator Active Tabs, Player Profile Card
    Engine: Preserved Replica Reader, Flex Remote Handler, Stock Clamping, Automations
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

-- // Clean Previous Instances (Kill Old Panel) // --
local parentGui = getGuiParent()
local oldGui = parentGui:FindFirstChild("ArcadeHUB_GUI")
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
	note = "Sent via ArcadeHUB",
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
-- ARCADEHUB UI DESIGN ENGINE (NAPOLEON REFERENCE EXACT REPLICATION)
-- =============================================================================

local THEME = {
	WindowBg    = Color3.fromRGB(10, 12, 17),
	HeaderBg    = Color3.fromRGB(13, 15, 22),
	SidebarBg   = Color3.fromRGB(12, 14, 20),
	CardBg      = Color3.fromRGB(18, 22, 30),
	CardHover   = Color3.fromRGB(24, 29, 40),
	Stroke      = Color3.fromRGB(30, 36, 50),
	StrokeFocus = Color3.fromRGB(124, 58, 237),
	AccentPurple= Color3.fromRGB(124, 58, 237), -- Electric Purple
	AccentGreen = Color3.fromRGB(16, 185, 129),
	TextMain    = Color3.fromRGB(243, 244, 246),
	TextSub     = Color3.fromRGB(156, 163, 175),
	TextMuted   = Color3.fromRGB(107, 114, 128),
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ArcadeHUB_GUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parentGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.fromOffset(520, 350)
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -175)
MainFrame.BackgroundColor3 = THEME.WindowBg
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local MainStroke = Instance.new("UIStroke") MainStroke.Color = THEME.AccentPurple MainStroke.Thickness = 1.2 MainStroke.Parent = MainFrame

-- Header Bar
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 38)
Header.BackgroundColor3 = THEME.HeaderBg
Header.BorderSizePixel = 0
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local TitleLogo = Instance.new("TextLabel")
TitleLogo.Size = UDim2.new(0.5, 0, 1, 0) TitleLogo.Position = UDim2.fromOffset(16, 0) TitleLogo.BackgroundTransparency = 1
TitleLogo.Text = "ArcadeHUB" TitleLogo.Font = Enum.Font.GothamBold TitleLogo.TextSize = 14
TitleLogo.TextColor3 = THEME.AccentPurple TitleLogo.TextXAlignment = Enum.TextXAlignment.Left TitleLogo.Parent = Header

-- Window Controls (Top Right: _, [], X)
local windowControls = Instance.new("Frame")
windowControls.Size = UDim2.fromOffset(80, 26) windowControls.Position = UDim2.new(1, -86, 0.5, -13) windowControls.BackgroundTransparency = 1 windowControls.Parent = Header

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(24, 24) minBtn.Position = UDim2.fromOffset(0, 1) minBtn.BackgroundTransparency = 1
minBtn.Text = "—" minBtn.Font = Enum.Font.GothamBold minBtn.TextSize = 11 minBtn.TextColor3 = THEME.TextSub minBtn.Parent = windowControls

local maxBtn = Instance.new("TextButton")
maxBtn.Size = UDim2.fromOffset(24, 24) maxBtn.Position = UDim2.fromOffset(26, 1) maxBtn.BackgroundTransparency = 1
maxBtn.Text = "⛶" maxBtn.Font = Enum.Font.GothamBold maxBtn.TextSize = 11 maxBtn.TextColor3 = THEME.TextSub maxBtn.Parent = windowControls

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(24, 24) closeBtn.Position = UDim2.fromOffset(52, 1) closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕" closeBtn.Font = Enum.Font.GothamBold closeBtn.TextSize = 12 closeBtn.TextColor3 = THEME.TextSub closeBtn.Parent = windowControls

closeBtn.MouseEnter:Connect(function() closeBtn.TextColor3 = Color3.fromRGB(239, 68, 68) end)
closeBtn.MouseLeave:Connect(function() closeBtn.TextColor3 = THEME.TextSub end)
closeBtn.MouseButton1Click:Connect(function() ScreenGui.Enabled = false end)

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

-- Main Body Workspace
local Body = Instance.new("Frame")
Body.Size = UDim2.new(1, 0, 1, -38) Body.Position = UDim2.fromOffset(0, 38) Body.BackgroundTransparency = 1 Body.Parent = MainFrame

-- Left Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 135, 1, 0) Sidebar.BackgroundColor3 = THEME.SidebarBg Sidebar.BorderSizePixel = 0 Sidebar.Parent = Body

-- Sidebar Search Bar
local searchCard = Instance.new("Frame")
searchCard.Size = UDim2.new(0.88, 0, 0, 26) searchCard.Position = UDim2.fromOffset(8, 8) searchCard.BackgroundColor3 = THEME.CardBg searchCard.Parent = Sidebar
Instance.new("UICorner", searchCard).CornerRadius = UDim.new(0, 6)
local searchStroke = Instance.new("UIStroke") searchStroke.Color = THEME.Stroke searchStroke.Parent = searchCard

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -12, 1, 0) searchBox.Position = UDim2.fromOffset(6, 0) searchBox.BackgroundTransparency = 1
searchBox.Font = Enum.Font.Gotham searchBox.TextSize = 10 searchBox.TextColor3 = THEME.TextMain
searchBox.PlaceholderText = "🔍 Search..." searchBox.PlaceholderColor3 = THEME.TextMuted searchBox.Text = "" searchBox.Parent = searchCard

-- Sidebar Tab Container
local tabScroll = Instance.new("ScrollingFrame")
tabScroll.Size = UDim2.new(1, 0, 1, -85) tabScroll.Position = UDim2.fromOffset(0, 42) tabScroll.BackgroundTransparency = 1 tabScroll.BorderSizePixel = 0
tabScroll.ScrollBarThickness = 0 tabScroll.CanvasSize = UDim2.fromOffset(0, 0) tabScroll.Parent = Sidebar

local tabList = Instance.new("UIListLayout") tabList.Padding = UDim.new(0, 4) tabList.HorizontalAlignment = Enum.HorizontalAlignment.Center tabList.Parent = tabScroll
local tabPad = Instance.new("UIPadding") tabPad.PaddingTop = UDim.new(0, 4) tabPad.Parent = tabScroll

-- Bottom Profile Card (Reference Matching Avatar + Username)
local profileCard = Instance.new("Frame")
profileCard.Size = UDim2.new(0.9, 0, 0, 32) profileCard.Position = UDim2.new(0.05, 0, 1, -38) profileCard.BackgroundColor3 = THEME.CardBg profileCard.Parent = Sidebar
Instance.new("UICorner", profileCard).CornerRadius = UDim.new(0, 6)
local profStroke = Instance.new("UIStroke") profStroke.Color = THEME.Stroke profStroke.Parent = profileCard

local avatarImg = Instance.new("ImageLabel")
avatarImg.Size = UDim2.fromOffset(24, 24) avatarImg.Position = UDim2.fromOffset(4, 4) avatarImg.BackgroundColor3 = THEME.HeaderBg
avatarImg.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", LocalPlayer.UserId) avatarImg.Parent = profileCard
Instance.new("UICorner", avatarImg).CornerRadius = UDim.new(1, 0)

local usernameLabel = Instance.new("TextLabel")
usernameLabel.Size = UDim2.new(1, -34, 1, 0) usernameLabel.Position = UDim2.fromOffset(32, 0) usernameLabel.BackgroundTransparency = 1
usernameLabel.Text = LocalPlayer.Name usernameLabel.Font = Enum.Font.GothamBold usernameLabel.TextSize = 9 usernameLabel.TextColor3 = THEME.TextMain
usernameLabel.TextXAlignment = Enum.TextXAlignment.Left usernameLabel.TextTruncate = Enum.TextTruncate.AtEnd usernameLabel.Parent = profileCard

-- Right Main Content Workspace
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -135, 1, 0) ContentArea.Position = UDim2.fromOffset(135, 0) ContentArea.BackgroundTransparency = 1 ContentArea.Parent = Body

-- Breadcrumb Sub-Header (Reference Matching)
local breadcrumbLabel = Instance.new("TextLabel")
breadcrumbLabel.Size = UDim2.new(1, -20, 0, 20) breadcrumbLabel.Position = UDim2.fromOffset(12, 6) breadcrumbLabel.BackgroundTransparency = 1
breadcrumbLabel.Text = "ArcadeHUB — Grow a Garden" breadcrumbLabel.Font = Enum.Font.GothamBold breadcrumbLabel.TextSize = 11
breadcrumbLabel.TextColor3 = THEME.AccentPurple breadcrumbLabel.TextXAlignment = Enum.TextXAlignment.Left breadcrumbLabel.Parent = ContentArea

-- Tabs Navigation System with Glowing Left Bar (Reference Matching `| Info`)
local Tabs, TabButtons, activeTab = {}, {}, nil

local function createTab(tabName: string): Frame
	local tabBtn = Instance.new("TextButton")
	tabBtn.Size = UDim2.new(0, 120, 0, 30) tabBtn.BackgroundColor3 = THEME.CardBg tabBtn.BackgroundTransparency = 1
	tabBtn.Text = "  " .. tabName tabBtn.Font = Enum.Font.GothamMedium tabBtn.TextSize = 11 tabBtn.TextColor3 = THEME.TextSub
	tabBtn.TextXAlignment = Enum.TextXAlignment.Left tabBtn.BorderSizePixel = 0 tabBtn.Parent = tabScroll

	local activeIndicator = Instance.new("Frame")
	activeIndicator.Name = "Indicator" activeIndicator.Size = UDim2.fromOffset(3, 18) activeIndicator.Position = UDim2.fromOffset(2, 6)
	activeIndicator.BackgroundColor3 = THEME.AccentPurple activeIndicator.Visible = false activeIndicator.Parent = tabBtn
	Instance.new("UICorner", activeIndicator).CornerRadius = UDim.new(1, 0)

	local tabContent = Instance.new("Frame")
	tabContent.Name = "Content_" .. tabName tabContent.Size = UDim2.new(1, 0, 1, -26) tabContent.Position = UDim2.fromOffset(0, 26)
	tabContent.BackgroundTransparency = 1 tabContent.Visible = false tabContent.Parent = ContentArea

	tabBtn.MouseButton1Click:Connect(function()
		for name, content in pairs(Tabs) do content.Visible = (name == tabName) end
		for name, button in pairs(TabButtons) do
			local ind = button:FindFirstChild("Indicator")
			if name == tabName then
				button.BackgroundTransparency = 0.5 button.TextColor3 = THEME.TextMain
				if ind then ind.Visible = true end
			else
				button.BackgroundTransparency = 1 button.TextColor3 = THEME.TextSub
				if ind then ind.Visible = false end
			end
		end
	end)

	Tabs[tabName] = tabContent
	TabButtons[tabName] = tabBtn

	if not activeTab then
		activeTab = tabName tabContent.Visible = true
		tabBtn.BackgroundTransparency = 0.5 tabBtn.TextColor3 = THEME.TextMain
		activeIndicator.Visible = true
	end
	return tabContent
end

local function addToggleCard(tabContainer: Instance, title: string, desc: string, defaultState: boolean, callback: (boolean) -> ())
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 360, 0, 48) card.BackgroundColor3 = THEME.CardBg card.BorderSizePixel = 0 card.Parent = tabContainer
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 7)
	local stroke = Instance.new("UIStroke") stroke.Color = THEME.Stroke stroke.Thickness = 1 stroke.Parent = card

	local cardTitle = Instance.new("TextLabel")
	cardTitle.Size = UDim2.new(0.7, 0, 0, 20) cardTitle.Position = UDim2.fromOffset(12, 6) cardTitle.BackgroundTransparency = 1
	cardTitle.Text = title cardTitle.Font = Enum.Font.GothamBold cardTitle.TextSize = 11 cardTitle.TextColor3 = THEME.TextMain cardTitle.TextXAlignment = Enum.TextXAlignment.Left cardTitle.Parent = card

	local cardDesc = Instance.new("TextLabel")
	cardDesc.Size = UDim2.new(0.7, 0, 0, 14) cardDesc.Position = UDim2.fromOffset(12, 26) cardDesc.BackgroundTransparency = 1
	cardDesc.Text = desc cardDesc.Font = Enum.Font.Gotham cardDesc.TextSize = 9 cardDesc.TextColor3 = THEME.TextSub cardDesc.TextXAlignment = Enum.TextXAlignment.Left cardDesc.Parent = card

	local switchBtn = Instance.new("TextButton")
	switchBtn.Size = UDim2.fromOffset(40, 20) switchBtn.Position = UDim2.new(1, -52, 0.5, -10)
	switchBtn.BackgroundColor3 = defaultState and THEME.AccentPurple or THEME.Stroke switchBtn.Text = "" switchBtn.BorderSizePixel = 0 switchBtn.Parent = card
	Instance.new("UICorner", switchBtn).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(14, 14) knob.Position = defaultState and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255) knob.BorderSizePixel = 0 knob.Parent = switchBtn
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local currentState = defaultState
	switchBtn.MouseButton1Click:Connect(function()
		currentState = not currentState
		local targetPos = currentState and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)
		local targetColor = currentState and THEME.AccentPurple or THEME.Stroke
		TweenService:Create(knob, TweenInfo.new(0.15), { Position = targetPos }):Play()
		TweenService:Create(switchBtn, TweenInfo.new(0.15), { BackgroundColor3 = targetColor }):Play()
		callback(currentState)
	end)
end

-- Creating Navigation Tabs
local infoTabContent   = createTab("Info")
local mainTabContent   = createTab("Main")
local mailTabContent   = createTab("Mail Tool")
local visualTabContent = createTab("Visuals")
local miscTabContent   = createTab("Misc")

local function createScrollLayout(parentTab: Frame): ScrollingFrame
	local scroller = Instance.new("ScrollingFrame")
	scroller.Size = UDim2.new(1, 0, 1, 0) scroller.BackgroundTransparency = 1 scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 3 scroller.ScrollBarImageColor3 = THEME.Stroke scroller.Parent = parentTab
	local list = Instance.new("UIListLayout") list.Padding = UDim.new(0, 8) list.HorizontalAlignment = Enum.HorizontalAlignment.Center list.Parent = scroller
	local pad = Instance.new("UIPadding") pad.PaddingTop = UDim.new(0, 10) pad.PaddingBottom = UDim.new(0, 10) pad.Parent = scroller
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() scroller.CanvasSize = UDim2.fromOffset(0, list.AbsoluteContentSize.Y + 20) end)
	return scroller
end

-- Info Tab Section (Reference Matching `?? Script Info` Card)
local infoScroll = createScrollLayout(infoTabContent)
local infoCard = Instance.new("Frame")
infoCard.Size = UDim2.new(0, 360, 0, 110) infoCard.BackgroundColor3 = THEME.CardBg infoCard.Parent = infoScroll
Instance.new("UICorner", infoCard).CornerRadius = UDim.new(0, 7)
local infoStroke = Instance.new("UIStroke") infoStroke.Color = THEME.Stroke infoStroke.Parent = infoCard

local infoTitle = Instance.new("TextLabel")
infoTitle.Size = UDim2.new(1, -20, 0, 22) infoTitle.Position = UDim2.fromOffset(10, 6) infoTitle.BackgroundTransparency = 1
infoTitle.Text = "ℹ️ ArcadeHUB — Script Info" infoTitle.Font = Enum.Font.GothamBold infoTitle.TextSize = 11 infoTitle.TextColor3 = THEME.TextMain infoTitle.TextXAlignment = Enum.TextXAlignment.Left infoTitle.Parent = infoCard

local infoBody = Instance.new("TextLabel")
infoBody.Size = UDim2.new(1, -20, 0, 74) infoBody.Position = UDim2.fromOffset(10, 30) infoBody.BackgroundTransparency = 1
infoBody.Text = "Instant Interact: Bypass prompt hold duration.\nMail Tool: Complete multi-item gifting cart & batching.\nAnti-Lag & Clear Textures: Optimize FPS & performance."
infoBody.Font = Enum.Font.Gotham infoBody.TextSize = 9 infoBody.TextColor3 = THEME.TextSub infoBody.TextXAlignment = Enum.TextXAlignment.Left infoBody.TextYAlignment = Enum.TextYAlignment.Top infoBody.TextWrapped = true infoBody.Parent = infoCard

-- Main & Visuals Tabs
local mainScroll   = createScrollLayout(mainTabContent)
local visualScroll = createScrollLayout(visualTabContent)

addToggleCard(mainScroll, "Instant Interact", "Bypass hold duration prompt", State.InstantInteract, toggleInstantInteract)
addToggleCard(mainScroll, "Auto Spam E", "Simulate rapid E key press", State.AutoSpamE, function(s) State.AutoSpamE = s end)
addToggleCard(mainScroll, "Auto Drop Item", "Simulate rapid Backspace press", State.AutoDrop, function(s) State.AutoDrop = s end)

addToggleCard(visualScroll, "Anti-Lag Plants", "Hide plant meshes to save RAM", State.AntiLagPlants, toggleAntiLagPlants)
addToggleCard(visualScroll, "Clear Textures", "SmoothPlastic map & clear sky", State.ClearTextures, toggleClearTextures)

-- =============================================================================
-- REDESIGNED MAIL TOOL (CATEGORY DROPDOWN + INLINE QUANTITY INPUT)
-- =============================================================================

local MailUI = { SelectedCategory = "Pets", SelectedItemKey = nil, Cart = {}, Sending = false }

local mailContainer = Instance.new("Frame")
mailContainer.Size = UDim2.new(1, 0, 1, 0) mailContainer.BackgroundTransparency = 1 mailContainer.Parent = mailTabContent

local mailPad = Instance.new("UIPadding")
mailPad.PaddingLeft = UDim.new(0, 10) mailPad.PaddingRight = UDim.new(0, 10) mailPad.PaddingTop = UDim.new(0, 8) mailPad.Parent = mailContainer

-- 1. Recipient Input Card
local recCard = Instance.new("Frame")
recCard.Size = UDim2.new(1, 0, 0, 30) recCard.BackgroundColor3 = THEME.CardBg recCard.Parent = mailContainer
Instance.new("UICorner", recCard).CornerRadius = UDim.new(0, 6)
local recStroke = Instance.new("UIStroke") recStroke.Color = THEME.Stroke recStroke.Parent = recCard

local recipientBox = Instance.new("TextBox")
recipientBox.Size = UDim2.new(1, -20, 1, 0) recipientBox.Position = UDim2.fromOffset(10, 0) recipientBox.BackgroundTransparency = 1
recipientBox.Font = Enum.Font.GothamMedium recipientBox.TextSize = 10 recipientBox.TextColor3 = THEME.TextMain
recipientBox.PlaceholderText = "Recipient Roblox Username..." recipientBox.PlaceholderColor3 = THEME.TextMuted recipientBox.Text = "" recipientBox.Parent = recCard

recipientBox.Focused:Connect(function() TweenService:Create(recStroke, TweenInfo.new(0.2), { Color = THEME.StrokeFocus }):Play() end)
recipientBox.FocusLost:Connect(function() TweenService:Create(recStroke, TweenInfo.new(0.2), { Color = THEME.Stroke }):Play() end)

-- 2. Category Selector Dropdown Button
local catDropdownBtn = Instance.new("TextButton")
catDropdownBtn.Size = UDim2.new(1, 0, 0, 28) catDropdownBtn.Position = UDim2.fromOffset(0, 36) catDropdownBtn.BackgroundColor3 = THEME.CardBg
catDropdownBtn.Font = Enum.Font.GothamMedium catDropdownBtn.TextSize = 10 catDropdownBtn.TextColor3 = THEME.TextMain
catDropdownBtn.Text = "  Category: Pets  ▼" catDropdownBtn.TextXAlignment = Enum.TextXAlignment.Left catDropdownBtn.Parent = mailContainer
Instance.new("UICorner", catDropdownBtn).CornerRadius = UDim.new(0, 6)
local catStroke = Instance.new("UIStroke") catStroke.Color = THEME.Stroke catStroke.Parent = catDropdownBtn

-- Category Popup Modal
local catPopupFrame = Instance.new("ScrollingFrame")
catPopupFrame.Size = UDim2.new(1, 0, 0, 110) catPopupFrame.Position = UDim2.fromOffset(0, 68) catPopupFrame.BackgroundColor3 = THEME.HeaderBg
catPopupFrame.BorderSizePixel = 0 catPopupFrame.CanvasSize = UDim2.fromOffset(0, #CATEGORIES * 24) catPopupFrame.ScrollBarThickness = 3
catPopupFrame.Visible = false catPopupFrame.ZIndex = 40 catPopupFrame.Parent = mailContainer
Instance.new("UICorner", catPopupFrame).CornerRadius = UDim.new(0, 6)
local catPopStroke = Instance.new("UIStroke") catPopStroke.Color = THEME.StrokeFocus catPopStroke.Parent = catPopupFrame
local catPopList = Instance.new("UIListLayout") catPopList.Padding = UDim.new(0, 2) catPopList.Parent = catPopupFrame

for _, catName in ipairs(CATEGORIES) do
	local cBtn = Instance.new("TextButton")
	cBtn.Size = UDim2.new(0.96, 0, 0, 22) cBtn.BackgroundColor3 = THEME.CardBg cBtn.Text = "  " .. catName cBtn.Font = Enum.Font.GothamMedium
	cBtn.TextSize = 9 cBtn.TextColor3 = THEME.TextMain cBtn.TextXAlignment = Enum.TextXAlignment.Left cBtn.ZIndex = 41 cBtn.Parent = catPopupFrame
	Instance.new("UICorner", cBtn).CornerRadius = UDim.new(0, 4)

	cBtn.MouseButton1Click:Connect(function()
		MailUI.SelectedCategory = catName
		MailUI.SelectedItemKey = nil
		catDropdownBtn.Text = "  Category: " .. catName .. "  ▼"
		catPopupFrame.Visible = false
	end)
end

catDropdownBtn.MouseButton1Click:Connect(function() catPopupFrame.Visible = not catPopupFrame.Visible end)

-- 3. Item Picker Dropdown Button
local itemPickerBtn = Instance.new("TextButton")
itemPickerBtn.Size = UDim2.new(1, 0, 0, 28) itemPickerBtn.Position = UDim2.fromOffset(0, 70) itemPickerBtn.BackgroundColor3 = THEME.CardBg
itemPickerBtn.Font = Enum.Font.GothamMedium itemPickerBtn.TextSize = 10 itemPickerBtn.TextColor3 = THEME.TextSub
itemPickerBtn.Text = "  Select Item from Inventory...  ▼" itemPickerBtn.TextXAlignment = Enum.TextXAlignment.Left itemPickerBtn.Parent = mailContainer
Instance.new("UICorner", itemPickerBtn).CornerRadius = UDim.new(0, 6)
local itemStroke = Instance.new("UIStroke") itemStroke.Color = THEME.Stroke itemStroke.Parent = itemPickerBtn

-- Item Dropdown Modal Overlay
local itemPopupFrame = Instance.new("ScrollingFrame")
itemPopupFrame.Size = UDim2.new(1, 0, 0, 110) itemPopupFrame.Position = UDim2.fromOffset(0, 102) itemPopupFrame.BackgroundColor3 = THEME.HeaderBg
itemPopupFrame.BorderSizePixel = 0 itemPopupFrame.CanvasSize = UDim2.fromOffset(0, 0) itemPopupFrame.ScrollBarThickness = 3
itemPopupFrame.Visible = false itemPopupFrame.ZIndex = 30 itemPopupFrame.Parent = mailContainer
Instance.new("UICorner", itemPopupFrame).CornerRadius = UDim.new(0, 6)
local dropStroke = Instance.new("UIStroke") dropStroke.Color = THEME.StrokeFocus dropStroke.Thickness = 1.5 dropStroke.Parent = itemPopupFrame
local dropList = Instance.new("UIListLayout") dropList.Padding = UDim.new(0, 4) dropList.Parent = itemPopupFrame

local function populateItemDropdown()
	for _, child in ipairs(itemPopupFrame:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
	local items = listCategoryItems(MailUI.SelectedCategory)
	if #items == 0 then
		itemPickerBtn.Text = "  No items in category: " .. MailUI.SelectedCategory
		itemPickerBtn.TextColor3 = Color3.fromRGB(239, 68, 68)
		return
	end

	for _, item in ipairs(items) do
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(0.96, 0, 0, 24) row.BackgroundColor3 = THEME.CardBg row.Text = "" row.ZIndex = 31 row.Parent = itemPopupFrame
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.65, 0, 1, 0) nameLbl.Position = UDim2.fromOffset(8, 0) nameLbl.BackgroundTransparency = 1
		nameLbl.Text = item.displayName nameLbl.Font = Enum.Font.GothamMedium nameLbl.TextSize = 9 nameLbl.TextColor3 = THEME.TextMain
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left nameLbl.ZIndex = 32 nameLbl.Parent = row

		local countBadge = Instance.new("TextLabel")
		countBadge.Size = UDim2.new(0.28, 0, 0, 16) countBadge.Position = UDim2.new(0.7, 0, 0.5, -8) countBadge.BackgroundColor3 = THEME.HeaderBg
		countBadge.Text = "Stock: " .. item.count countBadge.Font = Enum.Font.GothamBold countBadge.TextSize = 8 countBadge.TextColor3 = THEME.AccentPurple
		countBadge.ZIndex = 32 countBadge.Parent = row
		Instance.new("UICorner", countBadge).CornerRadius = UDim.new(0, 4)

		row.MouseButton1Click:Connect(function()
			MailUI.SelectedItemKey = item.itemKey
			itemPickerBtn.Text = "  " .. item.displayName .. " (Stock: " .. item.count .. ")"
			itemPickerBtn.TextColor3 = THEME.TextMain
			itemPopupFrame.Visible = false
		end)
	end
	itemPopupFrame.CanvasSize = UDim2.fromOffset(0, #items * 28)
end

itemPickerBtn.MouseButton1Click:Connect(function()
	catPopupFrame.Visible = false
	itemPopupFrame.Visible = not itemPopupFrame.Visible
	if itemPopupFrame.Visible then populateItemDropdown() end
end)

-- 4. Quantity Input + Add to Cart Row
local addRow = Instance.new("Frame")
addRow.Size = UDim2.new(1, 0, 0, 28) addRow.Position = UDim2.fromOffset(0, 104) addRow.BackgroundTransparency = 1 addRow.Parent = mailContainer

local qtyInputBox = Instance.new("TextBox")
qtyInputBox.Size = UDim2.new(0.35, 0, 1, 0) qtyInputBox.BackgroundColor3 = THEME.CardBg qtyInputBox.BorderSizePixel = 0
qtyInputBox.Font = Enum.Font.GothamBold qtyInputBox.TextSize = 10 qtyInputBox.TextColor3 = THEME.AccentPurple
qtyInputBox.PlaceholderText = "Qty (Def: 1)" qtyInputBox.PlaceholderColor3 = THEME.TextMuted qtyInputBox.Text = "1" qtyInputBox.Parent = addRow
Instance.new("UICorner", qtyInputBox).CornerRadius = UDim.new(0, 6)
local qtyStroke = Instance.new("UIStroke") qtyStroke.Color = THEME.Stroke qtyStroke.Parent = qtyInputBox

local addCartBtn = Instance.new("TextButton")
addCartBtn.Size = UDim2.new(0.62, 0, 1, 0) addCartBtn.Position = UDim2.new(0.38, 0, 0, 0) addCartBtn.BackgroundColor3 = THEME.AccentPurple
addCartBtn.Font = Enum.Font.GothamBold addCartBtn.TextSize = 10 addCartBtn.TextColor3 = Color3.fromRGB(255, 255, 255) addCartBtn.Text = "+ Add to Cart" addCartBtn.Parent = addRow
Instance.new("UICorner", addCartBtn).CornerRadius = UDim.new(0, 6)

-- 5. Cart Table Frame
local cartFrame = Instance.new("ScrollingFrame")
cartFrame.Size = UDim2.new(1, 0, 0, 85) cartFrame.Position = UDim2.fromOffset(0, 138) cartFrame.BackgroundColor3 = THEME.CardBg
cartFrame.BorderSizePixel = 0 cartFrame.CanvasSize = UDim2.fromOffset(0, 0) cartFrame.ScrollBarThickness = 3 cartFrame.Parent = mailContainer
Instance.new("UICorner", cartFrame).CornerRadius = UDim.new(0, 6)
local cartFrameStroke = Instance.new("UIStroke") cartFrameStroke.Color = THEME.Stroke cartFrameStroke.Parent = cartFrame

local cartList = Instance.new("UIListLayout") cartList.Padding = UDim.new(0, 4) cartList.Parent = cartFrame
local cartPadIn = Instance.new("UIPadding") cartPadIn.PaddingTop = UDim.new(0, 4) cartPadIn.PaddingLeft = UDim.new(0, 4) cartPadIn.Parent = cartFrame

local function refreshCartUI()
	for _, child in ipairs(cartFrame:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
	for idx, entry in ipairs(MailUI.Cart) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(0.96, 0, 0, 24) row.BackgroundColor3 = THEME.HeaderBg row.Parent = cartFrame
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.55, 0, 1, 0) nameLbl.Position = UDim2.fromOffset(8, 0) nameLbl.BackgroundTransparency = 1
		nameLbl.Text = entry.itemKey .. " [" .. entry.category .. "]" nameLbl.Font = Enum.Font.GothamMedium nameLbl.TextSize = 9
		nameLbl.TextColor3 = THEME.TextMain nameLbl.TextXAlignment = Enum.TextXAlignment.Left nameLbl.Parent = row

		local countBox = Instance.new("TextBox")
		countBox.Size = UDim2.fromOffset(36, 16) countBox.Position = UDim2.new(1, -65, 0.5, -8)
		countBox.BackgroundColor3 = THEME.CardBg countBox.Text = tostring(entry.sendCount) countBox.Font = Enum.Font.GothamBold
		countBox.TextSize = 9 countBox.TextColor3 = THEME.AccentPurple countBox.Parent = row
		Instance.new("UICorner", countBox).CornerRadius = UDim.new(0, 4)

		countBox.FocusLost:Connect(function()
			local num = tonumber(countBox.Text) or 1
			entry.sendCount = math.clamp(math.floor(num), 1, math.max(1, entry.maxAvailable))
			countBox.Text = tostring(entry.sendCount)
		end)

		local delBtn = Instance.new("TextButton")
		delBtn.Size = UDim2.fromOffset(18, 16) delBtn.Position = UDim2.new(1, -22, 0.5, -8)
		delBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68) delBtn.Text = "✕" delBtn.Font = Enum.Font.GothamBold
		delBtn.TextSize = 8 delBtn.TextColor3 = Color3.fromRGB(255, 255, 255) delBtn.Parent = row
		Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 4)

		delBtn.MouseButton1Click:Connect(function() table.remove(MailUI.Cart, idx) refreshCartUI() end)
	end
	cartFrame.CanvasSize = UDim2.fromOffset(0, #MailUI.Cart * 28)
end

addCartBtn.MouseButton1Click:Connect(function()
	if not MailUI.SelectedItemKey then return end
	local available = getAvailableCount(MailUI.SelectedCategory, MailUI.SelectedItemKey)
	if available <= 0 then return end

	local userQty = tonumber(qtyInputBox.Text) or 1
	local clampedQty = math.clamp(math.floor(userQty), 1, available)

	for _, entry in ipairs(MailUI.Cart) do
		if entry.category == MailUI.SelectedCategory and entry.itemKey == MailUI.SelectedItemKey then
			entry.sendCount = math.clamp(entry.sendCount + clampedQty, 1, available)
			refreshCartUI()
			return
		end
	end

	table.insert(MailUI.Cart, {
		category = MailUI.SelectedCategory,
		itemKey = MailUI.SelectedItemKey,
		sendCount = clampedQty,
		maxAvailable = available
	})
	refreshCartUI()
end)

-- 6. Action Bar & Status Text
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 14) statusLabel.Position = UDim2.fromOffset(0, 228) statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium statusLabel.TextSize = 9 statusLabel.TextColor3 = THEME.TextSub statusLabel.Text = "Cart Ready (0 Items)" statusLabel.TextXAlignment = Enum.TextXAlignment.Left statusLabel.Parent = mailContainer

local sendBtn = Instance.new("TextButton")
sendBtn.Size = UDim2.new(1, 0, 0, 30) sendBtn.Position = UDim2.fromOffset(0, 244) sendBtn.BackgroundColor3 = THEME.AccentPurple
sendBtn.Font = Enum.Font.GothamBold sendBtn.TextSize = 11 sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255) sendBtn.Text = "SEND GIFTS" sendBtn.Parent = mailContainer
Instance.new("UICorner", sendBtn).CornerRadius = UDim.new(0, 6)

sendBtn.MouseButton1Click:Connect(function()
	if MailUI.Sending then return end
	local recipient = recipientBox.Text
	if recipient == "" or #MailUI.Cart == 0 then return end

	MailUI.Sending = true sendBtn.Text = "SENDING..." sendBtn.BackgroundColor3 = THEME.Stroke
	task.spawn(function()
		local userId, lookupErr = lookupUser(recipient)
		if not userId then
			statusLabel.Text = "Error: " .. (lookupErr or "Lookup failed")
			MailUI.Sending = false sendBtn.Text = "SEND GIFTS" sendBtn.BackgroundColor3 = THEME.AccentPurple
			return
		end

		local allLines = {}
		for _, row in ipairs(MailUI.Cart) do
			local lines, err = buildLinesForEntry(row.category, row.itemKey, row.sendCount)
			if not lines then
				statusLabel.Text = "Error: " .. (err or "Build lines failed")
				MailUI.Sending = false sendBtn.Text = "SEND GIFTS" sendBtn.BackgroundColor3 = THEME.AccentPurple
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
				MailUI.Sending = false sendBtn.Text = "SEND GIFTS" sendBtn.BackgroundColor3 = THEME.AccentPurple
				return
			end
		end

		statusLabel.Text = "Gifts successfully delivered to " .. recipient .. "!"
		table.clear(MailUI.Cart)
		refreshCartUI()
		MailUI.Sending = false sendBtn.Text = "SEND GIFTS" sendBtn.BackgroundColor3 = THEME.AccentPurple
	end)
end)

-- Search Filtering Logic for Sidebar Tabs
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	local query = string.lower(searchBox.Text)
	for name, button in pairs(TabButtons) do
		if query == "" or string.find(string.lower(name), query) then
			button.Visible = true
		else
			button.Visible = false
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightControl then ScreenGui.Enabled = not ScreenGui.Enabled end
end)

print("[ArcadeHUB V1.0]: Custom Reference Theme Loaded Successfully.")
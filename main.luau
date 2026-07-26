--[[
    =============================================================================
    ArcadeHUB — V5.0 (WIND UI ULTRA-MODERN EDITION)
    Framework: WindUI Library (Acrylic Glassmorphism & Spring Animations)
    Preserved Engine: Replica Reader, Flex Remote Handler, Stock Clamping, Automations
    =============================================================================
--]]

task.wait(0.3)

-- // Services // --
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService    = game:GetService("UserInputService")
local Players             = game:GetService("Players")
local CoreGui             = game:GetService("CoreGui")
local RunService          = game:GetService("RunService")
local Lighting            = game:GetService("Lighting")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- // Load WindUI Framework (With Fallback Mirror) // --
local WindUI
local loadOk, err = pcall(function()
	WindUI = loadstring(game:HttpGet("https://tree-hub.luau.site/windui/main.lua"))()
end)
if not loadOk or not WindUI then
	WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/FootGes/WindUI/main/dist/main.lua"))()
end

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
	note = "Sent via ArcadeHUB V5",
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
-- WIND UI WINDOW CREATION & THEME CONFIGURATION
-- =============================================================================

local Window = WindUI:CreateWindow({
	Title = "ArcadeHUB",
	Icon = "sparkles",
	Author = "Grow a Garden 2",
	Folder = "ArcadeHUB",
	Size = UDim2.fromOffset(540, 360),
	Transparent = true,
	Theme = "Dark",
})

-- Tab 1: Info Tab
local InfoTab = Window:Tab({ Title = "Info", Icon = "info" })
InfoTab:Section({ Title = "ArcadeHUB — Grow a Garden" })
InfoTab:Paragraph({
	Title = "Script Status & Features",
	Desc = "• Instant Interact: Bypass proximity prompt hold duration\n• Auto Spam E & Auto Drop: High-speed key automation\n• Mail Tool: Integrated multi-item gifting cart & Replica reader\n• Visual Optimizations: Anti-Lag Plants & Map Texture Cleaner",
})

-- Tab 2: Main Automations
local MainTab = Window:Tab({ Title = "Main", Icon = "zap" })
MainTab:Section({ Title = "Interactions & Inputs" })

MainTab:Toggle({
	Title = "Instant Interact",
	Desc = "Bypass hold duration on all ProximityPrompts",
	Value = false,
	Callback = function(val) toggleInstantInteract(val) end,
})

MainTab:Toggle({
	Title = "Auto Spam E",
	Desc = "Simulate rapid press on E key",
	Value = false,
	Callback = function(val) State.AutoSpamE = val end,
})

MainTab:Toggle({
	Title = "Auto Drop Item",
	Desc = "Simulate rapid press on Backspace",
	Value = false,
	Callback = function(val) State.AutoDrop = val end,
})

-- Tab 3: Mail Tool (Integrated Gifting System)
local MailTab = Window:Tab({ Title = "Mail Tool", Icon = "mail" })
MailTab:Section({ Title = "Multi-Item Gifting System" })

local MailState = {
	Recipient = "",
	SelectedCategory = "Pets",
	SelectedItemKey = nil,
	InputQty = 1,
	Cart = {},
	Sending = false,
}

MailTab:Input({
	Title = "Recipient Roblox Username",
	Desc = "Target player's username to deliver gifts",
	Value = "",
	Placeholder = "Username...",
	Callback = function(text) MailState.Recipient = text end,
})

local ItemDropdown = nil

local function getItemValues(cat: string)
	local list = listCategoryItems(cat)
	local values = {}
	if #list == 0 then return { "No items available" } end
	for _, item in ipairs(list) do
		table.insert(values, item.displayName .. " (Stock: " .. item.count .. ")")
	end
	return values
end

MailTab:Dropdown({
	Title = "Category",
	Desc = "Select item category from inventory",
	Values = CATEGORIES,
	Value = "Pets",
	Callback = function(option)
		MailState.SelectedCategory = option
		MailState.SelectedItemKey = nil
		if ItemDropdown then
			ItemDropdown:Refresh(getItemValues(option), "Select Item...")
		end
	end,
})

ItemDropdown = MailTab:Dropdown({
	Title = "Select Item from Inventory",
	Desc = "Pick the item you want to add to cart",
	Values = getItemValues("Pets"),
	Value = "Select Item...",
	Callback = function(option)
		if option and option ~= "No items available" and option ~= "Select Item..." then
			local key = string.match(option, "^(.-)%s*%(") or option
			MailState.SelectedItemKey = key
		end
	end,
})

MailTab:Input({
	Title = "Quantity to Send",
	Desc = "Amount of item to add (Default: 1)",
	Value = "1",
	Placeholder = "Quantity...",
	Callback = function(text)
		MailState.InputQty = tonumber(text) or 1
	end,
})

local CartParagraph = MailTab:Paragraph({
	Title = "Cart Summary (0 Items)",
	Desc = "Your gifting cart is empty.",
})

local function refreshCartSummary()
	if #MailState.Cart == 0 then
		CartParagraph:Set({ Title = "Cart Summary (0 Items)", Desc = "Your gifting cart is empty." })
		return
	end
	local text = ""
	for i, entry in ipairs(MailState.Cart) do
		text = text .. string.format("%d. %s [%s] x%d (Stock: %d)\n", i, entry.itemKey, entry.category, entry.sendCount, entry.maxAvailable)
	end
	CartParagraph:Set({ Title = string.format("Cart Summary (%d Types)", #MailState.Cart), Desc = text })
end

MailTab:Button({
	Title = "+ Add Selected Item to Cart",
	Desc = "Add item and quantity to cart",
	Callback = function()
		if not MailState.SelectedItemKey then
			WindUI:Notify({ Title = "Cart Error", Content = "Please pick a valid item from inventory dropdown first!", Duration = 3 })
			return
		end

		local available = getAvailableCount(MailState.SelectedCategory, MailState.SelectedItemKey)
		if available <= 0 then
			WindUI:Notify({ Title = "Stock Error", Content = "You have 0 stock for " .. MailState.SelectedItemKey, Duration = 3 })
			return
		end

		local clamped = math.clamp(math.floor(MailState.InputQty), 1, available)

		for _, entry in ipairs(MailState.Cart) do
			if entry.category == MailState.SelectedCategory and entry.itemKey == MailState.SelectedItemKey then
				entry.sendCount = math.clamp(entry.sendCount + clamped, 1, available)
				refreshCartSummary()
				WindUI:Notify({ Title = "Cart Updated", Content = entry.itemKey .. " quantity set to " .. entry.sendCount, Duration = 2 })
				return
			end
		end

		table.insert(MailState.Cart, {
			category = MailState.SelectedCategory,
			itemKey = MailState.SelectedItemKey,
			sendCount = clamped,
			maxAvailable = available
		})
		refreshCartSummary()
		WindUI:Notify({ Title = "Added to Cart", Content = MailState.SelectedItemKey .. " x" .. clamped .. " added!", Duration = 2 })
	end,
})

MailTab:Button({
	Title = "Clear Cart",
	Desc = "Remove all queued items from cart",
	Callback = function()
		table.clear(MailState.Cart)
		refreshCartSummary()
		WindUI:Notify({ Title = "Cart Cleared", Content = "All items removed.", Duration = 2 })
	end,
})

MailTab:Button({
	Title = "🚀 SEND GIFTS NOW",
	Desc = "Execute automated mail delivery",
	Callback = function()
		if MailState.Sending then return end
		if MailState.Recipient == "" then
			WindUI:Notify({ Title = "Recipient Error", Content = "Please enter a recipient username!", Duration = 3 })
			return
		end
		if #MailState.Cart == 0 then
			WindUI:Notify({ Title = "Cart Error", Content = "Cart is empty!", Duration = 3 })
			return
		end

		MailState.Sending = true
		WindUI:Notify({ Title = "Processing", Content = "Looking up " .. MailState.Recipient .. "...", Duration = 3 })

		task.spawn(function()
			local userId, lookupErr = lookupUser(MailState.Recipient)
			if not userId then
				WindUI:Notify({ Title = "Lookup Failed", Content = lookupErr or "User not found!", Duration = 4 })
				MailState.Sending = false
				return
			end

			local allLines = {}
			for _, row in ipairs(MailState.Cart) do
				local lines, err = buildLinesForEntry(row.category, row.itemKey, row.sendCount)
				if not lines then
					WindUI:Notify({ Title = "Build Error", Content = err or "Line build error", Duration = 4 })
					MailState.Sending = false
					return
				end
				for _, line in ipairs(lines) do table.insert(allLines, line) end
			end

			local mails = packPayloadLines(allLines)
			WindUI:Notify({ Title = "Delivering", Content = string.format("Sending %d mail batch(es)...", #mails), Duration = 4 })

			for i, payload in ipairs(mails) do
				if i > 1 then task.wait(MailCfg.sendCooldownSec) end
				local ok, sendErr = remoteCall(Networking.Mailbox.SendBatch, userId, payload, MailCfg.note)
				if not ok then
					WindUI:Notify({ Title = "Send Failed", Content = tostring(sendErr), Duration = 5 })
					MailState.Sending = false
					return
				end
			end

			WindUI:Notify({ Title = "Gifting Delivered!", Content = "Gifts successfully delivered to " .. MailState.Recipient, Duration = 5 })
			table.clear(MailState.Cart)
			refreshCartSummary()
			MailState.Sending = false
		end)
	end,
})

-- Tab 4: Visuals Tab
local VisualTab = Window:Tab({ Title = "Visuals", Icon = "eye" })
VisualTab:Section({ Title = "Performance & Map Adjustments" })

VisualTab:Toggle({
	Title = "Anti-Lag Plants",
	Desc = "Hide plant mesh sizes to save RAM and increase FPS",
	Value = false,
	Callback = function(val) toggleAntiLagPlants(val) end,
})

VisualTab:Toggle({
	Title = "Clear Map Textures",
	Desc = "Apply SmoothPlastic map and clear post-effects",
	Value = false,
	Callback = function(val) toggleClearTextures(val) end,
})

WindUI:Notify({
	Title = "ArcadeHUB V5.0",
	Content = "WindUI Glassmorphism Edition Loaded!",
	Duration = 4,
})

print("[ArcadeHUB V5.0]: WindUI Glassmorphism Edition Loaded Successfully.")
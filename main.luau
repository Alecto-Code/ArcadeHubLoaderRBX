--[[
    =============================================================================
    GARDEN SUITE PRO - V4.0 (RAYFIELD UI DARK THEME EDITION)
    Framework: Rayfield UI Library
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

-- // Safe Cleanup Protocol (Kill Old Instances) // --
local function destroyOldGui()
	local parentGuis = { CoreGui, LocalPlayer:FindFirstChild("PlayerGui") }
	for _, pGui in ipairs(parentGuis) do
		if pGui then
			for _, child in ipairs(pGui:GetChildren()) do
				if child.Name == "Rayfield" or child.Name == "GardenSuiteGUI_V3" or child.Name == "GardenSuiteGUI" then
					child:Destroy()
				end
			end
		end
	end
end
destroyOldGui()

-- // Load Rayfield Framework // --
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

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
	note = "Sent via Garden Suite Pro V4",
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
-- RAYFIELD UI INITIALIZATION (DARK THEME)
-- =============================================================================

local Window = Rayfield:CreateWindow({
	Name = "Garden Suite Pro V4.0",
	LoadingTitle = "Garden Suite Pro",
	LoadingSubtitle = "Rayfield Dark Theme",
	ConfigurationSaving = { Enabled = false },
	Discord = { Enabled = false },
	KeySystem = false,
})

-- Tab 1: Main Automations
local MainTab = Window:CreateTab("Main Automations", 4483362458)
MainTab:CreateSection("Key Pressers & Interactions")

MainTab:CreateToggle({
	Name = "Instant Interact",
	CurrentValue = false,
	Flag = "InstantInteract",
	Callback = function(Value) toggleInstantInteract(Value) end,
})

MainTab:CreateToggle({
	Name = "Auto Spam E",
	CurrentValue = false,
	Flag = "AutoSpamE",
	Callback = function(Value) State.AutoSpamE = Value end,
})

MainTab:CreateToggle({
	Name = "Auto Drop Item",
	CurrentValue = false,
	Flag = "AutoDrop",
	Callback = function(Value) State.AutoDrop = Value end,
})

-- Tab 2: Visual Optimizations
local VisualTab = Window:CreateTab("Visual Optimizations", 4483362458)
VisualTab:CreateSection("Performance Tweak")

VisualTab:CreateToggle({
	Name = "Anti-Lag Plants",
	CurrentValue = false,
	Flag = "AntiLagPlants",
	Callback = function(Value) toggleAntiLagPlants(Value) end,
})

VisualTab:CreateToggle({
	Name = "Clear Map Textures & Sky",
	CurrentValue = false,
	Flag = "ClearTextures",
	Callback = function(Value) toggleClearTextures(Value) end,
})

-- Tab 3: Mail Tool (Integrated Mailbox System)
local MailTab = Window:CreateTab("Mail Tool", 4483362458)
MailTab:CreateSection("Gifting Configuration")

local MailState = {
	Recipient = "",
	SelectedCategory = "Pets",
	SelectedItemKey = nil,
	InputQty = 1,
	Cart = {},
	Sending = false,
}

MailTab:CreateInput({
	Name = "Recipient Roblox Username",
	PlaceholderText = "Type username here...",
	RemoveTextAfterFocusLost = false,
	Callback = function(Text) MailState.Recipient = Text end,
})

local ItemDropdown = nil

local function getItemOptions(cat: string)
	local list = listCategoryItems(cat)
	local options = {}
	if #list == 0 then return { "No items in category" } end
	for _, item in ipairs(list) do
		table.insert(options, item.displayName .. " (Stock: " .. item.count .. ")")
	end
	return options
end

MailTab:CreateDropdown({
	Name = "Category",
	Options = CATEGORIES,
	CurrentOption = { "Pets" },
	MultipleOptions = false,
	Flag = "CategoryDropdown",
	Callback = function(Option)
		local cat = typeof(Option) == "table" and Option[1] or Option
		MailState.SelectedCategory = cat
		MailState.SelectedItemKey = nil
		if ItemDropdown then
			ItemDropdown:Refresh(getItemOptions(cat), true)
		end
	end,
})

ItemDropdown = MailTab:CreateDropdown({
	Name = "Select Item from Inventory",
	Options = getItemOptions("Pets"),
	CurrentOption = { "Select item..." },
	MultipleOptions = false,
	Flag = "ItemDropdown",
	Callback = function(Option)
		local rawText = typeof(Option) == "table" and Option[1] or Option
		local key = string.match(rawText, "^(.-)%s*%(") or rawText
		MailState.SelectedItemKey = key
	end,
})

MailTab:CreateInput({
	Name = "Quantity to Send",
	PlaceholderText = "Default: 1",
	RemoveTextAfterFocusLost = false,
	Callback = function(Text)
		MailState.InputQty = tonumber(Text) or 1
	end,
})

local CartParagraph = MailTab:CreateParagraph({ Title = "Cart Summary (0 Items)", Content = "No items in cart yet." })

local function updateCartParagraph()
	if #MailState.Cart == 0 then
		CartParagraph:Set({ Title = "Cart Summary (0 Items)", Content = "No items in cart yet." })
		return
	end
	local summaryText = ""
	for i, entry in ipairs(MailState.Cart) do
		summaryText = summaryText .. string.format("%d. %s [%s] x%d (Max Stock: %d)\n", i, entry.itemKey, entry.category, entry.sendCount, entry.maxAvailable)
	end
	CartParagraph:Set({ Title = string.format("Cart Summary (%d Item Types)", #MailState.Cart), Content = summaryText })
end

MailTab:CreateButton({
	Name = "+ Add Selected Item to Cart",
	Callback = function()
		if not MailState.SelectedItemKey or MailState.SelectedItemKey == "Select item..." or MailState.SelectedItemKey == "No items in category" then
			Rayfield:Notify({ Title = "Cart Error", Content = "Please pick a valid item from inventory dropdown first!", Duration = 3 })
			return
		end

		local available = getAvailableCount(MailState.SelectedCategory, MailState.SelectedItemKey)
		if available <= 0 then
			Rayfield:Notify({ Title = "Stock Error", Content = "You have 0 stock for " .. MailState.SelectedItemKey, Duration = 3 })
			return
		end

		local clamped = math.clamp(math.floor(MailState.InputQty), 1, available)

		for _, entry in ipairs(MailState.Cart) do
			if entry.category == MailState.SelectedCategory and entry.itemKey == MailState.SelectedItemKey then
				entry.sendCount = math.clamp(entry.sendCount + clamped, 1, available)
				updateCartParagraph()
				Rayfield:Notify({ Title = "Cart Updated", Content = entry.itemKey .. " quantity updated to " .. entry.sendCount, Duration = 2 })
				return
			end
		end

		table.insert(MailState.Cart, {
			category = MailState.SelectedCategory,
			itemKey = MailState.SelectedItemKey,
			sendCount = clamped,
			maxAvailable = available,
		})
		updateCartParagraph()
		Rayfield:Notify({ Title = "Added to Cart", Content = MailState.SelectedItemKey .. " x" .. clamped .. " added!", Duration = 2 })
	end,
})

MailTab:CreateButton({
	Name = "Clear Cart",
	Callback = function()
		table.clear(MailState.Cart)
		updateCartParagraph()
		Rayfield:Notify({ Title = "Cart Cleared", Content = "All items removed from cart.", Duration = 2 })
	end,
})

MailTab:CreateButton({
	Name = "🚀 SEND GIFTS NOW",
	Callback = function()
		if MailState.Sending then return end
		if MailState.Recipient == "" then
			Rayfield:Notify({ Title = "Recipient Error", Content = "Please enter a valid Roblox username!", Duration = 3 })
			return
		end
		if #MailState.Cart == 0 then
			Rayfield:Notify({ Title = "Cart Error", Content = "Your cart is empty!", Duration = 3 })
			return
		end

		MailState.Sending = true
		Rayfield:Notify({ Title = "Processing", Content = "Looking up player " .. MailState.Recipient .. "...", Duration = 3 })

		task.spawn(function()
			local userId, err = lookupUser(MailState.Recipient)
			if not userId then
				Rayfield:Notify({ Title = "Lookup Failed", Content = err or "User not found!", Duration = 4 })
				MailState.Sending = false
				return
			end

			local allLines = {}
			for _, row in ipairs(MailState.Cart) do
				local lines, lineErr = buildLinesForEntry(row.category, row.itemKey, row.sendCount)
				if not lines then
					Rayfield:Notify({ Title = "Build Error", Content = lineErr or "Item line error", Duration = 4 })
					MailState.Sending = false
					return
				end
				for _, line in ipairs(lines) do table.insert(allLines, line) end
			end

			local mails = packPayloadLines(allLines)
			Rayfield:Notify({ Title = "Sending Mails", Content = string.format("Sending %d mail batch(es)...", #mails), Duration = 4 })

			for i, payload in ipairs(mails) do
				if i > 1 then task.wait(MailCfg.sendCooldownSec) end
				local ok, sendErr = remoteCall(Networking.Mailbox.SendBatch, userId, payload, MailCfg.note)
				if not ok then
					Rayfield:Notify({ Title = "Send Failed", Content = tostring(sendErr), Duration = 5 })
					MailState.Sending = false
					return
				end
			end

			Rayfield:Notify({ Title = "Gifting Complete!", Content = "All gifts successfully delivered to " .. MailState.Recipient, Duration = 5 })
			table.clear(MailState.Cart)
			updateCartParagraph()
			MailState.Sending = false
		end)
	end,
})

Rayfield:Notify({
	Title = "Garden Suite Pro V4",
	Content = "Loaded with Rayfield Dark Theme!",
	Duration = 4,
})

print("[Garden Suite Pro V4.0]: Rayfield Dark Theme Loaded Successfully.")
--[[
    =============================================================================
    ARCADEHUB — VISUAL MODULE (Visual.lua)
    =============================================================================
    Handles Fruit Price Overlay, Backpack Badges, Map Textures, Sky & FPS Visuals.
    =============================================================================
--]]

local Lighting          = game:GetService("Lighting")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer or Players.PlayerAdded:Wait()

local Visual = {}

Visual.OriginalTextures = {}
Visual.OriginalLightingEffects = {}

local FruitValueCalc, SellValueData, SeedData
pcall(function()
	local sharedMod = ReplicatedStorage:FindFirstChild("SharedModules") or ReplicatedStorage:FindFirstChild("SharedData")
	if sharedMod then
		if sharedMod:FindFirstChild("FruitValueCalc") then FruitValueCalc = require(sharedMod.FruitValueCalc) end
		if sharedMod:FindFirstChild("SellValueData") then SellValueData = require(sharedMod.SellValueData) end
		if sharedMod:FindFirstChild("SeedData") then SeedData = require(sharedMod.SeedData) end
	end
end)

local ItemPriceCache = {} 
local WeightLookupMap = {} 
local TotalInventoryValue = 0

function Visual.cleanFruitName(fullName: string): string
	if not fullName then return "" end
	local clean = string.gsub(fullName, "%s*%[.-%]", "")
	clean = string.gsub(clean, "%s*%d+%.?%d*kg", "")
	clean = string.gsub(clean, "%s*[Ss]eed", "")
	clean = string.gsub(clean, "%s*[Pp]lant", "")
	return (string.gsub(clean, "^%s*(.-)%s*$", "%1"))
end

function Visual.formatShortPrice(n: number): string
	if n >= 1e12 then
		return string.format("$%.2fT", n / 1e12)
	elseif n >= 1e9 then
		return string.format("$%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("$%.2fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("$%.2fK", n / 1e3)
	else
		return string.format("$%.0f", n)
	end
end

function Visual.formatFullCommas(n: number): string
	local formatted = tostring(math.floor(n))
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if k == 0 then break end
	end
	return formatted
end

function Visual.getFruitBaseWeight(fruitName: string): number
	if SeedData then
		local cleanedTarget = Visual.cleanFruitName(fruitName)
		for _, seedInfo in pairs(SeedData) do
			if typeof(seedInfo) == "table" then
				local sName = seedInfo.SeedName or seedInfo.Name or seedInfo.FruitName
				if sName and Visual.cleanFruitName(tostring(sName)) == cleanedTarget then
					local bw = tonumber(seedInfo.BaseWeight or seedInfo.Weight)
					if bw and bw > 0 then return bw end
				end
			end
		end
	end
	return (fruitName == "Carrot" and 0.8) or (fruitName == "Bamboo" and 4.0) or (fruitName == "Dragon's Breath" and 7.5) or 10.0
end

function Visual.parseWeightFromName(name: string): number?
	local match = string.match(name, "(%d+%.?%d*)%s*kg")
	return tonumber(match)
end

function Visual.getExactFruitPrice(item: Instance): (number, string)
	local fruitName = item:GetAttribute("FruitName") or item:GetAttribute("Fruit") or Visual.cleanFruitName(item.Name)
	local weight    = tonumber(item:GetAttribute("Weight")) or Visual.parseWeightFromName(item.Name) or 1
	local mutName   = item:GetAttribute("Mutation") or item:GetAttribute("Variant")
	local decay     = tonumber(item:GetAttribute("DecayAlpha")) or 0

	local sizeMult  = tonumber(item:GetAttribute("SizeMultiplier"))
	if not sizeMult or sizeMult <= 0 then
		local baseWeight = Visual.getFruitBaseWeight(fruitName)
		sizeMult = weight / math.max(0.01, baseWeight)
	end

	if FruitValueCalc then
		local ok, nativePrice = pcall(function()
			return FruitValueCalc(fruitName, sizeMult, mutName, LocalPlayer, decay)
		end)
		if ok and typeof(nativePrice) == "number" then
			return nativePrice, Visual.formatShortPrice(nativePrice)
		end
	end

	local basePrice = (SellValueData and SellValueData[fruitName]) or 800
	local fallbackCalc = math.floor(basePrice * math.pow(sizeMult, 1.75))
	return fallbackCalc, Visual.formatShortPrice(fallbackCalc)
end

function Visual.syncAllHarvestedFruits()
	table.clear(ItemPriceCache)
	table.clear(WeightLookupMap)
	TotalInventoryValue = 0

	local containers = {}
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
	if backpack then table.insert(containers, backpack) end
	if LocalPlayer.Character then table.insert(containers, LocalPlayer.Character) end

	for _, container in ipairs(containers) do
		for _, item in ipairs(container:GetChildren()) do
			if item:GetAttribute("HarvestedFruit") == true then
				local weight = tonumber(item:GetAttribute("Weight")) or Visual.parseWeightFromName(item.Name) or 0

				if weight > 0 then
					local price, formatted = Visual.getExactFruitPrice(item)
					TotalInventoryValue += price

					local record = { price = price, formatted = formatted, weight = weight, item = item }
					ItemPriceCache[item] = record

					local weightKey = string.format("%.2fkg", weight)
					if not WeightLookupMap[weightKey] then
						WeightLookupMap[weightKey] = {}
					end
					table.insert(WeightLookupMap[weightKey], record)
				end
			end
		end
	end
end

function Visual.getPriceByUiText(rawKgText: string, slotIndex: number): string
	local cleanText = string.match(rawKgText, "%d+%.?%d*kg")
	if not cleanText then
		local num = tonumber(string.match(rawKgText, "(%d+%.?%d*)"))
		if num then cleanText = string.format("%.2fkg", num) end
	end

	if cleanText and WeightLookupMap[cleanText] and #WeightLookupMap[cleanText] > 0 then
		local list = WeightLookupMap[cleanText]
		local idx = ((slotIndex - 1) % #list) + 1
		return list[idx].formatted
	end

	return "$0"
end

function Visual.removePriceBadges()
	local backpackGui = LocalPlayer.PlayerGui:FindFirstChild("BackpackGui")
	if not backpackGui then return end

	for _, descendant in ipairs(backpackGui:GetDescendants()) do
		if descendant.Name == "ArcadePriceCenterBadge" or descendant.Name == "ArcadeTotalValueHeader" then
			descendant:Destroy()
		end
	end
end

function Visual.hideAllPriceBadges()
	local backpackGui = LocalPlayer.PlayerGui:FindFirstChild("BackpackGui")
	if not backpackGui then return end

	for _, descendant in ipairs(backpackGui:GetDescendants()) do
		if descendant.Name == "ArcadePriceCenterBadge" then
			descendant.Visible = false
		end
	end
end

function Visual.applyBadgeToSlot(slot: GuiObject, priceText: string, isHotbar: boolean)
	local badge = slot:FindFirstChild("ArcadePriceCenterBadge")
	if not badge then
		badge = Instance.new("Frame")
		badge.Name = "ArcadePriceCenterBadge"
		badge.Size = isHotbar and UDim2.new(0.9, 0, 0, 18) or UDim2.new(0.86, 0, 0, 22)
		badge.Position = isHotbar and UDim2.new(0.5, 0, 0.25, 0) or UDim2.new(0.5, 0, 0.48, 0)
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
		badge.BackgroundTransparency = 0.25
		badge.ZIndex = 150
		badge.Parent = slot

		Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 6)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(16, 185, 129)
		stroke.Thickness = 1
		stroke.Transparency = 0.3
		stroke.Parent = badge

		local label = Instance.new("TextLabel")
		label.Name = "PriceText"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = isHotbar and 10.5 or 12.5
		label.TextColor3 = Color3.fromRGB(52, 211, 153)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.ZIndex = 151
		label.Parent = badge
	end

	badge.Visible = true
	local lbl = badge:FindFirstChild("PriceText")
	if lbl and lbl.Text ~= priceText then
		lbl.Text = priceText
	end
end

function Visual.renderPriceOverlay(State, isScriptRunning)
	if not isScriptRunning or not State.FruitOverlay then
		Visual.removePriceBadges()
		return
	end

	Visual.hideAllPriceBadges()
	Visual.syncAllHarvestedFruits()

	local backpackGui = LocalPlayer.PlayerGui:FindFirstChild("BackpackGui")
	if not backpackGui then return end

	local inventoryFrame = backpackGui:FindFirstChild("Backpack")
		and backpackGui.Backpack:FindFirstChild("Inventory")
	if not inventoryFrame then return end

	inventoryFrame.ClipsDescendants = false

	-- 1. Render Header Total Value
	local headerLabel = inventoryFrame:FindFirstChild("ArcadeTotalValueHeader")
	if not headerLabel then
		headerLabel = Instance.new("TextLabel")
		headerLabel.Name = "ArcadeTotalValueHeader"
		headerLabel.Size = UDim2.new(0, 420, 0, 24)
		headerLabel.Position = UDim2.new(0, 10, 0, -28)
		headerLabel.BackgroundTransparency = 1
		headerLabel.Font = Enum.Font.GothamBold
		headerLabel.TextSize = 14
		headerLabel.TextColor3 = Color3.fromRGB(52, 211, 153)
		headerLabel.TextXAlignment = Enum.TextXAlignment.Left
		headerLabel.ZIndex = 200
		headerLabel.Parent = inventoryFrame
	end

	local totalText = string.format("Total Value: %s (%s)", Visual.formatShortPrice(TotalInventoryValue), Visual.formatFullCommas(TotalInventoryValue))
	if headerLabel.Text ~= totalText then
		headerLabel.Text = totalText
	end

	-- 2. Render Badges di Inventory Grid
	local grid = inventoryFrame:FindFirstChild("ScrollingFrame")
		and inventoryFrame.ScrollingFrame:FindFirstChild("UIGridFrame")
	if grid then
		local slotIdx = 0
		for _, slot in ipairs(grid:GetChildren()) do
			if slot:IsA("GuiObject") then
				slotIdx += 1
				local toolCountLbl = slot:FindFirstChild("ToolCount") or slot:FindFirstChildWhichIsA("TextLabel")
				if toolCountLbl and toolCountLbl:IsA("TextLabel") and string.find(toolCountLbl.Text, "kg") then
					local priceText = Visual.getPriceByUiText(toolCountLbl.Text, slotIdx)
					Visual.applyBadgeToSlot(slot, priceText, false)
				end
			end
		end
	end

	-- 3. Render Badges di Hotbar Bawah (1 - 0)
	local hotbarFrame = backpackGui:FindFirstChild("Backpack")
		and backpackGui.Backpack:FindFirstChild("Hotbar")
	if hotbarFrame then
		local slotIdx = 0
		for _, slot in ipairs(hotbarFrame:GetChildren()) do
			if slot:IsA("GuiObject") then
				slotIdx += 1
				local toolCountLbl = slot:FindFirstChild("ToolCount") or slot:FindFirstChildWhichIsA("TextLabel", true)
				if toolCountLbl and toolCountLbl:IsA("TextLabel") and string.find(toolCountLbl.Text, "kg") then
					local priceText = Visual.getPriceByUiText(toolCountLbl.Text, slotIdx)
					Visual.applyBadgeToSlot(slot, priceText, true)
				end
			end
		end
	end
end

function Visual.toggleClearTextures(enabled: boolean, State)
	State.ClearTextures = enabled
	if enabled then
		for _, v in ipairs(workspace:GetDescendants()) do
			if v:IsA("BasePart") and not v:IsA("MeshPart") then Visual.OriginalTextures[v] = { Material = v.Material } v.Material = Enum.Material.SmoothPlastic
			elseif v:IsA("Texture") or v:IsA("Decal") then Visual.OriginalTextures[v] = { Parent = v.Parent } v.Parent = nil end
		end
		for _, effect in ipairs(Lighting:GetChildren()) do
			if effect:IsA("PostEffect") or effect:IsA("Sky") or string.find(effect.Name, "Effect") or string.find(effect.Name, "SunRays") then
				Visual.OriginalLightingEffects[effect] = { Parent = effect.Parent } effect.Parent = nil
			end
		end
	else
		for obj, data in pairs(Visual.OriginalTextures) do
			if obj and typeof(obj) == "Instance" then
				if obj:IsA("BasePart") then obj.Material = data.Material else obj.Parent = data.Parent end
			end
		end
		table.clear(Visual.OriginalTextures)
		for effect, data in pairs(Visual.OriginalLightingEffects) do
			if effect and typeof(effect) == "Instance" then effect.Parent = data.Parent end
		end
		table.clear(Visual.OriginalLightingEffects)
	end
end

return Visual

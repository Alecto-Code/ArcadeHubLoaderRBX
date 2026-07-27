--[[
    =============================================================================
    ARCADEHUB — INVENTORY MODULE (Inventory.lua)
    =============================================================================
    Handles Item Stock Scanning, Mail Gifting Cart, & Multi-Item Payload Engine.
    =============================================================================
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer or Players.PlayerAdded:Wait()

local Inventory = {}

Inventory.MailCfg = {
	recipient = "",
	category = "Pets",
	note = "Sent via ArcadeHUB V5.5",
	maxMailLines = 20,
	sendCooldownSec = 11,
}

Inventory.CATEGORIES = { "Seeds", "Sprinklers", "WateringCans", "Trowels", "Mushrooms", "Raccoons", "Gnomes", "HarvestedFruits", "Pets" }
Inventory.LINE_EXPANDED = { Pets = true, HarvestedFruits = true }

local Networking, PlayerStateClient
pcall(function()
	local sharedMod = ReplicatedStorage:FindFirstChild("SharedModules") or ReplicatedStorage:FindFirstChild("SharedData")
	if sharedMod and sharedMod:FindFirstChild("Networking") then
		Networking = require(sharedMod.Networking)
	end
	PlayerStateClient = require(ReplicatedStorage:WaitForChild("ClientModules", 10):WaitForChild("PlayerStateClient"))
end)

function Inventory.remoteCall(remote: any, ...: any): (boolean, ...any)
	if remote == nil then return false, "nil remote" end
	local args = { ... }
	if typeof(remote) == "Instance" and remote:IsA("RemoteFunction") then
		return pcall(function() return remote:InvokeServer(table.unpack(args)) end)
	elseif typeof(remote) == "Instance" and remote:IsA("RemoteEvent") then
		return pcall(function() return remote:FireServer(table.unpack(args)) end)
	end
	if typeof(remote.Fire) == "function" then return pcall(function() return remote:Fire(table.unpack(args)) end) end
	if typeof(remote.Invoke) == "function" then return pcall(function() return remote:Invoke(table.unpack(args)) end) end
	if typeof(remote.InvokeServer) == "function" then return pcall(function() return remote:InvokeServer(table.unpack(args)) end) end
	if typeof(remote.FireServer) == "function" then return pcall(function() return remote:FireServer(table.unpack(args)) end) end
	return false, "remote invalid"
end

function Inventory.getInventory()
	if not PlayerStateClient then return nil end
	local ok, replica = pcall(function() return PlayerStateClient:GetLocalReplica() end)
	return ok and replica and replica.Data and replica.Data.Inventory
end

function Inventory.getStackCount(category: string, itemKey: string): number
	local inv = Inventory.getInventory()
	local bucket = inv and inv[category]
	if typeof(bucket) ~= "table" then return 0 end
	local entry = bucket[itemKey]
	if typeof(entry) == "number" then return entry end
	if typeof(entry) == "table" and typeof(entry.Count) == "number" then return entry.Count end
	if entry ~= nil then return 1 end
	return 0
end

function Inventory.normalizePetKey(value: string): string
	return (string.gsub(string.lower(value), "[%s%p]", ""))
end

function Inventory.readPetFields(data: any): (string?, boolean)
	if typeof(data) ~= "table" then return nil, false end
	local species = data.Name or data.name or data.Species or data.species or data.PetName or data.petName
	local equipped = data.Equipped == true
	if typeof(species) ~= "string" or species == "" then return nil, equipped end
	return species, equipped
end

function Inventory.matchPets(species: string): { string }
	local inv = Inventory.getInventory()
	local bucket = inv and inv.Pets
	if typeof(bucket) ~= "table" then return {} end
	local want = Inventory.normalizePetKey(species)
	local matched: { string } = {}
	for uuid, data in pairs(bucket) do
		local sp, equipped = Inventory.readPetFields(data)
		if sp and Inventory.normalizePetKey(sp) == want and not equipped then
			table.insert(matched, tostring(uuid))
		end
	end
	return matched
end

function Inventory.matchFruits(fruitNameTarget: string, VisualModule): { string }
	local matched: { string } = {}
	local targetClean = VisualModule.cleanFruitName(fruitNameTarget)

	local containers = {}
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
	if backpack then table.insert(containers, backpack) end
	if LocalPlayer.Character then table.insert(containers, LocalPlayer.Character) end

	for _, container in ipairs(containers) do
		for _, item in ipairs(container:GetChildren()) do
			if item:GetAttribute("HarvestedFruit") == true then
				local fName = item:GetAttribute("FruitName") or item:GetAttribute("Fruit") or VisualModule.cleanFruitName(item.Name)
				if VisualModule.cleanFruitName(fName) == targetClean then
					local itemId = item:GetAttribute("Id") or item.Name
					table.insert(matched, tostring(itemId))
				end
			end
		end
	end
	return matched
end

function Inventory.resolveStackKey(category: string, itemKey: string): string?
	local inv = Inventory.getInventory()
	local bucket = inv and inv[category]
	if typeof(bucket) ~= "table" then return nil end
	if bucket[itemKey] then return itemKey end
	for key in pairs(bucket) do
		if string.lower(tostring(key)) == string.lower(itemKey) then return tostring(key) end
	end
	return nil
end

function Inventory.getAvailableCount(category: string, itemKey: string, VisualModule): number
	if category == "Pets" then return #Inventory.matchPets(itemKey) end
	if category == "HarvestedFruits" then return #Inventory.matchFruits(itemKey, VisualModule) end
	local key = Inventory.resolveStackKey(category, itemKey)
	if not key then return 0 end
	return Inventory.getStackCount(category, key)
end

function Inventory.listCategoryItems(category: string, VisualModule): { any }
	local items: { any } = {}

	if category == "Pets" then
		local inv = Inventory.getInventory()
		local bucket = inv and inv.Pets
		if typeof(bucket) == "table" then
			local groups: { [string]: number } = {}
			for _, data in pairs(bucket) do
				local species, equipped = Inventory.readPetFields(data)
				if species and not equipped then groups[species] = (groups[species] or 0) + 1 end
			end
			for species, count in pairs(groups) do
				table.insert(items, { itemKey = species, displayName = species, count = count })
			end
		end
	elseif category == "HarvestedFruits" then
		local groups: { [string]: number } = {}
		local containers = {}
		local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
		if backpack then table.insert(containers, backpack) end
		if LocalPlayer.Character then table.insert(containers, LocalPlayer.Character) end

		for _, container in ipairs(containers) do
			for _, item in ipairs(container:GetChildren()) do
				if item:GetAttribute("HarvestedFruit") == true then
					local fName = item:GetAttribute("FruitName") or item:GetAttribute("Fruit") or VisualModule.cleanFruitName(item.Name)
					if fName and fName ~= "" then
						groups[fName] = (groups[fName] or 0) + 1
					end
				end
			end
		end
		for fName, count in pairs(groups) do
			table.insert(items, { itemKey = fName, displayName = fName, count = count })
		end
	else
		local inv = Inventory.getInventory()
		local bucket = inv and inv[category]
		if typeof(bucket) == "table" then
			for key, entry in pairs(bucket) do
				local count = Inventory.getStackCount(category, tostring(key))
				if count > 0 then
					table.insert(items, { itemKey = tostring(key), displayName = tostring(key), count = count })
				end
			end
		end
	end
	table.sort(items, function(a, b) return a.displayName < b.displayName end)
	return items
end

local lookupCache: { [string]: number } = {}
function Inventory.lookupUser(username: string): (number?, string?)
	if not username or username == "" then return nil, "Username is empty" end
	local key = string.lower(username)
	if lookupCache[key] then return lookupCache[key], nil end

	if Networking and Networking.Mailbox and Networking.Mailbox.LookupPlayer then
		local ok, userId = Inventory.remoteCall(Networking.Mailbox.LookupPlayer, username)
		if ok and typeof(userId) == "number" and userId > 0 then
			lookupCache[key] = userId
			return userId, nil
		end
	end

	local okApi, userIdApi = pcall(function()
		return Players:GetUserIdFromNameAsync(username)
	end)
	if okApi and typeof(userIdApi) == "number" and userIdApi > 0 then
		lookupCache[key] = userIdApi
		return userIdApi, nil
	end

	return nil, "Player '" .. username .. "' not found"
end

function Inventory.buildLinesForEntry(category: string, itemKey: string, count: number, VisualModule): ({ any }?, string?)
	if category == "Pets" then
		local matched = Inventory.matchPets(itemKey)
		if #matched < count then return nil, string.format("Pets/%s: need %d, have %d", itemKey, count, #matched) end
		local lines = {}
		for i = 1, count do table.insert(lines, { Category = "Pets", ItemKey = matched[i], Count = 1 }) end
		return lines, nil
	elseif category == "HarvestedFruits" then
		local matched = Inventory.matchFruits(itemKey, VisualModule)
		if #matched < count then return nil, string.format("HarvestedFruits/%s: need %d, have %d", itemKey, count, #matched) end
		local lines = {}
		for i = 1, count do table.insert(lines, { Category = "HarvestedFruits", ItemKey = matched[i], Count = 1 }) end
		return lines, nil
	end
	local resolvedKey = Inventory.resolveStackKey(category, itemKey)
	if not resolvedKey then return nil, itemKey .. " not found in inventory" end
	local have = Inventory.getStackCount(category, resolvedKey)
	if have < count then return nil, string.format("%s: need %d, have %d", resolvedKey, count, have) end
	return { { Category = category, ItemKey = resolvedKey, Count = count } }, nil
end

function Inventory.packPayloadLines(lines: { any }): { { any } }
	local maxLines = Inventory.MailCfg.maxMailLines
	local mails: { { any } } = {}
	local current: { any } = {}
	local used = 0

	for _, entry in ipairs(lines) do
		local cost = Inventory.LINE_EXPANDED[entry.Category] and entry.Count or 1
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

return Inventory

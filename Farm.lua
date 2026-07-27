--[[
    =============================================================================
    ARCADEHUB - FARM MODULE (Farm.lua)
    =============================================================================
    Handles Direct Remote Auto Farm (Sprinklers & Water Cans) and Auto Harvest V4.0.
    =============================================================================
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer or Players.PlayerAdded:Wait()

local Farm = {}

Farm.toolCache = { sprinkler = {}, water = {} }

local Networking
pcall(function()
	local sharedMod = ReplicatedStorage:FindFirstChild("SharedModules") or ReplicatedStorage:FindFirstChild("SharedData")
	if sharedMod and sharedMod:FindFirstChild("Networking") then
		Networking = require(sharedMod.Networking)
	end
end)

-- Dynamic Executor Global Resolver (Suppresses VS Code Undefined Global Warnings)
local function triggerProximityPrompt(prompt: Instance)
	pcall(function()
		local env = getfenv()
		local fireFunc = env["fireproximityprompt"]
		if not fireFunc and typeof(env["getgenv"]) == "function" then
			local genv = env["getgenv"]()
			fireFunc = genv and genv["fireproximityprompt"]
		end
		if typeof(fireFunc) == "function" then
			fireFunc(prompt)
		end
	end)
end

function Farm.refreshToolCache(scriptConnections)
	Farm.toolCache.sprinkler = {}
	Farm.toolCache.water = {}

	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
	local char = LocalPlayer.Character

	local containers = { backpack, char }
	for _, container in ipairs(containers) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") then
					local n = string.lower(item.Name)
					local isSprinkler = item:GetAttribute("Sprinkler") ~= nil or string.find(n, "sprinkler")
					local isWaterCan  = item:GetAttribute("WateringCan") ~= nil or string.find(n, "water") or string.find(n, "can")

					if isSprinkler then table.insert(Farm.toolCache.sprinkler, item) end
					if isWaterCan then table.insert(Farm.toolCache.water, item) end
				end
			end
		end
	end
end

function Farm.preciseWait(seconds: number, State, isScriptRunning, currentSession)
	local targetTime = os.clock() + seconds
	while os.clock() < targetTime do
		if not isScriptRunning or _G.ArcadeFarmSession ~= currentSession or _G.ArcadeHarvestSession ~= currentSession then
			break
		end
		task.wait(0.1)
	end
end

function Farm.teleportPlayerPostSprinkler(targetPos: Vector3)
	local char = LocalPlayer.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		local dest = Vector3.new(targetPos.X, targetPos.Y + 3, targetPos.Z + 20)
		pcall(function()
			char:PivotTo(CFrame.new(dest))
		end)
	end
end

function Farm.fireSprinklerRemote(State): boolean
	Farm.refreshToolCache()
	if #Farm.toolCache.sprinkler == 0 then return false end

	local toolInstance = nil
	if State.SelectedSprinkler then
		for _, t in ipairs(Farm.toolCache.sprinkler) do
			if t.Name == State.SelectedSprinkler then toolInstance = t break end
		end
	end
	if not toolInstance then toolInstance = Farm.toolCache.sprinkler[1] end

	local char = LocalPlayer.Character
	local bp = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
	if not char or not bp then return false end

	local targetPos = State.TargetVector3
	if not targetPos and char:FindFirstChild("HumanoidRootPart") then
		targetPos = char.HumanoidRootPart.Position
	end
	if not targetPos then return false end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then pcall(function() hum:EquipTool(toolInstance) end) end
	toolInstance.Parent = char
	task.wait(0.3)

	local sprinklerType = toolInstance:GetAttribute("Sprinkler") or toolInstance.Name
	local plotId = LocalPlayer:GetAttribute("PlotId") or 1
	local success = false

	if Networking and Networking.Place and Networking.Place.PlaceSprinkler then
		local ok, err = pcall(function()
			Networking.Place.PlaceSprinkler:Fire(targetPos, sprinklerType, toolInstance, plotId)
		end)
		success = ok
		if not ok and err then warn("⚠️ [ArcadeHub Remote Warning - PlaceSprinkler]:", err) end
	end

	task.wait(0.3)
	if toolInstance and toolInstance.Parent == char then
		if hum then pcall(function() hum:UnequipTools() end) end
		toolInstance.Parent = bp
	end

	return success
end

function Farm.fireWateringCanRemote(State): boolean
	Farm.refreshToolCache()
	if #Farm.toolCache.water == 0 then return false end

	local toolInstance = nil
	if State.SelectedWaterCan then
		for _, t in ipairs(Farm.toolCache.water) do
			if t.Name == State.SelectedWaterCan then toolInstance = t break end
		end
	end
	if not toolInstance then toolInstance = Farm.toolCache.water[1] end

	local char = LocalPlayer.Character
	local bp = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
	if not char or not bp then return false end

	local targetPos = State.TargetVector3
	if not targetPos and char:FindFirstChild("HumanoidRootPart") then
		targetPos = char.HumanoidRootPart.Position
	end
	if not targetPos then return false end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then pcall(function() hum:EquipTool(toolInstance) end) end
	toolInstance.Parent = char
	task.wait(0.3)

	local canName = toolInstance:GetAttribute("WateringCan") or toolInstance.Name
	local finalPos = targetPos - Vector3.new(0, 0.3, 0)
	local success = false

	if Networking and Networking.WateringCan and Networking.WateringCan.UseWateringCan then
		local ok, err = pcall(function()
			Networking.WateringCan.UseWateringCan:Fire(finalPos, canName, toolInstance)
		end)
		success = ok
		if not ok and err then warn("⚠️ [ArcadeHub Remote Warning - UseWateringCan]:", err) end
	end

	task.wait(0.3)
	if toolInstance and toolInstance.Parent == char then
		if hum then pcall(function() hum:UnequipTools() end) end
		toolInstance.Parent = bp
	end

	return success
end

function Farm.scanAndHarvestFruits(State, isScriptRunning, currentSession, VisualModule)
	local Gardens = workspace:FindFirstChild("Gardens")
	if not Gardens then return end

	local plotId = LocalPlayer:GetAttribute("PlotId") or 1
	local myPlot = Gardens:FindFirstChild("Plot" .. plotId)
	if not myPlot then return end

	local plantsFolder = myPlot:FindFirstChild("Plants")
	if not plantsFolder then return end

	for _, plant in ipairs(plantsFolder:GetChildren()) do
		local fruitsFolder = plant:FindFirstChild("Fruits") or plant:FindFirstChild("Fruit")
		if fruitsFolder then
			for _, fruit in ipairs(fruitsFolder:GetChildren()) do
				if not State.AutoHarvestEnabled or not isScriptRunning or _G.ArcadeHarvestSession ~= currentSession then return end

				local age    = tonumber(fruit:GetAttribute("Age")) or 0
				local maxAge = tonumber(fruit:GetAttribute("MaxAge")) or 1

				if age >= maxAge then
					local shouldHarvest = false

					if State.HarvestMode == "Harvest All" then
						shouldHarvest = true
					elseif State.HarvestMode == "Harvest Filter" then
						local fruitName = fruit:GetAttribute("CorePartName") or VisualModule.cleanFruitName(fruit.Name)
						local baseWeight = VisualModule.getFruitBaseWeight(fruitName)
						local sizeMulti  = tonumber(fruit:GetAttribute("SizeMulti")) or 1.0
						local calculatedKg = sizeMulti * baseWeight

						local passesSize = false
						if State.SizeMode == "Above" then
							passesSize = (calculatedKg > State.SizeThreshold)
						elseif State.SizeMode == "Below" then
							passesSize = (calculatedKg < State.SizeThreshold)
						end

						local mut = fruit:GetAttribute("Mutation") or "None"
						if mut == "" then mut = "None" end

						local passesMutation = (State.SelectedMutations[mut] == true)

						if passesSize and passesMutation then
							shouldHarvest = true
						end
					end

					if shouldHarvest then
						local harvestPart = fruit:FindFirstChild("HarvestPart")
						if harvestPart then
							local prompt = harvestPart:FindFirstChildOfClass("ProximityPrompt")
							if prompt then
								triggerProximityPrompt(prompt)
								task.wait(0.15)
							end
						end
					end
				end
			end
		end
	end
end

return Farm

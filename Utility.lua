--[[
    =============================================================================
    ARCADEHUB — UTILITY MODULE (Utility.lua)
    =============================================================================
    Handles Anti-Lag Plants, Auto-Spam E, Auto-Drop Item, and Cleanup Protocols.
    =============================================================================
--]]

local VirtualInputManager = game:GetService("VirtualInputManager")

local Utility = {}

Utility.OriginalPlantData = {}

function Utility.minimizePlant(plantModel: Instance)
	if not plantModel:IsA("Model") then return end
	for _, child in ipairs(plantModel:GetDescendants()) do
		if child:IsA("BasePart") or child:IsA("MeshPart") then
			if not Utility.OriginalPlantData[child] then Utility.OriginalPlantData[child] = { Size = child.Size, Transparency = child.Transparency, CanCollide = child.CanCollide } end
			child.Size = Vector3.zero child.Transparency = 1 child.CanCollide = false
		elseif child:IsA("Decal") or child:IsA("Texture") then
			if not Utility.OriginalPlantData[child] then Utility.OriginalPlantData[child] = { Transparency = child.Transparency } end
			child.Transparency = 1
		end
	end
end

function Utility.restorePlants()
	for child, data in pairs(Utility.OriginalPlantData) do
		if child and child.Parent then
			if child:IsA("BasePart") or child:IsA("MeshPart") then child.Size = data.Size child.Transparency = data.Transparency child.CanCollide = data.CanCollide
			elseif child:IsA("Decal") or child:IsA("Texture") then child.Transparency = data.Transparency end
		end
	end
	table.clear(Utility.OriginalPlantData)
end

function Utility.toggleAntiLagPlants(enabled: boolean, State)
	State.AntiLagPlants = enabled
	local gardens = workspace:FindFirstChild("Gardens")
	if not gardens then return end
	if enabled then
		for _, plot in ipairs(gardens:GetChildren()) do
			local plants = plot:FindFirstChild("Plants")
			if plants then for _, plant in ipairs(plants:GetChildren()) do Utility.minimizePlant(plant) end end
		end
	else Utility.restorePlants() end
end

function Utility.startAutoSpamELoop(State, isScriptRunning)
	task.spawn(function()
		while isScriptRunning() do
			if State.AutoSpamE then
				VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game) task.wait(0.02)
				VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game) task.wait(0.03)
			else task.wait(0.1) end
		end
	end)
end

function Utility.startAutoDropLoop(State, isScriptRunning)
	task.spawn(function()
		while isScriptRunning() do
			if State.AutoDrop then
				VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game) task.wait(0.02)
				VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game) task.wait(0.03)
			else task.wait(0.1) end
		end
	end)
end

function Utility.cleanupAll(isScriptRunningRef, State, scriptConnections, VisualModule, ScreenGui)
	isScriptRunningRef.value = false
	State.AutoFarmEnabled = false
	State.AutoHarvestEnabled = false
	for _, conn in ipairs(scriptConnections) do pcall(function() conn:Disconnect() end) end
	table.clear(scriptConnections)
	pcall(VisualModule.removePriceBadges)
	if ScreenGui then pcall(function() ScreenGui:Destroy() end) end
end

return Utility

--[[
    =============================================================================
    ARCADEHUB - MAIN ENTRY POINT (Main.lua)
    =============================================================================
    Master End Point: Bootstraps Session Locks, Requirements, GUI Mounting & Loops.
    =============================================================================
--]]

task.wait(0.3)

local currentSession = tick()
_G.ArcadeFarmSession = currentSession
_G.ArcadeHarvestSession = currentSession

-- // Services // --
local Players   = game:GetService("Players")
local CoreGui   = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- // Safe GUI Parent Resolution // --
local function getGuiParent(): Instance
	local success, _ = pcall(function()
		local t = CoreGui.Name
	end)
	if success then return CoreGui end
	return LocalPlayer:WaitForChild("PlayerGui")
end

-- // Safe Cleanup Protocol (Kill Old Instances) // --
local parentGui = getGuiParent()
local oldGui = parentGui:FindFirstChild("ArcadeHUB_GUI")
if oldGui then oldGui:Destroy() end

local oldFarmGui = parentGui:FindFirstChild("ArcadeFarmGuiMaster")
if oldFarmGui then oldFarmGui:Destroy() end

local oldHarvestGui = parentGui:FindFirstChild("ArcadeHarvestGuiMaster")
if oldHarvestGui then oldHarvestGui:Destroy() end

if _G.ArcadeOverlayCleanup then
	pcall(_G.ArcadeOverlayCleanup)
	task.wait(0.1)
end

-- // Safe Universal Module Resolver // --
local function getModule(moduleName: string): any
	-- 1. Check if running inside Roblox Studio / Instance Hierarchy (script.Parent)
	local okScript, scriptObj = pcall(function() return script end)
	if okScript and scriptObj and typeof(scriptObj) == "Instance" and scriptObj.Parent then
		local found = scriptObj.Parent:FindFirstChild(moduleName)
		if found then return require(found) end
	end

	-- 2. Check if folder exists in ReplicatedStorage, CoreGui, or PlayerGui
	local searchContainers = {
		game:GetService("ReplicatedStorage"),
		parentGui,
		workspace
	}
	for _, container in ipairs(searchContainers) do
		if container then
			local folder = container:FindFirstChild("ArcadeHUB_Modular") or container:FindFirstChild("ArcadeHUB") or container:FindFirstChild("BYPASSE")
			if folder and folder:FindFirstChild(moduleName) then
				return require(folder:FindFirstChild(moduleName))
			end
			if container:FindFirstChild(moduleName) then
				return require(container:FindFirstChild(moduleName))
			end
		end
	end

	error("[ArcadeHUB Error]: Module '" .. moduleName .. "' not found. Make sure your ModuleScript files are inside a folder named 'ArcadeHUB' or 'BYPASSE' in ReplicatedStorage or PlayerGui!")
end

-- // Load Sub-Modules // --
local Theme          = getModule("Theme")
local Visual         = getModule("Visual")
local Farm           = getModule("Farm")
local Inventory      = getModule("Inventory")
local PlayerModule   = getModule("Player")
local Utility        = getModule("Utility")
local Gui            = getModule("Gui")

-- // Dynamic Mutation Registry & State // --
local knownMutations = {
	"None", "Gold", "Rainbow", "Electric", "Frozen", "Bloodlit",
	"Chained", "Starstruck", "Aurora", "Ignited", "Glow", "Eclipsed", "Veil"
}

local State = {
	InstantInteract   = false,
	AutoSpamE         = false,
	AutoDrop          = false,
	AntiLagPlants     = false,
	ClearTextures     = false,
	FruitOverlay      = true,
	-- Auto Farm Engine States --
	AutoFarmEnabled   = false,
	SelectedSprinkler = nil,
	SelectedWaterCan  = nil,
	TargetVector3     = nil,
	SprinklerCooldown = 120,
	WateringCooldown  = 30,
	-- Auto Harvest Engine States --
	AutoHarvestEnabled= false,
	HarvestMode       = "Harvest All",
	SizeMode          = "Above",
	SizeThreshold     = 10,
	SelectedMutations = {},
	HarvestCooldown   = 5,
}

for _, mutName in ipairs(knownMutations) do
	State.SelectedMutations[mutName] = true
end

local isScriptRunningRef = { value = true }
local scriptConnections = {}

-- Initialize Utility Loops
Utility.startAutoSpamELoop(State, function() return isScriptRunningRef.value end)
Utility.startAutoDropLoop(State, function() return isScriptRunningRef.value end)

table.insert(scriptConnections, workspace.DescendantAdded:Connect(function(descendant)
	if State.InstantInteract then task.wait(0.05) PlayerModule.applyInstantPrompt(descendant, State) end
end))

-- Registered Global Cleanup Handlers
local function executeCleanup()
	Utility.cleanupAll(isScriptRunningRef, State, scriptConnections, Visual, parentGui:FindFirstChild("ArcadeHUB_GUI"))
end

_G.ArcadeOverlayCleanup = executeCleanup
_G.ArcadeFarmCleanup    = executeCleanup
_G.ArcadeHarvestCleanup = executeCleanup

-- // Build GUI // --
local ScreenGuiInstance = Gui.Build(
	parentGui, Theme, State, knownMutations,
	Visual, Farm, Inventory, PlayerModule, Utility,
	isScriptRunningRef, currentSession, scriptConnections
)

-- // Continuous Main Overlay Execution Loop // --
task.spawn(function()
	while isScriptRunningRef.value do
		pcall(function() Visual.renderPriceOverlay(State, isScriptRunningRef.value) end)
		task.wait(0.3)
	end
end)

print("[ArcadeHUB V5.5]: Modular Multi-File Architecture Loaded Successfully (Main.lua Entry Point Ready)!")

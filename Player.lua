--[[
    =============================================================================
    ARCADEHUB — PLAYER MODULE (Player.lua)
    =============================================================================
    Handles Player Target Coordinates & Instant Interact Proximity Prompt Bypass.
    =============================================================================
--]]

local Player = {}

function Player.applyInstantPrompt(prompt: Instance, State)
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

function Player.toggleInstantInteract(enabled: boolean, State)
	State.InstantInteract = enabled
	for _, desc in ipairs(workspace:GetDescendants()) do
		Player.applyInstantPrompt(desc, State)
	end
end

return Player

--[[
    =============================================================================
    ARCADEHUB — THEME MODULE (Theme.lua)
    =============================================================================
    Defines UI Color Tokens, Styling Properties, and Micro-Animation Utilities.
    =============================================================================
--]]

local TweenService = game:GetService("TweenService")

local Theme = {
	WindowBg    = Color3.fromRGB(15, 23, 42),    -- Slate 900 Glass
	HeaderBg    = Color3.fromRGB(30, 41, 59),    -- Slate 800
	SidebarBg   = Color3.fromRGB(24, 32, 47),    -- Slate 850
	CardBg      = Color3.fromRGB(30, 41, 59),    -- Slate 800 Card
	CardHover   = Color3.fromRGB(51, 65, 85),    -- Slate 700 Hover
	Stroke      = Color3.fromRGB(71, 85, 105),   -- Slate 600 Border Stroke
	StrokeFocus = Color3.fromRGB(59, 130, 246),  -- Blue 500 Glow Focus
	AccentPurple= Color3.fromRGB(37, 99, 235),   -- Primary Dark Blue Glass Accent
	AccentIndigo= Color3.fromRGB(59, 130, 246),  -- Accent Blue Hover
	AccentGreen = Color3.fromRGB(16, 185, 129),  -- Emerald Success
	TextMain    = Color3.fromRGB(248, 250, 252), -- Slate 50 Primary Text
	TextSub     = Color3.fromRGB(148, 163, 184), -- Slate 400 Secondary Text
	TextMuted   = Color3.fromRGB(100, 116, 139), -- Slate 500 Muted Text

	CornerWindow = UDim.new(0, 12),
	CornerCard   = UDim.new(0, 8),
	CornerControl= UDim.new(0, 6),
}

function Theme.Tween(instance, properties, duration)
	local info = TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local tween = TweenService:Create(instance, info, properties)
	tween:Play()
	return tween
end

function Theme.AddCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.CornerControl
	corner.Parent = parent
	return corner
end

function Theme.AddStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color or Theme.Stroke
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0.4
	stroke.Parent = parent
	return stroke
end

function Theme.AddPadding(parent, top, bottom, left, right)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, top or 10)
	pad.PaddingBottom = UDim.new(0, bottom or 10)
	pad.PaddingLeft = UDim.new(0, left or 10)
	pad.PaddingRight = UDim.new(0, right or 10)
	pad.Parent = parent
	return pad
end

return Theme

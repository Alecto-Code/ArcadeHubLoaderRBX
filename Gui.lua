--[[
    =============================================================================
    ARCADEHUB - GUI MODULE (Gui.lua)
    =============================================================================
    Renders Desktop Glassmorphism GUI & Hooks Component Events to Core Modules.
    =============================================================================
--]]

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local LocalPlayer      = Players.LocalPlayer or Players.PlayerAdded:Wait()

local Gui = {}

function Gui.Build(parentGui, Theme, State, knownMutations, Visual, Farm, Inventory, PlayerModule, Utility, isScriptRunningRef, currentSession, scriptConnections)
	local THEME = Theme

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "ArcadeHUB_GUI"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = parentGui

	local MainFrame = Instance.new("Frame")
	MainFrame.Name = "MainFrame"
	MainFrame.Size = UDim2.fromOffset(650, 420)
	MainFrame.Position = UDim2.new(0.5, -325, 0.5, -210)
	MainFrame.BackgroundColor3 = THEME.WindowBg
	MainFrame.BackgroundTransparency = 0.12
	MainFrame.BorderSizePixel = 0
	MainFrame.ClipsDescendants = true
	MainFrame.Parent = ScreenGui

	Theme.AddCorner(MainFrame, THEME.CornerWindow)
	Theme.AddStroke(MainFrame, THEME.Stroke, 1.2, 0.3)

	-- Header Bar (40px)
	local Header = Instance.new("Frame")
	Header.Name = "Header"
	Header.Size = UDim2.new(1, 0, 0, 40)
	Header.BackgroundColor3 = THEME.HeaderBg
	Header.BackgroundTransparency = 0.15
	Header.BorderSizePixel = 0
	Header.Parent = MainFrame

	Theme.AddCorner(Header, THEME.CornerWindow)
	Theme.AddPadding(Header, 0, 0, 14, 14)

	local TitleLogo = Instance.new("TextLabel")
	TitleLogo.Name = "TitleLogo"
	TitleLogo.Size = UDim2.new(0.5, 0, 1, 0)
	TitleLogo.BackgroundTransparency = 1
	TitleLogo.Text = "ArcadeHUB - Master Edition"
	TitleLogo.Font = Enum.Font.GothamBold
	TitleLogo.TextSize = 14
	TitleLogo.TextColor3 = THEME.TextMain
	TitleLogo.TextXAlignment = Enum.TextXAlignment.Left
	TitleLogo.Parent = Header

	local windowControls = Instance.new("Frame")
	windowControls.Name = "windowControls"
	windowControls.Size = UDim2.fromOffset(80, 26)
	windowControls.Position = UDim2.new(1, -80, 0.5, -13)
	windowControls.BackgroundTransparency = 1
	windowControls.Parent = Header

	local windowCtrlLayout = Instance.new("UIListLayout", windowControls)
	windowCtrlLayout.FillDirection = Enum.FillDirection.Horizontal
	windowCtrlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	windowCtrlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	windowCtrlLayout.Padding = UDim.new(0, 6)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "closeBtn"
	closeBtn.Size = UDim2.fromOffset(24, 24)
	closeBtn.BackgroundColor3 = THEME.HeaderBg
	closeBtn.BackgroundTransparency = 0.5
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "✕"
	closeBtn.TextSize = 12
	closeBtn.TextColor3 = THEME.TextSub
	closeBtn.AutoButtonColor = false
	closeBtn.Parent = windowControls
	Theme.AddCorner(closeBtn, UDim.new(0, 6))

	closeBtn.MouseEnter:Connect(function()
		Theme.Tween(closeBtn, { BackgroundColor3 = Color3.fromRGB(239, 68, 68), TextColor3 = THEME.TextMain }, 0.15)
	end)
	closeBtn.MouseLeave:Connect(function()
		Theme.Tween(closeBtn, { BackgroundColor3 = THEME.HeaderBg, TextColor3 = THEME.TextSub }, 0.15)
	end)
	closeBtn.MouseButton1Click:Connect(function() ScreenGui.Enabled = false end)

	-- Window Dragging
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
	Body.Name = "Body"
	Body.Size = UDim2.new(1, 0, 1, -40)
	Body.Position = UDim2.fromOffset(0, 40)
	Body.BackgroundTransparency = 1
	Body.Parent = MainFrame

	-- Left Sidebar (150px)
	local Sidebar = Instance.new("Frame")
	Sidebar.Name = "Sidebar"
	Sidebar.Size = UDim2.new(0, 150, 1, 0)
	Sidebar.BackgroundColor3 = THEME.SidebarBg
	Sidebar.BackgroundTransparency = 0.2
	Sidebar.BorderSizePixel = 0
	Sidebar.Parent = Body
	Theme.AddPadding(Sidebar, 10, 10, 8, 8)

	-- Sidebar Search Bar
	local searchCard = Instance.new("Frame")
	searchCard.Name = "searchCard"
	searchCard.Size = UDim2.new(1, 0, 0, 28)
	searchCard.BackgroundColor3 = THEME.WindowBg
	searchCard.BackgroundTransparency = 0.4
	searchCard.Parent = Sidebar
	Theme.AddCorner(searchCard, THEME.CornerControl)
	local searchStroke = Theme.AddStroke(searchCard, THEME.Stroke, 1, 0.6)

	local searchBox = Instance.new("TextBox")
	searchBox.Name = "searchBox"
	searchBox.Size = UDim2.new(1, -12, 1, 0)
	searchBox.Position = UDim2.fromOffset(6, 0)
	searchBox.BackgroundTransparency = 1
	searchBox.Font = Enum.Font.Gotham
	searchBox.TextSize = 11
	searchBox.TextColor3 = THEME.TextMain
	searchBox.PlaceholderText = "Search..."
	searchBox.PlaceholderColor3 = THEME.TextSub
	searchBox.Text = ""
	searchBox.Parent = searchCard

	searchBox.Focused:Connect(function() Theme.Tween(searchStroke, { Color = THEME.StrokeFocus, Transparency = 0 }, 0.15) end)
	searchBox.FocusLost:Connect(function() Theme.Tween(searchStroke, { Color = THEME.Stroke, Transparency = 0.6 }, 0.15) end)

	-- Sidebar Tab Scroll
	local tabScroll = Instance.new("ScrollingFrame")
	tabScroll.Name = "tabScroll"
	tabScroll.Size = UDim2.new(1, 0, 1, -74)
	tabScroll.Position = UDim2.fromOffset(0, 34)
	tabScroll.BackgroundTransparency = 1
	tabScroll.BorderSizePixel = 0
	tabScroll.ScrollBarThickness = 0
	tabScroll.CanvasSize = UDim2.fromOffset(0, 0)
	tabScroll.Parent = Sidebar

	local tabList = Instance.new("UIListLayout", tabScroll)
	tabList.Name = "tabList"
	tabList.Padding = UDim.new(0, 4)
	tabList.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- Bottom Profile Card
	local profileCard = Instance.new("Frame")
	profileCard.Name = "profileCard"
	profileCard.Size = UDim2.new(1, 0, 0, 32)
	profileCard.Position = UDim2.new(0, 0, 1, -32)
	profileCard.BackgroundColor3 = THEME.WindowBg
	profileCard.BackgroundTransparency = 0.3
	profileCard.Parent = Sidebar
	Theme.AddCorner(profileCard, THEME.CornerControl)
	Theme.AddStroke(profileCard, THEME.Stroke, 1, 0.6)

	local avatarImg = Instance.new("ImageLabel")
	avatarImg.Name = "avatarImg"
	avatarImg.Size = UDim2.fromOffset(24, 24)
	avatarImg.Position = UDim2.fromOffset(4, 4)
	avatarImg.BackgroundColor3 = THEME.HeaderBg
	avatarImg.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", LocalPlayer.UserId)
	avatarImg.Parent = profileCard
	Theme.AddCorner(avatarImg, UDim.new(1, 0))

	local usernameLabel = Instance.new("TextLabel")
	usernameLabel.Name = "usernameLabel"
	usernameLabel.Size = UDim2.new(1, -34, 1, 0)
	usernameLabel.Position = UDim2.fromOffset(32, 0)
	usernameLabel.BackgroundTransparency = 1
	usernameLabel.Text = LocalPlayer.Name
	usernameLabel.Font = Enum.Font.GothamBold
	usernameLabel.TextSize = 10
	usernameLabel.TextColor3 = THEME.TextMain
	usernameLabel.TextXAlignment = Enum.TextXAlignment.Left
	usernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	usernameLabel.Parent = profileCard

	-- Content Area
	local ContentArea = Instance.new("Frame")
	ContentArea.Name = "ContentArea"
	ContentArea.Size = UDim2.new(1, -150, 1, 0)
	ContentArea.Position = UDim2.fromOffset(150, 0)
	ContentArea.BackgroundTransparency = 1
	ContentArea.Parent = Body
	Theme.AddPadding(ContentArea, 8, 8, 12, 12)

	local breadcrumbLabel = Instance.new("TextLabel")
	breadcrumbLabel.Name = "breadcrumbLabel"
	breadcrumbLabel.Size = UDim2.new(1, 0, 0, 20)
	breadcrumbLabel.Position = UDim2.fromOffset(0, 0)
	breadcrumbLabel.BackgroundTransparency = 1
	breadcrumbLabel.Text = "ArcadeHUB - Grow a Garden"
	breadcrumbLabel.Font = Enum.Font.GothamBold
	breadcrumbLabel.TextSize = 12
	breadcrumbLabel.TextColor3 = THEME.AccentIndigo
	breadcrumbLabel.TextXAlignment = Enum.TextXAlignment.Left
	breadcrumbLabel.Parent = ContentArea

	-- Tab Builder
	local Tabs, TabButtons, activeTab = {}, {}, nil

	local function createTab(tabName: string): Frame
		local tabBtn = Instance.new("TextButton")
		tabBtn.Name = "TabBtn_" .. tabName
		tabBtn.Size = UDim2.new(1, 0, 0, 30)
		tabBtn.BackgroundColor3 = THEME.CardBg
		tabBtn.BackgroundTransparency = 1
		tabBtn.Text = "   " .. tabName
		tabBtn.Font = Enum.Font.GothamMedium
		tabBtn.TextSize = 12
		tabBtn.TextColor3 = THEME.TextSub
		tabBtn.TextXAlignment = Enum.TextXAlignment.Left
		tabBtn.BorderSizePixel = 0
		tabBtn.AutoButtonColor = false
		tabBtn.Parent = tabScroll
		Theme.AddCorner(tabBtn, THEME.CornerControl)

		local activeIndicator = Instance.new("Frame")
		activeIndicator.Name = "Indicator"
		activeIndicator.Size = UDim2.fromOffset(3, 18)
		activeIndicator.Position = UDim2.fromOffset(2, 6)
		activeIndicator.BackgroundColor3 = THEME.AccentPurple
		activeIndicator.Visible = false
		activeIndicator.Parent = tabBtn
		Theme.AddCorner(activeIndicator, UDim.new(1, 0))

		local tabContent = Instance.new("Frame")
		tabContent.Name = "Content_" .. tabName
		tabContent.Size = UDim2.new(1, 0, 1, -24)
		tabContent.Position = UDim2.fromOffset(0, 24)
		tabContent.BackgroundTransparency = 1
		tabContent.Visible = false
		tabContent.Parent = ContentArea

		tabBtn.MouseButton1Click:Connect(function()
			for name, content in pairs(Tabs) do content.Visible = (name == tabName) end
			for name, button in pairs(TabButtons) do
				local ind = button:FindFirstChild("Indicator")
				if name == tabName then
					Theme.Tween(button, { BackgroundTransparency = 0.4, TextColor3 = THEME.TextMain, BackgroundColor3 = THEME.AccentPurple }, 0.15)
					if ind then ind.Visible = true end
				else
					Theme.Tween(button, { BackgroundTransparency = 1, TextColor3 = THEME.TextSub, BackgroundColor3 = THEME.CardBg }, 0.15)
					if ind then ind.Visible = false end
				end
			end
		end)

		Tabs[tabName] = tabContent
		TabButtons[tabName] = tabBtn

		if not activeTab then
			activeTab = tabName
			tabContent.Visible = true
			tabBtn.BackgroundTransparency = 0.4
			tabBtn.BackgroundColor3 = THEME.AccentPurple
			tabBtn.TextColor3 = THEME.TextMain
			activeIndicator.Visible = true
		end
		return tabContent
	end

	local function addToggleCard(tabContainer: Instance, title: string, desc: string, defaultState: boolean, callback: (boolean) -> ())
		local card = Instance.new("Frame")
		card.Name = "ToggleCard_" .. title
		card.Size = UDim2.new(1, 0, 0, 48)
		card.BackgroundColor3 = THEME.CardBg
		card.BackgroundTransparency = 0.15
		card.BorderSizePixel = 0
		card.Parent = tabContainer

		Theme.AddCorner(card, THEME.CornerCard)
		Theme.AddStroke(card, THEME.Stroke, 1, 0.5)

		local cardTitle = Instance.new("TextLabel", card)
		cardTitle.Size = UDim2.new(0.7, 0, 0, 20) cardTitle.Position = UDim2.fromOffset(12, 6) cardTitle.BackgroundTransparency = 1
		cardTitle.Text = title cardTitle.Font = Enum.Font.GothamBold cardTitle.TextSize = 12 cardTitle.TextColor3 = THEME.TextMain cardTitle.TextXAlignment = Enum.TextXAlignment.Left

		local cardDesc = Instance.new("TextLabel", card)
		cardDesc.Size = UDim2.new(0.7, 0, 0, 14) cardDesc.Position = UDim2.fromOffset(12, 26) cardDesc.BackgroundTransparency = 1
		cardDesc.Text = desc cardDesc.Font = Enum.Font.Gotham cardDesc.TextSize = 10 cardDesc.TextColor3 = THEME.TextSub cardDesc.TextXAlignment = Enum.TextXAlignment.Left

		local switchBtn = Instance.new("TextButton", card)
		switchBtn.Name = "switchBtn"
		switchBtn.Size = UDim2.fromOffset(40, 20) switchBtn.Position = UDim2.new(1, -52, 0.5, -10)
		switchBtn.BackgroundColor3 = defaultState and THEME.AccentPurple or THEME.CardHover switchBtn.Text = "" switchBtn.BorderSizePixel = 0 switchBtn.AutoButtonColor = false
		Theme.AddCorner(switchBtn, UDim.new(1, 0))

		local knob = Instance.new("Frame", switchBtn)
		knob.Size = UDim2.fromOffset(16, 16) knob.Position = defaultState and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2)
		knob.BackgroundColor3 = THEME.TextMain knob.BorderSizePixel = 0
		Theme.AddCorner(knob, UDim.new(1, 0))

		local currentState = defaultState
		switchBtn.MouseButton1Click:Connect(function()
			currentState = not currentState
			local targetPos = currentState and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2)
			local targetColor = currentState and THEME.AccentPurple or THEME.CardHover
			Theme.Tween(knob, { Position = targetPos }, 0.15)
			Theme.Tween(switchBtn, { BackgroundColor3 = targetColor }, 0.15)
			callback(currentState)
		end)
	end

	-- Instantiate Tabs
	local infoTabContent        = createTab("Info")
	local mainTabContent        = createTab("Main")
	local autoFarmTabContent    = createTab("Auto Farm")
	local autoHarvestTabContent = createTab("Auto Harvest")
	local mailTabContent        = createTab("Mail Tool")
	local visualTabContent      = createTab("Visuals")

	local function createScrollLayout(parentTab: Frame): ScrollingFrame
		local scroller = Instance.new("ScrollingFrame", parentTab)
		scroller.Size = UDim2.new(1, 0, 1, 0) scroller.BackgroundTransparency = 1 scroller.BorderSizePixel = 0 scroller.ScrollBarThickness = 3 scroller.ScrollBarImageColor3 = THEME.Stroke
		local list = Instance.new("UIListLayout", scroller) list.Padding = UDim.new(0, 8) list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local pad = Instance.new("UIPadding", scroller) pad.PaddingTop = UDim.new(0, 8) pad.PaddingBottom = UDim.new(0, 10)
		list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() scroller.CanvasSize = UDim2.fromOffset(0, list.AbsoluteContentSize.Y + 20) end)
		return scroller
	end

	-- Info Tab
	local infoScroll = createScrollLayout(infoTabContent)
	local infoCard = Instance.new("Frame", infoScroll)
	infoCard.Name = "infoCard" infoCard.Size = UDim2.new(1, 0, 0, 140) infoCard.BackgroundColor3 = THEME.CardBg infoCard.BackgroundTransparency = 0.15
	Theme.AddCorner(infoCard, THEME.CornerCard) Theme.AddStroke(infoCard, THEME.Stroke, 1, 0.5)

	local infoTitle = Instance.new("TextLabel", infoCard)
	infoTitle.Name = "infoTitle" infoTitle.Size = UDim2.new(1, -20, 0, 22) infoTitle.Position = UDim2.fromOffset(10, 6) infoTitle.BackgroundTransparency = 1
	infoTitle.Text = "ArcadeHUB - Script Info" infoTitle.Font = Enum.Font.GothamBold infoTitle.TextSize = 12 infoTitle.TextColor3 = THEME.TextMain infoTitle.TextXAlignment = Enum.TextXAlignment.Left

	local infoBody = Instance.new("TextLabel", infoCard)
	infoBody.Name = "infoBody" infoBody.Size = UDim2.new(1, -20, 0, 104) infoBody.Position = UDim2.fromOffset(10, 30) infoBody.BackgroundTransparency = 1
	infoBody.Text = "Auto Harvest V4.0: Multi-Select Mutation Checkbox & Size Filtering.\nAuto Farm: Direct Remote Sprinkler & Watering Can.\nFruit Price Overlay: Native fruit sell prices & total value.\nMail Tool: Multi-item gifting cart (Pets + Harvested Fruits).\nInstant Interact: Bypass prompt hold duration.\nAnti-Lag & Clear Textures: Optimize FPS & performance."
	infoBody.Font = Enum.Font.Gotham infoBody.TextSize = 10 infoBody.TextColor3 = THEME.TextSub infoBody.TextXAlignment = Enum.TextXAlignment.Left infoBody.TextYAlignment = Enum.TextYAlignment.Top infoBody.TextWrapped = true

	-- Main & Visuals Tabs
	local mainScroll   = createScrollLayout(mainTabContent)
	local visualScroll = createScrollLayout(visualTabContent)

	addToggleCard(mainScroll, "Fruit Price Overlay", "Display native fruit sell prices & total value", State.FruitOverlay, function(s) State.FruitOverlay = s Visual.renderPriceOverlay(State, isScriptRunningRef.value) end)
	addToggleCard(mainScroll, "Instant Interact", "Bypass hold duration prompt", State.InstantInteract, function(s) PlayerModule.toggleInstantInteract(s, State) end)
	addToggleCard(mainScroll, "Auto Spam E", "Simulate rapid E key press", State.AutoSpamE, function(s) State.AutoSpamE = s end)
	addToggleCard(mainScroll, "Auto Drop Item", "Simulate rapid Backspace press", State.AutoDrop, function(s) State.AutoDrop = s end)

	addToggleCard(visualScroll, "Anti-Lag Plants", "Hide plant meshes to save RAM", State.AntiLagPlants, function(s) Utility.toggleAntiLagPlants(s, State) end)
	addToggleCard(visualScroll, "Clear Textures", "SmoothPlastic map & clear sky", State.ClearTextures, function(s) Visual.toggleClearTextures(s, State) end)

	-- Auto Harvest Tab
	local autoHarvestScroll = createScrollLayout(autoHarvestTabContent)

	local harvestModeCard = Instance.new("Frame", autoHarvestScroll)
	harvestModeCard.Name = "harvestModeCard" harvestModeCard.Size = UDim2.new(1, 0, 0, 44) harvestModeCard.BackgroundColor3 = THEME.CardBg harvestModeCard.BackgroundTransparency = 0.15
	Theme.AddCorner(harvestModeCard, THEME.CornerCard) Theme.AddStroke(harvestModeCard, THEME.Stroke, 1, 0.5)

	local modeBtn = Instance.new("TextButton", harvestModeCard)
	modeBtn.Name = "modeBtn" modeBtn.Size = UDim2.new(1, -20, 0, 30) modeBtn.Position = UDim2.fromOffset(10, 7) modeBtn.BackgroundColor3 = THEME.AccentPurple
	modeBtn.Font = Enum.Font.GothamBold modeBtn.TextSize = 11 modeBtn.TextColor3 = Color3.fromRGB(251, 191, 36) modeBtn.Text = "Mode Panen: Harvest All"
	Theme.AddCorner(modeBtn, UDim.new(0, 6))

	local sizeCard = Instance.new("Frame", autoHarvestScroll)
	sizeCard.Name = "sizeCard" sizeCard.Size = UDim2.new(1, 0, 0, 48) sizeCard.BackgroundColor3 = THEME.CardBg sizeCard.BackgroundTransparency = 0.15
	Theme.AddCorner(sizeCard, THEME.CornerCard) Theme.AddStroke(sizeCard, THEME.Stroke, 1, 0.5)

	local sizeModeBtn = Instance.new("TextButton", sizeCard)
	sizeModeBtn.Name = "sizeModeBtn" sizeModeBtn.Size = UDim2.new(0.48, -10, 0, 32) sizeModeBtn.Position = UDim2.fromOffset(10, 8) sizeModeBtn.BackgroundColor3 = THEME.HeaderBg
	sizeModeBtn.Font = Enum.Font.GothamBold sizeModeBtn.TextSize = 10 sizeModeBtn.TextColor3 = THEME.TextMain sizeModeBtn.Text = "Above (>)"
	Theme.AddCorner(sizeModeBtn, UDim.new(0, 6))

	local sizeInput = Instance.new("TextBox", sizeCard)
	sizeInput.Name = "sizeInput" sizeInput.Size = UDim2.new(0.48, -10, 0, 32) sizeInput.Position = UDim2.new(0.52, 0, 0, 8) sizeInput.BackgroundColor3 = THEME.HeaderBg
	sizeInput.Font = Enum.Font.GothamBold sizeInput.TextSize = 11 sizeInput.TextColor3 = Color3.fromRGB(251, 191, 36) sizeInput.Text = "10 kg"
	Theme.AddCorner(sizeInput, UDim.new(0, 6))

	local mutCard = Instance.new("Frame", autoHarvestScroll)
	mutCard.Name = "mutCard" mutCard.Size = UDim2.new(1, 0, 0, 48) mutCard.BackgroundColor3 = THEME.CardBg mutCard.BackgroundTransparency = 0.15
	Theme.AddCorner(mutCard, THEME.CornerCard) Theme.AddStroke(mutCard, THEME.Stroke, 1, 0.5)

	local mutBtn = Instance.new("TextButton", mutCard)
	mutBtn.Name = "mutBtn" mutBtn.Size = UDim2.new(1, -20, 0, 32) mutBtn.Position = UDim2.fromOffset(10, 8) mutBtn.BackgroundColor3 = THEME.HeaderBg
	mutBtn.Font = Enum.Font.GothamMedium mutBtn.TextSize = 10 mutBtn.TextColor3 = THEME.TextMain mutBtn.Text = "Filter Mutasi (" .. #knownMutations .. "/" .. #knownMutations .. " Dicentang) v"
	Theme.AddCorner(mutBtn, UDim.new(0, 6))

	local mutDropdownFrame = Instance.new("Frame", MainFrame)
	mutDropdownFrame.Name = "ArcadeMutationDropdownModal" mutDropdownFrame.Size = UDim2.new(0, 360, 0, 180) mutDropdownFrame.Position = UDim2.new(0.5, -180, 0.5, -90) mutDropdownFrame.BackgroundColor3 = THEME.HeaderBg mutDropdownFrame.Visible = false mutDropdownFrame.ZIndex = 300
	Theme.AddCorner(mutDropdownFrame, UDim.new(0, 8))
	local mutDropdownStroke = Instance.new("UIStroke", mutDropdownFrame) mutDropdownStroke.Color = Color3.fromRGB(251, 191, 36) mutDropdownStroke.Thickness = 1.5

	local quickHeader = Instance.new("Frame", mutDropdownFrame) quickHeader.Size = UDim2.new(1, 0, 0, 30) quickHeader.BackgroundTransparency = 1 quickHeader.ZIndex = 301
	local selectAllBtn = Instance.new("TextButton", quickHeader) selectAllBtn.Name = "selectAllBtn" selectAllBtn.Size = UDim2.new(0.48, -6, 1, -6) selectAllBtn.Position = UDim2.fromOffset(6, 3) selectAllBtn.BackgroundColor3 = THEME.AccentGreen selectAllBtn.Font = Enum.Font.GothamBold selectAllBtn.TextSize = 9.5 selectAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255) selectAllBtn.Text = "[v] Pilih Semua" selectAllBtn.ZIndex = 302
	Theme.AddCorner(selectAllBtn, UDim.new(0, 4))
	local clearAllBtn = Instance.new("TextButton", quickHeader) clearAllBtn.Name = "clearAllBtn" clearAllBtn.Size = UDim2.new(0.48, -6, 1, -6) clearAllBtn.Position = UDim2.new(0.52, 0, 0, 3) clearAllBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68) clearAllBtn.Font = Enum.Font.GothamBold clearAllBtn.TextSize = 9.5 clearAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255) clearAllBtn.Text = "[x] Kosongkan" clearAllBtn.ZIndex = 302
	Theme.AddCorner(clearAllBtn, UDim.new(0, 4))

	local scrollList = Instance.new("ScrollingFrame", mutDropdownFrame) scrollList.Name = "scrollList" scrollList.Size = UDim2.new(1, -12, 1, -36) scrollList.Position = UDim2.fromOffset(6, 32) scrollList.BackgroundTransparency = 1 scrollList.BorderSizePixel = 0 scrollList.ZIndex = 301 scrollList.CanvasSize = UDim2.new(0, 0, 0, #knownMutations * 26) scrollList.ScrollBarThickness = 3
	local listLayout = Instance.new("UIListLayout", scrollList) listLayout.SortOrder = Enum.SortOrder.LayoutOrder listLayout.Padding = UDim.new(0, 2)

	local itemButtons = {}
	local function updateMutBtnLabel()
		local count = 0
		for _, checked in pairs(State.SelectedMutations) do if checked then count += 1 end end
		mutBtn.Text = string.format("Filter Mutasi (%d/%d Dicentang) v", count, #knownMutations)
	end

	for _, mutName in ipairs(knownMutations) do
		local itemBtn = Instance.new("TextButton", scrollList)
		itemBtn.Name = "ItemBtn_" .. mutName itemBtn.Size = UDim2.new(1, -4, 0, 24) itemBtn.BackgroundColor3 = THEME.CardBg itemBtn.Font = Enum.Font.GothamBold itemBtn.TextSize = 10 itemBtn.TextColor3 = THEME.AccentGreen itemBtn.Text = "  [v] " .. mutName itemBtn.TextXAlignment = Enum.TextXAlignment.Left itemBtn.ZIndex = 302
		Theme.AddCorner(itemBtn, UDim.new(0, 4)) itemButtons[mutName] = itemBtn

		itemBtn.MouseButton1Click:Connect(function()
			State.SelectedMutations[mutName] = not State.SelectedMutations[mutName]
			if State.SelectedMutations[mutName] then itemBtn.Text = "  [v] " .. mutName itemBtn.TextColor3 = THEME.AccentGreen else itemBtn.Text = "  [  ] " .. mutName itemBtn.TextColor3 = THEME.TextMuted end
			updateMutBtnLabel()
		end)
	end

	selectAllBtn.MouseButton1Click:Connect(function()
		for _, mutName in ipairs(knownMutations) do State.SelectedMutations[mutName] = true if itemButtons[mutName] then itemButtons[mutName].Text = "  [v] " .. mutName itemButtons[mutName].TextColor3 = THEME.AccentGreen end end
		updateMutBtnLabel()
	end)

	clearAllBtn.MouseButton1Click:Connect(function()
		for _, mutName in ipairs(knownMutations) do State.SelectedMutations[mutName] = false if itemButtons[mutName] then itemButtons[mutName].Text = "  [  ] " .. mutName itemButtons[mutName].TextColor3 = THEME.TextMuted end end
		updateMutBtnLabel()
	end)

	mutBtn.MouseButton1Click:Connect(function() mutDropdownFrame.Visible = not mutDropdownFrame.Visible end)

	local cdCard = Instance.new("Frame", autoHarvestScroll) cdCard.Name = "cdCard" cdCard.Size = UDim2.new(1, 0, 0, 48) cdCard.BackgroundColor3 = THEME.CardBg cdCard.BackgroundTransparency = 0.15
	Theme.AddCorner(cdCard, THEME.CornerCard) Theme.AddStroke(cdCard, THEME.Stroke, 1, 0.5)

	local cdInput = Instance.new("TextBox", cdCard) cdInput.Name = "cdInput" cdInput.Size = UDim2.new(1, -20, 0, 32) cdInput.Position = UDim2.fromOffset(10, 8) cdInput.BackgroundColor3 = THEME.HeaderBg cdInput.Font = Enum.Font.GothamBold cdInput.TextSize = 11 cdInput.TextColor3 = Color3.fromRGB(251, 191, 36) cdInput.Text = "5s (Cooldown Panen)"
	Theme.AddCorner(cdInput, UDim.new(0, 6))

	local toggleHarvestBtn = Instance.new("TextButton", autoHarvestScroll) toggleHarvestBtn.Name = "toggleHarvestBtn" toggleHarvestBtn.Size = UDim2.new(1, 0, 0, 36) toggleHarvestBtn.BackgroundColor3 = THEME.AccentGreen toggleHarvestBtn.Font = Enum.Font.GothamBold toggleHarvestBtn.TextSize = 11 toggleHarvestBtn.TextColor3 = Color3.fromRGB(255, 255, 255) toggleHarvestBtn.Text = "> START AUTO HARVEST"
	Theme.AddCorner(toggleHarvestBtn, THEME.CornerCard)

	modeBtn.MouseButton1Click:Connect(function()
		if State.HarvestMode == "Harvest All" then State.HarvestMode = "Harvest Filter" modeBtn.Text = "Mode Panen: Harvest Filter" modeBtn.TextColor3 = THEME.AccentGreen
		else State.HarvestMode = "Harvest All" modeBtn.Text = "Mode Panen: Harvest All" modeBtn.TextColor3 = Color3.fromRGB(251, 191, 36) end
	end)

	sizeModeBtn.MouseButton1Click:Connect(function()
		if State.SizeMode == "Above" then State.SizeMode = "Below" sizeModeBtn.Text = "Below (<)" else State.SizeMode = "Above" sizeModeBtn.Text = "Above (>)" end
	end)

	sizeInput.FocusLost:Connect(function()
		local num = tonumber(string.match(sizeInput.Text, "%d+%.?%d*"))
		if num then State.SizeThreshold = math.max(0.1, num) sizeInput.Text = tostring(State.SizeThreshold) .. " kg" else sizeInput.Text = tostring(State.SizeThreshold) .. " kg" end
	end)

	cdInput.FocusLost:Connect(function()
		local num = tonumber(string.match(cdInput.Text, "%d+%.?%d*"))
		if num then State.HarvestCooldown = math.max(0.5, num) cdInput.Text = tostring(State.HarvestCooldown) .. "s" else cdInput.Text = tostring(State.HarvestCooldown) .. "s" end
	end)

	toggleHarvestBtn.MouseButton1Click:Connect(function()
		State.AutoHarvestEnabled = not State.AutoHarvestEnabled
		if State.AutoHarvestEnabled then
			toggleHarvestBtn.Text = "STOP AUTO HARVEST" toggleHarvestBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
			task.spawn(function()
				while State.AutoHarvestEnabled and isScriptRunningRef.value and _G.ArcadeHarvestSession == currentSession do
					pcall(function() Farm.scanAndHarvestFruits(State, isScriptRunningRef.value, currentSession, Visual) end)
					Farm.preciseWait(State.HarvestCooldown, State, isScriptRunningRef.value, currentSession)
				end
			end)
		else toggleHarvestBtn.Text = "> START AUTO HARVEST" toggleHarvestBtn.BackgroundColor3 = THEME.AccentGreen end
	end)

	-- Auto Farm Tab
	local autoFarmScroll = createScrollLayout(autoFarmTabContent)

	local posCard = Instance.new("Frame", autoFarmScroll) posCard.Name = "posCard" posCard.Size = UDim2.new(1, 0, 0, 58) posCard.BackgroundColor3 = THEME.CardBg posCard.BackgroundTransparency = 0.15
	Theme.AddCorner(posCard, THEME.CornerCard) Theme.AddStroke(posCard, THEME.Stroke, 1, 0.5)

	local setPosBtn = Instance.new("TextButton", posCard) setPosBtn.Name = "setPosBtn" setPosBtn.Size = UDim2.new(1, -20, 0, 26) setPosBtn.Position = UDim2.fromOffset(10, 6) setPosBtn.BackgroundColor3 = THEME.HeaderBg setPosBtn.Font = Enum.Font.GothamBold setPosBtn.TextSize = 10.5 setPosBtn.TextColor3 = THEME.AccentGreen setPosBtn.Text = "SET TARGET KOORDINAT (NARO/SIRAM)"
	Theme.AddCorner(setPosBtn, UDim.new(0, 6))

	local posStatusLbl = Instance.new("TextLabel", posCard) posStatusLbl.Name = "posStatusLbl" posStatusLbl.Size = UDim2.new(1, -20, 0, 16) posStatusLbl.Position = UDim2.fromOffset(10, 36) posStatusLbl.BackgroundTransparency = 1 posStatusLbl.Font = Enum.Font.Gotham posStatusLbl.TextSize = 9.5 posStatusLbl.TextColor3 = THEME.TextSub posStatusLbl.Text = "Target Koordinat: Belum Di-set" posStatusLbl.TextXAlignment = Enum.TextXAlignment.Center

	setPosBtn.MouseButton1Click:Connect(function()
		local char = LocalPlayer.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			State.TargetVector3 = char.HumanoidRootPart.Position
			posStatusLbl.Text = string.format("Target Vector3: (X:%.1f, Y:%.1f, Z:%.1f)", State.TargetVector3.X, State.TargetVector3.Y, State.TargetVector3.Z)
			posStatusLbl.TextColor3 = THEME.AccentGreen
		end
	end)

	local sprCard = Instance.new("Frame", autoFarmScroll) sprCard.Name = "sprCard" sprCard.Size = UDim2.new(1, 0, 0, 48) sprCard.BackgroundColor3 = THEME.CardBg sprCard.BackgroundTransparency = 0.15
	Theme.AddCorner(sprCard, THEME.CornerCard) Theme.AddStroke(sprCard, THEME.Stroke, 1, 0.5)

	local sprBtn = Instance.new("TextButton", sprCard) sprBtn.Name = "sprBtn" sprBtn.Size = UDim2.new(0.68, -10, 0, 32) sprBtn.Position = UDim2.fromOffset(10, 8) sprBtn.BackgroundColor3 = THEME.HeaderBg sprBtn.Font = Enum.Font.GothamMedium sprBtn.TextSize = 10 sprBtn.TextColor3 = THEME.TextMain sprBtn.Text = "  Geledah Sprinkler..." sprBtn.TextXAlignment = Enum.TextXAlignment.Left
	Theme.AddCorner(sprBtn, UDim.new(0, 6))

	local sprCdInput = Instance.new("TextBox", sprCard) sprCdInput.Name = "sprCdInput" sprCdInput.Size = UDim2.new(0.28, -10, 0, 32) sprCdInput.Position = UDim2.new(0.72, 0, 0, 8) sprCdInput.BackgroundColor3 = THEME.HeaderBg sprCdInput.Font = Enum.Font.GothamBold sprCdInput.TextSize = 11 sprCdInput.TextColor3 = THEME.AccentGreen sprCdInput.Text = "120s"
	Theme.AddCorner(sprCdInput, UDim.new(0, 6))

	local waterCard = Instance.new("Frame", autoFarmScroll) waterCard.Name = "waterCard" waterCard.Size = UDim2.new(1, 0, 0, 48) waterCard.BackgroundColor3 = THEME.CardBg waterCard.BackgroundTransparency = 0.15
	Theme.AddCorner(waterCard, THEME.CornerCard) Theme.AddStroke(waterCard, THEME.Stroke, 1, 0.5)

	local waterBtn = Instance.new("TextButton", waterCard) waterBtn.Name = "waterBtn" waterBtn.Size = UDim2.new(0.68, -10, 0, 32) waterBtn.Position = UDim2.fromOffset(10, 8) waterBtn.BackgroundColor3 = THEME.HeaderBg waterBtn.Font = Enum.Font.GothamMedium waterBtn.TextSize = 10 waterBtn.TextColor3 = THEME.TextMain waterBtn.Text = "  Geledah Penyiram..." waterBtn.TextXAlignment = Enum.TextXAlignment.Left
	Theme.AddCorner(waterBtn, UDim.new(0, 6))

	local waterCdInput = Instance.new("TextBox", waterCard) waterCdInput.Name = "waterCdInput" waterCdInput.Size = UDim2.new(0.28, -10, 0, 32) waterCdInput.Position = UDim2.new(0.72, 0, 0, 8) waterCdInput.BackgroundColor3 = THEME.HeaderBg waterCdInput.Font = Enum.Font.GothamBold waterCdInput.TextSize = 11 waterCdInput.TextColor3 = THEME.AccentGreen waterCdInput.Text = "30s"
	Theme.AddCorner(waterCdInput, UDim.new(0, 6))

	local function populateInitialFarmLabels()
		Farm.refreshToolCache(scriptConnections)
		if #Farm.toolCache.sprinkler > 0 then State.SelectedSprinkler = Farm.toolCache.sprinkler[1].Name sprBtn.Text = string.format("  [1/%d] %s", #Farm.toolCache.sprinkler, State.SelectedSprinkler) sprBtn.TextColor3 = THEME.AccentGreen end
		if #Farm.toolCache.water > 0 then State.SelectedWaterCan = Farm.toolCache.water[1].Name waterBtn.Text = string.format("  [1/%d] %s", #Farm.toolCache.water, State.SelectedWaterCan) waterBtn.TextColor3 = THEME.AccentGreen end
	end
	populateInitialFarmLabels()

	sprBtn.MouseButton1Click:Connect(function()
		Farm.refreshToolCache(scriptConnections)
		if #Farm.toolCache.sprinkler == 0 then State.SelectedSprinkler = nil sprBtn.Text = "  Gak ada Sprinkler di Tas!" sprBtn.TextColor3 = Color3.fromRGB(239, 68, 68)
		else local currentName = State.SelectedSprinkler local currentIdx = 0 for i, tool in ipairs(Farm.toolCache.sprinkler) do if tool.Name == currentName then currentIdx = i break end end local nextIdx = (currentIdx % #Farm.toolCache.sprinkler) + 1 State.SelectedSprinkler = Farm.toolCache.sprinkler[nextIdx].Name sprBtn.Text = string.format("  [%d/%d] %s", nextIdx, #Farm.toolCache.sprinkler, State.SelectedSprinkler) sprBtn.TextColor3 = THEME.AccentGreen end
	end)

	waterBtn.MouseButton1Click:Connect(function()
		Farm.refreshToolCache(scriptConnections)
		if #Farm.toolCache.water == 0 then State.SelectedWaterCan = nil waterBtn.Text = "  Gak ada Penyiram di Tas!" waterBtn.TextColor3 = Color3.fromRGB(239, 68, 68)
		else local currentName = State.SelectedWaterCan local currentIdx = 0 for i, tool in ipairs(Farm.toolCache.water) do if tool.Name == currentName then currentIdx = i break end end local nextIdx = (currentIdx % #Farm.toolCache.water) + 1 State.SelectedWaterCan = Farm.toolCache.water[nextIdx].Name waterBtn.Text = string.format("  [%d/%d] %s", nextIdx, #Farm.toolCache.water, State.SelectedWaterCan) waterBtn.TextColor3 = THEME.AccentGreen end
	end)

	sprCdInput.FocusLost:Connect(function()
		local num = tonumber(string.match(sprCdInput.Text, "%d+%.?%d*"))
		if num then State.SprinklerCooldown = math.max(0.5, num) sprCdInput.Text = tostring(State.SprinklerCooldown) .. "s" else sprCdInput.Text = tostring(State.SprinklerCooldown) .. "s" end
	end)

	waterCdInput.FocusLost:Connect(function()
		local num = tonumber(string.match(waterCdInput.Text, "%d+%.?%d*"))
		if num then State.WateringCooldown = math.max(0.5, num) waterCdInput.Text = tostring(State.WateringCooldown) .. "s" else waterCdInput.Text = tostring(State.WateringCooldown) .. "s" end
	end)

	local toggleFarmBtn = Instance.new("TextButton", autoFarmScroll) toggleFarmBtn.Name = "toggleFarmBtn" toggleFarmBtn.Size = UDim2.new(1, 0, 0, 36) toggleFarmBtn.BackgroundColor3 = THEME.AccentGreen toggleFarmBtn.Font = Enum.Font.GothamBold toggleFarmBtn.TextSize = 11 toggleFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255) toggleFarmBtn.Text = "> START DIRECT REMOTE AUTO FARM"
	Theme.AddCorner(toggleFarmBtn, THEME.CornerCard)

	toggleFarmBtn.MouseButton1Click:Connect(function()
		State.AutoFarmEnabled = not State.AutoFarmEnabled
		if State.AutoFarmEnabled then
			toggleFarmBtn.Text = "STOP AUTO FARM" toggleFarmBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
			task.spawn(function()
				local lastSprinklerTime = 0
				while State.AutoFarmEnabled and isScriptRunningRef.value and _G.ArcadeFarmSession == currentSession do
					local now = os.clock()
					if lastSprinklerTime == 0 or (now - lastSprinklerTime >= State.SprinklerCooldown) then
						local sprinklerPlaced = false pcall(function() sprinklerPlaced = Farm.fireSprinklerRemote(State) end)
						if sprinklerPlaced then
							lastSprinklerTime = os.clock()
							local refPos = State.TargetVector3 or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position)
							if refPos then Farm.teleportPlayerPostSprinkler(refPos) end
							task.wait(0.5)
						end
					end
					local isWatered = false pcall(function() isWatered = Farm.fireWateringCanRemote(State) end)
					if isWatered then Farm.preciseWait(State.WateringCooldown, State, isScriptRunningRef.value, currentSession) else Farm.preciseWait(2, State, isScriptRunningRef.value, currentSession) end
				end
			end)
		else toggleFarmBtn.Text = "> START DIRECT REMOTE AUTO FARM" toggleFarmBtn.BackgroundColor3 = THEME.AccentGreen end
	end)

	-- Mail Tool Tab
	local mailContainer = Instance.new("Frame", mailTabContent) mailContainer.Name = "mailContainer" mailContainer.Size = UDim2.new(1, 0, 1, 0) mailContainer.BackgroundTransparency = 1
	Theme.AddPadding(mailContainer, 4, 0, 4, 4)

	local recCard = Instance.new("Frame", mailContainer) recCard.Name = "recCard" recCard.Size = UDim2.new(1, 0, 0, 32) recCard.BackgroundColor3 = THEME.CardBg recCard.BackgroundTransparency = 0.15
	Theme.AddCorner(recCard, THEME.CornerControl) local recStroke = Theme.AddStroke(recCard, THEME.Stroke, 1, 0.5)

	local recipientBox = Instance.new("TextBox", recCard) recipientBox.Name = "recipientBox" recipientBox.Size = UDim2.new(1, -20, 1, 0) recipientBox.Position = UDim2.fromOffset(10, 0) recipientBox.BackgroundTransparency = 1 recipientBox.Font = Enum.Font.GothamMedium recipientBox.TextSize = 11 recipientBox.TextColor3 = THEME.TextMain recipientBox.PlaceholderText = "Recipient Roblox Username..." recipientBox.PlaceholderColor3 = THEME.TextMuted recipientBox.Text = ""
	recipientBox.Focused:Connect(function() Theme.Tween(recStroke, { Color = THEME.StrokeFocus, Transparency = 0 }, 0.2) end)
	recipientBox.FocusLost:Connect(function() Theme.Tween(recStroke, { Color = THEME.Stroke, Transparency = 0.5 }, 0.2) end)

	local catDropdownBtn = Instance.new("TextButton", mailContainer) catDropdownBtn.Name = "catDropdownBtn" catDropdownBtn.Size = UDim2.new(1, 0, 0, 30) catDropdownBtn.Position = UDim2.fromOffset(0, 38) catDropdownBtn.BackgroundColor3 = THEME.CardBg catDropdownBtn.BackgroundTransparency = 0.15 catDropdownBtn.Font = Enum.Font.GothamMedium catDropdownBtn.TextSize = 11 catDropdownBtn.TextColor3 = THEME.TextMain catDropdownBtn.Text = "  Category: Pets  v" catDropdownBtn.TextXAlignment = Enum.TextXAlignment.Left
	Theme.AddCorner(catDropdownBtn, THEME.CornerControl) Theme.AddStroke(catDropdownBtn, THEME.Stroke, 1, 0.5)

	local catPopupFrame = Instance.new("ScrollingFrame", mailContainer) catPopupFrame.Name = "catPopupFrame" catPopupFrame.Size = UDim2.new(1, 0, 0, 110) catPopupFrame.Position = UDim2.fromOffset(0, 72) catPopupFrame.BackgroundColor3 = THEME.HeaderBg catPopupFrame.BorderSizePixel = 0 catPopupFrame.CanvasSize = UDim2.fromOffset(0, #Inventory.CATEGORIES * 26) catPopupFrame.ScrollBarThickness = 3 catPopupFrame.Visible = false catPopupFrame.ZIndex = 40
	Theme.AddCorner(catPopupFrame, THEME.CornerControl) Theme.AddStroke(catPopupFrame, THEME.StrokeFocus, 1, 0)
	local catPopList = Instance.new("UIListLayout", catPopupFrame) catPopList.Padding = UDim.new(0, 2)

	for _, catName in ipairs(Inventory.CATEGORIES) do
		local cBtn = Instance.new("TextButton", catPopupFrame) cBtn.Name = "CatBtn_" .. catName cBtn.Size = UDim2.new(0.96, 0, 0, 24) cBtn.BackgroundColor3 = THEME.CardBg cBtn.Text = "  " .. catName cBtn.Font = Enum.Font.GothamMedium cBtn.TextSize = 10 cBtn.TextColor3 = THEME.TextMain cBtn.TextXAlignment = Enum.TextXAlignment.Left cBtn.ZIndex = 41
		Theme.AddCorner(cBtn, UDim.new(0, 4))
		cBtn.MouseButton1Click:Connect(function()
			Inventory.MailUI.SelectedCategory = catName Inventory.MailUI.SelectedItemKey = nil catDropdownBtn.Text = "  Category: " .. catName .. "  v" catPopupFrame.Visible = false
		end)
	end
	catDropdownBtn.MouseButton1Click:Connect(function() catPopupFrame.Visible = not catPopupFrame.Visible end)

	local itemPickerBtn = Instance.new("TextButton", mailContainer) itemPickerBtn.Name = "itemPickerBtn" itemPickerBtn.Size = UDim2.new(1, 0, 0, 30) itemPickerBtn.Position = UDim2.fromOffset(0, 74) itemPickerBtn.BackgroundColor3 = THEME.CardBg itemPickerBtn.BackgroundTransparency = 0.15 itemPickerBtn.Font = Enum.Font.GothamMedium itemPickerBtn.TextSize = 11 itemPickerBtn.TextColor3 = THEME.TextSub itemPickerBtn.Text = "  Select Item from Inventory...  v" itemPickerBtn.TextXAlignment = Enum.TextXAlignment.Left
	Theme.AddCorner(itemPickerBtn, THEME.CornerControl) Theme.AddStroke(itemPickerBtn, THEME.Stroke, 1, 0.5)

	local itemPopupFrame = Instance.new("ScrollingFrame", mailContainer) itemPopupFrame.Name = "itemPopupFrame" itemPopupFrame.Size = UDim2.new(1, 0, 0, 110) itemPopupFrame.Position = UDim2.fromOffset(0, 108) itemPopupFrame.BackgroundColor3 = THEME.HeaderBg itemPopupFrame.BorderSizePixel = 0 itemPopupFrame.CanvasSize = UDim2.fromOffset(0, 0) itemPopupFrame.ScrollBarThickness = 3 itemPopupFrame.Visible = false itemPopupFrame.ZIndex = 30
	Theme.AddCorner(itemPopupFrame, THEME.CornerControl) Theme.AddStroke(itemPopupFrame, THEME.StrokeFocus, 1.2, 0)
	local dropList = Instance.new("UIListLayout", itemPopupFrame) dropList.Padding = UDim.new(0, 4)

	local function populateItemDropdown()
		for _, child in ipairs(itemPopupFrame:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
		local items = Inventory.listCategoryItems(Inventory.MailUI.SelectedCategory, Visual)
		if #items == 0 then itemPickerBtn.Text = "  No items in category: " .. Inventory.MailUI.SelectedCategory itemPickerBtn.TextColor3 = Color3.fromRGB(239, 68, 68) return end

		for _, item in ipairs(items) do
			local row = Instance.new("TextButton", itemPopupFrame) row.Name = "ItemRow_" .. item.itemKey row.Size = UDim2.new(0.96, 0, 0, 24) row.BackgroundColor3 = THEME.CardBg row.Text = "" row.ZIndex = 31
			Theme.AddCorner(row, UDim.new(0, 4))
			local nameLbl = Instance.new("TextLabel", row) nameLbl.Size = UDim2.new(0.65, 0, 1, 0) nameLbl.Position = UDim2.fromOffset(8, 0) nameLbl.BackgroundTransparency = 1 nameLbl.Text = item.displayName nameLbl.Font = Enum.Font.GothamMedium nameLbl.TextSize = 10 nameLbl.TextColor3 = THEME.TextMain nameLbl.TextXAlignment = Enum.TextXAlignment.Left nameLbl.ZIndex = 32
			local countBadge = Instance.new("TextLabel", row) countBadge.Size = UDim2.new(0.28, 0, 0, 16) countBadge.Position = UDim2.new(0.7, 0, 0.5, -8) countBadge.BackgroundColor3 = THEME.HeaderBg countBadge.Text = "Stock: " .. item.count countBadge.Font = Enum.Font.GothamBold countBadge.TextSize = 9 countBadge.TextColor3 = THEME.AccentIndigo countBadge.ZIndex = 32
			Theme.AddCorner(countBadge, UDim.new(0, 4))
			row.MouseButton1Click:Connect(function()
				Inventory.MailUI.SelectedItemKey = item.itemKey itemPickerBtn.Text = "  " .. item.displayName .. " (Stock: " .. item.count .. ")" itemPickerBtn.TextColor3 = THEME.TextMain itemPopupFrame.Visible = false
			end)
		end
		itemPopupFrame.CanvasSize = UDim2.fromOffset(0, #items * 28)
	end

	itemPickerBtn.MouseButton1Click:Connect(function() catPopupFrame.Visible = false itemPopupFrame.Visible = not itemPopupFrame.Visible if itemPopupFrame.Visible then populateItemDropdown() end end)

	local addRow = Instance.new("Frame", mailContainer) addRow.Name = "addRow" addRow.Size = UDim2.new(1, 0, 0, 30) addRow.Position = UDim2.fromOffset(0, 110) addRow.BackgroundTransparency = 1
	local qtyInputBox = Instance.new("TextBox", addRow) qtyInputBox.Name = "qtyInputBox" qtyInputBox.Size = UDim2.new(0.35, 0, 1, 0) qtyInputBox.BackgroundColor3 = THEME.CardBg qtyInputBox.BackgroundTransparency = 0.15 qtyInputBox.Font = Enum.Font.GothamBold qtyInputBox.TextSize = 11 qtyInputBox.TextColor3 = THEME.AccentIndigo qtyInputBox.PlaceholderText = "Qty (Def: 1)" qtyInputBox.PlaceholderColor3 = THEME.TextMuted qtyInputBox.Text = "1"
	Theme.AddCorner(qtyInputBox, THEME.CornerControl) Theme.AddStroke(qtyInputBox, THEME.Stroke, 1, 0.5)

	local addCartBtn = Instance.new("TextButton", addRow) addCartBtn.Name = "addCartBtn" addCartBtn.Size = UDim2.new(0.62, 0, 1, 0) addCartBtn.Position = UDim2.new(0.38, 0, 0, 0) addCartBtn.BackgroundColor3 = THEME.AccentPurple addCartBtn.Font = Enum.Font.GothamBold addCartBtn.TextSize = 11 addCartBtn.TextColor3 = Color3.fromRGB(255, 255, 255) addCartBtn.Text = "+ Add to Cart"
	Theme.AddCorner(addCartBtn, THEME.CornerControl)

	local cartFrame = Instance.new("ScrollingFrame", mailContainer) cartFrame.Name = "cartFrame" cartFrame.Size = UDim2.new(1, 0, 0, 95) cartFrame.Position = UDim2.fromOffset(0, 146) cartFrame.BackgroundColor3 = THEME.CardBg cartFrame.BackgroundTransparency = 0.15 cartFrame.BorderSizePixel = 0 cartFrame.CanvasSize = UDim2.fromOffset(0, 0) cartFrame.ScrollBarThickness = 3
	Theme.AddCorner(cartFrame, THEME.CornerControl) Theme.AddStroke(cartFrame, THEME.Stroke, 1, 0.5)
	local cartList = Instance.new("UIListLayout", cartFrame) cartList.Padding = UDim.new(0, 4)
	local cartPadIn = Instance.new("UIPadding", cartFrame) cartPadIn.PaddingTop = UDim.new(0, 4) cartPadIn.PaddingLeft = UDim.new(0, 4)

	local function refreshCartUI()
		for _, child in ipairs(cartFrame:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
		for idx, entry in ipairs(Inventory.MailUI.Cart) do
			local row = Instance.new("Frame", cartFrame) row.Name = "CartRow_" .. idx row.Size = UDim2.new(0.96, 0, 0, 24) row.BackgroundColor3 = THEME.HeaderBg
			Theme.AddCorner(row, UDim.new(0, 4))
			local nameLbl = Instance.new("TextLabel", row) nameLbl.Size = UDim2.new(0.55, 0, 1, 0) nameLbl.Position = UDim2.fromOffset(8, 0) nameLbl.BackgroundTransparency = 1 nameLbl.Text = entry.itemKey .. " [" .. entry.category .. "]" nameLbl.Font = Enum.Font.GothamMedium nameLbl.TextSize = 10 nameLbl.TextColor3 = THEME.TextMain nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			local countBox = Instance.new("TextBox", row) countBox.Name = "countBox" countBox.Size = UDim2.fromOffset(36, 16) countBox.Position = UDim2.new(1, -65, 0.5, -8) countBox.BackgroundColor3 = THEME.CardBg countBox.Text = tostring(entry.sendCount) countBox.Font = Enum.Font.GothamBold countBox.TextSize = 9.5 countBox.TextColor3 = THEME.AccentIndigo
			Theme.AddCorner(countBox, UDim.new(0, 4))
			countBox.FocusLost:Connect(function() local num = tonumber(countBox.Text) or 1 entry.sendCount = math.clamp(math.floor(num), 1, math.max(1, entry.maxAvailable)) countBox.Text = tostring(entry.sendCount) end)
			local delBtn = Instance.new("TextButton", row) delBtn.Name = "delBtn" delBtn.Size = UDim2.fromOffset(18, 16) delBtn.Position = UDim2.new(1, -22, 0.5, -8) delBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68) delBtn.Text = "x" delBtn.Font = Enum.Font.GothamBold delBtn.TextSize = 9 delBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			Theme.AddCorner(delBtn, UDim.new(0, 4))
			delBtn.MouseButton1Click:Connect(function() table.remove(Inventory.MailUI.Cart, idx) refreshCartUI() end)
		end
		cartFrame.CanvasSize = UDim2.fromOffset(0, #Inventory.MailUI.Cart * 28)
	end

	addCartBtn.MouseButton1Click:Connect(function()
		if not Inventory.MailUI.SelectedItemKey then return end
		local available = Inventory.getAvailableCount(Inventory.MailUI.SelectedCategory, Inventory.MailUI.SelectedItemKey, Visual)
		if available <= 0 then return end
		local userQty = tonumber(qtyInputBox.Text) or 1
		local clampedQty = math.clamp(math.floor(userQty), 1, available)
		for _, entry in ipairs(Inventory.MailUI.Cart) do
			if entry.category == Inventory.MailUI.SelectedCategory and entry.itemKey == Inventory.MailUI.SelectedItemKey then
				entry.sendCount = math.clamp(entry.sendCount + clampedQty, 1, available) refreshCartUI() return
			end
		end
		table.insert(Inventory.MailUI.Cart, { category = Inventory.MailUI.SelectedCategory, itemKey = Inventory.MailUI.SelectedItemKey, sendCount = clampedQty, maxAvailable = available })
		refreshCartUI()
	end)

	local statusLabel = Instance.new("TextLabel", mailContainer) statusLabel.Name = "statusLabel" statusLabel.Size = UDim2.new(1, 0, 0, 14) statusLabel.Position = UDim2.fromOffset(0, 246) statusLabel.BackgroundTransparency = 1 statusLabel.Font = Enum.Font.GothamMedium statusLabel.TextSize = 10 statusLabel.TextColor3 = THEME.TextSub statusLabel.Text = "Cart Ready (0 Items)" statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	local sendBtn = Instance.new("TextButton", mailContainer) sendBtn.Name = "sendBtn" sendBtn.Size = UDim2.new(1, 0, 0, 32) sendBtn.Position = UDim2.fromOffset(0, 264) sendBtn.BackgroundColor3 = THEME.AccentPurple sendBtn.Font = Enum.Font.GothamBold sendBtn.TextSize = 11 sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255) sendBtn.Text = "SEND GIFTS"
	Theme.AddCorner(sendBtn, THEME.CornerControl)

	sendBtn.MouseButton1Click:Connect(function()
		if Inventory.MailUI.Sending then return end
		local recipient = recipientBox.Text
		if recipient == "" or #Inventory.MailUI.Cart == 0 then return end
		Inventory.MailUI.Sending = true sendBtn.Text = "SENDING..." sendBtn.BackgroundColor3 = THEME.Stroke
		task.spawn(function()
			local userId, lookupErr = Inventory.lookupUser(recipient)
			if not userId then statusLabel.Text = "Error: " .. (lookupErr or "Lookup failed") Inventory.MailUI.Sending = false sendBtn.Text = "SEND GIFTS" sendBtn.BackgroundColor3 = THEME.AccentPurple return end
			local allLines = {}
			for _, row in ipairs(Inventory.MailUI.Cart) do
				local lines, err = Inventory.buildLinesForEntry(row.category, row.itemKey, row.sendCount, Visual)
				if not lines then statusLabel.Text = "Error: " .. (err or "Build lines failed") Inventory.MailUI.Sending = false sendBtn.Text = "SEND GIFTS" sendBtn.BackgroundColor3 = THEME.AccentPurple return end
				for _, line in ipairs(lines) do table.insert(allLines, line) end
			end
			local mails = Inventory.packPayloadLines(allLines) statusLabel.Text = string.format("Delivering %d items in %d mails...", #allLines, #mails)
			for i, payload in ipairs(mails) do
				if i > 1 then task.wait(Inventory.MailCfg.sendCooldownSec) end
				local ok, err = Inventory.remoteCall(game:GetService("ReplicatedStorage"):WaitForChild("SharedModules"):WaitForChild("Networking").Mailbox.SendBatch, userId, payload, Inventory.MailCfg.note)
				if not ok then statusLabel.Text = "Error: " .. tostring(err) Inventory.MailUI.Sending = false sendBtn.Text = "SEND GIFTS" sendBtn.BackgroundColor3 = THEME.AccentPurple return end
			end
			statusLabel.Text = "Gifts successfully delivered to " .. recipient .. "!"
			table.clear(Inventory.MailUI.Cart) refreshCartUI() Inventory.MailUI.Sending = false sendBtn.Text = "SEND GIFTS" sendBtn.BackgroundColor3 = THEME.AccentPurple
		end)
	end)

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local query = string.lower(searchBox.Text)
		for name, button in pairs(TabButtons) do
			if query == "" or string.find(string.lower(name), query) then button.Visible = true else button.Visible = false end
		end
	end)

	table.insert(scriptConnections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.RightShift then ScreenGui.Enabled = not ScreenGui.Enabled end
	end))

	return ScreenGui
end

return Gui

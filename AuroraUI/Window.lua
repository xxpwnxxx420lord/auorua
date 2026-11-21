--!strict
-- Aurora UI · Window
-- The 640x430 macOS-style glass window: draggable titlebar, traffic lights,
-- sliding sidebar selection, crossfading pages, live stats, notification
-- banner, minimize-to-pill and hover island.
--
-- Roblox has no runtime backdrop blur, so the glass uses a blurred image
-- sampled behind the window (the blur texture is clipped to the window and
-- tracks its screen position). No separate scenic backdrop is drawn.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Config = require(script.Parent.Config)
local Tab = require(script.Parent.Tab)

-- Neutral frosted-glass noise. The glass must never show a landscape, so this
-- is a colourless frost layer (uploaded from the generated 640x430 texture)
-- rather than a blurred screenshot of a scene.
local DEFAULT_BLUR = "rbxassetid://112811578533426"

local Window = {}
Window.__index = Window

local WIDTH = 640
local HEIGHT = 430
local TITLEBAR = 44
local SIDEBAR = 172
local CONTENT_WIDTH = 468
local CONTENT_HEIGHT = 386
local ITEM_HEIGHT = 36
local ITEM_STEP = 40

-- Sidebar tiles default to the three Figma gradients + glyphs when a tab does
-- not specify its own Badge/Glyph (the normal case for the simple API).
local DEFAULT_BADGES = {
	{ Color3.fromHex("5AC8FA"), Color3.fromHex("0A84FF") },
	{ Color3.fromHex("FFB340"), Color3.fromHex("FF7A00") },
	{ Color3.fromHex("D47BFF"), Color3.fromHex("6E5CE6") },
}
local DEFAULT_GLYPHS = { "grid", "sliders", "paint" }

local function viewport(): Vector2
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1280, 800)
end

-- Tabs can be a plain string, or a table using either the short API names
-- (Title/Icon) or the original ones (Name/Glyph).
local function normalizeTab(spec: any): { [string]: any }
	if type(spec) == "string" then
		return { Name = spec }
	end
	if type(spec) ~= "table" then
		return {}
	end
	local tab: any = spec
	tab.Name = tab.Name or tab.Title
	tab.Glyph = tab.Glyph or tab.Icon
	return tab
end

function Window.new(props: { [string]: any }?)
	local options = props or {}
	local self = setmetatable({}, Window)

	self.Parent = assert(options.Parent, "Aurora.Window requires a Parent")
	self.Context = assert(options.Context, "Aurora.Window requires a Context")
	-- Custom option: theme = { ...token overrides... }
	if typeof(options.Theme) == "table" then
		self.Context:SetTheme(options.Theme, false)
	end
	self.Player = options.Player or Players.LocalPlayer
	self.Tabs = {}
	for index, spec in ipairs(options.Tabs or {}) do
		self.Tabs[index] = normalizeTab(spec)
	end
	self.Title = options.Title or "Aurora"
	self.SubTitle = options.SubTitle or options.Subtitle
	self.BlurredImage = options.BlurredImage or DEFAULT_BLUR
	-- Custom option: background_image: image id
	self.BackgroundImage = options.BackgroundImage or options.background_image or ""
	-- Custom option: starting_tab: int (1-based)
	self.StartingTab = math.max(1, math.floor(tonumber(options.StartingTab or options.starting_tab) or 1))
	self.Pages = {}
	self.TabObjects = {}
	self.ItemLabels = {}
	self.ItemHovers = {}
	self.ActiveIndex = 0
	self.Minimized = false
	self.Closed = false
	self.ZoomFactor = 1
	self.HasMoved = false
	self.StatsChanged = Util.Signal.new()
	self.TabChanged = Util.Signal.new()
	self.ToggleChanged = Util.Signal.new()
	self.ClosedChanged = Util.Signal.new()
	self.Toggles = {}
	self._toggles = {}
	self.Stats = { FPS = 60, Ping = 42, Players = 1, Memory = 0, SessionSeconds = 0 }
	self.StartedAt = os.clock()
	self._transitioning = false
	self._bannerToken = 0
	self._frameCount = 0
	self._frameAcc = 0
	self._dragging = false
	self._dragTilt = 0
	self._dragVelocity = 0
	self._dragBaseScale = 1

	if self.Parent:IsA("ScreenGui") then
		self.Parent.IgnoreGuiInset = true
		self.Parent.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		-- Float above the rest of the game's UI so the window and its shadow
		-- are never covered by another ScreenGui.
		self.Parent.DisplayOrder = math.max(self.Parent.DisplayOrder, 100)
	end

	self:_build()
	self:_startStats()
	self:_watchViewport()
	if #self.Tabs > 0 then
		self:SelectTab(self.StartingTab, false)
	end
	self:_openAnimation()

	-- Register value-only toggles passed as `Toggles = { Name = boolean }`.
	if typeof(options.Toggles) == "table" then
		for name, value in pairs(options.Toggles) do
			self:_installToggle(name, nil, value == true, nil)
		end
	end

	-- Optional autosave/autoload. `Config = "name"` or `Config = true` for
	-- the default "window" profile.
	if options.Config then
		local profile = typeof(options.Config) == "string" and options.Config or "window"
		self.ConfigHandle = Config.attach(self, profile, options.ConfigOptions)
	end

	return self
end

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

function Window:_build()
	local parent = self.Parent
	local ctx = self.Context

	local root = Util.frame({
		Name = "AuroraWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = parent,
	})
	self.Root = root

	local scale = Instance.new("UIScale")
	scale.Parent = root
	self.Scale = scale

	-- The 640x430 offset size already carries the ratio; the constraint keeps
	-- the window square-on if a consumer swaps the root to a scale size, and
	-- documents the aspect for anyone extending the library.
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = WIDTH / HEIGHT
	aspect.AspectType = Enum.AspectType.FitWithinMaxSize
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = root
	self.Aspect = aspect

	------------------------------------------------------------
	-- Shadow · 9-slice drop-shadow asset (StarterGui.DropShadowHolder)
	------------------------------------------------------------
	-- The old stack of flat translucent rectangles read as an ash smear. The
	-- 9-slice shadow follows the window radius and scales cleanly, so the
	-- window looks like it is floating above the scene.
	local shadowHolder = Util.frame({
		Name = "ShadowHolder",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		-- The shadow sits behind the glass but the whole ScreenGui is raised to
		-- DisplayOrder 100, so the window and its shadow show over other UI.
		ZIndex = 0,
		Parent = root,
	})
	self.ShadowHolder = shadowHolder

	self.ShadowImages = {}
	local function shadowLayer(name: string, spread: number, transparency: number): ImageLabel
		local image = Instance.new("ImageLabel")
		image.Name = name
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.new(1, spread, 1, spread)
		image.BackgroundTransparency = 1
		image.BorderSizePixel = 0
		image.Image = "rbxassetid://6014261993"
		image.ImageColor3 = Color3.fromHex("000000")
		image.ImageTransparency = transparency
		image.ScaleType = Enum.ScaleType.Slice
		image.SliceCenter = Rect.new(49, 49, 450, 450)
		image.SliceScale = 1
		image.ZIndex = 0
		image.Parent = shadowHolder
		table.insert(self.ShadowImages, image)
		return image
	end
	-- Exactly the StarterGui.DropShadowHolder setup: one 9-slice layer, 47px
	-- larger than the frame on both axes, centred, 50% black. The shadow hugs
	-- the frame and scales with it, so it never becomes a big ash rectangle.
	self.ShadowAmbient = shadowLayer("DropShadow", 47, 0.50)

	------------------------------------------------------------
	-- Glass surface + frost texture
	------------------------------------------------------------
	local clip = Util.frame({
		Name = "GlassClip",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = root,
	})
	Util.corner(clip, Theme.Radius.Window)
	self.Clip = clip

	-- The frost fills the window exactly. Its own UICorner means the rounded
	-- corners never leak a square image wedge, even if rounded clipping is
	-- composited differently on a given platform.
	local blurImage = Instance.new("ImageLabel")
	blurImage.Name = "Blur"
	blurImage.AnchorPoint = Vector2.new(0, 0)
	blurImage.Position = UDim2.fromOffset(0, 0)
	blurImage.Size = UDim2.fromScale(1, 1)
	blurImage.BackgroundTransparency = 1
	blurImage.BorderSizePixel = 0
	blurImage.ScaleType = Enum.ScaleType.Stretch
	blurImage.Image = self.BlurredImage
	blurImage.ImageColor3 = Color3.fromHex("F2F6FF")
	blurImage.ImageTransparency = 1
	blurImage.ZIndex = 1
	blurImage.Parent = clip
	Util.corner(blurImage, Theme.Radius.Window)
	self.BlurImage = blurImage

	-- Stable dark body. Keeps the glass dark and neutral over any scene without
	-- turning the window into a picture of the scene.
	local depth = Util.frame({
		Name = "GlassDepth",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = ctx.Theme.GlassDepth,
		BackgroundTransparency = ctx.Theme.GlassDepthTransparency,
		ZIndex = 2,
		Parent = clip,
	})
	Util.corner(depth, Theme.Radius.Window)
	self.GlassDepth = depth

	-- Custom option: background_image. Sits above the dark body and below the
	-- tint, so a wallaper still reads as tinted glass rather than a raw photo.
	local background = Instance.new("ImageLabel")
	background.Name = "BackgroundImage"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundTransparency = 1
	background.BorderSizePixel = 0
	background.ScaleType = Enum.ScaleType.Crop
	background.Image = self.BackgroundImage ~= "" and self.BackgroundImage or ""
	background.Visible = self.BackgroundImage ~= ""
	background.ImageTransparency = 0
	background.ZIndex = 2
	background.Parent = clip
	Util.corner(background, Theme.Radius.Window)
	self.BackgroundFrame = background

	local tint = Util.frame({
		Name = "GlassTint",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = ctx.Theme.GlassWindow,
		BackgroundTransparency = ctx.Theme.GlassWindowTransparency,
		ZIndex = 3,
		Parent = clip,
	})
	Util.corner(tint, Theme.Radius.Window)
	self.BlurTint = tint

	local sheen = Util.frame({
		Name = "GlassSheen",
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = clip,
	})
	Util.gradient(
		sheen,
		ColorSequence.new(Color3.new(1, 1, 1)),
		90,
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.952),
			NumberSequenceKeypoint.new(1, 1),
		})
	)
	self.GlassSheen = sheen

	local canvas = Instance.new("CanvasGroup")
	canvas.Name = "Canvas"
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundTransparency = 1
	canvas.ClipsDescendants = true
	canvas.ZIndex = 5
	canvas.Parent = clip
	Util.corner(canvas, Theme.Radius.Window)
	self.Canvas = canvas

	------------------------------------------------------------
	-- Titlebar
	------------------------------------------------------------
	local titlebar = Util.frame({
		Name = "Titlebar",
		Size = UDim2.fromOffset(WIDTH, TITLEBAR),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = canvas,
	})
	self.Titlebar = titlebar

	-- Start the drag strip after the traffic lights so their hover/click work
	-- and the lights are never swallowed by an invisible full-width button.
	local dragArea = Util.button({
		Name = "DragArea",
		Position = UDim2.fromOffset(78, 0),
		Size = UDim2.new(1, -78, 1, 0),
		BackgroundTransparency = 1,
		Active = true,
		Selectable = false,
		ZIndex = 8,
		Parent = titlebar,
	})
	self.DragArea = dragArea
	Util.corner(dragArea, 0)

	local title = Util.text({
		Name = "Title",
		Size = UDim2.fromOffset(WIDTH, TITLEBAR),
		Text = self.SubTitle and (self.Title .. "  ·  " .. self.SubTitle) or self.Title,
		TextSize = 13,
		Font = Theme.Font.Semibold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 6,
		Parent = titlebar,
	})
	self.TitlebarLabel = title

	local separator = Util.frame({
		Name = "Separator",
		Position = UDim2.fromOffset(0, TITLEBAR - 1),
		Size = UDim2.fromOffset(WIDTH, 1),
		BackgroundColor3 = ctx.Theme.StrokeHairline,
		BackgroundTransparency = ctx.Theme.StrokeHairlineTransparency,
		ZIndex = 6,
		Parent = titlebar,
	})
	self.TitleSeparator = separator

	local traffic = Util.frame({
		Name = "TrafficLights",
		Position = UDim2.fromOffset(18, 16),
		Size = UDim2.fromOffset(52, 12),
		BackgroundTransparency = 1,
		ZIndex = 9,
		Parent = titlebar,
	})
	self.Traffic = traffic

	local trafficSpec = {
		{ Name = "Close", Color = ctx.Theme.TrafficClose, Glyph = "×", X = 0, Action = function()
			self:Close()
		end },
		{ Name = "Minimize", Color = ctx.Theme.TrafficMinimize, Glyph = "−", X = 20, Action = function()
			self:Minimize()
		end },
		{ Name = "Zoom", Color = ctx.Theme.TrafficZoom, Glyph = "+", X = 40, Action = function()
			self:ToggleZoom()
		end },
	}
	self.TrafficButtons = {}
	for _, spec in ipairs(trafficSpec) do
		local button = Util.button({
			Name = spec.Name,
			Position = UDim2.fromOffset(spec.X, 0),
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = spec.Color,
			AutoButtonColor = false,
			ZIndex = 10,
			Parent = traffic,
		})
		Util.corner(button, UDim.new(0.5, 0))
		Util.stroke(button, Color3.fromHex("000000"), 0.88, 1)
		local glyph = Util.text({
			Name = "Glyph",
			Size = UDim2.fromScale(1, 1),
			Text = spec.Glyph,
			TextSize = 9,
			Font = Theme.Font.Bold,
			TextColor3 = Color3.fromHex("1A1A1A"),
			TextTransparency = 0.45,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Visible = false,
			ZIndex = 11,
			Parent = button,
		})
		local scaleButton = Instance.new("UIScale")
		scaleButton.Parent = button
		local hovered = false
		button.MouseEnter:Connect(function()
			hovered = true
			glyph.Visible = true
			glyph.TextTransparency = 1
			Util.tween(glyph, { TextTransparency = 0.35 }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			Util.tween(scaleButton, { Scale = 1.18 }, 0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end)
		button.MouseLeave:Connect(function()
			hovered = false
			Util.tween(glyph, { TextTransparency = 1 }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			Util.tween(scaleButton, { Scale = 1 }, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			task.delay(0.13, function()
				if not hovered then
					glyph.Visible = false
				end
			end)
		end)
		button.Activated:Connect(spec.Action)
		table.insert(self.TrafficButtons, button)
	end

	------------------------------------------------------------
	-- Sidebar
	------------------------------------------------------------
	local sidebar = Util.frame({
		Name = "Sidebar",
		Position = UDim2.fromOffset(0, TITLEBAR),
		Size = UDim2.fromOffset(SIDEBAR, HEIGHT - TITLEBAR),
		BackgroundColor3 = ctx.Theme.GlassSidebar,
		BackgroundTransparency = ctx.Theme.GlassSidebarTransparency,
		ZIndex = 2,
		Parent = canvas,
	})
	self.Sidebar = sidebar

	local sidebarDivider = Util.frame({
		Name = "Divider",
		Position = UDim2.fromOffset(SIDEBAR - 1, 0),
		Size = UDim2.fromOffset(1, HEIGHT - TITLEBAR),
		BackgroundColor3 = ctx.Theme.StrokeHairline,
		BackgroundTransparency = ctx.Theme.StrokeHairlineTransparency,
		ZIndex = 3,
		Parent = sidebar,
	})
	self.SidebarDivider = sidebarDivider

	local selection = Util.frame({
		Name = "Selection",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(148, ITEM_HEIGHT),
		BackgroundColor3 = ctx.Theme.GlassSelected,
		BackgroundTransparency = ctx.Theme.GlassSelectedTransparency,
		ZIndex = 2,
		Parent = sidebar,
	})
	Util.corner(selection, Theme.Radius.Item)
	self.Selection = selection

	for index, tab in ipairs(self.Tabs) do
		self:_createSidebarItem(tab, index)
	end

	local footer = Util.frame({
		Name = "Footer",
		Position = UDim2.fromOffset(14, 344),
		Size = UDim2.fromOffset(140, 28),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = sidebar,
	})
	local avatar = Components.Avatar.new({
		Parent = footer,
		Size = 28,
		Initial = self.Player and self.Player.DisplayName:sub(1, 1):upper() or "P",
		DisplayName = self.Player and self.Player.DisplayName or "Player",
		UserId = self.Player and self.Player.UserId or nil,
	})
	avatar.Root.Position = UDim2.fromOffset(0, 0)
	local footerName = Util.text({
		Name = "Name",
		Position = UDim2.fromOffset(36, 0),
		Size = UDim2.fromOffset(104, 15),
		Text = self.Player and self.Player.DisplayName or "Player",
		TextSize = 11,
		Font = Theme.Font.Semibold,
		ZIndex = 3,
		Parent = footer,
	})
	local footerStatus = Util.text({
		Name = "Status",
		Position = UDim2.fromOffset(36, 14),
		Size = UDim2.fromOffset(104, 14),
		Text = "Connected",
		TextSize = 10,
		Font = Theme.Font.Regular,
		ZIndex = 3,
		Parent = footer,
	})
	self.FooterName = footerName
	self.FooterStatus = footerStatus
	self.Avatar = avatar

	------------------------------------------------------------
	-- Content
	------------------------------------------------------------
	local content = Util.frame({
		Name = "Content",
		Position = UDim2.fromOffset(SIDEBAR, TITLEBAR),
		Size = UDim2.fromOffset(CONTENT_WIDTH, CONTENT_HEIGHT),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = canvas,
	})
	self.Content = content

	------------------------------------------------------------
	-- Border
	------------------------------------------------------------
	local border = Util.frame({
		Name = "Border",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = root,
	})
	Util.corner(border, Theme.Radius.Window)
	self.Border = border
	self.BorderStroke = Util.stroke(border, ctx.Theme.StrokeGlass, ctx.Theme.StrokeGlassTransparency, 1)

	------------------------------------------------------------
	-- Overlay, banner and pill
	------------------------------------------------------------
	local overlay = Util.frame({
		Name = "AuroraOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		Selectable = false,
		ZIndex = 100,
		Parent = parent,
	})
	self.Overlay = overlay
	ctx.Overlay = overlay

	self:_buildPill()
	self:_ensureBanner()

	------------------------------------------------------------
	-- Pages
	------------------------------------------------------------
	for index, tab in ipairs(self.Tabs) do
		self:_createPage(tab, index)
	end

	------------------------------------------------------------
	-- Interactions
	------------------------------------------------------------
	Util.makeDraggable(
		root,
		dragArea,
		function(_x: number, _y: number, delta: Vector2)
			self.HasMoved = true
			self._dragVelocity = delta.X
			self:_clampWindow()
		end,
		function()
			if self.Minimized or self._transitioning then
				return
			end
			-- Lift the window while it is held: a small scale-up, a darker
			-- shadow and a velocity-driven tilt make the drag feel physical.
			self._dragging = true
			self._dragBaseScale = self.Scale.Scale
			self._dragTilt = 0
			self._dragVelocity = 0
			Util.tween(self.Scale, { Scale = self._dragBaseScale * 1.012 }, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			self:_applyShadow(self.Context.Theme, 0.22)
			Util.tween(self.BorderStroke, {
				Transparency = math.max(0.45, self.Context.Theme.StrokeGlassTransparency - 0.12),
			}, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		end,
		function()
			if not self._dragging then
				return
			end
			self._dragging = false
			self._dragVelocity = 0
			Util.tween(self.Root, { Rotation = 0 }, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			Util.tween(self.Scale, {
				Scale = self.FitScale * self.ZoomFactor,
			}, 0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			self._dragTilt = 0
			self:_applyShadow(self.Context.Theme, 0.34)
			Util.tween(self.BorderStroke, {
				Transparency = self.Context.Theme.StrokeGlassTransparency,
			}, 0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		end
	)

	local lastClick = 0
	dragArea.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local now = os.clock()
		if now - lastClick < 0.32 then
			self:ToggleZoom()
			lastClick = 0
		else
			lastClick = now
		end
	end)

	------------------------------------------------------------
	-- Theme binding
	------------------------------------------------------------
	ctx:Bind(function(t: any, duration: number)
		self:_applyChrome(t, duration)
	end)
end

function Window:_createSidebarItem(tab: any, index: number)
	local ctx = self.Context
	local item = Util.button({
		Name = "Item" .. (tab.Name or index),
		Position = UDim2.fromOffset(12, 12 + (index - 1) * ITEM_STEP),
		Size = UDim2.fromOffset(148, ITEM_HEIGHT),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = self.Sidebar,
	})
	Util.corner(item, Theme.Radius.Item)

	local hover = Util.frame({
		Name = "Hover",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = ctx.Theme.GlassControlHover,
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = item,
	})
	Util.corner(hover, Theme.Radius.Item)
	table.insert(self.ItemHovers, hover)

	local colors = tab.Badge or DEFAULT_BADGES[((index - 1) % #DEFAULT_BADGES) + 1]
	-- Simple tabs usually have no icon; cycle the Figma glyphs so the sidebar
	-- tiles still read as icons. Pass `Icon = ""` to get a flat tile instead.
	local glyph = tab.Glyph
	if glyph == nil and tab.Badge == nil then
		glyph = DEFAULT_GLYPHS[((index - 1) % #DEFAULT_GLYPHS) + 1]
	end
	local badge = Components.Badge.new({
		Parent = item,
		Colors = colors,
		Glyph = glyph,
		Size = 20,
		Radius = 6,
	})
	badge.Root.Position = UDim2.fromOffset(12, 8)
	badge.Root.ZIndex = 3

	local label = Util.text({
		Name = "Label",
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -50, 1, 0),
		Text = tab.Name or ("Tab " .. index),
		TextSize = 13,
		Font = Theme.Font.Medium,
		TextColor3 = ctx.Theme.LabelSecondary,
		TextTransparency = ctx.Theme.LabelSecondaryTransparency,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = item,
	})
	table.insert(self.ItemLabels, label)

	item.MouseEnter:Connect(function()
		Util.tween(hover, { BackgroundTransparency = 0.94 }, Theme.Motion.Hover, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	end)
	item.MouseLeave:Connect(function()
		Util.tween(hover, { BackgroundTransparency = 1 }, Theme.Motion.Fast, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	end)
	item.Activated:Connect(function()
		self:SelectTab(index, true)
	end)
end

function Window:_createPage(tab: any, index: number): any
	local page = Instance.new("CanvasGroup")
	page.Name = tab.Name or ("Page" .. index)
	page.Position = UDim2.fromOffset(0, 0)
	page.Size = UDim2.fromOffset(CONTENT_WIDTH, CONTENT_HEIGHT)
	page.BackgroundTransparency = 1
	page.GroupTransparency = 1
	page.Visible = false
	page.ZIndex = 3
	page.Parent = self.Content
	self.Pages[index] = page

	if tab.Build then
		local ok, err = pcall(tab.Build, page, self.Context, self)
		if not ok then
			warn("[Aurora] Page '" .. tostring(tab.Name) .. "' failed: " .. tostring(err))
		end
		return page
	end

	local tabObject = Tab.new({
		Window = self,
		Context = self.Context,
		Page = page,
		Index = index,
		Title = tab.Name,
	})
	self.TabObjects[index] = tabObject
	return tabObject
end

--------------------------------------------------------------------------------
-- Chrome
--------------------------------------------------------------------------------

function Window:_applyChrome(t: any, duration: number)
	Util.apply(self.GlassDepth, {
		BackgroundColor3 = t.GlassDepth,
		BackgroundTransparency = t.GlassDepthTransparency,
	}, duration)
	Util.apply(self.BlurTint, {
		BackgroundColor3 = t.GlassWindow,
	}, duration)
	Util.apply(self.TitlebarLabel, {
		TextColor3 = t.LabelPrimary,
		TextTransparency = t.LabelPrimaryTransparency,
	}, duration)
	Util.apply(self.TitleSeparator, {
		BackgroundColor3 = t.StrokeHairline,
		BackgroundTransparency = t.StrokeHairlineTransparency,
	}, duration)
	Util.apply(self.Sidebar, {
		BackgroundColor3 = t.GlassSidebar,
		BackgroundTransparency = t.GlassSidebarTransparency,
	}, duration)
	Util.apply(self.SidebarDivider, {
		BackgroundColor3 = t.StrokeHairline,
		BackgroundTransparency = t.StrokeHairlineTransparency,
	}, duration)
	Util.apply(self.Selection, {
		BackgroundColor3 = t.GlassSelected,
		BackgroundTransparency = t.GlassSelectedTransparency,
	}, duration)
	Util.apply(self.BorderStroke, {
		Color = t.StrokeGlass,
		Transparency = t.StrokeGlassTransparency,
	}, duration)
	Util.apply(self.FooterName, {
		TextColor3 = t.LabelPrimary,
		TextTransparency = t.LabelPrimaryTransparency,
	}, duration)
	Util.apply(self.FooterStatus, {
		TextColor3 = t.LabelTertiary,
		TextTransparency = t.LabelTertiaryTransparency,
	}, duration)

	for index, label in ipairs(self.ItemLabels) do
		local selected = index == self.ActiveIndex
		Util.apply(label, {
			TextColor3 = selected and t.LabelPrimary or t.LabelSecondary,
			TextTransparency = selected and t.LabelPrimaryTransparency or t.LabelSecondaryTransparency,
		}, duration)
	end
	for _, hover in ipairs(self.ItemHovers) do
		Util.apply(hover, { BackgroundColor3 = t.GlassControlHover }, duration)
	end

	self:_applyBlurState(t, duration)
	self:_applyPillTheme(t, duration)
	self:_applyShadow(t, duration)
end

function Window:_applyShadow(t: any, duration: number)
	-- One drop shadow only, matching the DropShadowHolder example: 50% black
	-- by default, a touch darker while the window is lifted.
	local drop = 0.50
	if t.Mode == "Light" then
		drop = 0.58
	end
	self.ShadowDropBase = drop
	if self._dragging then
		drop = math.max(0, drop - 0.12)
	end
	Util.apply(self.ShadowAmbient, { ImageTransparency = drop }, duration)
end

-- The frosted layer is a neutral frost texture (not a screenshot of a scene)
-- stretched across the glass. Intensity fades the frost in/out; Glass blur off
-- leaves a clean tinted panel.
function Window:_blurTransparency(): number
	-- A custom background image replaces the frost layer entirely.
	if self.BackgroundImage ~= "" or not self.Context.BlurEnabled or self.BlurredImage == "" then
		return 1
	end
	local intensity = math.clamp(self.Context.GlassIntensity or 75, 0, 100)
	return 1 - (intensity / 100) * 0.95
end

function Window:_applyBlurState(t: any?, duration: number?)
	local theme = t or self.Context.Theme
	local blurOn = self.Context.BlurEnabled and self.BlurredImage ~= "" and self.BackgroundImage == ""
	local transparency = theme.GlassWindowTransparency - (blurOn and 0 or 0.04)
	Util.apply(self.BlurTint, {
		BackgroundColor3 = theme.GlassWindow,
		BackgroundTransparency = math.clamp(transparency, 0, 0.95),
	}, duration or 0)
	local imageTransparency = self:_blurTransparency()
	Util.apply(self.BlurImage, { ImageTransparency = imageTransparency }, duration or 0)
	self.BlurImage.Visible = imageTransparency < 0.999
end

function Window:_applyPillTheme(t: any, duration: number)
	local pill = self.Pill
	Util.apply(pill, {
		BackgroundColor3 = t.GlassPill,
		BackgroundTransparency = t.GlassPillTransparency,
	}, duration)
	Util.apply(self.PillStroke, {
		Color = t.StrokeGlass,
		Transparency = t.StrokeGlassTransparency,
	}, duration)
	Util.apply(self.PillTitle, {
		TextColor3 = t.LabelPrimary,
		TextTransparency = t.LabelPrimaryTransparency,
	}, duration)
	Util.apply(self.PillDivider, {
		BackgroundColor3 = t.StrokeHairline,
		BackgroundTransparency = self.PillExpanded and t.StrokeHairlineTransparency or 1,
	}, duration)
	Util.apply(self.PillCore, { BackgroundColor3 = t.Accent }, duration)
	self.PillGradient.Color = t.HeroGradient
	Util.apply(self.PillStats, {
		TextColor3 = t.LabelPrimary,
		TextTransparency = t.LabelPrimaryTransparency,
	}, duration)
	self:_updatePillStats(t)
end

--------------------------------------------------------------------------------
-- Pill
--------------------------------------------------------------------------------

function Window:_buildPill()
	local ctx = self.Context
	local pill = Util.button({
		Name = "AuroraPill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.fromOffset(109, 44),
		BackgroundColor3 = ctx.Theme.GlassPill,
		BackgroundTransparency = ctx.Theme.GlassPillTransparency,
		AutoButtonColor = false,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 90,
		Parent = self.Overlay,
	})
	Util.corner(pill, UDim.new(0.5, 0))
	self.Pill = pill
	self.PillStroke = Util.stroke(pill, ctx.Theme.StrokeGlass, ctx.Theme.StrokeGlassTransparency, 1)

	local pillScale = Instance.new("UIScale")
	pillScale.Parent = pill
	self.PillScale = pillScale

	local glyph = Util.frame({
		Name = "Glyph",
		Position = UDim2.fromOffset(9, 9),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = pill,
	})
	Util.corner(glyph, UDim.new(0.5, 0))
	Util.stroke(glyph, Color3.new(1, 1, 1), 0.62, 1.5)
	local glow = Util.frame({
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(17, 17),
		BackgroundColor3 = ctx.Theme.Accent,
		BackgroundTransparency = 0.8,
		ZIndex = 2,
		Parent = glyph,
	})
	Util.corner(glow, UDim.new(0.5, 0))
	local core = Util.frame({
		Name = "Core",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = ctx.Theme.Accent,
		ZIndex = 3,
		Parent = glyph,
	})
	Util.corner(core, UDim.new(0.5, 0))
	local coreGradient = Util.gradient(core, ctx.Theme.HeroGradient, 30)
	self.PillGlyph = glyph
	self.PillGlow = glow
	self.PillCore = core
	self.PillGradient = coreGradient

	local title = Util.text({
		Name = "Title",
		Position = UDim2.fromOffset(45, 13.5),
		Size = UDim2.fromOffset(52, 17),
		Text = self.Title,
		TextSize = 13,
		Font = Theme.Font.Semibold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = pill,
	})
	self.PillTitle = title

	local divider = Util.frame({
		Name = "Divider",
		Position = UDim2.fromOffset(101, 16),
		Size = UDim2.fromOffset(1, 20),
		BackgroundColor3 = ctx.Theme.StrokeHairline,
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = pill,
	})
	self.PillDivider = divider

	local stats = Util.text({
		Name = "Stats",
		Position = UDim2.fromOffset(112, 18),
		Size = UDim2.fromOffset(214, 16),
		Text = "",
		TextSize = 12,
		Font = Theme.Font.Medium,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 2,
		Parent = pill,
	})
	self.PillStats = stats

	pill.MouseEnter:Connect(function()
		if not self.Minimized then
			return
		end
		self.PillExpanded = true
		Util.tween(pill, { Size = UDim2.fromOffset(340, 52) }, Theme.Motion.Pill, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		Util.tween(glyph, { Position = UDim2.fromOffset(9, 13) }, Theme.Motion.Pill, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		Util.tween(title, { Position = UDim2.fromOffset(45, 17.5) }, Theme.Motion.Pill, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		Util.tween(divider, {
			BackgroundTransparency = self.Context.Theme.StrokeHairlineTransparency,
		}, Theme.Motion.Pill, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	end)
	pill.MouseLeave:Connect(function()
		if not self.Minimized then
			return
		end
		self.PillExpanded = false
		Util.tween(pill, { Size = UDim2.fromOffset(109, 44) }, Theme.Motion.PillOut, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		Util.tween(glyph, { Position = UDim2.fromOffset(9, 9) }, Theme.Motion.PillOut, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		Util.tween(title, { Position = UDim2.fromOffset(45, 13.5) }, Theme.Motion.PillOut, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		Util.tween(divider, { BackgroundTransparency = 1 }, Theme.Motion.PillOut, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	end)

	pill.Activated:Connect(function()
		self:Restore()
	end)

	self:_updatePillStats(self.Context.Theme)
end

function Window:_updatePillStats(t: any?)
	local theme = t or self.Context.Theme
	local tertiary = Util.toHex(theme.LabelTertiary)
	local stats = self.Stats
	self.PillStats.Text = string.format(
		"%d <font color=\"%s\">FPS</font>   %d <font color=\"%s\">ms</font>   %d <font color=\"%s\">Players</font>",
		stats.FPS,
		tertiary,
		stats.Ping,
		tertiary,
		stats.Players,
		tertiary
	)
end

--------------------------------------------------------------------------------
-- Banner
--------------------------------------------------------------------------------

function Window:_ensureBanner()
	if self.Banner then
		return
	end
	local banner = Components.Banner.new({
		Parent = self.Overlay,
		Context = self.Context,
		Title = "Settings applied",
		Body = "Your changes have been saved.",
		Time = "now",
	})
	banner.Root.ZIndex = 80
	local bannerScale = Instance.new("UIScale")
	bannerScale.Parent = banner.Root
	self.BannerScale = bannerScale
	self.Banner = banner
end

function Window:UpdateBannerPositions()
	local fit = self.FitScale or 1
	local vp = self:_viewport()
	self.Banner.ShownPosition = UDim2.fromOffset(vp.X - 340 * fit - 24, 24)
	self.Banner.HiddenPosition = UDim2.fromOffset(vp.X + 24, 24)
	if self.BannerScale then
		self.BannerScale.Scale = fit
	end
end

function Window:ShowBanner(options: { [string]: any }?)
	local opts = options or {}
	if self.Minimized or self.Closed then
		return
	end
	self:_ensureBanner()
	self:UpdateBannerPositions()
	self.Banner:SetContent(
		opts.Title or "Settings applied",
		opts.Body or "Your changes have been saved.",
		opts.Time or "now"
	)
	self.Banner:Show()
	self._bannerToken += 1
	local token = self._bannerToken
	local duration = opts.Duration
	if duration == nil then
		duration = 3.6
	end
	-- Duration = false keeps the banner up until the next notification.
	if duration ~= false then
		task.delay(duration, function()
			if token == self._bannerToken then
				self.Banner:Hide()
			end
		end)
	end
end

-- Simple API alias. Accepts a string title or the same table as ShowBanner.
-- Duration = false keeps the banner on screen.
function Window:Notify(options: any)
	local opts = type(options) == "string" and { Title = options } or (options or {})
	local duration = opts.Duration
	if duration == nil then
		duration = opts.duration
	end
	self:ShowBanner({
		Title = opts.Title or opts.title or "Aurora",
		Body = opts.Content or opts.Body or opts.content or opts.body or "",
		Time = opts.Time or opts.time or "now",
		Duration = duration,
	})
end

--------------------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------------------

function Window:AddTab(spec: any): any
	local tab = normalizeTab(spec)
	table.insert(self.Tabs, tab)
	local index = #self.Tabs
	self:_createSidebarItem(tab, index)
	local result = self:_createPage(tab, index)
	if self.ActiveIndex == 0 then
		self:SelectTab(index, false)
	end
	return result
end

function Window:GetTab(key: number | string): any
	if type(key) == "string" then
		for index, tab in ipairs(self.Tabs) do
			if tab.Name == key then
				return self.TabObjects[index] or self.Pages[index]
			end
		end
		return nil
	end
	return self.TabObjects[key] or self.Pages[key]
end

function Window:SelectTab(index: number, animate: boolean?)
	if #self.Tabs == 0 then
		return
	end
	local target = math.clamp(math.floor(index), 1, #self.Tabs)
	if target == self.ActiveIndex then
		return
	end
	local previous = self.ActiveIndex
	self.ActiveIndex = target

	local selectionY = 12 + (target - 1) * ITEM_STEP
	if animate ~= false then
		Util.tween(self.Selection, { Position = UDim2.fromOffset(12, selectionY) }, Theme.Motion.Tab, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	else
		self.Selection.Position = UDim2.fromOffset(12, selectionY)
	end

	local t = self.Context.Theme
	for itemIndex, label in ipairs(self.ItemLabels) do
		local selected = itemIndex == target
		Util.apply(label, {
			TextColor3 = selected and t.LabelPrimary or t.LabelSecondary,
			TextTransparency = selected and t.LabelPrimaryTransparency or t.LabelSecondaryTransparency,
		}, animate == false and 0 or Theme.Motion.Tab, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	end

	local oldPage = self.Pages[previous]
	local newPage = self.Pages[target]

	if oldPage == newPage then
		if newPage then
			newPage.Visible = true
			newPage.GroupTransparency = 0
			newPage.Position = UDim2.fromOffset(0, 0)
		end
	else
		if oldPage then
			Util.tween(oldPage, { GroupTransparency = 1 }, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.delay(0.15, function()
				if self.ActiveIndex ~= previous then
					oldPage.Visible = false
				end
			end)
		end
		if newPage then
			newPage.Visible = true
			newPage.GroupTransparency = 1
			newPage.Position = UDim2.fromOffset(8, 0)
			if animate == false then
				newPage.GroupTransparency = 0
				newPage.Position = UDim2.fromOffset(0, 0)
			else
				Util.tween(newPage, {
					GroupTransparency = 0,
					Position = UDim2.fromOffset(0, 0),
				}, Theme.Motion.Tab, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			end
		end
	end

	self.TabChanged:Fire(target, self.Tabs[target])
end

function Window:BuildHeader(parent: Instance, title: string)
	local ctx = self.Context
	local header = Util.frame({
		Name = "Header",
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.fromOffset(428, 34),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = parent,
	})

	local back = Components.IconButton.new({
		Parent = header,
		Context = ctx,
		Glyph = "‹",
		GlyphSize = 22,
	})
	back.Root.Position = UDim2.fromOffset(0, 0)
	back.Clicked:Connect(function()
		if self.ActiveIndex ~= 1 then
			self:SelectTab(1, true)
		end
	end)

	local crumb = Util.text({
		Name = "Breadcrumb",
		Position = UDim2.fromOffset(44, 8),
		Size = UDim2.fromOffset(240, 18),
		Text = "",
		TextSize = 14,
		Font = Theme.Font.Medium,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 4,
		Parent = header,
	})

	local function updateCrumb(t: any)
		crumb.Text = string.format(
			"<font color=\"%s\"><b>%s</b></font><font color=\"%s\">  /  </font><font color=\"%s\">%s</font>",
			Util.toHex(t.LabelPrimary),
			self.Title,
			Util.toHex(t.LabelTertiary),
			Util.toHex(t.LabelSecondary),
			title
		)
	end
	updateCrumb(ctx.Theme)
	ctx:Bind(function(t: any)
		updateCrumb(t)
	end)

	local more = Components.IconButton.new({
		Parent = header,
		Context = ctx,
		Dots = true,
	})
	more.Root.Position = UDim2.fromOffset(394, 0)
	more.Clicked:Connect(function()
		self:ShowBanner({
			Title = "Settings applied",
			Body = "Your changes have been saved.",
			Time = "now",
		})
	end)

	return { Root = header, Back = back, Breadcrumb = crumb, More = more }
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

-- The ScreenGui's AbsoluteSize is the true UI canvas. Camera.ViewportSize can
-- report a different size on high-DPI / docked Studio windows, which made the
-- window scale far too large for the screen. Prefer the GUI canvas, fall back
-- to the camera.
function Window:_canvasSize(): Vector2
	local parent = self.Parent
	if parent and (parent:IsA("ScreenGui") or parent:IsA("GuiObject")) then
		local size = parent.AbsoluteSize
		if size.X >= 100 and size.Y >= 100 then
			return size
		end
	end
	return viewport()
end

function Window:_viewport(): Vector2
	return self.Viewport or self:_canvasSize()
end

-- Re-fit whenever the canvas or camera changes. The window only re-centers
-- while it has not been dragged. A cheap check in the render loop below also
-- catches Studio dock resizes that do not fire a signal.
function Window:_watchViewport()
	local function bindCamera()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		if self._viewportConnection then
			self._viewportConnection:Disconnect()
		end
		self._viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self:_fit()
		end)
		self:_fit()
	end
	bindCamera()
	if self._cameraConnection then
		self._cameraConnection:Disconnect()
	end
	self._cameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)

	local parent = self.Parent
	if parent and (parent:IsA("ScreenGui") or parent:IsA("GuiObject")) then
		if self._guiConnection then
			self._guiConnection:Disconnect()
		end
		self._guiConnection = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:_fit()
		end)
	end

	task.defer(function()
		if self.Root and self.Root.Parent then
			self:_fit()
		end
	end)
end

function Window:_fit()
	local vp = self:_canvasSize()
	if vp.X < 100 or vp.Y < 100 then
		vp = Vector2.new(Theme.Layout.DesignWidth, Theme.Layout.DesignHeight)
	end
	self.Viewport = vp

	-- Match Figma's composition: the 640x430 window is designed inside a
	-- 1280x800 canvas (50% x 54%), so scale with the artboard ratio instead of
	-- stretching the window to fill the whole screen. A safety fit prevents
	-- overflow on short viewports.
	local designFit = math.min(vp.X / Theme.Layout.DesignWidth, vp.Y / Theme.Layout.DesignHeight)
	local safeFit = math.min((vp.X - 24) / WIDTH, (vp.Y - 24) / HEIGHT)
	self.FitScale = math.clamp(math.min(designFit, safeFit), 0.45, 2.4)

	local effective = self.FitScale * self.ZoomFactor
	if not self._dragging then
		self.Scale.Scale = effective
		self.Root.Rotation = 0
	end

	if not self.HasMoved then
		self.Root.Position = UDim2.fromScale(0.5, 0.5)
	elseif not self._dragging then
		self:_clampWindow()
	end

	if self.Pill then
		self.PillScale.Scale = self.FitScale
		self.Pill.Position = UDim2.new(0.5, 0, 0, 24)
	end
	if self.Banner then
		self:UpdateBannerPositions()
	end
end

function Window:_clampWindow()
	local vp = self:_viewport()
	local effective = self.Scale.Scale
	local halfWidth = WIDTH * effective / 2
	local halfHeight = HEIGHT * effective / 2
	local position = self.Root.Position
	local x = math.clamp(
		position.X.Scale * vp.X + position.X.Offset,
		halfWidth - 40,
		vp.X - halfWidth + 40
	)
	local y = math.clamp(
		position.Y.Scale * vp.Y + position.Y.Offset,
		halfHeight - 10,
		vp.Y - halfHeight + 10
	)
	self.Root.Position = UDim2.fromScale(x / vp.X, y / vp.Y)
end

-- The frost is part of the glass surface, so it needs no screen tracking.
-- Kept as a method because the render loop and public API still call it.
function Window:_updateBlur() end

function Window:_openAnimation()
	local target = self.FitScale * self.ZoomFactor
	self.Scale.Scale = target * 0.965
	self.Canvas.GroupTransparency = 1
	self.BlurImage.ImageTransparency = 1
	if self.BorderStroke then
		self.BorderStroke.Transparency = 1
	end
	task.defer(function()
		Util.tween(self.Scale, { Scale = target }, Theme.Motion.WindowOpen, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		Util.tween(self.Canvas, { GroupTransparency = 0 }, Theme.Motion.WindowOpen, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		Util.tween(self.BlurImage, { ImageTransparency = self:_blurTransparency() }, 0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		self:_applyChrome(self.Context.Theme, Theme.Motion.WindowOpen)
	end)
end

--------------------------------------------------------------------------------
-- States
--------------------------------------------------------------------------------

function Window:Minimize()
	if self.Minimized or self._transitioning or self.Closed then
		return
	end
	self.Minimized = true
	self._transitioning = true
	self._bannerToken += 1
	if self.Banner then
		self.Banner:Hide()
	end

	local s = self.FitScale
	self._dragging = false
	self.PillExpanded = false
	self.Pill.Visible = false
	self.Pill.Size = UDim2.fromOffset(109, 44)

	-- The pill morph changes the window's size, so the aspect constraint must
	-- step aside until the full window is restored.
	if self.Aspect then
		self.Aspect.Parent = nil
	end
	self.Root.Rotation = 0

	Util.tween(self.Canvas, { GroupTransparency = 1 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Util.tween(self.GlassDepth, { BackgroundTransparency = 1 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Util.tween(self.BlurTint, { BackgroundTransparency = 1 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Util.tween(self.BorderStroke, { Transparency = 1 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, shadow in ipairs(self.ShadowImages) do
		Util.tween(shadow, { ImageTransparency = 1 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end
	Util.tween(self.BlurImage, { ImageTransparency = 1 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Util.tween(self.Root, {
		Size = UDim2.fromOffset(109, 44),
		Position = UDim2.new(0.5, 0, 0, 24 + 22 * s),
	}, 0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

	task.delay(0.44, function()
		self.Root.Visible = false
		self.Pill.Visible = true
		self.Pill.Size = UDim2.fromOffset(44, 44)
		Util.tween(self.Pill, { Size = UDim2.fromOffset(109, 44) }, Theme.Motion.Pill, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		self._transitioning = false
	end)

	if self.OnMinimize then
		task.spawn(self.OnMinimize)
	end
end

function Window:Restore()
	if not self.Minimized or self._transitioning or self.Closed then
		return
	end
	self._transitioning = true
	local s = self.FitScale

	self.Root.Visible = true
	self.Root.Size = UDim2.fromOffset(109, 44)
	self.Root.Position = UDim2.new(0.5, 0, 0, 24 + 22 * s)
	self.Root.Rotation = 0
	self.Minimized = false
	self.PillExpanded = false
	self:_applyChrome(self.Context.Theme, 0)
	-- Start from fully hidden so the restore grows the glass back in.
	self.Canvas.GroupTransparency = 1
	self.GlassDepth.BackgroundTransparency = 1
	self.BlurTint.BackgroundTransparency = 1
	self.BorderStroke.Transparency = 1
	self.BlurImage.ImageTransparency = 1
	for _, shadow in ipairs(self.ShadowImages) do
		shadow.ImageTransparency = 1
	end

	Util.tween(self.Root, {
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Position = UDim2.fromScale(0.5, 0.5),
	}, 0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	Util.tween(self.Canvas, { GroupTransparency = 0 }, 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	Util.tween(self.GlassDepth, {
		BackgroundTransparency = self.Context.Theme.GlassDepthTransparency,
	}, 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	Util.tween(self.BlurTint, {
		BackgroundTransparency = self.Context.Theme.GlassWindowTransparency,
	}, 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	Util.tween(self.BlurImage, { ImageTransparency = self:_blurTransparency() }, 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	Util.tween(self.BorderStroke, {
		Transparency = self.Context.Theme.StrokeGlassTransparency,
	}, 0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	-- The shadows were wiped above so they do not flash while the window is
	-- still pill-sized; fade them back in with the glass.
	self:_applyShadow(self.Context.Theme, 0.42)
	task.delay(0.16, function()
		self.Pill.Visible = false
	end)
	task.delay(0.46, function()
		self._transitioning = false
		if self.Aspect then
			self.Aspect.Parent = self.Root
		end
		if self.OnRestore then
			task.spawn(self.OnRestore)
		end
	end)
end

-- Custom option: close(): really closes the interface (rather than leaving the
-- minimize-to-pill affordance on screen). `Open()` brings it back.
function Window:Close(immediate: boolean?)
	if self.Closed then
		return
	end
	self.Closed = true
	self._dragging = false
	self.Root.Rotation = 0
	self.ClosedChanged:Fire(true)
	self._bannerToken += 1
	if self.Banner then
		self.Banner:Hide()
	end

	-- Leave the minimized state cleanly so a later Open() shows the full
	-- window, not a stray pill.
	if self.Minimized then
		self.Minimized = false
		self._transitioning = false
		self.Pill.Visible = false
		if self.Aspect then
			self.Aspect.Parent = self.Root
		end
		self.Root.Size = UDim2.fromOffset(WIDTH, HEIGHT)
		self.Root.Position = self.HasMoved and self.Root.Position or UDim2.fromScale(0.5, 0.5)
		self.Root.Rotation = 0
		self.Canvas.GroupTransparency = 0
		self:_applyChrome(self.Context.Theme, 0)
		self:_clampWindow()
	end

	if immediate then
		self.Root.Visible = false
		self.Overlay.Visible = false
	else
		Util.tween(self.Canvas, { GroupTransparency = 1 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Util.tween(self.GlassDepth, { BackgroundTransparency = 1 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Util.tween(self.BlurTint, { BackgroundTransparency = 1 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Util.tween(self.BlurImage, { ImageTransparency = 1 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Util.tween(self.BorderStroke, { Transparency = 1 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		for _, shadow in ipairs(self.ShadowImages) do
			Util.tween(shadow, { ImageTransparency = 1 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end
		task.delay(0.2, function()
			if not self.Closed then
				return
			end
			self.Root.Visible = false
			self.Overlay.Visible = false
		end)
	end

	if self.OnClose then
		task.spawn(self.OnClose)
	end
end

function Window:Open(animate: boolean?)
	if not self.Closed then
		return
	end
	self.Closed = false
	self.ClosedChanged:Fire(false)
	self.Minimized = false
	self._transitioning = false
	self.Pill.Visible = false
	self.Overlay.Visible = true
	self.Root.Visible = true
	self.Root.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	if not self.HasMoved then
		self.Root.Position = UDim2.fromScale(0.5, 0.5)
	end
	self.Root.Rotation = 0
	if self.Aspect then
		self.Aspect.Parent = self.Root
	end
	if self.HasMoved then
		self:_clampWindow()
	end

	if animate == false then
		self.Scale.Scale = self.FitScale * self.ZoomFactor
		self.Canvas.GroupTransparency = 0
		self:_applyChrome(self.Context.Theme, 0)
	else
		self:_openAnimation()
	end

	if self.OnOpen then
		task.spawn(self.OnOpen)
	end
end

function Window:Toggle()
	if self.Closed then
		self:Open()
	else
		self:Close()
	end
end

function Window:IsOpen(): boolean
	return not self.Closed
end

function Window:ToggleZoom()
	if self.Minimized then
		return
	end
	self.ZoomFactor = self.ZoomFactor == 1 and 1.14 or 1
	local target = self.FitScale * self.ZoomFactor
	Util.tween(self.Scale, { Scale = target }, Theme.Motion.Tab, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
end

function Window:SetMode(mode: string, animate: boolean?)
	self.Context:SetMode(mode, animate)
end

function Window:SetAccent(color: Color3, animate: boolean?)
	self.Context:SetAccent(color, animate)
end

function Window:SetBlurEnabled(enabled: boolean)
	self.Context:SetBlurEnabled(enabled)
	self:_applyBlurState(self.Context.Theme, Theme.Motion.Theme)
end

function Window:SetGlassIntensity(value: number)
	self.Context:SetGlassIntensity(value)
	self:_applyBlurState(self.Context.Theme, Theme.Motion.Fast)
end

-- Custom option: theme: table. Merge token overrides into the live context.
--   window:SetTheme({ GlassWindow = Color3.fromHex("101820") })
--   window:SetTheme(nil)   -- restore the stock theme
function Window:SetTheme(overrides: { [string]: any }?, animate: boolean?, replace: boolean?)
	self.Context:SetTheme(overrides, animate, replace)
end

function Window:GetTheme(): { [string]: any }
	return self.Context.Theme
end

-- Custom option: background_image: image id.
-- Passing "" or nil removes the image and brings the frost back.
function Window:SetBackgroundImage(imageId: string?)
	local value = imageId or ""
	self.BackgroundImage = value
	if self.BackgroundFrame then
		self.BackgroundFrame.Image = value
		self.BackgroundFrame.Visible = value ~= ""
	end
	self:_applyBlurState(self.Context.Theme, Theme.Motion.Fast)
end

--------------------------------------------------------------------------------
-- Toggles
--------------------------------------------------------------------------------

-- Register an existing Switch under a name so ChangeToggle() and the config
-- file can drive it.
function Window:_installToggle(
	name: string,
	switch: any?,
	initial: boolean?,
	callback: ((value: boolean) -> ())?,
	animate: boolean?
)
	local record = {
		Name = name,
		Switch = switch,
		Value = switch and switch.Value or (initial == true),
		Callback = callback,
		Changed = Util.Signal.new(),
	}
	self._toggles[name] = record
	self.Toggles[name] = record.Value

	if switch then
		if initial ~= nil then
			switch:SetValue(initial == true, animate == true, true)
			record.Value = switch.Value
			self.Toggles[name] = record.Value
		end
		local connection = switch.Changed:Connect(function(value: boolean)
			local current = self._toggles[name]
			if not current or current.Value == value then
				return
			end
			current.Value = value
			self.Toggles[name] = value
			current.Changed:Fire(value)
			self.ToggleChanged:Fire(name, value)
			if current.Callback then
				task.spawn(current.Callback, value)
			end
		end)
		record.Connection = connection
	end

	return record
end

-- Bind a Switch you created yourself:
--   local auto = Aurora.Components.Switch.new({ Context = ctx })
--   window:BindToggle("AutoApply", auto)
function Window:BindToggle(name: string, switch: any, callback: ((value: boolean) -> ())?): any
	local existing = self._toggles[name]
	if existing and existing.Switch == switch then
		if callback then
			existing.Callback = callback
		end
		return existing
	end
	local initial = switch.Value
	if existing and existing.Value ~= nil then
		initial = existing.Value
	end
	return self:_installToggle(name, switch, initial, callback or (existing and existing.Callback))
end

-- Create + register a Switch in one call:
--   local auto = window:AddToggle("AutoApply", { Parent = row, Value = true })
function Window:AddToggle(name: string, options: { [string]: any }?)
	local opts = options or {}
	local switch = Components.Switch.new({
		Context = self.Context,
		Parent = opts.Parent,
		Value = opts.Value == true,
		Name = opts.Name,
		OnChanged = opts.OnChanged,
	})
	return self:BindToggle(name, switch, opts.Callback)
end

-- change_toggle(name, boolean): updates the switch, the stored value, fires
-- ToggleChanged and runs the registered callback.
function Window:ChangeToggle(name: string, value: boolean, animate: boolean?)
	local record = self._toggles[name]
	if not record then
		record = self:_installToggle(name, nil, value == true, nil)
	end
	local nextValue = value == true
	if record.Switch then
		record.Switch:SetValue(nextValue, animate == true, false)
		-- Switch fires Changed synchronously, which updates the record.
		if record.Value == nextValue then
			return nextValue
		end
	end
	if record.Value ~= nextValue then
		record.Value = nextValue
		self.Toggles[name] = nextValue
		record.Changed:Fire(nextValue)
		self.ToggleChanged:Fire(name, nextValue)
		if record.Callback then
			task.spawn(record.Callback, nextValue)
		end
	end
	return nextValue
end

function Window:SetToggle(name: string, value: boolean, animate: boolean?)
	return self:ChangeToggle(name, value, animate)
end

function Window:GetToggle(name: string): boolean?
	local record = self._toggles[name]
	return record and record.Value or nil
end

function Window:GetToggles(): { [string]: boolean }
	local result = {}
	for name, record in pairs(self._toggles) do
		result[name] = record.Value == true
	end
	return result
end

function Window:GetSessionSeconds(): number
	return os.clock() - self.StartedAt
end

--------------------------------------------------------------------------------
-- Stats
--------------------------------------------------------------------------------

function Window:_startStats()
	local canvasCheck = 0
	local render = RunService.RenderStepped:Connect(function(dt: number)
		-- Drag tilt: the window leans into the direction it is being thrown,
		-- with the velocity decaying so it settles instead of wobbling.
		if self._dragging then
			self._dragVelocity *= 0.86
			local targetTilt = math.clamp(self._dragVelocity * 0.055, -1.5, 1.5)
			self._dragTilt += (targetTilt - self._dragTilt) * math.min(1, dt * 14)
			self.Root.Rotation = self._dragTilt
		end

		-- Studio dock resizes do not always fire ViewportSize/AbsoluteSize in
		-- time, so poll a few times a second and re-fit only on a real change.
		canvasCheck += dt
		if canvasCheck >= 0.25 then
			canvasCheck = 0
			local size = self:_canvasSize()
			if self.Viewport and (math.abs(size.X - self.Viewport.X) > 0.5 or math.abs(size.Y - self.Viewport.Y) > 0.5) then
				self:_fit()
			end
		end

		self._frameCount += 1
		self._frameAcc += dt
		if self._frameAcc >= 0.5 then
			local fps = math.clamp(math.round(self._frameCount / self._frameAcc), 1, 240)
			self._frameCount = 0
			self._frameAcc = 0
			self:_updateStats(fps)
		end
	end)
	self._renderConnection = render

	task.defer(function()
		self:_updateStats(self.Stats.FPS)
	end)
end

function Window:_updateStats(fps: number)
	local ping = 42
	local memory = 0
	pcall(function()
		local item = Stats.Network.ServerStatsItem["Data Ping"]
		if item then
			ping = math.round(item:GetValue())
		end
	end)
	pcall(function()
		memory = Stats:GetTotalMemoryUsageMb()
	end)
	local playerCount = 1
	pcall(function()
		playerCount = math.max(1, #Players:GetPlayers())
	end)
	self.Stats = {
		FPS = fps,
		Ping = ping,
		Players = playerCount,
		Memory = memory,
		SessionSeconds = math.floor(self:GetSessionSeconds()),
	}
	self:_updatePillStats(self.Context.Theme)
	self.StatsChanged:Fire(self.Stats)
end

--------------------------------------------------------------------------------
-- Teardown
--------------------------------------------------------------------------------

function Window:Destroy()
	if self.ConfigHandle then
		pcall(function()
			self.ConfigHandle:Save()
			self.ConfigHandle:Destroy()
		end)
		self.ConfigHandle = nil
	end
	if self._renderConnection then
		self._renderConnection:Disconnect()
	end
	if self._viewportConnection then
		self._viewportConnection:Disconnect()
	end
	if self._cameraConnection then
		self._cameraConnection:Disconnect()
	end
	if self._guiConnection then
		self._guiConnection:Disconnect()
	end
	self.StatsChanged:DisconnectAll()
	self.TabChanged:DisconnectAll()
	self.ToggleChanged:DisconnectAll()
	self.ClosedChanged:DisconnectAll()
	for _, record in pairs(self._toggles) do
		if record.Connection then
			record.Connection:Disconnect()
		end
		record.Changed:DisconnectAll()
	end
	table.clear(self._toggles)
	if self.Banner then
		self.Banner:Destroy()
	end
	if self.Root then
		self.Root:Destroy()
	end
	if self.Overlay then
		self.Overlay:Destroy()
	end
	if self.OwnsGui and self.ScreenGui then
		self.ScreenGui:Destroy()
	end
end

return Window

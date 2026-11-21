--!strict
-- Aurora UI · Figma replica demo
-- Rebuilds every screen in "Aurora — Glass UI for Roblox":
-- Overview, Controls, Appearance, plus the notification banner, live stats,
-- minimize-to-pill and the theme mode switch.
--
-- The glass uses an uploaded pre-blurred frost texture clipped inside the
-- window. There is no scenic backdrop drawn behind it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Aurora = require(ReplicatedStorage:WaitForChild("AuroraUI"))
local Theme = Aurora.Theme
local Util = Aurora.Util
local C = Aurora.Components

local player = Players.LocalPlayer

--------------------------------------------------------------------------------
-- Context + ScreenGui
--------------------------------------------------------------------------------

local ctx = Theme.newContext("Dark")

-- newScreenGui uses gethui()/CoreGui when the executor provides them, and
-- falls back to PlayerGui in Studio.
local gui = Aurora.newScreenGui({ Name = "AuroraDemo" })

--------------------------------------------------------------------------------
-- Live settings
--------------------------------------------------------------------------------

local settings = {
	WalkSpeed = 50,
	JumpHeight = 25,
	FieldOfView = 75,
	CameraShake = false,
	AutoApply = true,
	ReduceMotion = false,
}

local function currentHumanoid(): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function applyMovement()
	local humanoid = currentHumanoid()
	if humanoid then
		humanoid.WalkSpeed = settings.WalkSpeed
		humanoid.JumpHeight = settings.JumpHeight
	end
end

local function applyCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera.FieldOfView = settings.FieldOfView
	end
end

player.CharacterAdded:Connect(function()
	task.wait(0.2)
	applyMovement()
end)
task.defer(applyMovement)
task.defer(applyCamera)

-- A deliberately tiny additive camera shake, so the "Camera shake" switch in
-- the Controls tab does something real.
local shakeClock = 0
RunService.RenderStepped:Connect(function(dt: number)
	if not settings.CameraShake then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	shakeClock += dt
	local amount = 0.0022
	camera.CFrame = camera.CFrame * CFrame.Angles(
		math.sin(shakeClock * 37) * amount,
		math.cos(shakeClock * 29) * amount,
		math.sin(shakeClock * 23) * amount * 1.3
	)
end)

--------------------------------------------------------------------------------
-- Layout helpers (all coordinates are the Figma design coordinates)
--------------------------------------------------------------------------------

local CONTENT_WIDTH = 468
local CONTENT_HEIGHT = 386

local function greeting(): string
	local hour = tonumber(os.date("%H")) or 19
	if hour < 12 then
		return "Good morning"
	elseif hour < 18 then
		return "Good afternoon"
	end
	return "Good evening"
end

local function displayName(): string
	return player.DisplayName
end

local function formatMemory(megabytes: number): string
	if megabytes >= 1024 then
		return string.format("%.1f GB", megabytes / 1024)
	end
	return string.format("%d MB", math.round(megabytes))
end

local function sectionLabel(parent: Instance, text: string, y: number): TextLabel
	local label = Util.text({
		Name = "Section / " .. text,
		Parent = parent,
		Position = UDim2.fromOffset(26, y),
		Size = UDim2.fromOffset(260, 13),
		Text = string.upper(text),
		TextSize = 10,
		Font = Theme.Font.Semibold,
		TextColor3 = ctx.Theme.LabelTertiary,
		TextTransparency = ctx.Theme.LabelTertiaryTransparency,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	ctx:Bind(function(t: any, duration: number)
		Util.apply(label, {
			TextColor3 = t.LabelTertiary,
			TextTransparency = t.LabelTertiaryTransparency,
		}, duration)
	end)
	return label
end

local function card(parent: Instance, x: number, y: number, width: number, height: number, radius: number?): Frame
	local frame = Util.frame({
		Name = "Card",
		Parent = parent,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = ctx.Theme.GlassCard,
		BackgroundTransparency = ctx.Theme.GlassCardTransparency,
	})
	Util.corner(frame, radius or Theme.Radius.Card)
	local stroke = Util.stroke(frame, ctx.Theme.StrokeHairline, ctx.Theme.StrokeHairlineTransparency, 1)
	local highlight = Util.frame({
		Name = "TopHighlight",
		Parent = frame,
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -48, 0, 1),
		BackgroundColor3 = ctx.Theme.HighlightTop,
		BackgroundTransparency = math.min(1, ctx.Theme.HighlightTopTransparency + 0.12),
	})
	ctx:Bind(function(t: any, duration: number)
		Util.apply(frame, {
			BackgroundColor3 = t.GlassCard,
			BackgroundTransparency = t.GlassCardTransparency,
		}, duration)
		Util.apply(stroke, {
			Color = t.StrokeHairline,
			Transparency = t.StrokeHairlineTransparency,
		}, duration)
		Util.apply(highlight, {
			BackgroundColor3 = t.HighlightTop,
			BackgroundTransparency = math.min(1, t.HighlightTopTransparency + 0.12),
		}, duration)
	end)
	return frame
end

local function groupCard(parent: Instance, y: number, height: number, rows: { any }): any
	local group = C.Group.new({
		Context = ctx,
		Parent = parent,
		Height = height,
		Width = 428,
	})
	for _, row in ipairs(rows) do
		group:AddRow(row)
	end
	group.Root.Position = UDim2.fromOffset(20, y)
	return group
end

local function row(label: string, trailing: any?): any
	local item = C.Row.new({ Context = ctx, Label = label })
	if trailing ~= nil then
		item:SetTrailing(trailing)
	end
	return item
end

--------------------------------------------------------------------------------
-- Overview
--------------------------------------------------------------------------------

local overviewRefs: { [string]: any } = {}

local function buildOverview(page: Instance, _ctx: any, window: any)
	window:BuildHeader(page, "Overview")

	----------------------------------------------------------------------------
	-- Hero
	----------------------------------------------------------------------------
	local hero = Util.frame({
		Name = "Hero",
		Parent = page,
		Position = UDim2.fromOffset(20, 62),
		Size = UDim2.fromOffset(428, 100),
		BackgroundColor3 = ctx.Theme.Accent,
	})
	Util.corner(hero, Theme.Radius.Card)
	local heroGradient = Util.gradient(hero, ctx.Theme.HeroGradient, 0)
	local heroStroke = Util.stroke(hero, ctx.Theme.StrokeGlass, ctx.Theme.StrokeGlassTransparency, 1)

	local sheen = Util.frame({
		Name = "Sheen",
		Parent = hero,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = Color3.new(1, 1, 1),
	})
	Util.corner(sheen, Theme.Radius.Card)
	Util.gradient(
		sheen,
		ColorSequence.new(Color3.new(1, 1, 1)),
		90,
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.70),
			NumberSequenceKeypoint.new(1, 1),
		})
	)

	local avatar = C.Avatar.new({
		Parent = hero,
		Size = 56,
		Initial = displayName():sub(1, 1):upper(),
		UserId = player.UserId,
		Ring = true,
	})
	avatar.Root.Position = UDim2.fromOffset(21, 22)
	if avatar.Ring then
		avatar.Ring.Transparency = 0.2
		avatar.Ring.Thickness = 2
	end

	local hello = Util.text({
		Name = "Hello",
		Parent = hero,
		Position = UDim2.fromOffset(93, 19),
		Size = UDim2.fromOffset(180, 16),
		Text = greeting(),
		TextSize = 13,
		Font = Theme.Font.Medium,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 0.18,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	local name = Util.text({
		Name = "Name",
		Parent = hero,
		Position = UDim2.fromOffset(93, 37),
		Size = UDim2.fromOffset(200, 27),
		Text = displayName(),
		TextSize = 22,
		Font = Theme.Font.Bold,
		TextColor3 = Color3.new(1, 1, 1),
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local status = Util.text({
		Name = "Status",
		Parent = hero,
		Position = UDim2.fromOffset(93, 66),
		Size = UDim2.fromOffset(200, 15),
		Text = "Connected · 42 ms",
		TextSize = 12,
		Font = Theme.Font.Medium,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 0.22,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	local sessionCaption = Util.text({
		Name = "SessionCaption",
		Parent = hero,
		Position = UDim2.fromOffset(321, 30),
		Size = UDim2.fromOffset(86, 13),
		Text = "Session",
		TextSize = 11,
		Font = Theme.Font.Medium,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 0.25,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	local sessionTime = Util.text({
		Name = "SessionTime",
		Parent = hero,
		Position = UDim2.fromOffset(321, 45),
		Size = UDim2.fromOffset(86, 24),
		Text = "00:00:00",
		TextSize = 20,
		Font = Theme.Font.Semibold,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	ctx:Bind(function(t: any)
		heroGradient.Color = t.HeroGradient
		hero.BackgroundColor3 = t.Accent
		heroStroke.Color = t.StrokeGlass
		heroStroke.Transparency = t.StrokeGlassTransparency
	end)

	----------------------------------------------------------------------------
	-- Stats
	----------------------------------------------------------------------------
	local statsCard = card(page, 20, 174, 428, 72)
	local cells = {
		{ X = 1, Value = "60", Label = "FPS" },
		{ X = 107.75, Value = "42 ms", Label = "Ping" },
		{ X = 214.5, Value = "12", Label = "Players" },
		{ X = 321.25, Value = "1.2 GB", Label = "Memory" },
	}
	local stats = {}
	for _, spec in ipairs(cells) do
		local stat = C.Stat.new({
			Context = ctx,
			Parent = statsCard,
			Width = 105.75,
			Value = spec.Value,
			Label = spec.Label,
		})
		stat.Root.Position = UDim2.fromOffset(spec.X, 7)
		stats[spec.Label] = stat
	end
	for index = 1, 3 do
		local divider = Util.frame({
			Name = "Divider" .. index,
			Parent = statsCard,
			Position = UDim2.fromOffset(1 + index * 106.75, 20),
			Size = UDim2.fromOffset(1, 32),
			BackgroundColor3 = ctx.Theme.StrokeHairline,
			BackgroundTransparency = ctx.Theme.StrokeHairlineTransparency,
		})
		ctx:Bind(function(t: any, duration: number)
			Util.apply(divider, {
				BackgroundColor3 = t.StrokeHairline,
				BackgroundTransparency = t.StrokeHairlineTransparency,
			}, duration)
		end)
	end

	overviewRefs.FPS = stats.FPS
	overviewRefs.Ping = stats.Ping
	overviewRefs.Players = stats.Players
	overviewRefs.Memory = stats.Memory
	overviewRefs.Status = status
	overviewRefs.Session = sessionTime

	----------------------------------------------------------------------------
	-- Settings group
	----------------------------------------------------------------------------
	local autoSwitch = C.Switch.new({ Context = ctx, Value = settings.AutoApply })
	autoSwitch.Changed:Connect(function(value: boolean)
		settings.AutoApply = value
	end)
	local motionSwitch = C.Switch.new({ Context = ctx, Value = settings.ReduceMotion })
	motionSwitch.Changed:Connect(function(value: boolean)
		settings.ReduceMotion = value
	end)

	-- Register the switches so `window:ChangeToggle("AutoApply", false)` and
	-- the config file can drive them by name.
	window:BindToggle("AutoApply", autoSwitch)
	window:BindToggle("ReduceMotion", motionSwitch)

	groupCard(page, 258, 99, {
		row("Auto-apply on spawn", autoSwitch.Root),
		row("Reduce motion", motionSwitch.Root),
	})

	window.StatsChanged:Connect(function(live: any)
		if overviewRefs.FPS then
			overviewRefs.FPS:SetValue(tostring(live.FPS))
			overviewRefs.Ping:SetValue(string.format("%d ms", live.Ping))
			overviewRefs.Players:SetValue(tostring(live.Players))
			overviewRefs.Memory:SetValue(formatMemory(live.Memory))
			overviewRefs.Status.Text = string.format("Connected · %d ms", live.Ping)
		end
	end)
end

--------------------------------------------------------------------------------
-- Controls
--------------------------------------------------------------------------------

local function buildControls(page: Instance, _ctx: any, window: any)
	window:BuildHeader(page, "Controls")

	sectionLabel(page, "Motion", 62)
	local walkSlider = C.Slider.new({
		Context = ctx,
		Value = settings.WalkSpeed,
		TrackWidth = 176,
		Min = 0,
		Max = 100,
		Step = 1,
		OnChanged = function(value: number)
			settings.WalkSpeed = value
			applyMovement()
		end,
	})
	local jumpSlider = C.Slider.new({
		Context = ctx,
		Value = settings.JumpHeight,
		TrackWidth = 176,
		Min = 0,
		Max = 100,
		Step = 1,
		OnChanged = function(value: number)
			settings.JumpHeight = value
			applyMovement()
		end,
	})
	groupCard(page, 81, 99, {
		row("Walk Speed", walkSlider.Root),
		row("Jump Height", jumpSlider.Root),
	})

	sectionLabel(page, "Camera", 192)
	local fovSlider = C.Slider.new({
		Context = ctx,
		Value = settings.FieldOfView,
		TrackWidth = 176,
		Min = 40,
		Max = 120,
		Step = 1,
		OnChanged = function(value: number)
			settings.FieldOfView = value
			applyCamera()
		end,
	})
	local shakeSwitch = C.Switch.new({ Context = ctx, Value = settings.CameraShake })
	shakeSwitch.Changed:Connect(function(value: boolean)
		settings.CameraShake = value
		if value then
			window:ShowBanner({
				Title = "Camera shake on",
				Body = "Your view will add a subtle handheld drift.",
				Time = "now",
			})
		end
	end)
	window:BindToggle("CameraShake", shakeSwitch)
	groupCard(page, 211, 99, {
		row("Field of View", fovSlider.Root),
		row("Camera shake", shakeSwitch.Root),
	})

	-- Debug hook used for automated screenshots.
	window.DebugWalk = walkSlider
end

--------------------------------------------------------------------------------
-- Appearance
--------------------------------------------------------------------------------

local function buildAppearance(page: Instance, _ctx: any, window: any)
	window:BuildHeader(page, "Appearance")

	sectionLabel(page, "Theme", 62)

	----------------------------------------------------------------------------
	-- Mode segmented
	----------------------------------------------------------------------------
	local segmented = C.Segmented.new({
		Context = ctx,
		Options = { "Dark", "Light" },
		Index = ctx.Mode == "Light" and 2 or 1,
	})
	segmented.Changed:Connect(function(_index: number, value: string)
		ctx:SetMode(value)
	end)
	ctx.Changed:Connect(function(t: any)
		segmented:SetIndex(t.Mode == "Light" and 2 or 1, true, true)
	end)

	----------------------------------------------------------------------------
	-- Glass blur + intensity
	----------------------------------------------------------------------------
	local blurSwitch = C.Switch.new({ Context = ctx, Value = ctx.BlurEnabled })
	blurSwitch.Changed:Connect(function(value: boolean)
		window:SetBlurEnabled(value)
	end)
	window:BindToggle("GlassBlur", blurSwitch)

	local intensity = C.Slider.new({
		Context = ctx,
		Value = ctx.GlassIntensity,
		TrackWidth = 176,
		Min = 0,
		Max = 100,
		Step = 1,
		OnChanged = function(value: number)
			window:SetGlassIntensity(value)
		end,
	})

	groupCard(page, 81, 148, {
		row("Appearance", segmented.Root),
		row("Glass blur", blurSwitch.Root),
		row("Glass intensity", intensity.Root),
	})

	----------------------------------------------------------------------------
	-- Accent swatches
	----------------------------------------------------------------------------
	sectionLabel(page, "Accent", 241)

	local swatchesHolder = Util.frame({
		Name = "Swatches",
		Size = UDim2.fromOffset(198, 22),
	})
	local swatches = {}
	local function refreshSwatches()
		for _, swatch in ipairs(swatches) do
			local selected = Theme.colorEquals(swatch.Color, ctx.CanonicalAccent)
			swatch.Stroke.Transparency = selected and 0 or 1
			swatch.Stroke.Thickness = selected and 2 or 1
		end
	end
	for index, accent in ipairs(Theme.Accents) do
		local holder = Util.frame({
			Name = "Swatch" .. index,
			Parent = swatchesHolder,
			Position = UDim2.fromOffset(3 + (index - 1) * 34, 0),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = accent.Color,
			ZIndex = 2,
		})
		Util.corner(holder, UDim.new(0.5, 0))
		local stroke = Util.stroke(holder, Color3.new(1, 1, 1), 1, 1)
		local hit = Util.button({
			Name = "Hit",
			Parent = holder,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 3,
		})
		hit.Activated:Connect(function()
			ctx:SetAccent(accent.Color)
			window:ShowBanner({
				Title = accent.Name .. " accent",
				Body = "Accent color updated across Aurora.",
				Time = "now",
			})
		end)
		hit.MouseEnter:Connect(function()
			Util.tween(holder, { Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(2 + (index - 1) * 34, -1) }, Theme.Motion.Fast, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		end)
		hit.MouseLeave:Connect(function()
			Util.tween(holder, { Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(3 + (index - 1) * 34, 0) }, Theme.Motion.Fast, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		end)
		table.insert(swatches, { Color = accent.Color, Stroke = stroke, Holder = holder })
	end
	refreshSwatches()
	ctx.Changed:Connect(refreshSwatches)

	groupCard(page, 260, 50, {
		row("Accent color", swatchesHolder),
	})

	-- Expose for the kit / external scripts.
	window.Settings = settings
	window.DebugIntensity = intensity
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------

local tabs = {
	{
		Name = "Overview",
		Glyph = "grid",
		Badge = { Color3.fromHex("5AC8FA"), Color3.fromHex("0A84FF") },
		Build = buildOverview,
	},
	{
		Name = "Controls",
		Glyph = "sliders",
		Badge = { Color3.fromHex("FFB340"), Color3.fromHex("FF7A00") },
		Build = buildControls,
	},
	{
		Name = "Appearance",
		Glyph = "paint",
		Badge = { Color3.fromHex("D47BFF"), Color3.fromHex("6E5CE6") },
		Build = buildAppearance,
	},
}

local window = Aurora.Window.new({
	Parent = gui,
	Context = ctx,
	Player = player,
	Title = "Aurora",
	Tabs = tabs,
	BlurredImage = Aurora.GlassBlur,
	-- Custom options:
	StartingTab = 1,
	-- Executor-only persistence; harmless in Studio (memory fallback).
	Config = "demo",
})

-- Debug/automation hooks: drive the replica from Studio without synthetic
-- input. Nothing in a normal game sets these attributes.
gui:GetAttributeChangedSignal("AuroraTab"):Connect(function()
	local index = tonumber(gui:GetAttribute("AuroraTab"))
	if index then
		window:SelectTab(index, true)
	end
end)
gui:GetAttributeChangedSignal("AuroraMode"):Connect(function()
	local mode = gui:GetAttribute("AuroraMode")
	if mode then
		window:SetMode(mode, true)
	end
end)
gui:GetAttributeChangedSignal("AuroraBanner"):Connect(function()
	local title = gui:GetAttribute("AuroraBanner")
	if title then
		window:ShowBanner({
			Title = title,
			Body = "Your changes have been saved.",
			Time = "now",
			Duration = 20,
		})
	end
end)
gui:GetAttributeChangedSignal("AuroraAction"):Connect(function()
	local action = gui:GetAttribute("AuroraAction")
	if action == "minimize" then
		window:Minimize()
	elseif action == "restore" then
		window:Restore()
	elseif action == "zoom" then
		window:ToggleZoom()
	elseif action == "close" then
		window:Close()
	elseif action == "open" then
		window:Open()
	end
end)
gui:GetAttributeChangedSignal("AuroraToggle"):Connect(function()
	local spec = gui:GetAttribute("AuroraToggle")
	if type(spec) ~= "string" then
		return
	end
	local name, raw = spec:match("^([%w_]+)%s*=%s*(%a+)$")
	if name then
		window:ChangeToggle(name, raw == "true", true)
	end
end)
gui:GetAttributeChangedSignal("AuroraTheme"):Connect(function()
	local value = gui:GetAttribute("AuroraTheme")
	if type(value) ~= "string" then
		return
	end
	if value == "" or value == "reset" then
		window:SetTheme(nil, true)
	else
		window:SetTheme({
			GlassWindow = Color3.fromHex(value:gsub("#", "")),
			GlassWindowTransparency = 0.25,
		}, true)
	end
end)
gui:GetAttributeChangedSignal("AuroraBackground"):Connect(function()
	local value = gui:GetAttribute("AuroraBackground")
	if type(value) == "string" then
		window:SetBackgroundImage(value)
	end
end)
gui:GetAttributeChangedSignal("AuroraSlider"):Connect(function()
	local value = tonumber(gui:GetAttribute("AuroraSlider"))
	if value and window.DebugWalk then
		window.DebugWalk:SetValue(value, true)
	end
end)
gui:GetAttributeChangedSignal("AuroraIntensity"):Connect(function()
	local value = tonumber(gui:GetAttribute("AuroraIntensity"))
	if value then
		window:SetGlassIntensity(value)
		if window.DebugIntensity then
			window.DebugIntensity:SetValue(value, true, true)
		end
	end
end)

-- Session clock (the banner and pill read from the same live values).
task.spawn(function()
	while window.Root.Parent do
		task.wait(0.25)
		if overviewRefs.Session then
			overviewRefs.Session.Text = Util.timeString(window:GetSessionSeconds())
		end
		if window.Banner == nil and window.Pill then
			-- no-op; keeps the loop cheap and the reference explicit
		end
	end
end)

-- First-run notification, matching the "Notification" screen in Figma.
task.delay(1.2, function()
	window:ShowBanner({
		Title = "Settings applied",
		Body = "Your changes have been saved.",
		Time = "now",
	})
end)

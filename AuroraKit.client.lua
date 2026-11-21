--!strict
-- Aurora UI · Component gallery
-- A second window that showcases every module in AuroraUI, independent of the
-- Figma replica demo. It stays dormant until the place sets
-- `game:SetAttribute("AuroraKit", true)` (see README), so a normal playtest
-- only shows the replica.
--
-- While the gallery is open, the demo ScreenGui is hidden so the two windows
-- never overlap. Closing the gallery brings the demo back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Aurora = require(ReplicatedStorage:WaitForChild("AuroraUI"))
local Theme = Aurora.Theme
local Util = Aurora.Util
local C = Aurora.Components

local player = Players.LocalPlayer

local GALLERY_ATTRIBUTE = "AuroraKit"

-- Wait for the opt-in instead of polling, so the script costs nothing until
-- someone opens the kit.
if not game:GetAttribute(GALLERY_ATTRIBUTE) then
	game:GetAttributeChangedSignal(GALLERY_ATTRIBUTE):Wait()
end

local ctx = Theme.newContext("Dark")

-- Prefer gethui()/CoreGui, fall back to PlayerGui in Studio.
local gui = Aurora.newScreenGui({ Name = "AuroraKit" })

--------------------------------------------------------------------------------
-- Layout helpers (same design coordinates as the Figma artboard)
--------------------------------------------------------------------------------

local function sectionLabel(parent: Instance, text: string, y: number): TextLabel
	local label = Util.text({
		Name = "Section / " .. text,
		Parent = parent,
		Position = UDim2.fromOffset(26, y),
		Size = UDim2.fromOffset(300, 13),
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

local function card(parent: Instance, x: number, y: number, width: number, height: number): Frame
	local frame = Util.frame({
		Name = "Card",
		Parent = parent,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = ctx.Theme.GlassCard,
		BackgroundTransparency = ctx.Theme.GlassCardTransparency,
	})
	Util.corner(frame, Theme.Radius.Card)
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
	for _, item in ipairs(rows) do
		group:AddRow(item)
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
-- Buttons
--------------------------------------------------------------------------------

local function buildButtons(page: Instance, _ctx: any, window: any)
	window:BuildHeader(page, "Buttons")

	sectionLabel(page, "Actions", 62)
	local strip = card(page, 20, 80, 428, 78)
	local actions = {
		{ Text = "Save changes", Style = "Primary", X = 24, Width = 124 },
		{ Text = "Preview", Style = "Secondary", X = 156, Width = 100 },
		{ Text = "Reset", Style = "Ghost", X = 264, Width = 82 },
		{ Text = "Delete", Style = "Danger", X = 354, Width = 86 },
	}
	for _, action in ipairs(actions) do
		local button = C.Button.new({
			Context = ctx,
			Parent = strip,
			Text = action.Text,
			Style = action.Style,
			Width = action.Width,
		})
		button.Root.Position = UDim2.fromOffset(action.X, 23)
		button.Clicked:Connect(function()
			window:ShowBanner({
				Title = action.Text,
				Body = "The " .. string.lower(action.Style) .. " button fired.",
				Time = "now",
			})
		end)
	end

	sectionLabel(page, "Controls", 168)
	local blurSwitch = C.Switch.new({ Context = ctx, Value = true })
	local motionSwitch = C.Switch.new({ Context = ctx, Value = false })
	local opacity = C.Slider.new({
		Context = ctx,
		Min = 0,
		Max = 100,
		Value = 75,
		TrackWidth = 148,
		Suffix = "%",
	})
	blurSwitch.Changed:Connect(function(value: boolean)
		window:SetBlurEnabled(value)
	end)
	motionSwitch.Changed:Connect(function(value: boolean)
		-- "Reduced motion" mirrors the glass intensity as a visible toggle.
		window:SetGlassIntensity(value and 30 or 75)
	end)
	opacity.Changed:Connect(function(value: number)
		window:SetGlassIntensity(value)
	end)
	groupCard(page, 186, 144, {
		row("Glass blur", blurSwitch.Root),
		row("Reduced motion", motionSwitch.Root),
		row("Glass intensity", opacity.Root),
	})

	local chipRow = Util.frame({
		Name = "Chips",
		Parent = page,
		Position = UDim2.fromOffset(20, 344),
		Size = UDim2.fromOffset(428, 28),
		BackgroundTransparency = 1,
	})
	local chips = {
		{ Text = "Stable", Tone = "Live" },
		{ Text = "Preview", Tone = "Accent" },
		{ Text = "Beta", Tone = "Neutral" },
	}
	local chipX = 0
	for _, chip in ipairs(chips) do
		local instance = C.Chip.new({
			Context = ctx,
			Parent = chipRow,
			Text = chip.Text,
			Tone = chip.Tone,
		})
		instance.Root.Position = UDim2.fromOffset(chipX, 0)
		chipX += instance.Root.Size.X.Offset + 8
	end
end

--------------------------------------------------------------------------------
-- Fields
--------------------------------------------------------------------------------

local function buildFields(page: Instance, _ctx: any, window: any)
	window:BuildHeader(page, "Fields")

	sectionLabel(page, "Text input", 62)
	local nameInput = C.Input.new({
		Context = ctx,
		Parent = page,
		WidthScale = 0,
		Width = 388,
		Placeholder = "Display name",
	})
	nameInput.Root.Position = UDim2.fromOffset(20, 80)
	nameInput.Submitted:Connect(function(text: string)
		window:ShowBanner({
			Title = "Name submitted",
			Body = text ~= "" and text or "(empty)",
			Time = "now",
		})
	end)

	sectionLabel(page, "Select", 128)
	local dropdown = C.Dropdown.new({
		Context = ctx,
		Parent = page,
		Width = 388,
		Options = { "Comfortable", "Compact", "Spacious" },
		OnChanged = function(_index: number, value: string)
			window:ShowBanner({
				Title = "Density: " .. value,
				Body = "The dropdown selection changed.",
				Time = "now",
			})
		end,
	})
	dropdown.Root.Position = UDim2.fromOffset(20, 146)
	dropdown:SetIndex(1, true)

	sectionLabel(page, "Progress", 190)
	local progressCard = card(page, 20, 208, 428, 76)
	local progressLabel = Util.text({
		Name = "Label",
		Parent = progressCard,
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.fromOffset(300, 16),
		Text = "Uploading assets",
		TextSize = 12,
		Font = Theme.Font.Medium,
	})
	local progressValue = Util.text({
		Name = "Value",
		Parent = progressCard,
		Position = UDim2.fromOffset(316, 14),
		Size = UDim2.fromOffset(96, 16),
		Text = "68%",
		TextSize = 12,
		Font = Theme.Font.Semibold,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = ctx.Theme.Accent,
	})
	local progress = C.Progress.new({
		Context = ctx,
		Parent = progressCard,
		WidthScale = 0,
		Width = 396,
		Value = 0.68,
	})
	progress.Root.Position = UDim2.fromOffset(16, 46)
	ctx:Bind(function(t: any, duration: number)
		Util.apply(progressLabel, {
			TextColor3 = t.LabelSecondary,
			TextTransparency = t.LabelSecondaryTransparency,
		}, duration)
		Util.apply(progressValue, {
			TextColor3 = t.Accent,
		}, duration)
	end)

	sectionLabel(page, "Tooltip", 296)
	local tooltipButton = C.Button.new({
		Context = ctx,
		Parent = page,
		Text = "Hover me",
		Style = "Secondary",
		Width = 118,
	})
	tooltipButton.Root.Position = UDim2.fromOffset(20, 314)
	C.tooltip(tooltipButton.Root, "Tooltips follow the theme", {
		Context = ctx,
		Parent = window.Overlay,
	})
end

--------------------------------------------------------------------------------
-- Color
--------------------------------------------------------------------------------

local function buildColor(page: Instance, _ctx: any, window: any)
	window:BuildHeader(page, "Color")

	sectionLabel(page, "Custom accent", 62)
	local picker = C.ColorPicker.new({
		Context = ctx,
		Parent = page,
		Width = 388,
	})
	picker.Root.Position = UDim2.fromOffset(20, 82)

	local apply = C.Button.new({
		Context = ctx,
		Parent = page,
		Text = "Apply accent",
		Style = "Primary",
		Width = 132,
	})
	apply.Root.Position = UDim2.fromOffset(20, 344)
	apply.Clicked:Connect(function()
		local color = picker:GetColor()
		window:SetAccent(color, true)
		window:ShowBanner({
			Title = "Accent applied",
			Body = string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255),
			Time = "now",
		})
	end)

	local reset = C.Button.new({
		Context = ctx,
		Parent = page,
		Text = "Reset",
		Style = "Ghost",
		Width = 82,
	})
	reset.Root.Position = UDim2.fromOffset(160, 344)
	reset.Clicked:Connect(function()
		window:SetAccent(Theme.Accents[1].Color, true)
	end)
end

--------------------------------------------------------------------------------
-- Media
--------------------------------------------------------------------------------

local function buildMedia(page: Instance, _ctx: any, window: any)
	window:BuildHeader(page, "Media")

	sectionLabel(page, "Images", 62)
	local first = C.Image.new({
		Context = ctx,
		Parent = page,
		Width = 196,
		Height = 132,
		Caption = "Glass card",
	})
	first.Root.Position = UDim2.fromOffset(20, 82)
	local second = C.Image.new({
		Context = ctx,
		Parent = page,
		Width = 196,
		Height = 132,
		Placeholder = "◈",
		Caption = "Placeholder",
	})
	second.Root.Position = UDim2.fromOffset(232, 82)

	sectionLabel(page, "People", 228)
	local personCard = card(page, 20, 246, 428, 62)
	local avatars = {
		{ Initial = "A", X = 14, Ring = false },
		{ Initial = "M", X = 52, Ring = true },
		{ Initial = "R", X = 90, Ring = false },
	}
	for _, spec in ipairs(avatars) do
		local avatar = C.Avatar.new({
			Context = ctx,
			Parent = personCard,
			Size = 38,
			Initial = spec.Initial,
			Ring = spec.Ring,
		})
		avatar.Root.Position = UDim2.fromOffset(spec.X, 12)
	end
	local personName = Util.text({
		Name = "Name",
		Parent = personCard,
		Position = UDim2.fromOffset(146, 13),
		Size = UDim2.fromOffset(180, 16),
		Text = "Aurora team",
		TextSize = 13,
		Font = Theme.Font.Semibold,
	})
	local personMeta = Util.text({
		Name = "Meta",
		Parent = personCard,
		Position = UDim2.fromOffset(146, 31),
		Size = UDim2.fromOffset(180, 14),
		Text = "3 members online",
		TextSize = 11,
		Font = Theme.Font.Regular,
		TextColor3 = ctx.Theme.LabelTertiary,
		TextTransparency = ctx.Theme.LabelTertiaryTransparency,
	})
	local online = C.Chip.new({
		Context = ctx,
		Parent = personCard,
		Text = "Online",
		Tone = "Live",
	})
	online.Root.Position = UDim2.fromOffset(334, 17)
	ctx:Bind(function(t: any, duration: number)
		Util.apply(personName, {
			TextColor3 = t.LabelPrimary,
			TextTransparency = t.LabelPrimaryTransparency,
		}, duration)
		Util.apply(personMeta, {
			TextColor3 = t.LabelTertiary,
			TextTransparency = t.LabelTertiaryTransparency,
		}, duration)
	end)

	sectionLabel(page, "Stats", 314)
	local statsCard = card(page, 20, 330, 428, 54)
	local stats = {
		{ Value = "60", Label = "FPS", X = 18 },
		{ Value = "42 ms", Label = "Ping", X = 158 },
		{ Value = "12", Label = "Players", X = 298 },
	}
	for _, spec in ipairs(stats) do
		local stat = C.Stat.new({
			Context = ctx,
			Parent = statsCard,
			Value = spec.Value,
			Label = spec.Label,
			Width = 110,
			Height = 54,
		})
		stat.Root.Position = UDim2.fromOffset(spec.X, 0)
	end
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------

local tabs = {
	{
		Name = "Buttons",
		Glyph = "grid",
		Badge = { Color3.fromHex("5AC8FA"), Color3.fromHex("0A84FF") },
		Build = buildButtons,
	},
	{
		Name = "Fields",
		Glyph = "sliders",
		Badge = { Color3.fromHex("FFB340"), Color3.fromHex("FF7A00") },
		Build = buildFields,
	},
	{
		Name = "Color",
		Glyph = "paint",
		Badge = { Color3.fromHex("D47BFF"), Color3.fromHex("6E5CE6") },
		Build = buildColor,
	},
	{
		Name = "Media",
		Glyph = "grid",
		Badge = { Color3.fromHex("5AD1A0"), Color3.fromHex("159A6A") },
		Build = buildMedia,
	},
}

local demo = Aurora.findScreenGui("AuroraDemo")
if demo then
	demo.Enabled = false
end

local window = Aurora.Window.new({
	Parent = gui,
	Context = ctx,
	Player = player,
	Title = "Aurora Kit",
	Tabs = tabs,
	BlurredImage = Aurora.GlassBlur,
})

-- Debug hook: `gui:SetAttribute("KitTab", 2)` switches pages without input.
gui:GetAttributeChangedSignal("KitTab"):Connect(function()
	local index = tonumber(gui:GetAttribute("KitTab"))
	if index then
		window:SelectTab(index, true)
	end
end)
gui:GetAttributeChangedSignal("KitMode"):Connect(function()
	local mode = gui:GetAttribute("KitMode")
	if mode then
		window:SetMode(mode, true)
	end
end)
gui:GetAttributeChangedSignal("KitAction"):Connect(function()
	local action = gui:GetAttribute("KitAction")
	if action == "close" then
		window:Close()
	elseif action == "open" then
		window:Open()
	elseif action == "minimize" then
		window:Minimize()
	elseif action == "restore" then
		window:Restore()
	end
end)

window.OnClose = function()
	game:SetAttribute(GALLERY_ATTRIBUTE, false)
	-- Let the close fade finish before the gallery disappears and the replica
	-- demo comes back.
	task.delay(0.25, function()
		gui.Enabled = false
		local restoreDemo = Aurora.findScreenGui("AuroraDemo")
		if restoreDemo then
			restoreDemo.Enabled = true
		end
	end)
end

-- Re-open support: setting the attribute back to true reopens the existing
-- gallery instead of rebuilding it.
game:GetAttributeChangedSignal(GALLERY_ATTRIBUTE):Connect(function()
	if game:GetAttribute(GALLERY_ATTRIBUTE) then
		gui.Enabled = true
		local currentDemo = Aurora.findScreenGui("AuroraDemo")
		if currentDemo then
			currentDemo.Enabled = false
		end
		if window.Closed then
			window:Open()
		end
	end
end)

window:ShowBanner({
	Title = "Component gallery",
	Body = "Every Aurora module in one window.",
	Time = "now",
})

_G.AuroraKitWindow = window

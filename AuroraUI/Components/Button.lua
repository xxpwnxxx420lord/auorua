--!strict
-- Aurora UI · Button
-- 32px high, 12px radius, 16px horizontal padding. Primary is accent-filled;
-- Secondary is glass with a hairline. Pressed dims by 0.22 like the Figma spec.

local Common = require(script.Parent.Common)
local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local Button = {}
Button.__index = Button

local PRESS_DEPTH = 0.22

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

function Button.new(props: { [string]: any }?)
	local options = props or {}
	local ctx = assert(options.Context, "Aurora.Button requires a Context")
	local self = setmetatable({}, Button)

	self.Context = ctx
	self.Style = options.Style or "Primary"
	self.Enabled = options.Enabled ~= false
	self.Pressed = false
	self.Hovered = false
	self.Focused = false
	self.Clicked = Util.Signal.new()
	self._fixedWidth = options.Width
	self._minWidth = options.MinWidth or 0
	self._text = options.Text or options.Label or "Button"
	self._textSize = options.TextSize or 13
	self._height = options.Height or 32
	self._radius = options.Radius or Theme.Radius.Control

	local root = Util.button({
		Name = options.Name or "AuroraButton",
		Size = UDim2.fromOffset(64, self._height),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Selectable = true,
		Parent = options.Parent,
	})
	Util.corner(root, self._radius)
	self.Root = root

	local scale = Instance.new("UIScale")
	scale.Parent = root
	self.Scale = scale

	local background = Util.frame({
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	Util.corner(background, self._radius)
	self.Background = background

	local sheen = Util.frame({
		Name = "Sheen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = background,
	})
	Util.corner(sheen, self._radius)
	Util.gradient(
		sheen,
		ColorSequence.new(Color3.new(1, 1, 1)),
		90,
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.86),
			NumberSequenceKeypoint.new(0.55, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	)
	self.Sheen = sheen

	local stroke = Util.stroke(background, Color3.new(1, 1, 1), 1, 1)
	self.Stroke = stroke

	local label = Util.text({
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		Text = self._text,
		TextSize = self._textSize,
		Font = Theme.Font.Semibold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = root,
	})
	self.Label = label

	local focusRing = Util.frame({
		Name = "FocusRing",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 4,
		Parent = root,
	})
	Util.corner(focusRing, self._radius)
	self.FocusRing = focusRing
	Util.stroke(focusRing, ctx.Theme.Accent, 0.25, 1.5)

	local function refresh(duration: number)
		local t = ctx.Theme
		local style = self.Style
		local bgColor = t.GlassControl
		local bgTransparency = t.GlassControlTransparency
		local strokeColor = t.StrokeHairline
		local strokeTransparency = t.StrokeHairlineTransparency
		local labelColor = t.LabelPrimary
		local labelTransparency = t.LabelPrimaryTransparency
		local sheenVisible = false

		if style == "Primary" then
			bgColor = self.Hovered and t.AccentHover or t.Accent
			bgTransparency = self.Pressed and PRESS_DEPTH or 0
			strokeColor = Color3.new(1, 1, 1)
			strokeTransparency = 0.84
			labelColor = t.LabelOnAccent
			labelTransparency = 0
			sheenVisible = true
		elseif style == "Secondary" then
			bgColor = self.Hovered and t.GlassControlHover or t.GlassControl
			bgTransparency = self.Hovered and t.GlassControlHoverTransparency or t.GlassControlTransparency
			if self.Pressed then
				bgTransparency = math.min(1, bgTransparency + 0.12)
			end
			strokeColor = t.StrokeHairline
			strokeTransparency = t.StrokeHairlineTransparency
			labelColor = t.LabelPrimary
			labelTransparency = t.LabelPrimaryTransparency
		elseif style == "Ghost" then
			bgColor = t.GlassControl
			bgTransparency = self.Hovered and t.GlassControlTransparency or 1
			if self.Pressed then
				bgTransparency = math.min(1, bgTransparency + 0.08)
			end
			strokeColor = t.StrokeHairline
			strokeTransparency = 1
			labelColor = t.LabelPrimary
			labelTransparency = t.LabelPrimaryTransparency
		elseif style == "Danger" then
			bgColor = t.TrafficClose
			bgTransparency = self.Hovered and 0 or 0.06
			if self.Pressed then
				bgTransparency = PRESS_DEPTH
			end
			strokeColor = Color3.new(1, 1, 1)
			strokeTransparency = 0.84
			labelColor = Color3.new(1, 1, 1)
			labelTransparency = 0
			sheenVisible = true
		end

		if not self.Enabled then
			bgTransparency = math.min(1, bgTransparency + 0.5)
			strokeTransparency = math.min(1, strokeTransparency + 0.35)
			labelTransparency = math.min(1, labelTransparency + 0.55)
			sheenVisible = false
		end

		Util.apply(background, {
			BackgroundColor3 = bgColor,
			BackgroundTransparency = bgTransparency,
		}, duration)
		Util.apply(stroke, {
			Color = strokeColor,
			Transparency = strokeTransparency,
		}, duration)
		Util.apply(label, {
			TextColor3 = labelColor,
			TextTransparency = labelTransparency,
		}, duration)
		sheen.Visible = sheenVisible and bgTransparency < 0.9

		if self.Style == "Primary" or self.Style == "Danger" then
			Util.apply(focusRing, { BackgroundTransparency = 1 }, duration)
		end
	end

	self._refresh = refresh
	ctx:Bind(function(_, duration: number)
		refresh(duration)
	end)

	local function updateWidth()
		if self._fixedWidth then
			root.Size = UDim2.fromOffset(self._fixedWidth, self._height)
			return
		end
		local width = Common.textWidth(self._text, self._textSize, Theme.Font.Semibold) + 32
		root.Size = UDim2.fromOffset(math.max(self._minWidth, math.ceil(width)), self._height)
	end
	self._updateWidth = updateWidth
	updateWidth()

	root.MouseEnter:Connect(function()
		self.Hovered = true
		refresh(Theme.Motion.Hover)
	end)
	root.MouseLeave:Connect(function()
		self.Hovered = false
		refresh(Theme.Motion.Hover)
	end)

	root.InputBegan:Connect(function(input: InputObject)
		if not self.Enabled or not isPress(input) then
			return
		end
		self.Pressed = true
		Util.tween(scale, { Scale = 0.965 }, Theme.Motion.Press, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		refresh(Theme.Motion.Press)
	end)

	local function release()
		if not self.Pressed then
			return
		end
		self.Pressed = false
		Util.tween(scale, { Scale = self.Hovered and 1.015 or 1 }, Theme.Motion.Fast, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		refresh(Theme.Motion.Fast)
	end
	root.InputEnded:Connect(function(input: InputObject)
		if isPress(input) then
			release()
		end
	end)
	root.MouseLeave:Connect(release)

	root.SelectionGained:Connect(function()
		self.Focused = true
		focusRing.Visible = true
	end)
	root.SelectionLost:Connect(function()
		self.Focused = false
		focusRing.Visible = false
	end)

	root.Activated:Connect(function()
		if not self.Enabled then
			return
		end
		self.Clicked:Fire()
		if options.OnClick then
			task.spawn(options.OnClick, self)
		end
	end)

	return self
end

function Button:SetText(text: string)
	self._text = text
	self.Label.Text = text
	self._updateWidth()
end

function Button:SetEnabled(enabled: boolean)
	self.Enabled = enabled
	self.Root.Active = enabled
	self.Root.Selectable = enabled
	if not enabled then
		self.Pressed = false
		self.Hovered = false
		Util.tween(self.Scale, { Scale = 1 }, Theme.Motion.Fast)
	end
	self._refresh(Theme.Motion.Hover)
end

function Button:Destroy()
	self.Clicked:DisconnectAll()
	self.Root:Destroy()
end

return Button

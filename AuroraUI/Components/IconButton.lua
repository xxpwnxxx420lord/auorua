--!strict
-- Aurora UI · Icon Button
-- 34x34 circle, plain-text glyph, glass fill with a hairline. The "dots"
-- variant draws the three macOS-style ellipsis dots with frames so it renders
-- identically at any UI scale.

local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local IconButton = {}
IconButton.__index = IconButton

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

function IconButton.new(props: { [string]: any }?)
	local options = props or {}
	local ctx = assert(options.Context, "Aurora.IconButton requires a Context")
	local self = setmetatable({}, IconButton)

	self.Context = ctx
	self.Enabled = options.Enabled ~= false
	self.Hovered = false
	self.Pressed = false
	self.Clicked = Util.Signal.new()
	self._size = options.Size or 34
	self._glyph = options.Glyph or "‹"
	self._glyphSize = options.GlyphSize or 22

	local root = Util.button({
		Name = options.Name or "IconButton",
		Size = UDim2.fromOffset(self._size, self._size),
		BackgroundTransparency = 1,
		Selectable = true,
		Parent = options.Parent,
	})
	Util.corner(root, UDim.new(0.5, 0))
	self.Root = root

	local scale = Instance.new("UIScale")
	scale.Parent = root
	self.Scale = scale

	local background = Util.frame({
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	Util.corner(background, UDim.new(0.5, 0))
	self.Background = background
	local stroke = Util.stroke(background, Color3.new(1, 1, 1), 1, 1)
	self.Stroke = stroke

	local label = Util.text({
		Name = "Glyph",
		Size = UDim2.fromScale(1, 1),
		Text = self._glyph,
		TextSize = self._glyphSize,
		Font = Theme.Font.Medium,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = root,
	})
	self.Label = label

	if options.Dots then
		label.Visible = false
		local dots = Util.frame({
			Name = "Dots",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(18, 4),
			Parent = root,
		})
		for index = 1, 3 do
			local dot = Util.frame({
				Name = "Dot" .. index,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale((index - 1) / 2, 0.5),
				Size = UDim2.fromOffset(3.5, 3.5),
				Parent = dots,
			})
			Util.corner(dot, UDim.new(0.5, 0))
			dot.BackgroundColor3 = ctx.Theme.LabelPrimary
			ctx:Bind(function(t: any, duration: number)
				Util.apply(dot, {
					BackgroundColor3 = t.LabelPrimary,
					BackgroundTransparency = t.LabelPrimaryTransparency,
				}, duration)
			end)
		end
		self.Dots = dots
	end

	local focusRing = Util.frame({
		Name = "FocusRing",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 4,
		Parent = root,
	})
	Util.corner(focusRing, UDim.new(0.5, 0))
	Util.stroke(focusRing, ctx.Theme.Accent, 0.2, 1.5)
	self.FocusRing = focusRing

	local function refresh(duration: number)
		local t = ctx.Theme
		local transparency = t.GlassControlTransparency
		if self.Hovered then
			transparency = t.GlassControlHoverTransparency
		end
		if self.Pressed and not self.Hovered then
			transparency = math.min(1, transparency + 0.08)
		end
		if not self.Enabled then
			transparency = math.min(1, transparency + 0.5)
		end
		Util.apply(background, {
			BackgroundColor3 = self.Hovered and t.GlassControlHover or t.GlassControl,
			BackgroundTransparency = transparency,
		}, duration)
		Util.apply(stroke, {
			Color = t.StrokeHairline,
			Transparency = self.Enabled and t.StrokeHairlineTransparency or math.min(1, t.StrokeHairlineTransparency + 0.4),
		}, duration)
		Util.apply(label, {
			TextColor3 = t.LabelPrimary,
			TextTransparency = self.Enabled and t.LabelPrimaryTransparency or 0.5,
		}, duration)
		if self.Dots then
			for _, dot in ipairs(self.Dots:GetChildren()) do
				if dot:IsA("Frame") then
					Util.apply(dot, {
						BackgroundColor3 = t.LabelPrimary,
						BackgroundTransparency = self.Enabled and t.LabelPrimaryTransparency or 0.5,
					}, duration)
				end
			end
		end
	end

	self._refresh = refresh
	ctx:Bind(function(_, duration: number)
		refresh(duration)
	end)

	root.MouseEnter:Connect(function()
		self.Hovered = true
		refresh(Theme.Motion.Hover)
	end)
	root.MouseLeave:Connect(function()
		self.Hovered = false
		self.Pressed = false
		Util.tween(scale, { Scale = 1 }, Theme.Motion.Fast, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		refresh(Theme.Motion.Hover)
	end)

	root.InputBegan:Connect(function(input: InputObject)
		if not self.Enabled or not isPress(input) then
			return
		end
		self.Pressed = true
		Util.tween(scale, { Scale = 0.9 }, Theme.Motion.Press, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		refresh(Theme.Motion.Press)
	end)
	root.InputEnded:Connect(function(input: InputObject)
		if not isPress(input) then
			return
		end
		self.Pressed = false
		Util.tween(scale, { Scale = 1 }, Theme.Motion.Fast, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		refresh(Theme.Motion.Fast)
	end)

	root.SelectionGained:Connect(function()
		focusRing.Visible = true
	end)
	root.SelectionLost:Connect(function()
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

function IconButton:SetGlyph(glyph: string)
	self._glyph = glyph
	self.Label.Text = glyph
end

function IconButton:SetEnabled(enabled: boolean)
	self.Enabled = enabled
	self.Root.Active = enabled
	self.Root.Selectable = enabled
	self._refresh(Theme.Motion.Hover)
end

function IconButton:Destroy()
	self.Clicked:DisconnectAll()
	self.Root:Destroy()
end

return IconButton

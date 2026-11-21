--!strict
-- Aurora UI · Slider
-- 176x6 track, 22px knob, optional value readout. Click anywhere to jump,
-- drag to scrub. The fill and knob are spring-smoothed every frame, so a click
-- glides into place and a drag stays glued to the pointer. Hover/drag grow the
-- knob, light an accent halo, and pop the value readout.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local Slider = {}
Slider.__index = Slider

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

function Slider.new(props: { [string]: any }?)
	local options = props or {}
	local ctx = assert(options.Context, "Aurora.Slider requires a Context")
	local self = setmetatable({}, Slider)

	self.Context = ctx
	self.Min = options.Min or 0
	self.Max = options.Max or 100
	self.Step = options.Step or 1
	self.TrackWidth = options.TrackWidth or 176
	self.ShowValue = options.ShowValue ~= false
	self.Enabled = options.Enabled ~= false
	self.Hovered = false
	self.Dragging = false
	self.Value = self.Min
	self.Changed = Util.Signal.new()
	self._format = options.Format or function(value: number): string
		if self.Step >= 1 then
			return tostring(math.round(value))
		end
		return string.format("%.1f", value)
	end
	self._suffix = options.Suffix or ""

	local width = self.TrackWidth + (self.ShowValue and 46 or 0)
	local root = Util.frame({
		Name = options.Name or "Slider",
		Size = UDim2.fromOffset(width, 24),
		BackgroundTransparency = 1,
		Parent = options.Parent,
	})
	self.Root = root

	local hit = Util.button({
		Name = "HitArea",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Selectable = true,
		Parent = root,
	})
	self.Hit = hit

	local track = Util.frame({
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.fromOffset(self.TrackWidth, 6),
		Parent = root,
	})
	Util.corner(track, 3)
	self.Track = track

	-- Soft accent bleed under the filled part. It peeks 3px above and below
	-- the track while the slider is hovered or held.
	local fillGlow = Util.frame({
		Name = "FillGlow",
		Position = UDim2.fromOffset(0, -3),
		Size = UDim2.fromOffset(0, 12),
		BackgroundTransparency = 1,
		Parent = track,
	})
	Util.corner(fillGlow, 6)
	self.FillGlow = fillGlow

	local fill = Util.frame({
		Name = "Fill",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(0, 6),
		Parent = track,
	})
	Util.corner(fill, 3)
	self.Fill = fill

	local knobGlow = Util.frame({
		Name = "KnobGlow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(11, 12),
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Util.corner(knobGlow, UDim.new(0.5, 0))
	local knobGlowScale = Instance.new("UIScale")
	knobGlowScale.Parent = knobGlow
	self.KnobGlow = knobGlow

	local shadow = Util.frame({
		Name = "KnobShadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(11, 13),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = Color3.fromHex("000000"),
		BackgroundTransparency = 0.8,
		Parent = root,
	})
	Util.corner(shadow, UDim.new(0.5, 0))
	self.KnobShadow = shadow

	local knob = Util.frame({
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(11, 12),
		Size = UDim2.fromOffset(22, 22),
		Parent = root,
	})
	Util.corner(knob, UDim.new(0.5, 0))
	self.Knob = knob
	Util.stroke(knob, Color3.fromHex("000000"), 0.93, 1)

	local knobScale = Instance.new("UIScale")
	knobScale.Parent = knob
	self.KnobScale = knobScale

	local valueLabel = nil
	local valueScale = nil
	if self.ShowValue then
		valueLabel = Util.text({
			Name = "Value",
			Position = UDim2.fromOffset(self.TrackWidth + 16, 0),
			Size = UDim2.fromOffset(30, 24),
			Text = self._format(self.Min) .. self._suffix,
			TextSize = 14,
			Font = Theme.Font.Medium,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Center,
			Parent = root,
		})
		valueScale = Instance.new("UIScale")
		valueScale.Parent = valueLabel
		self.ValueLabel = valueLabel
		self.ValueScale = valueScale
	end

	local function refresh(duration: number)
		local t = ctx.Theme
		local active = self.Hovered or self.Dragging
		local trackTransparency = t.GlassControlTransparency
		if self.Dragging then
			trackTransparency = math.max(0, t.GlassControlTransparency - 0.09)
		elseif self.Hovered then
			trackTransparency = math.max(0, t.GlassControlTransparency - 0.04)
		end
		Util.apply(track, {
			BackgroundColor3 = t.GlassControl,
			BackgroundTransparency = self.Enabled and trackTransparency or math.min(1, trackTransparency + 0.4),
		}, duration)
		Util.apply(fill, {
			BackgroundColor3 = t.Accent,
			BackgroundTransparency = self.Enabled and 0 or 0.4,
		}, duration)
		Util.apply(fillGlow, {
			BackgroundColor3 = t.Accent,
			BackgroundTransparency = not self.Enabled and 1
				or (self.Dragging and 0.74 or (self.Hovered and 0.86 or 1)),
		}, duration)
		Util.apply(knob, {
			BackgroundColor3 = t.Knob,
			BackgroundTransparency = self.Enabled and 0 or 0.45,
		}, duration)
		Util.apply(knobGlow, {
			BackgroundColor3 = t.Accent,
			BackgroundTransparency = not self.Enabled and 1
				or (self.Dragging and 0.68 or (self.Hovered and 0.86 or 1)),
		}, duration)
		if valueLabel then
			Util.apply(valueLabel, {
				TextColor3 = t.LabelSecondary,
				TextTransparency = self.Enabled and t.LabelSecondaryTransparency or 0.5,
			}, duration)
		end
		Util.apply(shadow, { BackgroundTransparency = self.Enabled and 0.8 or 0.92 }, duration)
	end

	self._refresh = refresh
	ctx:Bind(function(_, duration: number)
		refresh(duration)
	end)

	local targetAlpha = 0
	local displayAlpha = 0
	local lastText = ""
	local labelFlashToken = 0

	local function fillWidthFor(alpha: number): number
		return math.clamp(alpha, 0, 1) * self.TrackWidth
	end

	local function paint()
		local fillWidth = fillWidthFor(displayAlpha)
		local center = math.clamp(fillWidth, 11, self.TrackWidth - 11)
		fill.Size = UDim2.fromOffset(fillWidth, 6)
		fillGlow.Size = UDim2.fromOffset(fillWidth, 12)
		knob.Position = UDim2.fromOffset(center, 12)
		shadow.Position = UDim2.fromOffset(center, 13)
		knobGlow.Position = UDim2.fromOffset(center, 12)
	end

	local function setTarget(animate: boolean)
		local span = self.Max - self.Min
		targetAlpha = span == 0 and 0 or (self.Value - self.Min) / span
		if not animate then
			displayAlpha = targetAlpha
			paint()
		end
		if valueLabel then
			local text = self._format(self.Value) .. self._suffix
			if text ~= lastText then
				lastText = text
				valueLabel.Text = text
				if animate then
					labelFlashToken += 1
					local token = labelFlashToken
					valueScale.Scale = 1.18
					Util.tween(valueScale, { Scale = 1 }, 0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
					valueLabel.TextColor3 = ctx.Theme.Accent
					valueLabel.TextTransparency = 0
					task.delay(0.24, function()
						if token == labelFlashToken then
							Util.tween(valueLabel, {
								TextColor3 = ctx.Theme.LabelSecondary,
								TextTransparency = self.Enabled and ctx.Theme.LabelSecondaryTransparency or 0.5,
							}, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
						end
					end)
				end
			end
		end
	end

	self._setTarget = setTarget

	local function quantize(raw: number): number
		local clamped = math.clamp(raw, self.Min, self.Max)
		if self.Step and self.Step > 0 then
			local steps = math.round((clamped - self.Min) / self.Step)
			clamped = self.Min + steps * self.Step
		end
		return math.clamp(clamped, self.Min, self.Max)
	end

	local function applyAlpha(alpha: number, animate: boolean)
		local nextValue = quantize(self.Min + (self.Max - self.Min) * math.clamp(alpha, 0, 1))
		if nextValue ~= self.Value then
			self.Value = nextValue
			setTarget(animate)
			self.Changed:Fire(self.Value, self)
			if options.OnChanged then
				task.spawn(options.OnChanged, self.Value, self)
			end
		else
			setTarget(animate)
		end
	end

	local function alphaFromInput(input: InputObject): number
		local scale = self.Root.AbsoluteSize.X / math.max(self.Root.Size.X.Offset, 1)
		local localX = (input.Position.X - self.Root.AbsolutePosition.X) / math.max(scale, 0.001)
		return localX / self.TrackWidth
	end

	local function setKnob(scale: number, duration: number, style: Enum.EasingStyle?)
		Util.tween(knobScale, { Scale = scale }, duration, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	end

	local function setGlow(scale: number, duration: number)
		Util.tween(knobGlowScale, { Scale = scale }, duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end

	hit.InputBegan:Connect(function(input: InputObject)
		if not self.Enabled or not isPress(input) then
			return
		end
		self.Dragging = true
		setKnob(1.18, 0.24, Enum.EasingStyle.Back)
		setGlow(1.18, 0.24)
		applyAlpha(alphaFromInput(input), true)
		refresh(Theme.Motion.Fast)
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not self.Dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		applyAlpha(alphaFromInput(input), false)
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if not self.Dragging then
			return
		end
		if isPress(input) then
			self.Dragging = false
			setKnob(self.Hovered and 1.07 or 1, 0.34)
			setGlow(self.Hovered and 1 or 0.86, 0.34)
			refresh(Theme.Motion.Fast)
		end
	end)

	hit.MouseEnter:Connect(function()
		self.Hovered = true
		if not self.Dragging then
			setKnob(1.07, 0.20)
			setGlow(1.0, 0.22)
		end
		refresh(Theme.Motion.Hover)
	end)
	hit.MouseLeave:Connect(function()
		self.Hovered = false
		if not self.Dragging then
			setKnob(1, 0.22)
			setGlow(0.86, 0.26)
		end
		refresh(Theme.Motion.Hover)
	end)

	-- One render hook keeps click-jumps and scrubbing smooth without spawning
	-- a tween every pointer move. It also lets the knob settle with a tiny
	-- spring instead of snapping.
	local render = RunService.RenderStepped:Connect(function(dt: number)
		local diff = targetAlpha - displayAlpha
		if math.abs(diff) > 0.0004 then
			local rate = self.Dragging and 30 or 18
			displayAlpha += diff * math.min(1, dt * rate)
			if math.abs(targetAlpha - displayAlpha) <= 0.0004 then
				displayAlpha = targetAlpha
			end
			paint()
		end
	end)
	self._renderConnection = render
	setGlow(0.86, 0)
	setKnob(1, 0)

	self:SetValue(options.Value or self.Min, false, true)
	self._format = options.Format or self._format
	return self
end

function Slider:SetValue(value: number, animate: boolean?, silent: boolean?)
	local clamped = math.clamp(value, self.Min, self.Max)
	if self.Step and self.Step > 0 then
		local steps = math.round((clamped - self.Min) / self.Step)
		clamped = self.Min + steps * self.Step
	end
	clamped = math.clamp(clamped, self.Min, self.Max)
	local changed = clamped ~= self.Value
	self.Value = clamped
	self._setTarget(animate == true)
	if changed and not silent then
		self.Changed:Fire(self.Value, self)
	end
end

function Slider:SetEnabled(enabled: boolean)
	self.Enabled = enabled
	self.Root.Active = enabled
	self.Hit.Active = enabled
	self._refresh(Theme.Motion.Hover)
end

function Slider:Destroy()
	self.Changed:DisconnectAll()
	if self._renderConnection then
		self._renderConnection:Disconnect()
	end
	self.Root:Destroy()
end

return Slider

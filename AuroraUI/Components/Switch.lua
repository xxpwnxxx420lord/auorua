--!strict
-- Aurora UI · Switch
-- 46x28 track, 24x24 knob, 2px inset. Tween is 0.20s Quint Out, exactly the
-- motion note from the Figma component description.

local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local Switch = {}
Switch.__index = Switch

function Switch.new(props: { [string]: any }?)
	local options = props or {}
	local ctx = assert(options.Context, "Aurora.Switch requires a Context")
	local self = setmetatable({}, Switch)

	self.Context = ctx
	self.Value = options.Value == true
	self.Enabled = options.Enabled ~= false
	self.Hovered = false
	self.Changed = Util.Signal.new()

	local width, height = 46, 28
	local root = Util.button({
		Name = options.Name or "Switch",
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		Selectable = true,
		Parent = options.Parent,
	})
	Util.corner(root, UDim.new(0.5, 0))
	self.Root = root

	local track = Util.frame({
		Name = "Track",
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	Util.corner(track, UDim.new(0.5, 0))
	self.Track = track
	local stroke = Util.stroke(track, Color3.new(1, 1, 1), 1, 1)
	self.Stroke = stroke

	local shadow = Util.frame({
		Name = "KnobShadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(14, 15),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Color3.fromHex("000000"),
		BackgroundTransparency = 0.8,
		Parent = track,
	})
	Util.corner(shadow, UDim.new(0.5, 0))
	self.KnobShadow = shadow

	local knob = Util.frame({
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(24, 24),
		Parent = track,
	})
	Util.corner(knob, UDim.new(0.5, 0))
	self.Knob = knob
	local knobStroke = Util.stroke(knob, Color3.fromHex("000000"), 0.92, 1)
	self.KnobStroke = knobStroke

	local function knobX(value: boolean): number
		return value and 32 or 14
	end

	local function refresh(duration: number)
		local t = ctx.Theme
		local trackColor = t.SwitchOff
		local trackTransparency = t.SwitchOffTransparency
		if self.Value then
			trackColor = self.Hovered and t.AccentHover or t.Accent
			trackTransparency = 0
		elseif self.Hovered then
			trackColor = t.GlassControlHover
			trackTransparency = t.GlassControlHoverTransparency
		end
		if not self.Enabled then
			trackTransparency = math.min(1, trackTransparency + 0.4)
		end
		Util.apply(track, {
			BackgroundColor3 = trackColor,
			BackgroundTransparency = trackTransparency,
		}, duration)
		Util.apply(stroke, {
			Color = t.StrokeHairline,
			Transparency = self.Value and 1 or t.StrokeHairlineTransparency,
		}, duration)
		Util.apply(knob, {
			BackgroundColor3 = t.Knob,
			BackgroundTransparency = self.Enabled and 0 or 0.4,
		}, duration)
		Util.apply(knobStroke, {
			Color = t.Mode == "Light" and Color3.fromHex("000000") or Color3.fromHex("FFFFFF"),
			Transparency = t.Mode == "Light" and 0.9 or 0.94,
		}, duration)
		Util.apply(shadow, { BackgroundTransparency = self.Enabled and 0.8 or 0.92 }, duration)
	end

	self._refresh = refresh
	ctx:Bind(function(_, duration: number)
		refresh(duration)
	end)

	local function positionKnob(animate: boolean)
		local target = UDim2.fromOffset(knobX(self.Value), 14)
		local shadowTarget = UDim2.fromOffset(knobX(self.Value), 15)
		if animate then
			Util.tween(knob, { Position = target }, Theme.Motion.Switch, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			Util.tween(shadow, { Position = shadowTarget }, Theme.Motion.Switch, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		else
			knob.Position = target
			shadow.Position = shadowTarget
		end
	end
	positionKnob(false)

	root.MouseEnter:Connect(function()
		self.Hovered = true
		refresh(Theme.Motion.Hover)
	end)
	root.MouseLeave:Connect(function()
		self.Hovered = false
		refresh(Theme.Motion.Hover)
	end)

	root.Activated:Connect(function()
		if not self.Enabled then
			return
		end
		self:SetValue(not self.Value, true)
		if options.OnChanged then
			task.spawn(options.OnChanged, self.Value, self)
		end
	end)

	return self
end

function Switch:SetValue(value: boolean, animate: boolean?, silent: boolean?)
	local nextValue = value == true
	local changed = nextValue ~= self.Value
	self.Value = nextValue
	local target = UDim2.fromOffset(nextValue and 32 or 14, 14)
	local shadowTarget = UDim2.fromOffset(nextValue and 32 or 14, 15)
	if animate then
		Util.tween(self.Knob, { Position = target }, Theme.Motion.Switch, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		Util.tween(self.KnobShadow, { Position = shadowTarget }, Theme.Motion.Switch, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	else
		self.Knob.Position = target
		self.KnobShadow.Position = shadowTarget
	end
	self._refresh(animate and Theme.Motion.Switch or 0)
	if changed and not silent then
		self.Changed:Fire(self.Value)
	end
end

function Switch:Toggle(animate: boolean?)
	self:SetValue(not self.Value, animate ~= false)
end

function Switch:Destroy()
	self.Changed:DisconnectAll()
	self.Root:Destroy()
end

return Switch

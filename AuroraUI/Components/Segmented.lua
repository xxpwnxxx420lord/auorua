--!strict
-- Aurora UI · Segmented
-- 136x32 glass track with a 0.20s sliding indicator. Supports any number of
-- options; the Figma component uses two (Dark / Light).

local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local Segmented = {}
Segmented.__index = Segmented

function Segmented.new(props: { [string]: any }?)
	local options = props or {}
	local ctx = assert(options.Context, "Aurora.Segmented requires a Context")
	local self = setmetatable({}, Segmented)

	self.Context = ctx
	self.Options = options.Options or { "Dark", "Light" }
	self.Index = 1
	self.Changed = Util.Signal.new()

	local width = options.Width or 136
	local height = options.Height or 32
	local count = math.max(1, #self.Options)
	local slotWidth = (width - 2) / count

	local root = Util.frame({
		Name = options.Name or "Segmented",
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		Parent = options.Parent,
	})
	self.Root = root

	local background = Util.frame({
		Name = "Track",
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	Util.corner(background, Theme.Radius.Item)
	self.Background = background
	local stroke = Util.stroke(background, Color3.new(1, 1, 1), 1, 1)
	self.Stroke = stroke

	local indicator = Util.frame({
		Name = "Indicator",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.fromOffset(slotWidth, height - 2),
		Parent = root,
	})
	Util.corner(indicator, Theme.Radius.Item)
	self.Indicator = indicator
	local indicatorStroke = Util.stroke(indicator, Color3.new(1, 1, 1), 1, 1)
	self.IndicatorStroke = indicatorStroke
	local indicatorSheen = Util.frame({
		Name = "Sheen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = indicator,
	})
	Util.corner(indicatorSheen, Theme.Radius.Item)
	Util.gradient(
		indicatorSheen,
		ColorSequence.new(Color3.new(1, 1, 1)),
		90,
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	)
	self.Sheen = indicatorSheen

	local labels = {}
	for index, text in ipairs(self.Options) do
		local label = Util.text({
			Name = "Option" .. index,
			Position = UDim2.fromOffset(1 + (index - 1) * slotWidth, 1),
			Size = UDim2.fromOffset(slotWidth, height - 2),
			Text = text,
			TextSize = options.TextSize or 13,
			Font = Theme.Font.Medium,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 3,
			Parent = root,
		})
		labels[index] = label

		local button = Util.button({
			Name = "OptionButton" .. index,
			Position = UDim2.fromOffset(1 + (index - 1) * slotWidth, 1),
			Size = UDim2.fromOffset(slotWidth, height - 2),
			BackgroundTransparency = 1,
			ZIndex = 4,
			Parent = root,
		})
		button.Activated:Connect(function()
			self:SetIndex(index, true)
			if options.OnChanged then
				task.spawn(options.OnChanged, index, self.Options[index], self)
			end
		end)
	end
	self.Labels = labels

	local function refresh(duration: number)
		local t = ctx.Theme
		Util.apply(background, {
			BackgroundColor3 = t.GlassControl,
			BackgroundTransparency = t.GlassControlTransparency,
		}, duration)
		Util.apply(stroke, {
			Color = t.StrokeHairline,
			Transparency = t.StrokeHairlineTransparency,
		}, duration)
		Util.apply(indicator, {
			BackgroundColor3 = t.GlassSelected,
			BackgroundTransparency = t.GlassSelectedTransparency,
		}, duration)
		Util.apply(indicatorStroke, {
			Color = t.StrokeHairline,
			Transparency = t.StrokeHairlineTransparency,
		}, duration)
		for index, label in ipairs(labels) do
			local selected = index == self.Index
			Util.apply(label, {
				TextColor3 = selected and t.LabelPrimary or t.LabelSecondary,
				TextTransparency = selected and t.LabelPrimaryTransparency or t.LabelSecondaryTransparency,
			}, duration)
		end
	end
	self._refresh = refresh
	ctx:Bind(function(_, duration: number)
		refresh(duration)
	end)

	local function moveIndicator(animate: boolean, silent: boolean)
		local target = UDim2.fromOffset(1 + (self.Index - 1) * slotWidth, 1)
		if animate then
			Util.tween(indicator, { Position = target }, Theme.Motion.Fast, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		else
			indicator.Position = target
		end
		refresh(animate and Theme.Motion.Fast or 0)
		if not silent then
			self.Changed:Fire(self.Index, self.Options[self.Index], self)
		end
	end
	moveIndicator(false, true)

	self._moveIndicator = moveIndicator
	self._initialized = true
	return self
end

function Segmented:SetIndex(index: number, animate: boolean?, silent: boolean?)
	local clamped = math.clamp(math.floor(index), 1, #self.Options)
	if clamped == self.Index and self._initialized then
		return
	end
	self.Index = clamped
	self._moveIndicator(animate == true, silent == true)
end

function Segmented:GetIndex(): number
	return self.Index
end

function Segmented:GetValue(): string
	return self.Options[self.Index]
end

function Segmented:SetOptions(options: { string }, index: number?)
	self.Options = options
	-- Callers rebuilding the options should recreate the component; this keeps
	-- the API honest instead of leaving stale labels behind.
	self:SetIndex(index or self.Index, false, true)
end

function Segmented:Destroy()
	self.Changed:DisconnectAll()
	self.Root:Destroy()
end

return Segmented

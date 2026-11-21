--!strict
-- Aurora UI · Progress
-- A slim 6px glass track with an accent fill.

local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local Progress = {}
Progress.__index = Progress

function Progress.new(props: { [string]: any }?)
	local options = props or {}
	local ctx = assert(options.Context, "Aurora.Progress requires a Context")
	local self = setmetatable({}, Progress)
	self.Value = math.clamp(options.Value or 0, 0, 1)

	local root = Util.frame({
		Name = options.Name or "Progress",
		Size = UDim2.new(options.WidthScale or 1, options.Width or 0, 0, options.Height or 6),
		BackgroundTransparency = 1,
		Parent = options.Parent,
	})
	self.Root = root

	local track = Util.frame({
		Name = "Track",
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	Util.corner(track, UDim.new(0.5, 0))
	self.Track = track

	local fill = Util.frame({
		Name = "Fill",
		Size = UDim2.fromScale(self.Value, 1),
		-- Util.frame defaults to transparent when no BackgroundColor3 is given,
		-- which made the accent fill invisible once the theme bound its colour.
		BackgroundTransparency = 0,
		Parent = track,
	})
	Util.corner(fill, UDim.new(0.5, 0))
	self.Fill = fill

	ctx:Bind(function(t: any, duration: number)
		Util.apply(track, {
			BackgroundColor3 = t.GlassControl,
			BackgroundTransparency = t.GlassControlTransparency,
		}, duration)
		Util.apply(fill, { BackgroundColor3 = t.Accent }, duration)
	end)

	return self
end

function Progress:SetValue(value: number, animate: boolean?)
	local clamped = math.clamp(value, 0, 1)
	self.Value = clamped
	if animate then
		Util.tween(self.Fill, { Size = UDim2.fromScale(clamped, 1) }, Theme.Motion.Fast, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	else
		self.Fill.Size = UDim2.fromScale(clamped, 1)
	end
end

function Progress:Destroy()
	self.Root:Destroy()
end

return Progress

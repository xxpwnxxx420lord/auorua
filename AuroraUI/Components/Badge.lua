--!strict
-- Aurora UI · Badge
-- 20x20 rounded gradient tile used by the sidebar. A small white glyph keeps
-- the three tabs readable at a glance (grid / sliders / paint).

local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local Badge = {}
Badge.__index = Badge

local function makeGlyph(parent: Instance, kind: string)
	local glyph = Util.frame({
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local white = Color3.new(1, 1, 1)

	if kind == "grid" then
		for row = 0, 1 do
			for column = 0, 1 do
				local cell = Util.frame({
					Position = UDim2.fromOffset(column * 7, row * 7),
					Size = UDim2.fromOffset(5, 5),
					BackgroundColor3 = white,
					BackgroundTransparency = 0.15,
					Parent = glyph,
				})
				Util.corner(cell, 1.5)
			end
		end
	elseif kind == "sliders" then
		for index = 0, 2 do
			local line = Util.frame({
				Position = UDim2.fromOffset(0, 1 + index * 5),
				Size = UDim2.fromOffset(12, 1.5),
				BackgroundColor3 = white,
				BackgroundTransparency = 0.25,
				Parent = glyph,
			})
			Util.corner(line, 1)
			local knob = Util.frame({
				Position = UDim2.fromOffset(index == 0 and 7 or (index == 1 and 3 or 9), index * 5),
				Size = UDim2.fromOffset(3.5, 3.5),
				BackgroundColor3 = white,
				BackgroundTransparency = 0,
				Parent = glyph,
			})
			Util.corner(knob, UDim.new(0.5, 0))
		end
	elseif kind == "paint" then
		local blob = Util.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(9, 9),
			BackgroundColor3 = white,
			BackgroundTransparency = 0.1,
			Rotation = 45,
			Parent = glyph,
		})
		Util.corner(blob, UDim.new(0.35, 0))
		local hole = Util.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(3.5, 3.5),
			BackgroundColor3 = Color3.fromHex("7A4BD6"),
			BackgroundTransparency = 0.25,
			Parent = glyph,
		})
		Util.corner(hole, UDim.new(0.5, 0))
	end

	return glyph
end

function Badge.new(props: { [string]: any }?)
	local options = props or {}
	local self = setmetatable({}, Badge)
	local size = options.Size or 20
	local radius = options.Radius or 6
	local colors = options.Colors or { Color3.fromHex("5AC8FA"), Color3.fromHex("0A84FF") }

	local root = Util.frame({
		Name = options.Name or "Badge",
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = options.Parent,
	})
	Util.corner(root, radius)
	self.Root = root

	local fill = Util.frame({
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colors[1],
		Parent = root,
	})
	Util.corner(fill, radius)
	local gradient = Util.gradient(fill, {
		[0] = colors[1],
		[1] = colors[2],
	}, 90)
	self.Fill = fill
	self.Gradient = gradient

	local highlight = Util.frame({
		Name = "Highlight",
		Position = UDim2.new(0, 3, 0, 0),
		Size = UDim2.new(1, -6, 0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		Parent = fill,
	})
	Util.corner(highlight, 1)
	self.Highlight = highlight

	if options.Glyph then
		self.Glyph = makeGlyph(fill, options.Glyph)
	end

	if options.Colors == nil then
		-- Generic badges follow the active accent.
		options.Context:Bind(function(t: any)
			local accent = t.Accent
			local deep = t.AccentDeep
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Util.mixColor(accent, Color3.new(1, 1, 1), 0.22)),
				ColorSequenceKeypoint.new(1, deep),
			})
			fill.BackgroundColor3 = accent
		end)
	end

	return self
end

function Badge:SetColors(from: Color3, to: Color3)
	self.Gradient.Color = ColorSequence.new(from, to)
	self.Fill.BackgroundColor3 = from
end

function Badge:Destroy()
	self.Root:Destroy()
end

return Badge

--!strict
-- Aurora UI · Group
-- 428px glass card, 20px radius, 48px rows with separators inset 16px.

local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local Group = {}
Group.__index = Group

function Group.new(props: { [string]: any }?)
	local options = props or {}
	local ctx = assert(options.Context, "Aurora.Group requires a Context")
	local self = setmetatable({}, Group)

	self.Context = ctx
	self.RowHeight = options.RowHeight or 48
	self.Radius = options.Radius or Theme.Radius.Card
	self.Width = options.Width or 428
	self.Rows = {}
	self._fixedHeight = options.Height

	local root = Util.frame({
		Name = options.Name or "Group",
		Size = UDim2.fromOffset(self.Width, options.Height or 50),
		BackgroundColor3 = ctx.Theme.GlassCard,
		BackgroundTransparency = ctx.Theme.GlassCardTransparency,
		ClipsDescendants = true,
		Parent = options.Parent,
	})
	Util.corner(root, self.Radius)
	self.Root = root

	local stroke = Util.stroke(root, ctx.Theme.StrokeHairline, ctx.Theme.StrokeHairlineTransparency, 1)
	self.Stroke = stroke

	local sheen = Util.frame({
		Name = "TopHighlight",
		Position = UDim2.new(0, 24, 0, 0),
		Size = UDim2.new(1, -48, 0, 1),
		BackgroundColor3 = ctx.Theme.HighlightTop,
		BackgroundTransparency = ctx.Theme.HighlightTopTransparency + 0.15,
		Parent = root,
	})
	self.Sheen = sheen

	ctx:Bind(function(t: any, duration: number)
		Util.apply(root, {
			BackgroundColor3 = t.GlassCard,
			BackgroundTransparency = t.GlassCardTransparency,
		}, duration)
		Util.apply(stroke, {
			Color = t.StrokeHairline,
			Transparency = t.StrokeHairlineTransparency,
		}, duration)
		Util.apply(sheen, {
			BackgroundColor3 = t.HighlightTop,
			BackgroundTransparency = math.min(1, t.HighlightTopTransparency + 0.15),
		}, duration)
	end)

	self._nextY = 1

	return self
end

function Group:AddRow(row: any)
	if type(row) == "table" and row.Root then
		row = row.Root
	end
	if not row or not row:IsA("GuiObject") then
		return
	end

	if #self.Rows > 0 then
		local separator = Util.frame({
			Name = "Separator",
			Position = UDim2.fromOffset(1, self._nextY - 1),
			Size = UDim2.fromOffset(self.Width - 2, 1),
			BackgroundTransparency = 1,
			Parent = self.Root,
		})
		local line = Util.frame({
			Name = "Line",
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(1, -32, 1, 0),
			BackgroundColor3 = self.Context.Theme.StrokeHairline,
			BackgroundTransparency = self.Context.Theme.StrokeHairlineTransparency,
			Parent = separator,
		})
		self.Context:Bind(function(t: any, duration: number)
			Util.apply(line, {
				BackgroundColor3 = t.StrokeHairline,
				BackgroundTransparency = t.StrokeHairlineTransparency,
			}, duration)
		end)
		self._separators = self._separators or {}
		table.insert(self._separators, separator)
	end

	row.Parent = self.Root
	row.Size = UDim2.new(1, -2, 0, self.RowHeight)
	row.Position = UDim2.fromOffset(1, self._nextY)
	self._nextY = self._nextY + self.RowHeight + 1
	table.insert(self.Rows, row)

	local height = self._fixedHeight or (2 + #self.Rows * self.RowHeight + math.max(0, #self.Rows - 1))
	self.Root.Size = UDim2.fromOffset(self.Width, height)
	return row
end

function Group:SetHeight(height: number)
	self._fixedHeight = height
	self.Root.Size = UDim2.fromOffset(self.Width, height)
end

function Group:Destroy()
	self.Root:Destroy()
end

return Group

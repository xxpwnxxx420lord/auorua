--!strict
-- Aurora UI · Row
-- 48px row: 14px label at x=16, trailing control anchored at right -16.

local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local Row = {}
Row.__index = Row

function Row.new(props: { [string]: any }?)
	local options = props or {}
	local ctx = assert(options.Context, "Aurora.Row requires a Context")
	local self = setmetatable({}, Row)

	self.Context = ctx
	self.Height = options.Height or 48
	self.Hovered = false

	local root = Util.frame({
		Name = options.Name or "Row",
		Size = UDim2.new(1, 0, 0, self.Height),
		BackgroundTransparency = 1,
		Parent = options.Parent,
	})
	self.Root = root

	local hover = Util.frame({
		Name = "Hover",
		Position = UDim2.fromOffset(6, 2),
		Size = UDim2.new(1, -12, 1, -4),
		BackgroundColor3 = ctx.Theme.GlassControlHover,
		BackgroundTransparency = 1,
		Parent = root,
	})
	Util.corner(hover, 10)
	self.Hover = hover

	local label = Util.text({
		Name = "Label",
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -240, 1, 0),
		Text = options.Label or "Row label",
		TextSize = options.LabelSize or 14,
		Font = Theme.Font.Medium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = root,
	})
	self.Label = label

	local trailing = options.Trailing
	local trailingObject: GuiObject? = nil
	local function setTrailing(value: any)
		if trailingObject then
			trailingObject:Destroy()
			trailingObject = nil
		end
		if value == nil then
			return
		end
		local object = value
		if typeof(value) == "function" then
			object = value(root)
		elseif type(value) == "table" and value.Root then
			object = value.Root
		end
		if object and object:IsA("GuiObject") then
			object.AnchorPoint = Vector2.new(1, 0.5)
			object.Position = UDim2.new(1, -16, 0.5, 0)
			if object.Parent ~= root then
				object.Parent = root
			end
			trailingObject = object
			self.Trailing = object
		end
	end
	setTrailing(trailing)
	self._setTrailing = setTrailing

	ctx:Bind(function(t: any, duration: number)
		Util.apply(label, {
			TextColor3 = t.LabelPrimary,
			TextTransparency = t.LabelPrimaryTransparency,
		}, duration)
		Util.apply(hover, {
			BackgroundColor3 = t.GlassControlHover,
			BackgroundTransparency = self.Hovered and math.min(0.97, t.GlassControlHoverTransparency + 0.9) or 1,
		}, duration)
	end)

	if options.Hover ~= false then
		root.MouseEnter:Connect(function()
			self.Hovered = true
			Util.tween(hover, { BackgroundTransparency = 0.965 }, Theme.Motion.Hover, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		end)
		root.MouseLeave:Connect(function()
			self.Hovered = false
			Util.tween(hover, { BackgroundTransparency = 1 }, Theme.Motion.Fast, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		end)
	end

	return self
end

function Row:SetLabel(text: string)
	self.Label.Text = text
end

function Row:SetTrailing(value: any)
	self._setTrailing(value)
end

function Row:Destroy()
	self.Root:Destroy()
end

return Row

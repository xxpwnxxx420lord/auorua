--!strict
-- Aurora UI · Stat
-- 22px semibold value over a 12px secondary label, centered in a 58px cell.

local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local Stat = {}
Stat.__index = Stat

function Stat.new(props: { [string]: any }?)
	local options = props or {}
	local ctx = assert(options.Context, "Aurora.Stat requires a Context")
	local self = setmetatable({}, Stat)

	self.Context = ctx

	local root = Util.frame({
		Name = options.Name or "Stat",
		Size = UDim2.fromOffset(options.Width or 105, options.Height or 58),
		BackgroundTransparency = 1,
		Parent = options.Parent,
	})
	self.Root = root

	local value = Util.text({
		Name = "Value",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 32),
		Text = options.Value or "0",
		TextSize = options.ValueSize or 22,
		Font = Theme.Font.Semibold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = root,
	})
	self.ValueLabel = value

	local label = Util.text({
		Name = "Label",
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 20),
		Text = options.Label or "Label",
		TextSize = options.LabelSize or 12,
		Font = Theme.Font.Medium,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = root,
	})
	self.Label = label

	ctx:Bind(function(t: any, duration: number)
		Util.apply(value, {
			TextColor3 = t.LabelPrimary,
			TextTransparency = t.LabelPrimaryTransparency,
		}, duration)
		Util.apply(label, {
			TextColor3 = t.LabelSecondary,
			TextTransparency = t.LabelSecondaryTransparency,
		}, duration)
	end)

	return self
end

function Stat:SetValue(text: string)
	self.ValueLabel.Text = text
end

function Stat:SetLabel(text: string)
	self.Label.Text = text
end

function Stat:Destroy()
	self.Root:Destroy()
end

return Stat

--!strict
-- Aurora UI · Tooltip
-- Attach a small glass tooltip to any GuiObject. It lives in the overlay so
-- it is never clipped, and scales with the target.

local Common = require(script.Parent.Common)
local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local Tooltip = {}

function Tooltip.attach(target: GuiObject, text: string, options: { [string]: any }?)
	local opts = options or {}
	local ctx = opts.Context
	local parent = opts.Parent
	if not ctx or not parent then
		return function() end
	end

	local tooltip = Instance.new("CanvasGroup")
	tooltip.Name = "Tooltip"
	tooltip.AnchorPoint = Vector2.new(0.5, 1)
	tooltip.Size = UDim2.fromOffset(Common.textWidth(text, 12, Theme.Font.Medium) + 20, 26)
	tooltip.BackgroundColor3 = ctx.Theme.GlassPill
	tooltip.BackgroundTransparency = 0.08
	tooltip.GroupTransparency = 1
	tooltip.Visible = false
	tooltip.ZIndex = 210
	tooltip.Parent = parent
	Util.corner(tooltip, 8)
	Util.stroke(tooltip, ctx.Theme.StrokeGlass, ctx.Theme.StrokeGlassTransparency, 1)

	local scale = Instance.new("UIScale")
	scale.Parent = tooltip

	local label = Util.text({
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextSize = 12,
		Font = Theme.Font.Medium,
		TextColor3 = ctx.Theme.LabelPrimary,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = tooltip,
	})

	ctx:Bind(function(t: any)
		tooltip.BackgroundColor3 = t.GlassPill
		label.TextColor3 = t.LabelPrimary
	end)

	local token = 0
	local function place()
		local targetScale = 1
		if target.Size.X.Offset > 0 then
			targetScale = target.AbsoluteSize.X / target.Size.X.Offset
		end
		scale.Scale = targetScale
		local screenX = target.AbsolutePosition.X + target.AbsoluteSize.X / 2
		local screenY = target.AbsolutePosition.Y - 8 * targetScale
		tooltip.Position = UDim2.fromOffset(
			screenX - parent.AbsolutePosition.X,
			screenY - parent.AbsolutePosition.Y
		)
	end

	local function show()
		place()
		tooltip.Visible = true
		tooltip.GroupTransparency = 1
		Util.tween(tooltip, { GroupTransparency = 0 }, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	end

	local function hide()
		token += 1
		Util.tween(tooltip, { GroupTransparency = 1 }, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(0.16, function()
			if tooltip.GroupTransparency > 0.98 then
				tooltip.Visible = false
			end
		end)
	end

	local enter = target.MouseEnter:Connect(function()
		token += 1
		local current = token
		task.delay(0.32, function()
			if current == token and target.Parent then
				show()
			end
		end)
	end)
	local leave = target.MouseLeave:Connect(hide)
	local input = target.InputBegan:Connect(hide)

	return function()
		enter:Disconnect()
		leave:Disconnect()
		input:Disconnect()
		tooltip:Destroy()
	end
end

return Tooltip

--!strict
-- Aurora UI · shared component helpers

local TextService = game:GetService("TextService")

local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local Common = {}

function Common.textWidth(text: string, size: number, font: Enum.Font): number
	local bounds = TextService:GetTextSize(text, size, font, Vector2.new(10000, 1000))
	return bounds.X
end

function Common.ellipse(parent: Instance, props: { [string]: any }?): Frame
	local frameProps: { [string]: any } = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = parent,
	}
	if props then
		for key, value in pairs(props) do
			frameProps[key] = value
		end
	end
	local frame = Util.frame(frameProps)
	Util.corner(frame, UDim.new(0.5, 0))
	return frame
end

function Common.softShadow(parent: Instance, radius: number, transparency: number): Frame
	local shadow = Util.frame({
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 10, 1, 18),
		BackgroundColor3 = Color3.fromHex("000000"),
		BackgroundTransparency = transparency,
		ZIndex = (parent :: any).ZIndex - 1,
		Parent = parent,
	})
	Util.corner(shadow, radius + 5)
	return shadow
end

function Common.card(
	parent: Instance,
	ctx: any,
	options: { Radius: number?, Stroke: boolean?, TransparencyOffset: number? }?
): (Frame, UIStroke)
	local opts = options or {}
	local radius = opts.Radius or Theme.Radius.Card
	local card = Util.frame({
		Name = "Card",
		BackgroundColor3 = ctx.Theme.GlassCard,
		BackgroundTransparency = ctx.Theme.GlassCardTransparency,
		Parent = parent,
	})
	Util.corner(card, radius)
	local stroke = nil
	if opts.Stroke ~= false then
		stroke = Util.stroke(card, ctx.Theme.StrokeHairline, ctx.Theme.StrokeHairlineTransparency, 1)
	end
	ctx:Bind(function(t: any, duration: number)
		local offset = opts.TransparencyOffset or 0
		Util.apply(card, {
			BackgroundColor3 = t.GlassCard,
			BackgroundTransparency = math.clamp(t.GlassCardTransparency + offset, 0, 1),
		}, duration)
		if stroke then
			Util.apply(stroke, {
				Color = t.StrokeHairline,
				Transparency = math.clamp(t.StrokeHairlineTransparency + offset, 0, 1),
			}, duration)
		end
	end)
	return card, stroke :: any
end

function Common.separator(parent: Instance, ctx: any): Frame
	local line = Util.frame({
		Name = "Separator",
		BackgroundColor3 = ctx.Theme.StrokeHairline,
		BackgroundTransparency = ctx.Theme.StrokeHairlineTransparency,
		BorderSizePixel = 0,
		Parent = parent,
	})
	ctx:Bind(function(t: any, duration: number)
		Util.apply(line, {
			BackgroundColor3 = t.StrokeHairline,
			BackgroundTransparency = t.StrokeHairlineTransparency,
		}, duration)
	end)
	return line
end

function Common.checker(parent: Instance, cell: number?, color: Color3?): Frame
	local size = cell or 8
	local tint = color or Color3.fromHex("FFFFFF")
	local root = Util.frame({
		Name = "Checker",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("D8D8DE"),
		Parent = parent,
	})
	Util.corner(root, 10)
	for row = 0, 2 do
		for column = 0, 20 do
			if (row + column) % 2 == 0 then
				local square = Util.frame({
					Position = UDim2.fromOffset(column * size, row * size),
					Size = UDim2.fromOffset(size, size),
					BackgroundColor3 = tint,
					BackgroundTransparency = 0.35,
					Parent = root,
				})
				square.Name = "Light"
			end
		end
	end
	return root
end

-- A tiny check glyph made from two rotated bars. Crisper than a text glyph
-- at small sizes and independent of font coverage.
function Common.check(parent: Instance, color: Color3, size: number?): Frame
	local scale = (size or 14) / 14
	local root = Util.frame({
		Name = "Check",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(14 * scale, 14 * scale),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local short = Util.frame({
		BackgroundColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.3, 0.62),
		Size = UDim2.fromOffset(6 * scale, 2 * scale),
		Rotation = 45,
		Parent = root,
	})
	Util.corner(short, 1)
	local long = Util.frame({
		BackgroundColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.58, 0.5),
		Size = UDim2.fromOffset(10 * scale, 2 * scale),
		Rotation = -45,
		Parent = root,
	})
	Util.corner(long, 1)
	return root
end

return Common

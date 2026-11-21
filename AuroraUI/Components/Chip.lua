--!strict
-- Aurora UI · Chip
-- 28px pill. Tones: Live (positive border + soft fill + pulsing dot),
-- Neutral (glass), Accent (accent border + soft fill).

local TweenService = game:GetService("TweenService")

local Common = require(script.Parent.Common)
local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local Chip = {}
Chip.__index = Chip

function Chip.new(props: { [string]: any }?)
	local options = props or {}
	local ctx = assert(options.Context, "Aurora.Chip requires a Context")
	local self = setmetatable({}, Chip)

	self.Context = ctx
	self.Tone = options.Tone or "Neutral"
	self._text = options.Text or "Chip"
	self._dot = self.Tone ~= "Neutral"
	self._padding = 12

	local root = Util.frame({
		Name = options.Name or "Chip",
		Size = UDim2.fromOffset(60, 28),
		BackgroundTransparency = 1,
		Parent = options.Parent,
	})
	Util.corner(root, UDim.new(0.5, 0))
	self.Root = root

	local background = Util.frame({
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	Util.corner(background, UDim.new(0.5, 0))
	self.Background = background
	local stroke = Util.stroke(background, Color3.new(1, 1, 1), 1, 1)
	self.Stroke = stroke

	local text = Util.text({
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		Text = self._text,
		TextSize = options.TextSize or 12,
		Font = Theme.Font.Medium,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = root,
	})
	self.Label = text

	local dot = nil
	if self._dot then
		dot = Common.ellipse(root, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, self._padding, 0.5, 0),
			Size = UDim2.fromOffset(6, 6),
			BackgroundColor3 = ctx.Theme.Positive,
			Parent = root,
		})
		self.Dot = dot
	end

	local function refresh(duration: number)
		local t = ctx.Theme
		local bgColor = t.GlassControl
		local bgTransparency = t.GlassControlTransparency
		local strokeColor = t.StrokeHairline
		local strokeTransparency = t.StrokeHairlineTransparency
		local textColor = t.LabelSecondary
		local textTransparency = t.LabelSecondaryTransparency
		local dotColor = t.Positive

		if self.Tone == "Live" or self.Tone == "Positive" then
			bgColor = t.PositiveSoft
			bgTransparency = t.PositiveSoftTransparency
			strokeColor = t.Positive
			strokeTransparency = 0.45
			textColor = t.Positive
			textTransparency = 0
			dotColor = t.Positive
		elseif self.Tone == "Accent" then
			bgColor = t.AccentSoft
			bgTransparency = t.AccentSoftTransparency
			strokeColor = t.Accent
			strokeTransparency = 0.45
			textColor = t.Accent
			textTransparency = 0
			dotColor = t.Accent
		end

		Util.apply(background, {
			BackgroundColor3 = bgColor,
			BackgroundTransparency = bgTransparency,
		}, duration)
		Util.apply(stroke, {
			Color = strokeColor,
			Transparency = strokeTransparency,
		}, duration)
		Util.apply(text, {
			TextColor3 = textColor,
			TextTransparency = textTransparency,
		}, duration)
		if dot then
			Util.apply(dot, { BackgroundColor3 = dotColor }, duration)
		end
	end
	self._refresh = refresh
	ctx:Bind(function(_, duration: number)
		refresh(duration)
	end)

	local function layout()
		local textWidth = Common.textWidth(self._text, options.TextSize or 12, Theme.Font.Medium)
		local dotSpace = self._dot and 12 or 0
		local width = math.ceil(textWidth + self._padding * 2 + dotSpace)
		root.Size = UDim2.fromOffset(width, 28)
		text.Position = UDim2.fromOffset(self._dot and 6 or 0, 0)
		text.Size = UDim2.new(1, self._dot and -6 or 0, 1, 0)
	end
	self._layout = layout
	layout()

	if self._dot and options.Pulse ~= false then
		local pulse = TweenService:Create(
			dot,
			TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ BackgroundTransparency = 0.6 }
		)
		pulse:Play()
		self._pulse = pulse
	end

	return self
end

function Chip:SetText(text: string)
	self._text = text
	self.Label.Text = text
	self._layout()
end

function Chip:SetTone(tone: string)
	self.Tone = tone
	self._refresh(Theme.Motion.Fast)
end

function Chip:Destroy()
	if self._pulse then
		self._pulse:Cancel()
	end
	self.Root:Destroy()
end

return Chip

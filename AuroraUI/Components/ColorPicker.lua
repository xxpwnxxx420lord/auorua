--!strict
-- Aurora UI · Color Picker
-- Saturation/value square, hue rail, alpha rail, hex input and presets.
-- Everything is vector-drawn; no external assets required.

local UserInputService = game:GetService("UserInputService")

local Common = require(script.Parent.Common)
local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local ColorPicker = {}
ColorPicker.__index = ColorPicker

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local function makeChecker(parent: Instance, width: number, height: number, cell: number)
	local root = Util.frame({
		Name = "Checker",
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Color3.fromHex("D9D9E0"),
		ClipsDescendants = true,
		Parent = parent,
	})
	Util.corner(root, 6)
	local columns = math.ceil(width / cell)
	local rows = math.ceil(height / cell)
	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			if (row + column) % 2 == 0 then
				local square = Util.frame({
					Position = UDim2.fromOffset(column * cell, row * cell),
					Size = UDim2.fromOffset(cell, cell),
					BackgroundColor3 = WHITE,
					BackgroundTransparency = 0.2,
					Parent = root,
				})
				square.Name = "Tile"
			end
		end
	end
	return root
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

function ColorPicker.new(props: { [string]: any }?)
	local options = props or {}
	local ctx = assert(options.Context, "Aurora.ColorPicker requires a Context")
	local self = setmetatable({}, ColorPicker)

	self.Context = ctx
	self.Width = options.Width or 428
	self.Hue = 0.58
	self.Sat = 0.96
	self.Value = 1
	self.Alpha = 1
	self.Changed = Util.Signal.new()
	self._updatingHex = false

	local width = self.Width
	local root = Util.frame({
		Name = options.Name or "ColorPicker",
		Size = UDim2.fromOffset(width, 250),
		BackgroundTransparency = 1,
		Parent = options.Parent,
	})
	self.Root = root

	------------------------------------------------------------
	-- Saturation / value
	------------------------------------------------------------
	local sv = Util.frame({
		Name = "SV",
		Size = UDim2.fromOffset(width, 150),
		ClipsDescendants = true,
		Parent = root,
	})
	Util.corner(sv, Theme.Radius.Control)
	self.SV = sv
	local svStroke = Util.stroke(sv, Color3.new(1, 1, 1), 1, 1)
	self.SVStroke = svStroke

	local base = Util.frame({
		Name = "Base",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHSV(self.Hue, 1, 1),
		Parent = sv,
	})
	Util.corner(base, Theme.Radius.Control)
	local baseGradient = Util.gradient(base, {
		[0] = WHITE,
		[1] = Color3.fromHSV(self.Hue, 1, 1),
	}, 0)
	self.SVGradient = baseGradient

	local shade = Util.frame({
		Name = "Shade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		Parent = sv,
	})
	Util.corner(shade, Theme.Radius.Control)
	local shadeGradient = Util.gradient(
		shade,
		ColorSequence.new(BLACK),
		90,
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		})
	)
	self.ShadeGradient = shadeGradient

	local svHit = Util.button({
		Name = "SVHit",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = sv,
	})

	local cursorOuter = Util.frame({
		Name = "CursorOuter",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = sv,
	})
	Util.corner(cursorOuter, UDim.new(0.5, 0))
	Util.stroke(cursorOuter, BLACK, 0.35, 1)
	local cursor = Util.frame({
		Name = "Cursor",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(13, 13),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = sv,
	})
	Util.corner(cursor, UDim.new(0.5, 0))
	Util.stroke(cursor, WHITE, 0.02, 2)
	self.Cursor = cursor
	self.CursorOuter = cursorOuter

	------------------------------------------------------------
	-- Hue rail
	------------------------------------------------------------
	local hueY = 162
	local hueTrack = Util.frame({
		Name = "HueTrack",
		Position = UDim2.fromOffset(0, hueY),
		Size = UDim2.fromOffset(width, 12),
		BackgroundColor3 = Color3.fromHex("FF0000"),
		Parent = root,
	})
	Util.corner(hueTrack, 6)
	Util.stroke(hueTrack, Color3.fromHex("000000"), 0.88, 1)
	Util.gradient(hueTrack, {
		[0] = Color3.fromHex("FF0000"),
		[0.166] = Color3.fromHex("FFFF00"),
		[0.333] = Color3.fromHex("00FF00"),
		[0.5] = Color3.fromHex("00FFFF"),
		[0.666] = Color3.fromHex("0000FF"),
		[0.833] = Color3.fromHex("FF00FF"),
		[1] = Color3.fromHex("FF0000"),
	}, 0)
	self.HueTrack = hueTrack
	local hueHit = Util.button({
		Name = "HueHit",
		Position = UDim2.fromOffset(0, hueY),
		Size = UDim2.fromOffset(width, 12),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = root,
	})
	self.HueHit = hueHit
	local hueKnobShadow = Common.ellipse(root, {
		Name = "HueKnobShadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(width * self.Hue, hueY + 7),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.78,
		ZIndex = 4,
		Parent = root,
	})
	local hueKnob = Util.frame({
		Name = "HueKnob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(width * self.Hue, hueY + 6),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = WHITE,
		ZIndex = 5,
		Parent = root,
	})
	Util.corner(hueKnob, UDim.new(0.5, 0))
	Util.stroke(hueKnob, BLACK, 0.9, 1)
	self.HueKnob = hueKnob
	self.HueKnobShadow = hueKnobShadow

	------------------------------------------------------------
	-- Alpha rail
	------------------------------------------------------------
	local alphaY = 184
	local alphaTrack = Util.frame({
		Name = "AlphaTrack",
		Position = UDim2.fromOffset(0, alphaY),
		Size = UDim2.fromOffset(width, 12),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = root,
	})
	Util.corner(alphaTrack, 6)
	makeChecker(alphaTrack, width, 12, 12)
	local alphaOverlay = Util.frame({
		Name = "AlphaOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHSV(self.Hue, self.Sat, self.Value),
		Parent = alphaTrack,
	})
	Util.corner(alphaOverlay, 6)
	local alphaGradient = Util.gradient(
		alphaOverlay,
		ColorSequence.new(Color3.fromHSV(self.Hue, self.Sat, self.Value)),
		0,
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		})
	)
	self.AlphaGradient = alphaGradient
	Util.stroke(alphaTrack, Color3.fromHex("000000"), 0.88, 1)
	self.AlphaTrack = alphaTrack
	local alphaHit = Util.button({
		Name = "AlphaHit",
		Position = UDim2.fromOffset(0, alphaY),
		Size = UDim2.fromOffset(width, 12),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = root,
	})
	self.AlphaHit = alphaHit
	local alphaKnobShadow = Common.ellipse(root, {
		Name = "AlphaKnobShadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(width * self.Alpha, alphaY + 7),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.78,
		ZIndex = 4,
		Parent = root,
	})
	local alphaKnob = Util.frame({
		Name = "AlphaKnob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(width * self.Alpha, alphaY + 6),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = WHITE,
		ZIndex = 5,
		Parent = root,
	})
	Util.corner(alphaKnob, UDim.new(0.5, 0))
	Util.stroke(alphaKnob, BLACK, 0.9, 1)
	self.AlphaKnob = alphaKnob
	self.AlphaKnobShadow = alphaKnobShadow

	------------------------------------------------------------
	-- Preview + hex + presets
	------------------------------------------------------------
	local previewHolder = Util.frame({
		Name = "Preview",
		Position = UDim2.fromOffset(0, 208),
		Size = UDim2.fromOffset(36, 36),
		ClipsDescendants = true,
		Parent = root,
	})
	Util.corner(previewHolder, Theme.Radius.Item)
	makeChecker(previewHolder, 36, 36, 9)
	local preview = Util.frame({
		Name = "PreviewColor",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHSV(self.Hue, self.Sat, self.Value),
		BackgroundTransparency = 1 - self.Alpha,
		Parent = previewHolder,
	})
	Util.corner(preview, Theme.Radius.Item)
	Util.stroke(previewHolder, Color3.new(1, 1, 1), 0.82, 1)
	self.Preview = preview

	local hex = Instance.new("TextBox")
	hex.Name = "Hex"
	hex.Position = UDim2.fromOffset(48, 208)
	hex.Size = UDim2.fromOffset(120, 36)
	hex.BackgroundColor3 = ctx.Theme.GlassControl
	hex.BackgroundTransparency = ctx.Theme.GlassControlTransparency
	hex.BorderSizePixel = 0
	hex.Font = Theme.Font.Medium
	hex.TextSize = 13
	hex.Text = Util.toHex(Color3.fromHSV(self.Hue, self.Sat, self.Value))
	hex.PlaceholderText = "#RRGGBB"
	hex.PlaceholderColor3 = ctx.Theme.LabelTertiary
	hex.TextColor3 = ctx.Theme.LabelPrimary
	hex.TextXAlignment = Enum.TextXAlignment.Left
	hex.TextYAlignment = Enum.TextYAlignment.Center
	hex.ClearTextOnFocus = false
	hex.Parent = root
	Util.corner(hex, Theme.Radius.Item)
	Util.padding(hex, 10, 0, 8, 0)
	local hexStroke = Util.stroke(hex, ctx.Theme.StrokeHairline, ctx.Theme.StrokeHairlineTransparency, 1)
	self.Hex = hex
	self.HexStroke = hexStroke

	local presetColors = options.Presets or Theme.Accents
	local presetSize = 22
	local presetGap = 12
	local presetCount = #presetColors
	local presetWidth = presetCount * presetSize + math.max(0, presetCount - 1) * presetGap
	local presetX = width - presetWidth
	local swatches = {}
	for index, preset in ipairs(presetColors) do
		local color = preset.Color or preset
		local holder = Util.frame({
			Name = "Preset" .. index,
			Position = UDim2.fromOffset(presetX + (index - 1) * (presetSize + presetGap), 215),
			Size = UDim2.fromOffset(presetSize, presetSize),
			BackgroundColor3 = color,
			Parent = root,
		})
		Util.corner(holder, UDim.new(0.5, 0))
		local swatchStroke = Util.stroke(holder, BLACK, 0.75, 1)
		local button = Util.button({
			Name = "PresetHit" .. index,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = holder,
		})
		button.Activated:Connect(function()
			self:SetColor(color, 1, true)
		end)
		table.insert(swatches, { Holder = holder, Stroke = swatchStroke, Color = color })
	end
	self.Swatches = swatches

	------------------------------------------------------------
	-- State
	------------------------------------------------------------
	local function currentColor(): Color3
		return Color3.fromHSV(self.Hue, self.Sat, math.max(self.Value, 0.0001))
	end
	self._currentColor = currentColor

	local function sync(fire: boolean)
		local color = currentColor()
		local hueColor = Color3.fromHSV(self.Hue, 1, 1)
		base.BackgroundColor3 = hueColor
		baseGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, WHITE),
			ColorSequenceKeypoint.new(1, hueColor),
		})
		cursorOuter.Position = UDim2.fromScale(self.Sat, 1 - self.Value)
		cursor.Position = UDim2.fromScale(self.Sat, 1 - self.Value)
		hueKnob.Position = UDim2.fromOffset(width * self.Hue, hueY + 6)
		hueKnobShadow.Position = UDim2.fromOffset(width * self.Hue, hueY + 7)
		alphaKnob.Position = UDim2.fromOffset(width * self.Alpha, alphaY + 6)
		alphaKnobShadow.Position = UDim2.fromOffset(width * self.Alpha, alphaY + 7)
		alphaOverlay.BackgroundColor3 = color
		alphaGradient.Color = ColorSequence.new(color)
		preview.BackgroundColor3 = color
		preview.BackgroundTransparency = 1 - self.Alpha
		self._updatingHex = true
		hex.Text = Util.toHex(color)
		self._updatingHex = false
		for _, swatch in ipairs(swatches) do
			local selected = Theme.colorEquals(swatch.Color, color) and self.Alpha > 0.99
			swatch.Stroke.Color = selected and WHITE or BLACK
			swatch.Stroke.Transparency = selected and 0.02 or 0.75
			swatch.Stroke.Thickness = selected and 2 or 1
		end
		if fire then
			self.Changed:Fire(color, self.Alpha, self)
			if options.OnChanged then
				task.spawn(options.OnChanged, color, self.Alpha, self)
			end
		end
	end
	self._sync = sync

	local active: string? = nil

	local function pointAlpha(gui: GuiObject, input: InputObject): number
		local size = gui.AbsoluteSize.X
		if size <= 0 then
			return 0
		end
		return math.clamp((input.Position.X - gui.AbsolutePosition.X) / size, 0, 1)
	end

	local function updateFromPoint(input: InputObject)
		if active == "sv" then
			self.Sat = pointAlpha(sv, input)
			local sizeY = sv.AbsoluteSize.Y
			if sizeY > 0 then
				self.Value = 1 - math.clamp((input.Position.Y - sv.AbsolutePosition.Y) / sizeY, 0, 1)
			end
		elseif active == "hue" then
			self.Hue = pointAlpha(hueTrack, input)
		elseif active == "alpha" then
			self.Alpha = pointAlpha(alphaTrack, input)
		end
		sync(true)
	end

	local function begin(kind: string)
		return function(input: InputObject)
			if not isPress(input) then
				return
			end
			active = kind
			updateFromPoint(input)
		end
	end

	svHit.InputBegan:Connect(begin("sv"))
	hueHit.InputBegan:Connect(begin("hue"))
	alphaHit.InputBegan:Connect(begin("alpha"))

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not active then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			updateFromPoint(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if isPress(input) then
			active = nil
		end
	end)

	local function commitHex()
		if self._updatingHex then
			return
		end
		local cleaned = hex.Text:gsub("#", ""):gsub("%s", "")
		if #cleaned == 6 and cleaned:match("^%x%x%x%x%x%x$") then
			local color = Color3.fromHex(cleaned)
			local h, s, v = color:ToHSV()
			self.Hue = h
			self.Sat = s
			self.Value = v
			sync(true)
		else
			sync(false)
		end
	end
	hex.FocusLost:Connect(commitHex)

	ctx:Bind(function(t: any, duration: number)
		Util.apply(hex, {
			BackgroundColor3 = t.GlassControl,
			BackgroundTransparency = t.GlassControlTransparency,
			TextColor3 = t.LabelPrimary,
			PlaceholderColor3 = t.LabelTertiary,
		}, duration)
		Util.apply(hexStroke, {
			Color = t.StrokeHairline,
			Transparency = t.StrokeHairlineTransparency,
		}, duration)
		Util.apply(svStroke, {
			Color = t.StrokeHairline,
			Transparency = t.StrokeHairlineTransparency,
		}, duration)
	end)

	if options.Color then
		local h, s, v = options.Color:ToHSV()
		self.Hue = h
		self.Sat = s
		self.Value = v
	end
	if options.Alpha then
		self.Alpha = math.clamp(options.Alpha, 0, 1)
	end
	sync(false)
	return self
end

function ColorPicker:SetColor(color: Color3, alpha: number?, silent: boolean?)
	local h, s, v = color:ToHSV()
	self.Hue = h
	self.Sat = s
	self.Value = v
	if alpha ~= nil then
		self.Alpha = math.clamp(alpha, 0, 1)
	end
	self._sync(silent ~= true)
end

function ColorPicker:GetColor(): (Color3, number)
	return self._currentColor(), self.Alpha
end

function ColorPicker:Destroy()
	self.Changed:DisconnectAll()
	self.Root:Destroy()
end

return ColorPicker

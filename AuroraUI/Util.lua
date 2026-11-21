--!strict
-- Aurora UI · Util
-- Small, dependency-free helpers used by every Aurora component.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Util = {}

--------------------------------------------------------------------------------
-- Signals
--------------------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn: (...any) -> ())
	local handle = { _fn = fn, _connected = true }
	table.insert(self._handlers, handle)
	return {
		Disconnect = function()
			if not handle._connected then
				return
			end
			handle._connected = false
			local index = table.find(self._handlers, handle)
			if index then
				table.remove(self._handlers, index)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, handle in ipairs(table.clone(self._handlers)) do
		if handle._connected then
			handle._fn(...)
		end
	end
end

function Signal:DisconnectAll()
	for _, handle in ipairs(self._handlers) do
		handle._connected = false
	end
	table.clear(self._handlers)
end

Util.Signal = Signal

--------------------------------------------------------------------------------
-- Instance helpers
--------------------------------------------------------------------------------

function Util.create(className: string, props: { [string]: any }?, children: { Instance }?): Instance
	local object = Instance.new(className)
	if props then
		for key, value in pairs(props) do
			if key ~= "Parent" then
				object[key] = value
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = object
		end
	end
	if props and props.Parent then
		object.Parent = props.Parent
	end
	return object
end

function Util.corner(parent: GuiObject, radius: number | UDim): UICorner
	local corner = parent:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

function Util.stroke(
	parent: GuiObject,
	color: Color3,
	transparency: number,
	thickness: number?
): UIStroke
	local stroke = parent:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness or 1
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = parent
	return stroke
end

function Util.gradient(
	parent: GuiObject,
	colors: ColorSequence | { [number]: Color3 },
	rotation: number?,
	transparency: NumberSequence?
): UIGradient
	local gradient = parent:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	if typeof(colors) == "ColorSequence" then
		gradient.Color = colors
	else
		local stops = {}
		for position, color in pairs(colors) do
			table.insert(stops, ColorSequenceKeypoint.new(position, color))
		end
		table.sort(stops, function(a, b)
			return a.Time < b.Time
		end)
		gradient.Color = ColorSequence.new(stops)
	end
	gradient.Rotation = rotation or 0
	if transparency then
		gradient.Transparency = transparency
	end
	gradient.Parent = parent
	return gradient
end

function Util.padding(parent: GuiObject, left: number, top: number?, right: number?, bottom: number?): UIPadding
	local padding = parent:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, left)
	padding.PaddingTop = UDim.new(0, top or left)
	padding.PaddingRight = UDim.new(0, right or left)
	padding.PaddingBottom = UDim.new(0, bottom or top or left)
	padding.Parent = parent
	return padding
end

function Util.list(
	parent: GuiObject,
	direction: Enum.FillDirection,
	padding: number,
	alignment: Enum.HorizontalAlignment?,
	verticalAlignment: Enum.VerticalAlignment?
): UIListLayout
	local layout = parent:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.Padding = UDim.new(0, padding)
	layout.HorizontalAlignment = alignment or Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = verticalAlignment or Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

function Util.text(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return Util.create("TextLabel", defaults)
end

function Util.button(props: { [string]: any }): TextButton
	local defaults = {
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		TextTransparency = 1,
	}
	if props and props.BackgroundColor3 ~= nil and props.BackgroundTransparency == nil then
		defaults.BackgroundTransparency = 0
	else
		defaults.BackgroundTransparency = 1
	end
	for key, value in pairs(props or {}) do
		defaults[key] = value
	end
	return Util.create("TextButton", defaults)
end

-- Frames are transparent containers by default. Passing a BackgroundColor3
-- without a transparency makes the frame visible, which is what a colored
-- surface (badge, knob, divider, swatch) always means.
function Util.frame(props: { [string]: any }): Frame
	local defaults = {
		BorderSizePixel = 0,
	}
	if props and props.BackgroundColor3 ~= nil and props.BackgroundTransparency == nil then
		defaults.BackgroundTransparency = 0
	else
		defaults.BackgroundTransparency = 1
	end
	for key, value in pairs(props or {}) do
		defaults[key] = value
	end
	return Util.create("Frame", defaults)
end

--------------------------------------------------------------------------------
-- Motion
--------------------------------------------------------------------------------

local EasingStyle = Enum.EasingStyle
local EasingDirection = Enum.EasingDirection

function Util.tween(
	object: Instance,
	properties: { [string]: any },
	duration: number,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	local info = TweenInfo.new(
		math.max(duration, 0),
		style or EasingStyle.Quint,
		direction or EasingDirection.Out
	)
	local tween = TweenService:Create(object, info, properties)
	tween:Play()
	return tween
end

-- Applies a property table immediately (duration = 0) or with a tween.
-- Used by every component's theme binding so a mode/accent change can
-- crossfade the entire interface in one pass.
function Util.apply(
	object: Instance,
	properties: { [string]: any },
	duration: number?,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	if not duration or duration <= 0 then
		for key, value in pairs(properties) do
			object[key] = value
		end
		return
	end
	local changes = {}
	for key, value in pairs(properties) do
		if object[key] ~= value then
			changes[key] = value
		end
	end
	if next(changes) then
		Util.tween(object, changes, duration, style, direction)
	end
end

function Util.tweenTransparency(
	object: Instance,
	property: string,
	value: number,
	duration: number,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	return Util.tween(object, { [property] = value }, duration, style, direction)
end

function Util.tweenColor(
	object: Instance,
	property: string,
	value: Color3,
	duration: number,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	return Util.tween(object, { [property] = value }, duration, style, direction)
end

function Util.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Util.clamp(value: number, min: number, max: number): number
	return math.max(min, math.min(max, value))
end

function Util.round(value: number, places: number?): number
	local mult = 10 ^ (places or 0)
	return math.floor(value * mult + 0.5) / mult
end

--------------------------------------------------------------------------------
-- Signals for interaction
--------------------------------------------------------------------------------

function Util.hover(gui: GuiObject, enter: () -> (), leave: () -> ())
	local enterConn = gui.MouseEnter:Connect(enter)
	local leaveConn = gui.MouseLeave:Connect(leave)
	return function()
		enterConn:Disconnect()
		leaveConn:Disconnect()
	end
end

function Util.pressScale(gui: GuiObject, scale: UIScale, pressedScale: number, duration: number?)
	local restScale = scale.Scale
	local function down()
		Util.tween(scale, { Scale = pressedScale }, duration or 0.12, EasingStyle.Quad, EasingDirection.Out)
	end
	local function up()
		Util.tween(scale, { Scale = restScale }, duration or 0.18, EasingStyle.Quint, EasingDirection.Out)
	end
	local began = gui.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			down()
		end
	end)
	local ended = gui.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			up()
		end
	end)
	return function()
		began:Disconnect()
		ended:Disconnect()
	end
end

--------------------------------------------------------------------------------
-- Drag helper
--------------------------------------------------------------------------------

-- Returns a disconnect function. Movement is converted into the parent's
-- scale space, so dragging stays exact on any screen size and inside a UIScale.
-- onStart / onEnd let callers animate the lifted state; onMoved receives the
-- window position plus the raw pointer delta (useful for tilt / velocity).
function Util.makeDraggable(
	frame: GuiObject,
	handle: GuiObject,
	onMoved: ((Vector2, Vector2) -> ())?,
	onStart: (() -> ())?,
	onEnd: (() -> ())?
)
	local dragging = false
	local startMouse = Vector2.zero
	local startScale = Vector2.zero
	local parentSize = Vector2.new(1, 1)

	local function parentScale(): number
		local scale = 1
		local current: Instance? = frame.Parent
		while current do
			if current:IsA("GuiObject") then
				local uiScale = current:FindFirstChildOfClass("UIScale")
				if uiScale then
					scale *= uiScale.Scale
				end
			end
			current = current.Parent
		end
		return scale
	end

	local function viewportSize(): Vector2
		local parent = frame.Parent
		if parent and parent:IsA("GuiObject") then
			return parent.AbsoluteSize
		end
		local camera = workspace.CurrentCamera
		return camera and camera.ViewportSize or Vector2.new(1280, 800)
	end

	local began = handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		dragging = true
		startMouse = Vector2.new(input.Position.X, input.Position.Y)
		startScale = Vector2.new(frame.Position.X.Scale, frame.Position.Y.Scale)
		parentSize = viewportSize()
		if onStart then
			onStart()
		end
	end)

	local changed = UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		local current = Vector2.new(input.Position.X, input.Position.Y)
		local delta = (current - startMouse) / math.max(parentScale(), 0.001)
		local size = Vector2.new(math.max(parentSize.X, 1), math.max(parentSize.Y, 1))
		frame.Position = UDim2.fromScale(
			startScale.X + delta.X / size.X,
			startScale.Y + delta.Y / size.Y
		)
		if onMoved then
			onMoved(frame.Position.X.Scale * size.X, frame.Position.Y.Scale * size.Y, delta)
		end
	end)

	local ended = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if dragging and onEnd then
				onEnd()
			end
			dragging = false
		end
	end)

	return function()
		began:Disconnect()
		changed:Disconnect()
		ended:Disconnect()
	end
end

--------------------------------------------------------------------------------
-- Color helpers
--------------------------------------------------------------------------------

function Util.hex(value: string): Color3
	local cleaned = value:gsub("#", "")
	if #cleaned == 8 then
		cleaned = cleaned:sub(1, 6)
	end
	return Color3.fromHex(cleaned)
end

function Util.hexAlpha(value: string): number
	local cleaned = value:gsub("#", "")
	if #cleaned == 8 then
		return tonumber(cleaned:sub(7, 8), 16) / 255
	end
	return 1
end

function Util.toHex(color: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.round(color.R * 255),
		math.round(color.G * 255),
		math.round(color.B * 255)
	)
end

function Util.mixColor(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, Util.clamp(t, 0, 1))
end

function Util.darken(color: Color3, amount: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, math.max(0, v - amount))
end

function Util.brighten(color: Color3, amount: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, math.min(1, v + amount))
end

function Util.contrastText(color: Color3): Color3
	local h, s, v = color:ToHSV()
	return v > 0.62 and Color3.fromHex("#111114") or Color3.new(1, 1, 1)
end

--------------------------------------------------------------------------------
-- Misc
--------------------------------------------------------------------------------

function Util.px(value: number): UDim
	return UDim.new(0, value)
end

function Util.scale(value: number): UDim
	return UDim.new(value, 0)
end

function Util.clearChildren(parent: Instance)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function Util.numberSequence(values: { [number]: number }): NumberSequence
	local keys = {}
	for time, value in pairs(values) do
		table.insert(keys, NumberSequenceKeypoint.new(time, value))
	end
	table.sort(keys, function(a, b)
		return a.Time < b.Time
	end)
	return NumberSequence.new(keys)
end

-- A soft, blurred-looking ellipse built from concentric translucent layers.
-- Roblox has no backdrop blur, so this gives the aurora its diffuse glow.
function Util.softBlob(parent: GuiObject, options: {
	position: UDim2,
	size: UDim2,
	color: Color3,
	alpha: number?,
	steps: number?,
	zIndex: number?,
	rotation: number?,
}): Frame
	local steps = options.steps or 14
	local root = Util.frame({
		Name = "SoftBlob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = options.position,
		Size = options.size,
		BackgroundTransparency = 1,
		ZIndex = options.zIndex or 2,
		Parent = parent,
	})
	local baseAlpha = options.alpha or 0.06
	for index = 1, steps do
		local t = index / steps
		local scale = 1 - (index - 1) / steps
		local layer = Util.frame({
			Name = "Layer",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(scale, scale),
			BackgroundColor3 = options.color,
			BackgroundTransparency = 1 - (baseAlpha * (0.45 + t * 0.55)),
			BorderSizePixel = 0,
			ZIndex = options.zIndex or 2,
			Parent = root,
		})
		Util.corner(layer, UDim.new(0.5, 0))
	end
	return root
end

function Util.timeString(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = math.floor(total / 3600)
	local minutes = math.floor((total % 3600) / 60)
	local secs = total % 60
	return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

return Util

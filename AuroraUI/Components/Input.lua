--!strict
-- Aurora UI · Input
-- 36px glass text field with accent focus ring and placeholder.

local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local Input = {}
Input.__index = Input

function Input.new(props: { [string]: any }?)
	local options = props or {}
	local ctx = assert(options.Context, "Aurora.Input requires a Context")
	local self = setmetatable({}, Input)
	self.Context = ctx
	self.Focused = false
	self.Submitted = Util.Signal.new()
	self.Changed = Util.Signal.new()

	local root = Util.frame({
		Name = options.Name or "Input",
		Size = UDim2.new(options.WidthScale or 1, options.Width or 0, 0, options.Height or 36),
		Parent = options.Parent,
	})
	Util.corner(root, Theme.Radius.Item)
	self.Root = root

	local stroke = Util.stroke(root, ctx.Theme.StrokeHairline, ctx.Theme.StrokeHairlineTransparency, 1)
	self.Stroke = stroke

	local box = Instance.new("TextBox")
	box.Name = "TextBox"
	box.BackgroundTransparency = 1
	box.BorderSizePixel = 0
	box.Position = UDim2.fromOffset(12, 0)
	box.Size = UDim2.new(1, -24, 1, 0)
	box.Font = Theme.Font.Regular
	box.TextSize = options.TextSize or 13
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Center
	box.Text = options.Text or ""
	box.PlaceholderText = options.Placeholder or "Type here…"
	box.PlaceholderColor3 = ctx.Theme.LabelTertiary
	box.TextColor3 = ctx.Theme.LabelPrimary
	box.ClearTextOnFocus = false
	box.MultiLine = false
	box.TextEditable = options.Enabled ~= false
	box.ClipsDescendants = true
	box.Parent = root
	self.TextBox = box

	local function refresh(duration: number)
		local t = ctx.Theme
		Util.apply(root, {
			BackgroundColor3 = self.Focused and t.GlassControlHover or t.GlassControl,
			BackgroundTransparency = self.Focused and t.GlassControlHoverTransparency or t.GlassControlTransparency,
		}, duration)
		Util.apply(stroke, {
			Color = self.Focused and t.Accent or t.StrokeHairline,
			Transparency = self.Focused and 0.35 or t.StrokeHairlineTransparency,
		}, duration)
		Util.apply(box, {
			TextColor3 = t.LabelPrimary,
			PlaceholderColor3 = t.LabelTertiary,
		}, duration)
	end
	self._refresh = refresh
	ctx:Bind(function(_, duration: number)
		refresh(duration)
	end)

	box.Focused:Connect(function()
		self.Focused = true
		refresh(Theme.Motion.Fast)
	end)
	box.FocusLost:Connect(function(enterPressed: boolean)
		self.Focused = false
		refresh(Theme.Motion.Fast)
		if enterPressed then
			self.Submitted:Fire(box.Text, self)
			if options.OnSubmit then
				task.spawn(options.OnSubmit, box.Text, self)
			end
		end
		if options.OnFocusLost then
			task.spawn(options.OnFocusLost, box.Text, self)
		end
	end)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		self.Changed:Fire(box.Text, self)
		if options.OnChanged then
			task.spawn(options.OnChanged, box.Text, self)
		end
	end)

	return self
end

function Input:SetText(text: string)
	self.TextBox.Text = text
end

function Input:GetText(): string
	return self.TextBox.Text
end

function Input:SetPlaceholder(text: string)
	self.TextBox.PlaceholderText = text
end

function Input:Focus()
	self.TextBox:CaptureFocus()
end

function Input:Destroy()
	self.Submitted:DisconnectAll()
	self.Changed:DisconnectAll()
	self.Root:Destroy()
end

return Input

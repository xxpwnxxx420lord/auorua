--!strict
-- Aurora UI · Tab
-- The simple API. A tab owns a scrolling stack of glass cards; every Add*
-- method positions its own control, so callers never touch UDim2.
--
--   local main = Window:AddTab("Main")
--   local auto = main:AddToggle("Auto apply", true)
--   auto:OnChanged(function(value) print(value) end)

local TextService = game:GetService("TextService")

local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local Tab = {}
Tab.__index = Tab

local BODY_Y = 62
local BODY_HEIGHT = 324
local CONTENT_WIDTH = 468
local CARD_X = 20
local CARD_WIDTH = 428
local GAP = 12

local function optionsFrom(first: any, fallback: { [string]: any }): { [string]: any }
	if type(first) == "table" then
		return first
	end
	return fallback
end

local function bindText(ctx: any, label: TextLabel, colorKey: string, transparencyKey: string)
	ctx:Bind(function(t: any, duration: number)
		Util.apply(label, {
			TextColor3 = t[colorKey],
			TextTransparency = t[transparencyKey],
		}, duration)
	end)
end

function Tab.new(props: { [string]: any }?)
	local options = props or {}
	local self = setmetatable({}, Tab)

	self.Window = assert(options.Window, "Aurora.Tab requires a Window")
	self.Context = assert(options.Context, "Aurora.Tab requires a Context")
	self.Page = assert(options.Page, "Aurora.Tab requires a Page")
	self.Index = options.Index or 1
	self.Title = options.Title or ("Tab " .. tostring(self.Index))
	self._y = 0
	self._card = nil
	self._cardY = 0

	self.Window:BuildHeader(self.Page, self.Title)

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(0, BODY_Y)
	body.Size = UDim2.fromOffset(CONTENT_WIDTH, BODY_HEIGHT)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ClipsDescendants = true
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.ScrollBarThickness = 2
	body.ScrollBarImageColor3 = self.Context.Theme.LabelTertiary
	body.ScrollBarImageTransparency = 0.4
	body.CanvasSize = UDim2.fromOffset(CONTENT_WIDTH, BODY_HEIGHT)
	body.ZIndex = 3
	body.Parent = self.Page
	self.Body = body

	self.Context:Bind(function(t: any, duration: number)
		Util.apply(body, {
			ScrollBarImageColor3 = t.LabelTertiary,
			ScrollBarImageTransparency = 0.4,
		}, duration)
	end)

	return self
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

function Tab:_layout()
	if self._card then
		self._y = self._cardY + self._card.Root.Size.Y.Offset + GAP
	end
	local height = math.max(BODY_HEIGHT, self._y + 8)
	self.Body.CanvasSize = UDim2.fromOffset(CONTENT_WIDTH, height)
end

function Tab:_ensureCard(): any
	if self._card then
		return self._card
	end
	local card = Components.Group.new({
		Context = self.Context,
		Parent = self.Body,
		Width = CARD_WIDTH,
	})
	card.Root.Position = UDim2.fromOffset(CARD_X, self._y)
	self._card = card
	self._cardY = self._y
	return card
end

function Tab:_addRow(row: any)
	local card = self:_ensureCard()
	card:AddRow(row)
	self:_layout()
end

function Tab:_endCard()
	self._card = nil
end

function Tab:_addStandalone(root: GuiObject, height: number)
	root.Position = UDim2.fromOffset(CARD_X, self._y)
	self._y += height + GAP
	self:_layout()
end

--------------------------------------------------------------------------------
-- Paragraph
--------------------------------------------------------------------------------

function Tab:AddParagraph(first: any, second: any)
	local options = optionsFrom(first, { Title = first, Content = second })
	local title = options.Title or options.Name
	local content = options.Content or options.Body or ""

	if not title and content == "" then
		return nil
	end

	local titleHeight = title and 20 or 0
	local bodyHeight = 0
	if content ~= "" then
		local ok, bounds = pcall(function()
			return TextService:GetTextSize(content, 13, Theme.Font.Regular, Vector2.new(CARD_WIDTH, 10000))
		end)
		bodyHeight = ok and math.ceil(bounds.Y) or 18
	end

	local height = titleHeight + (title and content ~= "" and 6 or 0) + bodyHeight
	local frame = Util.frame({
		Name = "Paragraph",
		Parent = self.Body,
		Size = UDim2.fromOffset(CARD_WIDTH, height),
		BackgroundTransparency = 1,
	})

	if title then
		local heading = Util.text({
			Name = "Title",
			Size = UDim2.fromOffset(CARD_WIDTH, 20),
			Text = title,
			TextSize = 14,
			Font = Theme.Font.Semibold,
			Parent = frame,
		})
		bindText(self.Context, heading, "LabelPrimary", "LabelPrimaryTransparency")
	end

	if content ~= "" then
		local body = Util.text({
			Name = "Content",
			Position = UDim2.fromOffset(0, titleHeight + (title and 6 or 0)),
			Size = UDim2.fromOffset(CARD_WIDTH, bodyHeight),
			Text = content,
			TextSize = 13,
			Font = Theme.Font.Regular,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = frame,
		})
		bindText(self.Context, body, "LabelSecondary", "LabelSecondaryTransparency")
	end

	self:_endCard()
	self:_addStandalone(frame, height)
	return { Root = frame }
end

--------------------------------------------------------------------------------
-- Button
--------------------------------------------------------------------------------

function Tab:AddButton(first: any, second: any)
	local options = optionsFrom(first, { Title = first, Callback = second })
	local title = tostring(options.Title or options.Name or "Button")
	local description = options.Description
	local callback = options.Callback or options.OnClick
	local height = description and 58 or 48

	self:_endCard()

	local card = Components.Group.new({
		Context = self.Context,
		Parent = self.Body,
		Width = CARD_WIDTH,
		RowHeight = height,
		Height = height + 2,
	})
	local row = Components.Row.new({
		Context = self.Context,
		Label = title,
		Height = height,
	})

	if description then
		row.Label.Position = UDim2.fromOffset(16, 10)
		row.Label.Size = UDim2.new(1, -60, 0, 18)
		row.Label.TextYAlignment = Enum.TextYAlignment.Top
		local sub = Util.text({
			Name = "Description",
			Position = UDim2.fromOffset(16, 30),
			Size = UDim2.new(1, -60, 0, 16),
			Text = tostring(description),
			TextSize = 11,
			Font = Theme.Font.Regular,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row.Root,
		})
		bindText(self.Context, sub, "LabelSecondary", "LabelSecondaryTransparency")
	end

	local chevron = Util.text({
		Name = "Chevron",
		Size = UDim2.fromOffset(18, 18),
		Text = "›",
		TextSize = 18,
		Font = Theme.Font.Medium,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = row.Root,
	})
	row:SetTrailing(chevron)
	bindText(self.Context, chevron, "LabelTertiary", "LabelTertiaryTransparency")

	card:AddRow(row)
	card.Root.Position = UDim2.fromOffset(CARD_X, self._y)
	self._y += card.Root.Size.Y.Offset + GAP
	self:_layout()

	local hit = Util.button({
		Name = "Action",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Selectable = true,
		ZIndex = 8,
		Parent = row.Root,
	})
	hit.Activated:Connect(function()
		if callback then
			task.spawn(callback)
		end
	end)

	return { Row = row, Card = card, Button = hit }
end

--------------------------------------------------------------------------------
-- Toggle
--------------------------------------------------------------------------------

function Tab:AddToggle(first: any, second: any, third: any)
	local options = optionsFrom(first, { Title = first, Default = second, Callback = third })
	local switch = Components.Switch.new({
		Context = self.Context,
		Value = options.Default == true or options.Value == true,
	})
	local row = Components.Row.new({
		Context = self.Context,
		Label = tostring(options.Title or options.Name or "Toggle"),
		Trailing = switch.Root,
	})
	self:_addRow(row)

	local id = options.Id or options.Name
	local callback = options.Callback
	if id then
		self.Window:BindToggle(id, switch, callback)
	elseif callback then
		switch.Changed:Connect(function(value: boolean)
			task.spawn(callback, value)
		end)
	end

	local record: any = {
		Value = switch.Value,
		Switch = switch,
		Row = row,
		Id = id,
	}
	switch.Changed:Connect(function(value: boolean)
		record.Value = value
	end)
	function record:SetValue(value: boolean, animate: boolean?)
		switch:SetValue(value == true, animate ~= false)
	end
	function record:OnChanged(fn: (boolean) -> ())
		return switch.Changed:Connect(fn)
	end
	return record
end

--------------------------------------------------------------------------------
-- Slider
--------------------------------------------------------------------------------

function Tab:AddSlider(first: any, second: any, third: any, fourth: any, fifth: any)
	local options = optionsFrom(first, {
		Title = first,
		Min = second,
		Max = third,
		Default = fourth,
		Callback = fifth,
	})
	local min = tonumber(options.Min) or 0
	local max = tonumber(options.Max) or 100
	local slider = Components.Slider.new({
		Context = self.Context,
		Min = min,
		Max = max,
		Step = tonumber(options.Step) or 1,
		Value = tonumber(options.Default) or min,
		Suffix = options.Suffix,
		Format = options.Format,
	})
	local row = Components.Row.new({
		Context = self.Context,
		Label = tostring(options.Title or options.Name or "Slider"),
		Trailing = slider.Root,
	})
	-- Slider + readout is the widest trailing control; keep the label clear.
	row.Label.Size = UDim2.new(1, -270, 1, 0)
	self:_addRow(row)

	local callback = options.Callback
	if callback then
		slider.Changed:Connect(function(value: number)
			task.spawn(callback, value)
		end)
	end

	local record: any = {
		Value = slider.Value,
		Slider = slider,
		Row = row,
	}
	slider.Changed:Connect(function(value: number)
		record.Value = value
	end)
	function record:SetValue(value: number, animate: boolean?)
		slider:SetValue(value, animate ~= false)
	end
	function record:OnChanged(fn: (number) -> ())
		return slider.Changed:Connect(fn)
	end
	return record
end

--------------------------------------------------------------------------------
-- Dropdown
--------------------------------------------------------------------------------

function Tab:AddDropdown(first: any, second: any, third: any, fourth: any)
	local options = optionsFrom(first, {
		Title = first,
		Options = second,
		Default = third,
		Callback = fourth,
	})
	local values = options.Options or options.Values or {}
	if #values == 0 then
		values = { "Option 1" }
	end

	local default = options.Default
	local index = 1
	if type(default) == "number" then
		index = math.clamp(math.floor(default), 1, #values)
	elseif type(default) == "string" then
		index = table.find(values, default) or 1
	end

	local dropdown = Components.Dropdown.new({
		Context = self.Context,
		Options = values,
		Index = index,
		Width = tonumber(options.Width) or 150,
	})
	local row = Components.Row.new({
		Context = self.Context,
		Label = tostring(options.Title or options.Name or "Dropdown"),
		Trailing = dropdown.Root,
	})
	self:_addRow(row)

	local callback = options.Callback
	if callback then
		dropdown.Changed:Connect(function(_, value: string)
			task.spawn(callback, value)
		end)
	end

	local record: any = {
		Value = dropdown:GetValue(),
		Dropdown = dropdown,
		Row = row,
	}
	dropdown.Changed:Connect(function(_, value: string)
		record.Value = value
	end)
	function record:SetValue(value: string, silent: boolean?)
		local nextIndex = table.find(values, value)
		if nextIndex then
			dropdown:SetIndex(nextIndex, silent == true)
			record.Value = dropdown:GetValue()
		end
	end
	function record:OnChanged(fn: (string) -> ())
		return dropdown.Changed:Connect(function(_, value: string)
			fn(value)
		end)
	end
	return record
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

function Tab:AddInput(first: any, second: any, third: any, fourth: any)
	local options = optionsFrom(first, {
		Title = first,
		Placeholder = second,
		Default = third,
		Callback = fourth,
	})
	local input = Components.Input.new({
		Context = self.Context,
		Text = tostring(options.Default or ""),
		Placeholder = tostring(options.Placeholder or "Type here…"),
		WidthScale = 0,
		Width = tonumber(options.Width) or 190,
		Height = 36,
	})
	local row = Components.Row.new({
		Context = self.Context,
		Label = tostring(options.Title or options.Name or "Input"),
		Trailing = input.Root,
	})
	self:_addRow(row)

	local callback = options.Callback
	if callback then
		input.Changed:Connect(function(text: string)
			task.spawn(callback, text)
		end)
	end

	local record: any = {
		Value = input:GetText(),
		Input = input,
		Row = row,
	}
	input.Changed:Connect(function(text: string)
		record.Value = text
	end)
	function record:SetValue(text: string)
		input:SetText(tostring(text))
		record.Value = input:GetText()
		input.Changed:Fire(record.Value)
	end
	function record:OnChanged(fn: (string) -> ())
		return input.Changed:Connect(function(text: string)
			fn(text)
		end)
	end
	return record
end

--------------------------------------------------------------------------------
-- Color picker
--------------------------------------------------------------------------------

function Tab:AddColorPicker(first: any, second: any, third: any)
	local options = optionsFrom(first, { Title = first, Default = second, Callback = third })
	local color = options.Default or options.Color or Color3.fromRGB(96, 205, 255)
	local alpha = options.Alpha
	if alpha == nil and options.Transparency ~= nil then
		alpha = 1 - (tonumber(options.Transparency) or 0)
	end
	alpha = math.clamp(tonumber(alpha) or 1, 0, 1)

	self:_endCard()

	local height = 302
	local card = Components.Group.new({
		Context = self.Context,
		Parent = self.Body,
		Width = CARD_WIDTH,
		Height = height,
	})
	card.Root.Position = UDim2.fromOffset(CARD_X, self._y)
	self._y += height + GAP
	self:_layout()

	local title = Util.text({
		Name = "Title",
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 18),
		Text = tostring(options.Title or options.Name or "Color"),
		TextSize = 13,
		Font = Theme.Font.Semibold,
		Parent = card.Root,
	})
	bindText(self.Context, title, "LabelPrimary", "LabelPrimaryTransparency")

	local picker = Components.ColorPicker.new({
		Context = self.Context,
		Parent = card.Root,
		Width = CARD_WIDTH - 32,
		Color = color,
		Alpha = alpha,
	})
	picker.Root.Position = UDim2.fromOffset(16, 36)

	local callback = options.Callback
	if callback then
		picker.Changed:Connect(function(nextColor: Color3, nextAlpha: number)
			task.spawn(callback, nextColor, nextAlpha)
		end)
	end

	local record: any = {
		Value = color,
		Alpha = alpha,
		Picker = picker,
		Card = card,
	}
	picker.Changed:Connect(function(nextColor: Color3, nextAlpha: number)
		record.Value = nextColor
		record.Alpha = nextAlpha
	end)
	function record:SetValue(nextColor: Color3, nextAlpha: number?)
		picker:SetColor(nextColor, nextAlpha)
		record.Value, record.Alpha = picker:GetColor()
	end
	function record:GetValue(): (Color3, number)
		return picker:GetColor()
	end
	function record:OnChanged(fn: (Color3, number) -> ())
		return picker.Changed:Connect(function(nextColor: Color3, nextAlpha: number)
			fn(nextColor, nextAlpha)
		end)
	end
	return record
end

return Tab

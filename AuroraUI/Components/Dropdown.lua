--!strict
-- Aurora UI · Dropdown
-- 32px glass trigger with an anchored menu. The menu lives in
-- Context.Overlay so it is never clipped by the window.

local UserInputService = game:GetService("UserInputService")

local Common = require(script.Parent.Common)
local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local Dropdown = {}
Dropdown.__index = Dropdown

function Dropdown.new(props: { [string]: any }?)
	local options = props or {}
	local ctx = assert(options.Context, "Aurora.Dropdown requires a Context")
	local self = setmetatable({}, Dropdown)

	self.Context = ctx
	self.Options = options.Options or { "Option 1", "Option 2" }
	self.Index = options.Index or 1
	self.Open = false
	self.Changed = Util.Signal.new()
	self._width = options.Width or 150

	local root = Util.button({
		Name = options.Name or "Dropdown",
		Size = UDim2.fromOffset(self._width, 32),
		BackgroundTransparency = 1,
		Selectable = true,
		Parent = options.Parent,
	})
	Util.corner(root, Theme.Radius.Item)
	self.Root = root

	local background = Util.frame({
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	Util.corner(background, Theme.Radius.Item)
	self.Background = background
	local stroke = Util.stroke(background, Color3.new(1, 1, 1), 1, 1)
	self.Stroke = stroke

	local label = Util.text({
		Name = "Label",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -38, 1, 0),
		Text = self.Options[self.Index] or "",
		TextSize = 13,
		Font = Theme.Font.Medium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = root,
	})
	self.Label = label

	local chevron = Util.frame({
		Name = "Chevron",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -18, 0.5, 1),
		Size = UDim2.fromOffset(9, 6),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local leftBar = Util.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.3, 0.5),
		Size = UDim2.fromOffset(6, 1.5),
		Rotation = 45,
		Parent = chevron,
	})
	Util.corner(leftBar, 1)
	local rightBar = Util.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.7, 0.5),
		Size = UDim2.fromOffset(6, 1.5),
		Rotation = -45,
		Parent = chevron,
	})
	Util.corner(rightBar, 1)
	self.Chevron = chevron

	ctx:Bind(function(t: any, duration: number)
		Util.apply(background, {
			BackgroundColor3 = t.GlassControl,
			BackgroundTransparency = t.GlassControlTransparency,
		}, duration)
		Util.apply(stroke, {
			Color = t.StrokeHairline,
			Transparency = t.StrokeHairlineTransparency,
		}, duration)
		Util.apply(label, {
			TextColor3 = t.LabelPrimary,
			TextTransparency = t.LabelPrimaryTransparency,
		}, duration)
		Util.apply(leftBar, { BackgroundColor3 = t.LabelSecondary }, duration)
		Util.apply(rightBar, { BackgroundColor3 = t.LabelSecondary }, duration)
	end)

	local function closeMenu()
		if not self.Menu then
			return
		end
		local menu = self.Menu
		local scrim = self.Scrim
		self.Menu = nil
		self.Scrim = nil
		self.Open = false
		if menu then
			Util.tween(menu, { GroupTransparency = 1 }, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			Util.tween(menu, { Position = menu.Position + UDim2.fromOffset(0, 6) }, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end
		if scrim then
			scrim:Destroy()
		end
		task.delay(0.18, function()
			if menu then
				menu:Destroy()
			end
		end)
	end
	self._closeMenu = closeMenu
	self.Close = closeMenu

	local function choose(index: number)
		self.Index = index
		label.Text = self.Options[index] or ""
		closeMenu()
		self.Changed:Fire(index, self.Options[index], self)
		if options.OnChanged then
			task.spawn(options.OnChanged, index, self.Options[index], self)
		end
	end

	local function buildMenu()
		local overlay = ctx.Overlay or root.Parent
		if not overlay then
			return
		end
		local t = ctx.Theme
		local scale = root.AbsoluteSize.X / math.max(root.Size.X.Offset, 1)
		local menuHeight = 8 + #self.Options * 34

		local scrim = Util.button({
			Name = "DropdownScrim",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 90,
			Parent = overlay,
		})
		scrim.Activated:Connect(closeMenu)
		self.Scrim = scrim

		local menu = Instance.new("CanvasGroup")
		menu.Name = "DropdownMenu"
		menu.Size = UDim2.fromOffset(self._width, menuHeight)
		menu.BackgroundColor3 = t.Mode == "Dark" and t.GlassPill or t.GlassWindow
		menu.BackgroundTransparency = t.Mode == "Dark" and 0.06 or 0.1
		menu.GroupTransparency = 1
		menu.ZIndex = 91
		menu.Parent = overlay
		Util.corner(menu, Theme.Radius.Control)
		Util.stroke(menu, t.StrokeGlass, t.StrokeGlassTransparency, 1)

		local menuScale = Instance.new("UIScale")
		menuScale.Scale = scale
		menuScale.Parent = menu

		local targetX = root.AbsolutePosition.X - overlay.AbsolutePosition.X
		local targetY = root.AbsolutePosition.Y - overlay.AbsolutePosition.Y + root.AbsoluteSize.Y + 6
		menu.Position = UDim2.fromOffset(targetX, targetY + 6)

		for index, text in ipairs(self.Options) do
			local item = Util.button({
				Name = "Item" .. index,
				Position = UDim2.fromOffset(4, 4 + (index - 1) * 34),
				Size = UDim2.new(1, -8, 0, 34),
				BackgroundTransparency = 1,
				ZIndex = 92,
				Parent = menu,
			})
			Util.corner(item, 8)
			local itemLabel = Util.text({
				Name = "Label",
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -36, 1, 0),
				Text = text,
				TextSize = 13,
				Font = Theme.Font.Medium,
				TextColor3 = index == self.Index and t.Accent or t.LabelPrimary,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 93,
				Parent = item,
			})
			if index == self.Index then
				item.BackgroundColor3 = t.AccentSoft
				item.BackgroundTransparency = 0.7
				local check = Common.check(item, t.Accent, 10)
				check.Position = UDim2.fromScale(0.92, 0.5)
				check.ZIndex = 94
			end
			item.MouseEnter:Connect(function()
				item.BackgroundColor3 = t.GlassControlHover
				item.BackgroundTransparency = 0.7
			end)
			item.MouseLeave:Connect(function()
				if index == self.Index then
					item.BackgroundColor3 = t.AccentSoft
					item.BackgroundTransparency = 0.7
				else
					item.BackgroundTransparency = 1
				end
			end)
			item.Activated:Connect(function()
				choose(index)
			end)
		end

		self.Menu = menu
		self.Open = true
		task.defer(function()
			if self.Menu == menu then
				Util.tween(menu, {
					Position = UDim2.fromOffset(targetX, targetY),
					GroupTransparency = 0,
				}, Theme.Motion.Fast, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			end
		end)
	end

	root.Activated:Connect(function()
		if self.Open then
			closeMenu()
		else
			buildMenu()
		end
	end)

	root.AncestryChanged:Connect(function()
		closeMenu()
	end)

	return self
end

function Dropdown:SetIndex(index: number, silent: boolean?)
	self.Index = math.clamp(math.floor(index), 1, #self.Options)
	self.Label.Text = self.Options[self.Index] or ""
	if not silent then
		self.Changed:Fire(self.Index, self.Options[self.Index], self)
	end
end

function Dropdown:GetValue(): string
	return self.Options[self.Index]
end

function Dropdown:Destroy()
	self._closeMenu()
	self.Changed:DisconnectAll()
	self.Root:Destroy()
end

return Dropdown

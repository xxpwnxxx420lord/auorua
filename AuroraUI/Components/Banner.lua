--!strict
-- Aurora UI · Banner
-- 340x76 notification card. Slides in with a Back Out curve and fades out
-- with Quad In, matching the motion note in Figma.

local Common = require(script.Parent.Common)
local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local Banner = {}
Banner.__index = Banner

function Banner.new(props: { [string]: any }?)
	local options = props or {}
	local ctx = assert(options.Context, "Aurora.Banner requires a Context")
	local self = setmetatable({}, Banner)

	self.Context = ctx
	self.Shown = false
	self.ShownPosition = options.ShownPosition or UDim2.fromOffset(916, 24)
	self.HiddenPosition = options.HiddenPosition or UDim2.fromOffset(1320, 24)

	local root = Instance.new("CanvasGroup")
	root.Name = options.Name or "Banner"
	root.Size = UDim2.fromOffset(340, 76)
	root.Position = self.HiddenPosition
	root.BackgroundColor3 = ctx.Theme.GlassPill
	root.BackgroundTransparency = ctx.Theme.GlassPillTransparency
	root.GroupTransparency = 1
	root.Visible = false
	root.Parent = options.Parent
	Util.corner(root, Theme.Radius.Card)
	self.Root = root

	local stroke = Util.stroke(root, ctx.Theme.StrokeGlass, ctx.Theme.StrokeGlassTransparency, 1)
	self.Stroke = stroke

	-- Same 9-slice shadow asset as the window, sized to the card.
	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.fromScale(0.5, 0.5)
	shadow.Size = UDim2.new(1, 30, 1, 30)
	shadow.BackgroundTransparency = 1
	shadow.BorderSizePixel = 0
	shadow.Image = "rbxassetid://6014261993"
	shadow.ImageColor3 = Color3.fromHex("000000")
	shadow.ImageTransparency = 0.50
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(49, 49, 450, 450)
	shadow.ZIndex = 0
	shadow.Parent = root
	self.Shadow = shadow

	local badge = Util.frame({
		Name = "Badge",
		Position = UDim2.fromOffset(17, 16),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = ctx.Theme.Accent,
		Parent = root,
	})
	Util.corner(badge, 14)
	local badgeGradient = Util.gradient(badge, ctx.Theme.HeroGradient, 35)
	Common.check(badge, Color3.new(1, 1, 1), 14)
	self.Badge = badge
	self.BadgeGradient = badgeGradient

	local title = Util.text({
		Name = "Title",
		Position = UDim2.fromOffset(73, 21),
		Size = UDim2.fromOffset(213, 18),
		Text = options.Title or "Settings applied",
		TextSize = 13,
		Font = Theme.Font.Semibold,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = root,
	})
	self.Title = title

	local body = Util.text({
		Name = "Body",
		Position = UDim2.fromOffset(73, 40),
		Size = UDim2.fromOffset(230, 16),
		Text = options.Body or "Your changes have been saved.",
		TextSize = 12,
		Font = Theme.Font.Regular,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = root,
	})
	self.Body = body

	local time = Util.text({
		Name = "Time",
		Position = UDim2.fromOffset(298, 31),
		Size = UDim2.fromOffset(30, 14),
		Text = options.Time or "now",
		TextSize = 10,
		Font = Theme.Font.Medium,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = root,
	})
	self.Time = time

	ctx:Bind(function(t: any, duration: number)
		Util.apply(root, {
			BackgroundColor3 = t.GlassPill,
			BackgroundTransparency = t.GlassPillTransparency,
		}, duration)
		Util.apply(stroke, {
			Color = t.StrokeGlass,
			Transparency = t.StrokeGlassTransparency,
		}, duration)
		Util.apply(title, {
			TextColor3 = t.LabelPrimary,
			TextTransparency = t.LabelPrimaryTransparency,
		}, duration)
		Util.apply(body, {
			TextColor3 = t.LabelSecondary,
			TextTransparency = t.LabelSecondaryTransparency,
		}, duration)
		Util.apply(time, {
			TextColor3 = t.LabelTertiary,
			TextTransparency = t.LabelTertiaryTransparency,
		}, duration)
		badgeGradient.Color = t.HeroGradient
		badge.BackgroundColor3 = t.Accent
	end)

	return self
end

function Banner:SetContent(title: string?, body: string?, time: string?)
	if title then
		self.Title.Text = title
	end
	if body then
		self.Body.Text = body
	end
	if time then
		self.Time.Text = time
	end
end

function Banner:Show()
	self.Root.Visible = true
	self.Root.Position = self.HiddenPosition
	self.Root.GroupTransparency = 1
	self.Shown = true
	Util.tween(self.Root, {
		Position = self.ShownPosition,
		GroupTransparency = 0,
	}, Theme.Motion.BannerIn, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

function Banner:Hide()
	if not self.Shown then
		return
	end
	self.Shown = false
	Util.tween(self.Root, {
		Position = self.HiddenPosition,
		GroupTransparency = 1,
	}, Theme.Motion.BannerOut, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(Theme.Motion.BannerOut + 0.05, function()
		if not self.Shown then
			self.Root.Visible = false
		end
	end)
end

function Banner:Destroy()
	self.Root:Destroy()
end

return Banner

--!strict
-- Aurora UI · Image
-- Rounded, cropped image card with an accent-gradient placeholder and an
-- optional bottom caption. Accepts any Roblox image asset or rbxthumb URL.

local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local Image = {}
Image.__index = Image

function Image.new(props: { [string]: any }?)
	local options = props or {}
	local ctx = assert(options.Context, "Aurora.Image requires a Context")
	local self = setmetatable({}, Image)

	local width = options.Width or 200
	local height = options.Height or 112
	local radius = options.Radius or 16

	local root = Util.frame({
		Name = options.Name or "ImageCard",
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = options.Parent,
	})
	Util.corner(root, radius)
	self.Root = root

	local fallback = Util.frame({
		Name = "Fallback",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = ctx.Theme.Accent,
		Parent = root,
	})
	Util.corner(fallback, radius)
	local fallbackGradient = Util.gradient(fallback, ctx.Theme.HeroGradient, 25)
	self.Fallback = fallback

	local glow = Util.frame({
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.25, 0.22),
		Size = UDim2.fromScale(0.8, 1.2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.82,
		Parent = fallback,
	})
	Util.corner(glow, UDim.new(0.5, 0))

	local placeholder = Util.text({
		Name = "Placeholder",
		Size = UDim2.fromScale(1, 1),
		Text = options.Placeholder or "◍",
		TextSize = options.PlaceholderSize or 30,
		Font = Theme.Font.Medium,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 0.35,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = fallback,
	})
	self.Placeholder = placeholder

	local image = Instance.new("ImageLabel")
	image.Name = "Image"
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Crop
	image.ImageTransparency = 1
	image.Visible = false
	image.Parent = root
	Util.corner(image, radius)
	self.ImageLabel = image

	local caption = nil
	if options.Caption then
		local captionHolder = Util.frame({
			Name = "CaptionHolder",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(1, 0.5),
			BackgroundTransparency = 1,
			Parent = root,
		})
		Util.gradient(
			captionHolder,
			ColorSequence.new(Color3.fromHex("000000")),
			90,
			NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0.35),
			})
		)
		caption = Util.text({
			Name = "Caption",
			Position = UDim2.new(0, 12, 1, -30),
			Size = UDim2.new(1, -24, 0, 20),
			Text = options.Caption,
			TextSize = 12,
			Font = Theme.Font.Semibold,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Parent = root,
		})
		self.Caption = caption
	end

	ctx:Bind(function(t: any)
		fallbackGradient.Color = t.HeroGradient
		fallback.BackgroundColor3 = t.Accent
	end)

	if options.Image then
		self:SetImage(options.Image)
	end

	return self
end

function Image:SetImage(image: string)
	if not image or image == "" then
		self.ImageLabel.Visible = false
		self.ImageLabel.Image = ""
		self.ImageLabel.ImageTransparency = 1
		return
	end
	self.ImageLabel.Image = image
	self.ImageLabel.Visible = true
	self.ImageLabel.ImageTransparency = 0
	self.Placeholder.Visible = false
end

function Image:SetCaption(text: string)
	if self.Caption then
		self.Caption.Text = text
	end
end

function Image:Destroy()
	self.Root:Destroy()
end

return Image

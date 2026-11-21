--!strict
-- Aurora UI · Avatar
-- Rounded avatar with a warm gradient fallback and optional Roblox headshot.
-- Headshots come straight from rbxthumb:// so no upload is required.

local Players = game:GetService("Players")

local Util = require(script.Parent.Parent.Util)
local Theme = require(script.Parent.Parent.Theme)

local Avatar = {}
Avatar.__index = Avatar

function Avatar.new(props: { [string]: any }?)
	local options = props or {}
	local self = setmetatable({}, Avatar)
	local size = options.Size or 28

	local root = Util.frame({
		Name = options.Name or "Avatar",
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = options.Parent,
	})
	Util.corner(root, UDim.new(0.5, 0))
	self.Root = root

	local fill = Util.frame({
		Name = "Fallback",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("FFC46B"),
		Parent = root,
	})
	Util.corner(fill, UDim.new(0.5, 0))
	Util.gradient(fill, {
		[0] = Color3.fromHex("FFE3B3"),
		[0.55] = Color3.fromHex("FFD09A"),
		[1] = Color3.fromHex("FFB36B"),
	}, 90)
	self.Fill = fill

	local initial = Util.text({
		Name = "Initial",
		Size = UDim2.fromScale(1, 1),
		Text = "P",
		TextSize = math.round(size * 0.43),
		Font = Theme.Font.Semibold,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = root,
	})
	self.Initial = initial

	local image = Instance.new("ImageLabel")
	image.Name = "Headshot"
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Crop
	image.ImageTransparency = 1
	image.Visible = false
	image.Parent = root
	Util.corner(image, UDim.new(0.5, 0))
	self.Image = image

	local ring = nil
	if options.Ring then
		ring = Util.stroke(root, Color3.new(1, 1, 1), 0.7, 1.5)
		self.Ring = ring
	end

	local name = options.Name or options.DisplayName or "Player"
	self:SetInitial(options.Initial or name:sub(1, 1):upper())
	if options.UserId then
		self:SetUser(options.UserId)
	elseif options.UseImage then
		local player = Players.LocalPlayer
		if player then
			self:SetUser(player.UserId)
		end
	end

	return self
end

function Avatar:SetInitial(text: string)
	self.Initial.Text = text:sub(1, 2)
end

function Avatar:SetUser(userId: number)
	if not userId or userId <= 0 then
		return
	end
	self.Image.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
	self.Image.Visible = true
	self.Image.ImageTransparency = 0.04
end

function Avatar:ClearImage()
	self.Image.Visible = false
	self.Image.Image = ""
end

function Avatar:Destroy()
	self.Root:Destroy()
end

return Avatar

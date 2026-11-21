--!strict
-- Aurora UI
-- A glass UI library for Roblox, rebuilt 1:1 from the Figma file
-- "Aurora — Glass UI for Roblox".
--
--   local Aurora = require(ReplicatedStorage.AuroraUI)
--   local gui = Aurora.newScreenGui({ Name = "Aurora" })
--   local ctx = Aurora.newContext("Dark")
--   local window = Aurora.createWindow({ Context = ctx, Tabs = tabs })
--
-- The glass uses a neutral frosted-noise texture clipped to the window,
-- because Roblox cannot blur a live backdrop inside a GuiObject. It is
-- deliberately colourless: the window is a frosted pane, never a picture of
-- the scene. Swap Aurora.GlassBlur for your own texture if you want.

local Players = game:GetService("Players")

local Aurora = {}

Aurora.Version = "1.2.0"
Aurora.Name = "Aurora"

Aurora.Util = require(script.Util)
Aurora.Theme = require(script.Theme)
Aurora.Config = require(script.Config)
Aurora.Components = require(script.Components)
Aurora.Tab = require(script.Tab)
Aurora.Window = require(script.Window)

-- Asset IDs used by the library. The matching source images live in
-- public/ next to this repository.
Aurora.Assets = {
	-- Neutral frost texture (uploaded from public/frost.png).
	Frost = "rbxassetid://112811578533426",
	-- 9-slice drop shadow (StarterGui.DropShadowHolder).
	Shadow = "rbxassetid://6014261993",
}

Aurora.GlassBlur = Aurora.Assets.Frost

--------------------------------------------------------------------------------
-- Executor-aware ScreenGui parenting
--------------------------------------------------------------------------------

-- Resolve an executor global without assuming one injection model. Some
-- executors put helpers on _G, others inside getgenv(), others in the script
-- environment returned by getfenv(0).
local function globalFunction(name: string): any
	local candidates = {}
	local getfenvFn = rawget(_G, "getfenv")
	if type(getfenvFn) == "function" then
		local ok, env = pcall(getfenvFn, 0)
		if ok and type(env) == "table" then
			table.insert(candidates, env)
		end
	end
	table.insert(candidates, _G)
	local getgenvFn = rawget(_G, "getgenv")
	if type(getgenvFn) == "function" then
		local ok, env = pcall(getgenvFn)
		if ok and type(env) == "table" then
			table.insert(candidates, env)
		end
	end
	for _, env in ipairs(candidates) do
		local value = rawget(env, name)
		if type(value) == "function" then
			return value
		end
	end
	return nil
end

local function gethuiInstance(): Instance?
	local gethuiFn = globalFunction("gethui")
	if not gethuiFn then
		return nil
	end
	local ok, result = pcall(gethuiFn)
	if ok and typeof(result) == "Instance" then
		return result
	end
	return nil
end

-- Returns the best parent for a ScreenGui:
--   1. the executor's hidden UI (gethui) when available,
--   2. CoreGui,
--   3. the local PlayerGui (Studio / vanilla Roblox).
function Aurora.getGuiParent(): Instance?
	local hidden = gethuiInstance()
	if hidden then
		return hidden
	end

	local coreGui = game:FindService("CoreGui")
	if coreGui then
		return coreGui
	end

	local player = Players.LocalPlayer
	if player then
		return player:FindFirstChildOfClass("PlayerGui")
	end
	return nil
end

-- Creates a ScreenGui with Aurora's defaults and parents it as high as the
-- current environment allows. In Studio the CoreGui assignment is protected,
-- so it quietly falls back to PlayerGui; in an executor gethui() is used.
function Aurora.newScreenGui(props: { [string]: any }?): ScreenGui
	local options = props or {}
	local gui = Instance.new("ScreenGui")
	gui.Name = options.Name or "Aurora"
	gui.IgnoreGuiInset = options.IgnoreGuiInset ~= false
	gui.ResetOnSpawn = options.ResetOnSpawn == true
	gui.DisplayOrder = options.DisplayOrder or 100
	gui.ZIndexBehavior = options.ZIndexBehavior or Enum.ZIndexBehavior.Sibling

	local requested = options.Parent or Aurora.getGuiParent()
	if requested then
		local ok = pcall(function()
			gui.Parent = requested
		end)
		if not ok or gui.Parent == nil then
			local player = Players.LocalPlayer
			local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
			if playerGui then
				gui.Parent = playerGui
			end
		end
	end

	return gui
end

-- Find an Aurora ScreenGui regardless of whether it was parented to gethui(),
-- CoreGui or PlayerGui.
function Aurora.findScreenGui(name: string): ScreenGui?
	local roots = {}
	local hidden = gethuiInstance()
	if hidden then
		table.insert(roots, hidden)
	end
	local coreGui = game:FindService("CoreGui")
	if coreGui then
		table.insert(roots, coreGui)
	end
	local player = Players.LocalPlayer
	if player then
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			table.insert(roots, playerGui)
		end
	end

	for _, root in ipairs(roots) do
		local ok, found = pcall(function()
			return root:FindFirstChild(name)
		end)
		if ok and found and found:IsA("ScreenGui") then
			return found
		end
	end
	return nil
end

-- Move an existing ScreenGui to the best available parent.
function Aurora.parentToGui(gui: ScreenGui): boolean
	local parent = Aurora.getGuiParent()
	if not parent then
		return false
	end
	local ok = pcall(function()
		gui.Parent = parent
	end)
	if ok and gui.Parent ~= nil then
		gui.DisplayOrder = math.max(gui.DisplayOrder, 100)
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- Constructors
--------------------------------------------------------------------------------

function Aurora.newContext(
	mode: string?,
	accent: Color3?,
	overrides: { [string]: any }?
)
	return Aurora.Theme.newContext(mode, accent, overrides)
end

function Aurora.createWindow(props: { [string]: any }?)
	local options = props or {}
	if not options.Context then
		options.Context = Aurora.newContext(options.Mode, options.Accent, options.Theme)
	end
	return Aurora.Window.new(options)
end

-- The short API:
--
--   local Window = Aurora:CreateWindow({ Title = "My script" })
--   local Main = Window:AddTab("Main")
--   Main:AddToggle("Auto apply", true)
--
-- It creates the ScreenGui, context and window for you. `Theme` may be a mode
-- string ("Dark"/"Light") or the usual token override table.
local function createSimpleWindow(options: { [string]: any }?)
	local opts = options or {}
	local parent = opts.Parent
	local ownsGui = false
	if not parent then
		parent = Aurora.newScreenGui({
			Name = opts.Name or opts.Title or "Aurora",
			DisplayOrder = opts.DisplayOrder,
		})
		ownsGui = true
	end

	local mode = opts.Mode
	if not mode and type(opts.Theme) == "string" then
		mode = opts.Theme
	end
	local overrides = type(opts.Theme) == "table" and opts.Theme or opts.ThemeOverrides
	local ctx = opts.Context or Aurora.newContext(mode, opts.Accent, overrides)

	local window = Aurora.Window.new({
		Parent = parent,
		Context = ctx,
		Player = opts.Player,
		Title = opts.Title,
		SubTitle = opts.SubTitle or opts.Subtitle,
		Tabs = opts.Tabs,
		StartingTab = opts.StartingTab or opts.starting_tab,
		BackgroundImage = opts.BackgroundImage or opts.background_image,
		Config = opts.Config,
		BlurredImage = opts.BlurredImage,
	})
	window.ScreenGui = parent
	window.OwnsGui = ownsGui
	return window
end

-- Accepts Aurora:CreateWindow({...}) and Aurora.CreateWindow({...}).
function Aurora.CreateWindow(first: any, second: any)
	local options = first == Aurora and second or first
	return createSimpleWindow(options)
end

return Aurora

--!nocheck
-- Aurora UI -- executor loader
--
-- Aurora is multi-file (Window, Theme, Config, Components/...), so an executor
-- cannot use a single pasted script. This file downloads the module tree from
-- GitHub, builds it as ModuleScripts in the executor's hidden UI, and returns
-- the required library.
--
-- One-liner:
--   local Aurora = loadstring(game:HttpGet(
--       "https://raw.githubusercontent.com/xxpwnxxx420lord/auorua/main/executor.lua"
--   ))()
--
-- Optional options (pass as the chunk argument):
--   local Aurora = loadstring(game:HttpGet(URL))({
--       Refresh = true,             -- ignore the session cache and re-download
--       BaseUrl = "https://raw.githubusercontent.com/xxpwnxxx420lord/auorua/main/",
--       Silent = true,              -- no loader prints
--   })
--
-- Requirements:
--   * game:HttpGet (every mainstream executor)
--   * loadstring to run this file (or run its contents with your executor's
--     script runner)
--   * outbound HTTP to raw.githubusercontent.com
--
-- The downloaded modules are parented to gethui() when available, then
-- CoreGui, then PlayerGui. They stay alive for the session; the returned table
-- is cached in getgenv() so repeated loads are instant.

local BASE_URL = "https://raw.githubusercontent.com/xxpwnxxx420lord/auorua/main/"
local CACHE_KEY = "__AuroraUILoader"
local HOLDER_NAME = "AuroraUILoader"

-- Every module the library requires. Parents must appear before children.
local TREE = {
	{ Path = "AuroraUI/init.lua", Key = "AuroraUI", Name = "AuroraUI" },
	{ Path = "AuroraUI/Util.lua", Key = "AuroraUI.Util", Name = "Util", Parent = "AuroraUI" },
	{ Path = "AuroraUI/Theme.lua", Key = "AuroraUI.Theme", Name = "Theme", Parent = "AuroraUI" },
	{ Path = "AuroraUI/Config.lua", Key = "AuroraUI.Config", Name = "Config", Parent = "AuroraUI" },
	{ Path = "AuroraUI/Window.lua", Key = "AuroraUI.Window", Name = "Window", Parent = "AuroraUI" },
	{ Path = "AuroraUI/Components/init.lua", Key = "AuroraUI.Components", Name = "Components", Parent = "AuroraUI" },
	{ Path = "AuroraUI/Components/Common.lua", Key = "AuroraUI.Components.Common", Name = "Common", Parent = "AuroraUI.Components" },
	{ Path = "AuroraUI/Components/Button.lua", Key = "AuroraUI.Components.Button", Name = "Button", Parent = "AuroraUI.Components" },
	{ Path = "AuroraUI/Components/IconButton.lua", Key = "AuroraUI.Components.IconButton", Name = "IconButton", Parent = "AuroraUI.Components" },
	{ Path = "AuroraUI/Components/Switch.lua", Key = "AuroraUI.Components.Switch", Name = "Switch", Parent = "AuroraUI.Components" },
	{ Path = "AuroraUI/Components/Slider.lua", Key = "AuroraUI.Components.Slider", Name = "Slider", Parent = "AuroraUI.Components" },
	{ Path = "AuroraUI/Components/Segmented.lua", Key = "AuroraUI.Components.Segmented", Name = "Segmented", Parent = "AuroraUI.Components" },
	{ Path = "AuroraUI/Components/Chip.lua", Key = "AuroraUI.Components.Chip", Name = "Chip", Parent = "AuroraUI.Components" },
	{ Path = "AuroraUI/Components/Badge.lua", Key = "AuroraUI.Components.Badge", Name = "Badge", Parent = "AuroraUI.Components" },
	{ Path = "AuroraUI/Components/Stat.lua", Key = "AuroraUI.Components.Stat", Name = "Stat", Parent = "AuroraUI.Components" },
	{ Path = "AuroraUI/Components/Row.lua", Key = "AuroraUI.Components.Row", Name = "Row", Parent = "AuroraUI.Components" },
	{ Path = "AuroraUI/Components/Group.lua", Key = "AuroraUI.Components.Group", Name = "Group", Parent = "AuroraUI.Components" },
	{ Path = "AuroraUI/Components/ColorPicker.lua", Key = "AuroraUI.Components.ColorPicker", Name = "ColorPicker", Parent = "AuroraUI.Components" },
	{ Path = "AuroraUI/Components/Image.lua", Key = "AuroraUI.Components.Image", Name = "Image", Parent = "AuroraUI.Components" },
	{ Path = "AuroraUI/Components/Avatar.lua", Key = "AuroraUI.Components.Avatar", Name = "Avatar", Parent = "AuroraUI.Components" },
	{ Path = "AuroraUI/Components/Banner.lua", Key = "AuroraUI.Components.Banner", Name = "Banner", Parent = "AuroraUI.Components" },
	{ Path = "AuroraUI/Components/Tooltip.lua", Key = "AuroraUI.Components.Tooltip", Name = "Tooltip", Parent = "AuroraUI.Components" },
	{ Path = "AuroraUI/Components/Progress.lua", Key = "AuroraUI.Components.Progress", Name = "Progress", Parent = "AuroraUI.Components" },
	{ Path = "AuroraUI/Components/Input.lua", Key = "AuroraUI.Components.Input", Name = "Input", Parent = "AuroraUI.Components" },
	{ Path = "AuroraUI/Components/Dropdown.lua", Key = "AuroraUI.Components.Dropdown", Name = "Dropdown", Parent = "AuroraUI.Components" },
}

local options = ...
if type(options) ~= "table" then
	options = {}
end

local baseUrl = type(options.BaseUrl) == "string" and options.BaseUrl or BASE_URL
if baseUrl:sub(-1) ~= "/" then
	baseUrl ..= "/"
end

local function globalEnv(): any
	local getgenvFn = rawget(_G, "getgenv")
	if type(getgenvFn) == "function" then
		local ok, env = pcall(getgenvFn)
		if ok and type(env) == "table" then
			return env
		end
	end
	return _G
end

local function executorGlobal(name: string): any
	local env = globalEnv()
	local value = rawget(env, name)
	if value == nil then
		value = rawget(_G, name)
	end
	return value
end

local function hiddenParent(): (Instance, string)
	local gethuiFn = executorGlobal("gethui")
	if type(gethuiFn) == "function" then
		local ok, hidden = pcall(gethuiFn)
		if ok and typeof(hidden) == "Instance" then
			return hidden, "gethui"
		end
	end

	local coreGui = game:FindService("CoreGui")
	if coreGui then
		local writable = pcall(function()
			local probe = Instance.new("Folder")
			probe.Parent = coreGui
			probe:Destroy()
		end)
		if writable then
			return coreGui, "CoreGui"
		end
	end

	local players = game:GetService("Players")
	local player = players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		return playerGui, "PlayerGui"
	end

	return game:GetService("ReplicatedStorage"), "ReplicatedStorage"
end

local function fetch(url: string): string
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if not ok then
		error(
			"[Aurora] HTTP request failed for "
				.. url
				.. "\n"
				.. tostring(body)
				.. "\nMake sure your executor allows game:HttpGet to raw.githubusercontent.com.",
			0
		)
	end
	if type(body) ~= "string" or #body < 16 then
		error("[Aurora] Empty response for " .. url, 0)
	end
	if body:match("^404:") or body:match("^<") then
		error("[Aurora] GitHub returned no Lua source for " .. url, 0)
	end
	return body
end

local env = globalEnv()
local cached = rawget(env, CACHE_KEY)
if type(cached) == "table" and cached.Aurora and cached.Folder and cached.Folder.Parent ~= nil and not options.Refresh then
	return cached.Aurora
end

-- Keep the old tree alive until the new one has required successfully, so a
-- failed refresh cannot break a UI that is already on screen.
local stale = nil
if options.Refresh and type(cached) == "table" and cached.Folder then
	stale = cached.Folder
	env[CACHE_KEY] = nil
end

local parent, parentName = hiddenParent()

local holder = Instance.new("Folder")
holder.Name = HOLDER_NAME

local built = {}
local ok, failure = pcall(function()
	if not options.Silent then
		print(("[Aurora] downloading %d modules from GitHub..."):format(#TREE))
	end

	-- Fetch everything first so a network failure cannot leave a half-built tree.
	local sources = {}
	for index, entry in ipairs(TREE) do
		local body = fetch(baseUrl .. entry.Path)
		sources[index] = body
	end

	for index, entry in ipairs(TREE) do
		local module = Instance.new("ModuleScript")
		module.Name = entry.Name
		module.Source = sources[index]
		if entry.Parent then
			local target = built[entry.Parent]
			if not target then
				error("[Aurora] loader bug: parent " .. entry.Parent .. " is missing", 0)
			end
			module.Parent = target
		end
		built[entry.Key] = module
	end

	built.AuroraUI.Parent = holder
	holder.Parent = parent
end)

if not ok then
	holder:Destroy()
	error(tostring(failure), 0)
end

local requireOk, Aurora = pcall(require, built.AuroraUI)
if not requireOk then
	holder:Destroy()
	error("[Aurora] module failed to load: " .. tostring(Aurora), 0)
end

if stale and stale ~= holder then
	pcall(function()
		stale:Destroy()
	end)
end

Aurora.Loader = {
	BaseUrl = baseUrl,
	Folder = holder,
	Parent = parentName,
}

env[CACHE_KEY] = {
	Aurora = Aurora,
	Folder = holder,
}

if not options.Silent then
	print(("[Aurora] ready v%s (%s, %d modules)"):format(tostring(Aurora.Version), parentName, #TREE))
end

return Aurora

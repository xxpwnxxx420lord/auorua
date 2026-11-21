--!nonstrict
-- Aurora UI · Config
-- Optional JSON persistence for a window's live state.
--
-- Roblox has no filesystem, so this module talks to the executor's file
-- functions when they exist (writefile / readfile / isfile / makefolder /
-- listfiles / delfile). In a normal Studio playtest those functions are
-- missing, and the module transparently falls back to an in-memory store so
-- every API still works for the current session.
--
--   local Config = Aurora.Config
--   Config.save("my_window", { Mode = "Dark" })
--   local state = Config.load("my_window")
--
-- A window can also opt into automatic save/load:
--
--   Aurora.createWindow({ ..., Config = "my_window" })

local Util = require(script.Parent.Util)

local Config = {}

Config.Version = 1
Config.FolderName = "AuroraUI"
Config.Extension = ".json"
Config._memory = {}
Config._folderReady = false
Config._warned = false

--------------------------------------------------------------------------------
-- Executor globals
--------------------------------------------------------------------------------

local function envTable(): any
	local getfenvFn = getfenv
	if type(getfenvFn) == "function" then
		local ok, env = pcall(getfenvFn, 0)
		if ok and type(env) == "table" then
			return env
		end
	end
	return nil
end

-- Finds an executor-provided global without assuming a specific executor.
-- Different executors expose their environment through `_G`, `getgenv()` or
-- the script environment, so try all three.
local function getGlobal(name: string): any
	local env = envTable()
	if env and rawget(env, name) ~= nil then
		return rawget(env, name)
	end
	if rawget(_G, name) ~= nil then
		return rawget(_G, name)
	end
	local getgenvFn = getgenv
	if type(getgenvFn) == "function" then
		local ok, genv = pcall(getgenvFn)
		if ok and type(genv) == "table" and genv[name] ~= nil then
			return genv[name]
		end
	end
	local genv = rawget(_G, "getgenv")
	if type(genv) == "function" then
		local ok, result = pcall(genv)
		if ok and type(result) == "table" and result[name] ~= nil then
			return result[name]
		end
	end
	return nil
end

local function fn(name: string): any
	local value = getGlobal(name)
	if type(value) == "function" then
		return value
	end
	return nil
end

function Config.isAvailable(): boolean
	return fn("writefile") ~= nil and fn("readfile") ~= nil
end

function Config.folder()
	return Config.FolderName
end

function Config.path(name: string): string
	return Config.FolderName .. "/" .. tostring(name) .. Config.Extension
end

local function ensureFolder()
	if Config._folderReady then
		return
	end
	Config._folderReady = true
	local makefolder = fn("makefolder")
	if makefolder then
		pcall(makefolder, Config.FolderName)
	end
end

--------------------------------------------------------------------------------
-- JSON
--------------------------------------------------------------------------------

local escapes = {
	['"'] = '\\"',
	["\\"] = "\\\\",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}

local function escapeString(value: string): string
	return '"' .. value:gsub('[%z\1-\31\\"]', function(char)
		return escapes[char] or string.format("\\u%04x", string.byte(char))
	end) .. '"'
end

local function isArray(value: { [any]: any }): boolean
	local count = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return false
		end
		count += 1
	end
	return count == #value
end

local function encodeValue(value: any, stack: { [any]: any }): string
	local valueType = typeof(value)
	if valueType == "nil" then
		return "null"
	end
	if valueType == "boolean" then
		return value and "true" or "false"
	end
	if valueType == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return "null"
		end
		return tostring(value)
	end
	if valueType == "string" then
		return escapeString(value)
	end
	if valueType == "Color3" then
		return string.format(
			'{"__type":"Color3","r":%.6f,"g":%.6f,"b":%.6f}',
			value.R,
			value.G,
			value.B
		)
	end
	if valueType == "Vector2" then
		return string.format('{"__type":"Vector2","x":%.4f,"y":%.4f}', value.X, value.Y)
	end
	if valueType == "UDim2" then
		return string.format(
			'{"__type":"UDim2","x":%.4f,"xs":%.4f,"y":%.4f,"ys":%.4f}',
			value.X.Offset,
			value.X.Scale,
			value.Y.Offset,
			value.Y.Scale
		)
	end
	if valueType ~= "table" then
		return "null"
	end
	if stack[value] then
		return "null"
	end
	stack[value] = true

	local parts = {}
	if isArray(value) then
		for index = 1, #value do
			parts[index] = encodeValue(value[index], stack)
		end
		stack[value] = nil
		return "[" .. table.concat(parts, ",") .. "]"
	end

	for key, item in pairs(value) do
		if type(key) == "string" or type(key) == "number" then
			table.insert(parts, escapeString(tostring(key)) .. ":" .. encodeValue(item, stack))
		end
	end
	stack[value] = nil
	return "{" .. table.concat(parts, ",") .. "}"
end

function Config.encode(value: any): string
	return encodeValue(value, {})
end

local function skipWhitespace(text: string, position: number): number
	while position <= #text do
		local byte = string.byte(text, position)
		if byte ~= 32 and byte ~= 9 and byte ~= 10 and byte ~= 13 then
			break
		end
		position += 1
	end
	return position
end

local decodeValue

local function decodeString(text: string, position: number): (string, number)
	-- position points at the opening quote
	position += 1
	local parts = {}
	local chunkStart = position
	while position <= #text do
		local byte = string.byte(text, position)
		if byte == 34 then
			table.insert(parts, string.sub(text, chunkStart, position - 1))
			return table.concat(parts), position + 1
		elseif byte == 92 then
			table.insert(parts, string.sub(text, chunkStart, position - 1))
			local escape = string.sub(text, position + 1, position + 1)
			if escape == "u" then
				local hex = string.sub(text, position + 2, position + 5)
				local code = tonumber(hex, 16) or 63
				table.insert(parts, utf8.char(code))
				position += 6
			else
				local map = {
					['"'] = '"',
					["\\"] = "\\",
					["/"] = "/",
					["b"] = "\b",
					["f"] = "\f",
					["n"] = "\n",
					["r"] = "\r",
					["t"] = "\t",
				}
				table.insert(parts, map[escape] or escape)
				position += 2
			end
			chunkStart = position
		else
			position += 1
		end
	end
	error("unterminated string")
end

local function decodeNumber(text: string, position: number): (number, number)
	local start = position
	if string.byte(text, position) == 45 then
		position += 1
	end
	while position <= #text do
		local byte = string.byte(text, position)
		if (byte >= 48 and byte <= 57) or byte == 46 or byte == 101 or byte == 69 or byte == 43 or byte == 45 then
			position += 1
		else
			break
		end
	end
	return tonumber(string.sub(text, start, position - 1)) or 0, position
end

decodeValue = function(text: string, position: number): (any, number)
	position = skipWhitespace(text, position)
	local char = string.sub(text, position, position)
	if char == "{" then
		local result = {}
		position = skipWhitespace(text, position + 1)
		if string.sub(text, position, position) == "}" then
			return result, position + 1
		end
		while position <= #text do
			position = skipWhitespace(text, position)
			if string.sub(text, position, position) ~= '"' then
				error("expected object key")
			end
			local key
			key, position = decodeString(text, position)
			position = skipWhitespace(text, position)
			if string.sub(text, position, position) ~= ":" then
				error("expected ':'")
			end
			local value
			value, position = decodeValue(text, position + 1)
			result[key] = value
			position = skipWhitespace(text, position)
			local nextChar = string.sub(text, position, position)
			if nextChar == "}" then
				return result, position + 1
			elseif nextChar ~= "," then
				error("expected ',' or '}'")
			end
			position += 1
		end
		error("unterminated object")
	elseif char == "[" then
		local result = {}
		position = skipWhitespace(text, position + 1)
		if string.sub(text, position, position) == "]" then
			return result, position + 1
		end
		while position <= #text do
			local value
			value, position = decodeValue(text, position)
			table.insert(result, value)
			position = skipWhitespace(text, position)
			local nextChar = string.sub(text, position, position)
			if nextChar == "]" then
				return result, position + 1
			elseif nextChar ~= "," then
				error("expected ',' or ']'")
			end
			position += 1
		end
		error("unterminated array")
	elseif char == '"' then
		return decodeString(text, position)
	elseif string.sub(text, position, position + 3) == "true" then
		return true, position + 4
	elseif string.sub(text, position, position + 4) == "false" then
		return false, position + 5
	elseif string.sub(text, position, position + 3) == "null" then
		return nil, position + 4
	else
		return decodeNumber(text, position)
	end
end

local function revive(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	if value.__type == "Color3" then
		return Color3.new(value.r or 0, value.g or 0, value.b or 0)
	end
	if value.__type == "Vector2" then
		return Vector2.new(value.x or 0, value.y or 0)
	end
	if value.__type == "UDim2" then
		return UDim2.new(value.xs or 0, value.x or 0, value.ys or 0, value.y or 0)
	end
	for key, item in pairs(value) do
		value[key] = revive(item)
	end
	return value
end

function Config.decode(text: string): any
	local position = skipWhitespace(text, 1)
	local value, finish = decodeValue(text, position)
	finish = skipWhitespace(text, finish)
	if finish <= #text then
		error("trailing characters in JSON")
	end
	return revive(value)
end

--------------------------------------------------------------------------------
-- Files
--------------------------------------------------------------------------------

function Config.exists(name: string): boolean
	local path = Config.path(name)
	local isfile = fn("isfile")
	if isfile then
		local ok, result = pcall(isfile, path)
		if ok and result then
			return true
		end
	end
	return Config._memory[name] ~= nil
end

function Config.save(name: string, data: any): (boolean, string?)
	local encoded = Config.encode(data)
	Config._memory[name] = encoded
	if not Config.isAvailable() then
		return false, "executor file functions unavailable (kept in memory)"
	end
	ensureFolder()
	local writefile = fn("writefile")
	local ok, err = pcall(writefile, Config.path(name), encoded)
	if not ok and not Config._warned then
		Config._warned = true
		warn("[Aurora.Config] writefile failed: " .. tostring(err))
	end
	return ok, ok and nil or tostring(err)
end

function Config.load(name: string, default: any?): (any, boolean)
	local encoded: string? = nil
	local path = Config.path(name)
	if Config.isAvailable() then
		local isfile = fn("isfile")
		local readfile = fn("readfile")
		local exists = true
		if isfile then
			local ok, result = pcall(isfile, path)
			exists = ok and result == true
		end
		if exists and readfile then
			local ok, contents = pcall(readfile, path)
			if ok and type(contents) == "string" and contents ~= "" then
				encoded = contents
			end
		end
	end
	if not encoded then
		encoded = Config._memory[name]
	end
	if not encoded then
		return default, false
	end
	local ok, value = pcall(Config.decode, encoded)
	if ok and value ~= nil then
		return value, true
	end
	return default, false
end

function Config.delete(name: string): boolean
	Config._memory[name] = nil
	local delfile = fn("delfile")
	if not delfile then
		return false
	end
	local ok = pcall(delfile, Config.path(name))
	return ok
end

function Config.list(): { string }
	local names: { [string]: boolean } = {}
	local listfiles = fn("listfiles")
	if listfiles then
		local ok, files = pcall(listfiles, Config.FolderName)
		if ok and type(files) == "table" then
			for _, path in ipairs(files) do
				local name = tostring(path):match("([^/\\]+)" .. Config.Extension .. "$")
				if name then
					names[name] = true
				end
			end
		end
	end
	for name in pairs(Config._memory) do
		names[name] = true
	end
	local result = {}
	for name in pairs(names) do
		table.insert(result, name)
	end
	table.sort(result)
	return result
end

function Config.clearMemory()
	table.clear(Config._memory)
end

--------------------------------------------------------------------------------
-- Window integration
--------------------------------------------------------------------------------

local function windowState(window: any): { [string]: any }
	local ctx = window.Context
	return {
		Version = Config.Version,
		Mode = ctx.Mode,
		Accent = Util.toHex(ctx.CanonicalAccent),
		GlassIntensity = ctx.GlassIntensity,
		BlurEnabled = ctx.BlurEnabled,
		Tab = window.ActiveIndex,
		Zoom = window.ZoomFactor,
		BackgroundImage = window.BackgroundImage or "",
		Moved = window.HasMoved == true,
		X = window.Root and window.Root.Position.X.Scale or 0.5,
		Y = window.Root and window.Root.Position.Y.Scale or 0.5,
		Toggles = window:GetToggles(),
	}
end

local function applyState(window: any, state: { [string]: any })
	if type(state.Mode) == "string" then
		window:SetMode(state.Mode, false)
	end

	if type(state.Accent) == "string" then
		local ok, color = pcall(Color3.fromHex, (state.Accent:gsub("#", "")))
		if ok and typeof(color) == "Color3" then
			window:SetAccent(color, false)
		end
	end

	if type(state.BlurEnabled) == "boolean" then
		window:SetBlurEnabled(state.BlurEnabled)
	end
	if tonumber(state.GlassIntensity) then
		window:SetGlassIntensity(tonumber(state.GlassIntensity))
	end
	if type(state.BackgroundImage) == "string" and window.SetBackgroundImage then
		window:SetBackgroundImage(state.BackgroundImage)
	end
	if tonumber(state.Tab) then
		window:SelectTab(tonumber(state.Tab), false)
	end
	if tonumber(state.Zoom) then
		window.ZoomFactor = tonumber(state.Zoom) == 1.14 and 1.14 or 1
	end

	if state.Moved == true and tonumber(state.X) and tonumber(state.Y) then
		window.HasMoved = true
		window.Root.Position = UDim2.fromScale(tonumber(state.X), tonumber(state.Y))
		window:_clampWindow()
	end

	if type(state.Toggles) == "table" then
		for name, value in pairs(state.Toggles) do
			if type(value) == "boolean" then
				window:ChangeToggle(name, value, false)
			end
		end
	end
end

-- Attaches autosave/autoload to a window. Returns a handle:
--   handle:Save()     force a save now
--   handle:Load()     re-read the file and apply it
--   handle:Delete()   remove the stored file
--   handle:Destroy()  stop the background saver
function Config.attach(window: any, name: string, options: { [string]: any }?): any
	local opts = options or {}
	local handle = {
		Name = name,
		Window = window,
		Loaded = false,
		_interval = opts.Interval or 2,
		_running = true,
	}

	local state, loaded = Config.load(name)
	if loaded and type(state) == "table" then
		handle.Loaded = true
		applyState(window, state)
	end

	handle.State = windowState(window)
	local lastEncoded = Config.encode(handle.State)

	function handle:GetState()
		return windowState(self.Window)
	end

	function handle:Save()
		self.State = windowState(self.Window)
		lastEncoded = Config.encode(self.State)
		return Config.save(self.Name, self.State)
	end

	function handle:Load()
		local nextState, ok = Config.load(self.Name)
		if ok and type(nextState) == "table" then
			applyState(self.Window, nextState)
			self.State = windowState(self.Window)
			lastEncoded = Config.encode(self.State)
			return true
		end
		return false
	end

	function handle:Delete()
		local result = Config.delete(self.Name)
		-- Keep the saver quiet until the window actually changes again.
		lastEncoded = Config.encode(windowState(self.Window))
		return result
	end

	function handle:Destroy()
		self._running = false
	end

	local function tick()
		while handle._running do
			task.wait(handle._interval)
			if not handle._running then
				break
			end
			local root = window.Root
			if root and root.Parent then
				local current = windowState(window)
				local encoded = Config.encode(current)
				if encoded ~= lastEncoded then
					lastEncoded = encoded
					handle.State = current
					Config.save(name, current)
				end
			end
		end
	end

	task.spawn(tick)

	-- Save immediately when the user closes the window, without disturbing a
	-- callback the game already installed.
	local previousClose = window.OnClose
	window.OnClose = function(...)
		handle:Save()
		if previousClose then
			previousClose(...)
		end
	end

	window.ConfigHandle = handle
	return handle
end

return Config

--!strict
-- Aurora UI · Theme
-- Every token below comes straight from the Figma variable modes.
-- Alpha values are stored as Roblox transparencies (1 - alpha).

local Util = require(script.Parent.Util)

local Theme = {}

--------------------------------------------------------------------------------
-- Type & geometry
--------------------------------------------------------------------------------

Theme.Font = {
	Regular = Enum.Font.Gotham,
	Medium = Enum.Font.GothamMedium,
	Semibold = Enum.Font.GothamSemibold,
	Bold = Enum.Font.GothamBold,
}

Theme.Radius = {
	Window = 10,
	Card = 20,
	Control = 12,
	Item = 10,
	Full = 999,
}

Theme.Motion = {
	Press = 0.12,
	Switch = 0.20,
	Fast = 0.18,
	Tab = 0.30,
	Theme = 0.45,
	Slow = 0.45,
	Pill = 0.40,
	PillOut = 0.30,
	BannerIn = 0.40,
	BannerOut = 0.30,
	WindowOpen = 0.35,
	Hover = 0.16,
}

Theme.Layout = {
	DesignWidth = 1280,
	DesignHeight = 800,
	WindowWidth = 640,
	WindowHeight = 430,
	Titlebar = 44,
	Sidebar = 172,
	SidebarItemHeight = 36,
	SidebarItemGap = 40,
	ContentWidth = 468,
	ContentHeight = 386,
	ContentPad = 20,
}

--------------------------------------------------------------------------------
-- Accent presets (Figma: ACCENT swatches)
--------------------------------------------------------------------------------

Theme.Accents = {
	{ Name = "Blue", Color = Color3.fromHex("0A84FF"), Light = Color3.fromHex("007AFF") },
	{ Name = "Indigo", Color = Color3.fromHex("5E5CE6") },
	{ Name = "Purple", Color = Color3.fromHex("BF5AF2") },
	{ Name = "Pink", Color = Color3.fromHex("FF375F") },
	{ Name = "Orange", Color = Color3.fromHex("FF9F0A") },
	{ Name = "Green", Color = Color3.fromHex("30D158") },
}

function Theme.colorEquals(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 0.006
		and math.abs(a.G - b.G) < 0.006
		and math.abs(a.B - b.B) < 0.006
end

function Theme.canonicalAccent(color: Color3): Color3
	for _, accent in ipairs(Theme.Accents) do
		if Theme.colorEquals(color, accent.Color) then
			return accent.Color
		end
		if accent.Light and Theme.colorEquals(color, accent.Light) then
			return accent.Color
		end
	end
	return color
end

function Theme.accentForMode(canonical: Color3, mode: string): Color3
	for _, accent in ipairs(Theme.Accents) do
		if Theme.colorEquals(canonical, accent.Color) then
			if mode == "Light" and accent.Light then
				return accent.Light
			end
			return accent.Color
		end
	end
	return canonical
end

function Theme.isDefaultBlue(color: Color3): boolean
	local blue = Theme.Accents[1]
	return Theme.colorEquals(color, blue.Color) or (blue.Light ~= nil and Theme.colorEquals(color, blue.Light))
end

--------------------------------------------------------------------------------
-- Dark mode tokens
--------------------------------------------------------------------------------

Theme.Dark = {
	Mode = "Dark",

	GlassWindow = Color3.fromHex("14161C"),
	GlassWindowTransparency = 0.42,
	-- Stable dark body beneath the live tint. The Figma glass sits over a
	-- blurred scene; without it the window would inherit whatever bright 3D
	-- scene is behind it and wash out. This keeps the glass dark and even.
	GlassDepth = Color3.fromHex("191C24"),
	GlassDepthTransparency = 0.30,
	GlassSidebar = Color3.fromHex("FFFFFF"),
	GlassSidebarTransparency = 0.949,
	GlassCard = Color3.fromHex("FFFFFF"),
	GlassCardTransparency = 0.929,
	GlassControl = Color3.fromHex("FFFFFF"),
	GlassControlTransparency = 0.898,
	GlassControlHover = Color3.fromHex("FFFFFF"),
	GlassControlHoverTransparency = 0.839,
	GlassSelected = Color3.fromHex("FFFFFF"),
	GlassSelectedTransparency = 0.859,
	GlassPill = Color3.fromHex("0B0C10"),
	GlassPillTransparency = 0.278,

	StrokeGlass = Color3.fromHex("FFFFFF"),
	StrokeGlassTransparency = 0.839,
	StrokeHairline = Color3.fromHex("FFFFFF"),
	StrokeHairlineTransparency = 0.922,
	HighlightTop = Color3.fromHex("FFFFFF"),
	HighlightTopTransparency = 0.761,
	ShadowDrop = Color3.fromHex("000000"),
	ShadowDropTransparency = 0.549,

	LabelPrimary = Color3.fromHex("FFFFFF"),
	LabelPrimaryTransparency = 0,
	LabelSecondary = Color3.fromHex("EBEBF5"),
	LabelSecondaryTransparency = 0.38,
	LabelTertiary = Color3.fromHex("EBEBF5"),
	LabelTertiaryTransparency = 0.659,
	LabelOnAccent = Color3.fromHex("FFFFFF"),

	Accent = Color3.fromHex("0A84FF"),
	AccentSoft = Color3.fromHex("0A84FF"),
	AccentSoftTransparency = 0.78,
	Positive = Color3.fromHex("30D158"),
	PositiveSoft = Color3.fromHex("30D158"),
	PositiveSoftTransparency = 0.839,

	TrafficClose = Color3.fromHex("FF5F57"),
	TrafficMinimize = Color3.fromHex("FEBC2E"),
	TrafficZoom = Color3.fromHex("28C840"),
	SwitchOff = Color3.fromHex("787880"),
	SwitchOffTransparency = 0.639,
	Knob = Color3.fromHex("FFFFFF"),
}

--------------------------------------------------------------------------------
-- Light mode tokens
--------------------------------------------------------------------------------

Theme.Light = {
	Mode = "Light",

	GlassWindow = Color3.fromHex("F6F7FA"),
	GlassWindowTransparency = 0.40,
	GlassDepth = Color3.fromHex("FFFFFF"),
	GlassDepthTransparency = 0.30,
	GlassSidebar = Color3.fromHex("FFFFFF"),
	GlassSidebarTransparency = 0.651,
	GlassCard = Color3.fromHex("FFFFFF"),
	GlassCardTransparency = 0.451,
	GlassControl = Color3.fromHex("000000"),
	GlassControlTransparency = 0.941,
	GlassControlHover = Color3.fromHex("000000"),
	GlassControlHoverTransparency = 0.898,
	GlassSelected = Color3.fromHex("FFFFFF"),
	GlassSelectedTransparency = 0.149,
	GlassPill = Color3.fromHex("F7F8FB"),
	-- The pill and banner float over the 3D scene rather than a card, so the
	-- light frost needs a little more body to keep secondary text legible.
	GlassPillTransparency = 0.16,

	StrokeGlass = Color3.fromHex("FFFFFF"),
	StrokeGlassTransparency = 0.251,
	StrokeHairline = Color3.fromHex("000000"),
	StrokeHairlineTransparency = 0.922,
	HighlightTop = Color3.fromHex("FFFFFF"),
	HighlightTopTransparency = 0.051,
	ShadowDrop = Color3.fromHex("3C3C50"),
	ShadowDropTransparency = 0.749,

	LabelPrimary = Color3.fromHex("111114"),
	LabelPrimaryTransparency = 0,
	LabelSecondary = Color3.fromHex("3C3C43"),
	LabelSecondaryTransparency = 0.30,
	LabelTertiary = Color3.fromHex("3C3C43"),
	LabelTertiaryTransparency = 0.55,
	LabelOnAccent = Color3.fromHex("FFFFFF"),

	Accent = Color3.fromHex("007AFF"),
	AccentSoft = Color3.fromHex("007AFF"),
	AccentSoftTransparency = 0.839,
	Positive = Color3.fromHex("34C759"),
	PositiveSoft = Color3.fromHex("34C759"),
	PositiveSoftTransparency = 0.839,

	TrafficClose = Color3.fromHex("FF5F57"),
	TrafficMinimize = Color3.fromHex("FEBC2E"),
	TrafficZoom = Color3.fromHex("28C840"),
	SwitchOff = Color3.fromHex("787880"),
	SwitchOffTransparency = 0.78,
	Knob = Color3.fromHex("FFFFFF"),
}

--------------------------------------------------------------------------------
-- Resolution
--------------------------------------------------------------------------------

-- `overrides` is an optional token table. It is merged last, so anything the
-- caller passes wins over the built-in dark/light token (including derived
-- accent tokens, if they want to control them explicitly). If it only sets
-- `Accent`, the hover/pressed/gradient tokens are still derived from it.
function Theme.resolve(
	mode: string?,
	canonicalAccent: Color3?,
	overrides: { [string]: any }?
): { [string]: any }
	local base = mode == "Light" and Theme.Light or Theme.Dark
	local resolved: { [string]: any } = table.clone(base)
	local canonical = canonicalAccent or Theme.Accents[1].Color
	local accent = Theme.accentForMode(canonical, resolved.Mode)
	if overrides and typeof(overrides.Accent) == "Color3" then
		accent = overrides.Accent
	end

	resolved.CanonicalAccent = canonical
	resolved.Accent = accent
	resolved.AccentSoft = accent
	resolved.AccentHover = Util.brighten(accent, 0.10)
	resolved.AccentPressed = Util.darken(accent, 0.14)
	resolved.AccentDeep = Util.darken(accent, 0.26)
	resolved.AccentText = Util.contrastText(accent)
	resolved.HeroGradient = ColorSequence.new({
		ColorSequenceKeypoint.new(0, accent),
		ColorSequenceKeypoint.new(0.55, Util.mixColor(accent, Color3.fromHex("5E5CE6"), 0.62)),
		ColorSequenceKeypoint.new(1, Util.mixColor(accent, Color3.fromHex("BF5AF2"), 0.55)),
	})
	resolved.HeroGradientLight = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Util.brighten(accent, 0.04)),
		ColorSequenceKeypoint.new(0.55, Util.mixColor(accent, Color3.fromHex("6E6BF0"), 0.55)),
		ColorSequenceKeypoint.new(1, Util.mixColor(accent, Color3.fromHex("C86BF5"), 0.48)),
	})

	if overrides then
		for key, value in pairs(overrides) do
			if key ~= "Mode" then
				resolved[key] = value
			end
		end
	end
	return resolved
end

function Theme.defaultAccent(mode: string?): Color3
	return mode == "Light" and Theme.Accents[1].Light or Theme.Accents[1].Color
end

--------------------------------------------------------------------------------
-- Context: live theme state shared by the window and every component
--------------------------------------------------------------------------------

local Context = {}
Context.__index = Context

-- `overrides` lets a caller recolour any token without forking the library:
--
--   local ctx = Aurora.newContext("Dark", nil, {
--       GlassWindow = Color3.fromHex("1B1030"),
--       GlassWindowTransparency = 0.28,
--       Accent = Color3.fromHex("FF7AB6"),
--   })
--
-- Keys are the names used by Theme.Dark / Theme.Light. Values may be Color3,
-- number, string or any other type the token expects.
function Theme.newContext(mode: string?, accent: Color3?, overrides: { [string]: any }?)
	local self = setmetatable({}, Context)
	self.Mode = mode == "Light" and "Light" or "Dark"
	self.CanonicalAccent = Theme.canonicalAccent(accent or Theme.Accents[1].Color)
	self.Overrides = overrides and table.clone(overrides) or {}
	self.Theme = Theme.resolve(self.Mode, self.CanonicalAccent, self.Overrides)
	self.Changed = Util.Signal.new()
	self._binds = {}
	self._destroyed = false
	self.BlurEnabled = true
	self.GlassIntensity = 75
	return self
end

function Context:Bind(fn: (theme: { [string]: any }, duration: number) -> ())
	local record = { Fn = fn }
	table.insert(self._binds, record)
	fn(self.Theme, 0)
	return function()
		local index = table.find(self._binds, record)
		if index then
			table.remove(self._binds, index)
		end
	end
end

function Context:_apply(duration: number)
	if self._destroyed then
		return
	end
	self.Theme = Theme.resolve(self.Mode, self.CanonicalAccent, self.Overrides)
	for _, record in ipairs(table.clone(self._binds)) do
		record.Fn(self.Theme, duration)
	end
	self.Changed:Fire(self.Theme, duration)
end

function Context:SetMode(nextMode: string, animate: boolean?)
	if nextMode ~= "Light" then
		nextMode = "Dark"
	end
	if nextMode == self.Mode then
		return
	end
	self.Mode = nextMode
	self:_apply(animate == false and 0 or Theme.Motion.Theme)
end

function Context:ToggleMode(animate: boolean?)
	self:SetMode(self.Mode == "Dark" and "Light" or "Dark", animate)
end

function Context:SetAccent(color: Color3, animate: boolean?)
	self.CanonicalAccent = Theme.canonicalAccent(color)
	-- A runtime accent choice must win over an Accent token pinned in a theme
	-- override table, otherwise SetAccent would look like a no-op.
	self.Overrides.Accent = nil
	self:_apply(animate == false and 0 or Theme.Motion.Theme)
end

function Context:SetBlurEnabled(enabled: boolean)
	self.BlurEnabled = enabled
	self.Changed:Fire(self.Theme, 0)
end

function Context:SetGlassIntensity(value: number)
	self.GlassIntensity = Util.clamp(value, 0, 100)
	self.Changed:Fire(self.Theme, 0)
end

-- Replace or merge token overrides at runtime.
--
--   window:SetTheme({ GlassWindow = Color3.fromHex("0E1A2B") })
--   window:SetTheme(nil)                       -- back to the stock theme
--   window:SetTheme({ ... }, true)             -- crossfade the change
--   window:SetTheme({ ... }, true, true)       -- replace instead of merge
function Context:SetTheme(overrides: { [string]: any }?, animate: boolean?, replace: boolean?)
	if overrides == nil then
		table.clear(self.Overrides)
	elseif replace then
		self.Overrides = table.clone(overrides)
	else
		if typeof(overrides) ~= "table" then
			return
		end
		for key, value in pairs(overrides) do
			self.Overrides[key] = value
		end
	end
	self:_apply(animate == false and 0 or Theme.Motion.Theme)
end

-- Set a single token, e.g. ctx:SetToken("LabelPrimary", Color3.new(1, 1, 1)).
function Context:SetToken(key: string, value: any, animate: boolean?)
	if value == nil then
		self.Overrides[key] = nil
	else
		self.Overrides[key] = value
	end
	self:_apply(animate == false and 0 or Theme.Motion.Theme)
end

function Context:GetOverrides(): { [string]: any }
	return table.clone(self.Overrides)
end

function Context:Destroy()
	self._destroyed = true
	self.Changed:DisconnectAll()
	table.clear(self._binds)
end

Theme.Context = Context

return Theme

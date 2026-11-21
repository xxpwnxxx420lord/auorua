# Aurora — Glass UI for Roblox

A complete, dependency-free Luau UI library rebuilt 1:1 from the Figma project
**“Aurora — Glass UI for Roblox.”** It ships with a live demo replica, a
component gallery, config persistence for executors, and a small, explicit API
for the pieces most UI libraries hide.

<img width="677" height="433" alt="image" src="https://github.com/user-attachments/assets/7e499f89-08f7-4742-a9cf-c256b7f0e4ae" />

- **Literal frosted glass.** A neutral frost texture is clipped inside the
  window. There is no scenic backdrop, no screenshot of the game behind it, and
  no fake blur rectangle. The glass stays colourless and works on any scene.
- **Figma-exact geometry.** 640 × 430 window, 44 px titlebar, 172 px sidebar,
  468 × 386 content area, 10 px window radius, macOS traffic lights, 9-slice
  drop shadow copied from `StarterGui.DropShadowHolder`.
- **Full motion language.** Sliding tab selection, cross-fading pages,
  spring-driven sliders, hover growth, drag lift + velocity tilt, minimize to a
  pill, notification banner, and a restore animation that fades the shadow back
  in.
- **Executor friendly.** `executor.lua` installs the whole module tree with one
  `loadstring` line — no Studio, no Rojo. `Aurora.newScreenGui()` parents to
  `gethui()` when the executor provides it, then `CoreGui`, then `PlayerGui`.
  Optional configs use `writefile` / `readfile` / `makefolder` / `listfiles` /
  `delfile`, and fall back to an in-memory store in Studio.
- **Simple to use.** `Aurora:CreateWindow` then `Window:AddTab` then
  `Tab:AddToggle` / `AddSlider` / `AddButton` / … Every control places itself in
  a scrolling glass card, so you never write `UDim2`.
- **Custom options:** `StartingTab`, `Close()` / `Open()`, `ChangeToggle`,
  a `Theme` override table, and `BackgroundImage`.

---

## Installation

### Rojo

The repository includes `default.project.json`:

```sh
rojo serve
```

This maps `AuroraUI/` to `ReplicatedStorage.AuroraUI` and the two demo scripts
to `StarterPlayerScripts`.

### Manual (Studio)

1. Create a **ModuleScript** named `AuroraUI` in `ReplicatedStorage`.
2. Copy `AuroraUI/init.lua` into it.
3. Add the other modules as children of `AuroraUI`:
   - `Util`, `Theme`, `Config`, `Tab`, `Window` as ModuleScripts
   - `Components` as a ModuleScript (`Components/init.lua`) with every
     `Components/*.lua` file as a ModuleScript child
4. Require it:

```lua
local Aurora = require(game:GetService("ReplicatedStorage").AuroraUI)
```

> The demo and gallery scripts are optional. They only need `AuroraDemo` and
> `AuroraKit` LocalScripts in `StarterPlayerScripts`.

### Executor (no Studio)

Aurora is a module tree, not one pasted script, so the repository ships
[`executor.lua`](executor.lua). It downloads every module from GitHub, builds
them as ModuleScripts inside the executor's hidden UI, requires the library,
and returns it:

```lua
local Aurora = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/xxpwnxxx420lord/auorua/main/executor.lua"
))()
```

That is the entire installation. Use it exactly like any other UI library:

```lua
local Window = Aurora:CreateWindow({ Title = "My script", SubTitle = "by me" })
local Main = Window:AddTab("Main")

Main:AddToggle("Auto apply", true):OnChanged(function(value)
    print(value)
end)
```

The [Quick start](#quick-start) below is the full version.

**Requirements**

- `game:HttpGet` with outbound access to `raw.githubusercontent.com`
- `loadstring` (or paste `executor.lua` into your executor's script runner)
- That's it — no Rojo, no Studio, no manual ModuleScripts

The loader parents the module tree to `gethui()` when the executor exposes it,
then `CoreGui`, then `PlayerGui` as a last resort. It prints one line when the
download starts and one when it finishes.

**Caching and updates**

The built tree and the returned `Aurora` table are cached in `getgenv()` (or
`_G` when the executor has no `getgenv`), so running the one-liner again in the
same session is instant. To pick up a newer commit, force a fresh download:

```lua
local Aurora = loadstring(game:HttpGet(URL))({ Refresh = true })
```

Other options:

```lua
local Aurora = loadstring(game:HttpGet(URL))({
    Refresh = true,   -- ignore the session cache
    Silent = true,    -- no loader prints
    BaseUrl = "https://raw.githubusercontent.com/xxpwnxxx420lord/auorua/COMMIT_HASH/",
})
```

`BaseUrl` is how you pin a version: replace `main` with a commit SHA or use your
own fork. The default URL always tracks `main`.

The loader is inspectable after it runs:

```lua
print(Aurora.Loader.Parent)  -- "gethui", "CoreGui", "PlayerGui" or "ReplicatedStorage"
print(Aurora.Loader.Folder)  -- the AuroraUILoader folder
print(Aurora.Loader.BaseUrl)
```

**Configs on an executor**

Everything in [Configs](#configs-executor-persistence) works in an executor.
`writefile` is optional: when the executor provides `writefile` / `readfile`,
profiles persist to `AuroraUI/<name>.json`; without them, configs live in
memory for the session. Window autosave (`Config = "my_window"`) is the easiest
way to keep tabs, toggles, accent and position between launches.

> Some executors block `require()` on instances created at runtime. If the
> loader errors at the `require` step, use an executor that supports it (most
> mainstream ones do), or install the files manually with the Studio steps
> above and require the resulting ModuleScript.

---

## Quick start

```lua
local Aurora = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/xxpwnxxx420lord/auorua/main/executor.lua"
))()

local Window = Aurora:CreateWindow({
    Title = "My script",
    SubTitle = "by me",
})

local Main = Window:AddTab("Main")
local Settings = Window:AddTab("Settings")

Main:AddParagraph("Profile", "Signed in as Player.")

Main:AddButton("Click me", function()
    Window:Notify({ Title = "Clicked", Content = "The button works." })
end)

local auto = Main:AddToggle("Auto apply", true)
auto:OnChanged(function(value)
    print("Auto apply:", value)
end)

local speed = Main:AddSlider("Walk speed", 0, 100, 32)
speed:OnChanged(function(value)
    print("Speed:", value)
end)

local mode = Main:AddDropdown("Mode", { "Low", "Medium", "High" }, "Medium")
mode:OnChanged(function(value)
    print("Mode:", value)
end)

local name = Main:AddInput("Name", "Type here", "Player")
name:OnChanged(function(value)
    print("Name:", value)
end)

Settings:AddColorPicker("Accent", Color3.fromRGB(10, 132, 255))
```

That is the whole script. `Window`, `Main` and every control are normal Luau
tables. There is no global `Options` table and no addon managers.

`Aurora:CreateWindow` creates the ScreenGui and theme context for you, then
`AddTab` adds the sidebar item and an empty glass page. Every `Add*` method
places its own control in a scrolling card stack, so you never write `UDim2`.

### Controls

Both forms work. The positional form is shorter; the table form adds
descriptions and ids.

```lua
Main:AddButton("Click me", function() end)

Main:AddButton({
    Title = "Click me",
    Description = "Optional second line",
    Callback = function() end,
})

local auto = Main:AddToggle("Auto apply", true)
local auto = Main:AddToggle({
    Title = "Auto apply",
    Default = true,
    Id = "AutoApply", -- optional: registers a window toggle for configs
})

local speed = Main:AddSlider("Walk speed", 0, 100, 32)
local speed = Main:AddSlider({
    Title = "Walk speed",
    Min = 0,
    Max = 100,
    Default = 32,
    Step = 1,
    Suffix = " studs",
})

local mode = Main:AddDropdown("Mode", { "Low", "Medium", "High" }, "Medium")
local name = Main:AddInput("Name", "Type here", "Player")
local accent = Main:AddColorPicker("Accent", Color3.fromRGB(10, 132, 255))

Main:AddParagraph("About", "A longer line of text that wraps automatically.")
Main:AddParagraph({ Title = "About", Content = "Table form also works." })
```

Every value control returns the same tiny interface:

```lua
control.Value                    -- current value
control:SetValue(value)          -- updates the control and fires OnChanged
control:OnChanged(function(value)
    print(value)
end)
```

`AddColorPicker` uses `(color, alpha)` for both `OnChanged` and `SetValue`.
The returned control also has the underlying component attached
(`control.Switch`, `control.Slider`, `control.Dropdown`, `control.Input`,
`control.Picker`) if you need low-level access.

### Notifications

```lua
Window:Notify({ Title = "Saved", Content = "Your settings were applied." })
Window:Notify("Done") -- title only
```

The banner slides in from the right and hides itself after a few seconds. Pass
`Duration = false` to leave it on screen until the next notification.

### Window options

```lua
local Window = Aurora:CreateWindow({
    Title = "My script",
    SubTitle = "optional titlebar suffix",
    Theme = "Dark",                -- "Dark", "Light", or a token override table
    Accent = Color3.fromRGB(10, 132, 255),
    Tabs = { "Main", "Settings" }, -- optional; AddTab works too
    StartingTab = 1,
    BackgroundImage = "rbxassetid://YOUR_IMAGE_ID",
    Config = "my_script",          -- optional autosave, no manager needed
})
```

If you omit `Parent`, `CreateWindow` makes and owns the ScreenGui. Pass
`Parent = existingScreenGui` to use your own.

### Adding to an existing window

`AddTab` works after the window exists, so scripts can register tabs lazily:

```lua
local Tab = Window:AddTab({ Title = "Extra", Icon = "grid" })
Tab:AddToggle("Feature", false)

print(Window:GetTab("Extra") == Tab) -- true
Window:SelectTab(2)
```

Tabs without an icon cycle the three Figma tiles automatically. `Icon` accepts
`"grid"`, `"sliders"` or `"paint"`; pass `Icon = ""` for a flat tile.

<details>
<summary>Advanced: build pages manually</summary>

The low-level API is still there if you want exact Figma positioning or your
own layout. `Aurora.createWindow` requires a parent and context; components and
`Build` callbacks are unchanged.

```lua
local Aurora = require(game:GetService("ReplicatedStorage").AuroraUI)
local C = Aurora.Components

local ctx = Aurora.newContext("Dark")
local gui = Aurora.newScreenGui({ Name = "Aurora" })

local tabs = {
    {
        Name = "Overview",
        Glyph = "grid",
        Build = function(page, context, window)
            window:BuildHeader(page, "Overview")

            local group = C.Group.new({
                Context = context,
                Parent = page,
                Width = 428,
            })
            local row = C.Row.new({ Context = context, Label = "Auto-apply" })
            local switch = C.Switch.new({ Context = context, Value = true })
            row:SetTrailing(switch.Root)
            group:AddRow(row)
            group.Root.Position = UDim2.fromOffset(20, 62)

            window:BindToggle("AutoApply", switch)
        end,
    },
}

local window = Aurora.createWindow({
    Parent = gui,
    Context = ctx,
    Tabs = tabs,
})
```

</details>

---

## Custom options

### `StartingTab` — open on a specific tab

1-based index, clamped to the number of tabs.

```lua
local Window = Aurora:CreateWindow({
    Title = "My script",
    Tabs = { "Main", "Controls", "Appearance" },
    StartingTab = 3, -- Appearance
})
```

### `Close()` / `Open()` — real close, not minimize

The red traffic light calls `Close()`, which fades the whole interface out and
hides it. `Open()` brings the same window back without rebuilding it. The yellow
light still minimizes to the pill.

```lua
local Window = Aurora:CreateWindow({ Title = "My script" })

Window:Close()
Window:Open()
Window:Toggle()

Window.ClosedChanged:Connect(function(closed)
    print(closed and "closed" or "opened")
end)

print(Window:IsOpen()) -- true / false
```

`OnClose` / `OnOpen` callbacks are supported:

```lua
Window.OnClose = function()
    print("window closed")
end
```

### `ChangeToggle` — named boolean state

Register an existing switch with `BindToggle`, or give a control an `Id` and it
is registered automatically. `ChangeToggle(name, boolean)` updates the switch,
the stored value, fires `ToggleChanged`, and runs the callback.

```lua
local Window = Aurora:CreateWindow({ Title = "My script" })
local Main = Window:AddTab("Main")

local auto = Main:AddToggle({
    Title = "Auto apply",
    Default = true,
    Id = "AutoApply", -- registers it for ChangeToggle + configs
})

Window:ChangeToggle("AutoApply", false)
print(auto.Value)                  -- false
print(Window:GetToggle("AutoApply")) -- false

-- All toggles at once (handy for configs)
for name, value in pairs(Window:GetToggles()) do
    print(name, value)
end

Window.ToggleChanged:Connect(function(name, value)
    print(name, value)
end)
```

If you built the switch yourself with the low-level API, hand it over:

```lua
Window:BindToggle("SlowMode", switch, function(value)
    print("SlowMode =", value)
end)
```

Create + register one control in a single call:

```lua
local slowMode = Main:AddToggle({
    Title = "Slow mode",
    Default = false,
    Id = "SlowMode",
})
```

Values can be declared before the switch exists:

```lua
local Window = Aurora:CreateWindow({
    Title = "My script",
    Toggles = {
        AutoApply = true,
        ReduceMotion = false,
    },
})

Window:ChangeToggle("ReduceMotion", true)
```

### `Theme` — token overrides

The `Theme` table is merged **last** over the built-in dark/light tokens.
Anything you pass wins, including derived accent tokens. If you only override
`Accent`, the hover/pressed/gradient tokens are still derived from it.

```lua
local Window = Aurora:CreateWindow({
    Title = "My script",
    Theme = "Dark", -- or the token override table below
    Accent = Color3.fromRGB(10, 132, 255),
})

-- Token overrides straight into the window
local Window = Aurora:CreateWindow({
    Title = "My script",
    Theme = {
        GlassWindow = Color3.fromHex("10131C"),
        GlassWindowTransparency = 0.25,
        Accent = Color3.fromHex("FF7AB6"),
        StrokeGlassTransparency = 0.70,
    },
})

-- Change later (merge by default)
Window:SetTheme({
    GlassWindow = Color3.fromHex("1A1026"),
    GlassWindowTransparency = 0.30,
}, true) -- true = animated crossfade

-- Replace the whole override table
Window:SetTheme({ Accent = Color3.fromHex("30D158") }, true, true)

-- Back to the stock theme
Window:SetTheme(nil)

-- Single token
Window.Context:SetToken("LabelPrimary", Color3.fromHex("FFFFFF"), true)
```

If you want a context you own, build it yourself and pass it in:

```lua
local ctx = Aurora.newContext("Dark", nil, {
    GlassWindow = Color3.fromHex("10131C"),
    Accent = Color3.fromHex("FF7AB6"),
})

local Window = Aurora:CreateWindow({ Title = "My script", Context = ctx })
```

Common token names (see `AuroraUI/Theme.lua` for the full list):

| Group | Tokens |
| --- | --- |
| Glass | `GlassWindow`, `GlassWindowTransparency`, `GlassDepth`, `GlassDepthTransparency`, `GlassSidebar`, `GlassSidebarTransparency`, `GlassCard`, `GlassCardTransparency`, `GlassControl`, `GlassControlTransparency`, `GlassPill`, `GlassPillTransparency` |
| Strokes | `StrokeGlass`, `StrokeGlassTransparency`, `StrokeHairline`, `StrokeHairlineTransparency`, `HighlightTop`, `HighlightTopTransparency` |
| Labels | `LabelPrimary`, `LabelPrimaryTransparency`, `LabelSecondary`, `LabelSecondaryTransparency`, `LabelTertiary`, `LabelTertiaryTransparency`, `LabelOnAccent` |
| Accent | `Accent`, `AccentSoft`, `AccentHover`, `AccentPressed`, `AccentDeep`, `HeroGradient`, `HeroGradientLight` |
| Status | `Positive`, `PositiveSoft`, `TrafficClose`, `TrafficMinimize`, `TrafficZoom`, `SwitchOff`, `Knob` |

Transparency values are Roblox transparencies: `0` = opaque, `1` = invisible.

A mode/accent preset change still works alongside overrides:

```lua
ctx:SetMode("Light")
ctx:SetAccent(Color3.fromHex("5E5CE6"))
```

`SetAccent` clears any pinned `Accent` override so the preset is not hidden.

### `BackgroundImage` — custom wallpaper

A background image sits above the dark glass body and below the tint, so it
reads as tinted glass rather than a raw photo. Setting an image disables the
frost layer; clearing it brings the frost back.

```lua
local Window = Aurora:CreateWindow({
    Title = "My script",
    BackgroundImage = "rbxassetid://YOUR_IMAGE_ID",
})

Window:SetBackgroundImage("rbxassetid://ANOTHER_ID")
Window:SetBackgroundImage("") -- remove, restore frost
```

---

## Executor / CoreGui

Install with the [one-line executor loader](#executor-no-studio), then
`Aurora.newScreenGui()` handles the parent chain for you:

1. `gethui()` from the executor, if present
2. `CoreGui`
3. `Players.LocalPlayer.PlayerGui`

```lua
local gui = Aurora.newScreenGui({
    Name = "Aurora",
    DisplayOrder = 100, -- default
    ResetOnSpawn = false,
})
```

Helpers are exported if you need them directly:

```lua
local parent = Aurora.getGuiParent()
Aurora.parentToGui(existingScreenGui)
local found = Aurora.findScreenGui("AuroraDemo")
```

In a normal Studio playtest `CoreGui` is protected, so the helper quietly falls
back to `PlayerGui`. In an executor it parents to the hidden UI.

The window also raises its ScreenGui to at least `DisplayOrder = 100`, so the
glass and its drop shadow float above other interfaces.

---

## Configs (executor persistence)

`Aurora.Config` is a small JSON store with an in-memory fallback:

```lua
local Config = Aurora.Config

Config.save("my_settings", { Enabled = true, Speed = 32 })
local data = Config.load("my_settings")
Config.delete("my_settings")

print(Config.exists("my_settings"))
print(Config.isAvailable())       -- true when writefile/readfile exist
print(Config.path("my_settings")) -- AuroraUI/my_settings.json
print(table.concat(Config.list(), ", "))
```

Automatic window autosave:

```lua
local Window = Aurora:CreateWindow({
    Title = "My script",
    Config = "my_window", -- or Config = true for "window"
})
```

The profile stores mode, accent, glass intensity, blur state, active tab, zoom,
background image, window position, and every registered toggle. It saves two
seconds after a change, and immediately on `Close()`.

```lua
Window.ConfigHandle:Save()
Window.ConfigHandle:Load()
Window.ConfigHandle:Delete()
Window.ConfigHandle:Destroy()
```

`Config.encode` / `Config.decode` support strings, numbers, booleans, arrays,
objects, `Color3`, `Vector2`, and `UDim2`. If the executor exposes no file
functions, everything still works for the current session.

The file functions are resolved from `_G`, `getgenv()` and `getfenv(0)`, so the
module does not assume a specific executor.

---

## Components

Every component takes a `Context`, exposes `.Root`, and has `:Destroy()`.

```lua
C.Button.new({ Context = ctx, Text = "Save", Style = "Primary" })
C.IconButton.new({ Context = ctx, Glyph = "‹" })
C.Switch.new({ Context = ctx, Value = true })
C.Slider.new({ Context = ctx, Min = 0, Max = 100, Value = 75 })
C.Segmented.new({ Context = ctx, Options = { "Dark", "Light" }, Index = 1 })
C.Chip.new({ Context = ctx, Text = "Live", Tone = "Live" })
C.Badge.new({ Colors = { Color3.new(), Color3.new() }, Glyph = "grid" })
C.Stat.new({ Context = ctx, Value = "60", Label = "FPS" })
C.Row.new({ Context = ctx, Label = "Auto-apply" })
C.Group.new({ Context = ctx, Width = 428, Height = 99 })
C.ColorPicker.new({ Context = ctx })
C.Image.new({ Context = ctx, Caption = "Preview" })
C.Avatar.new({ Context = ctx, Initial = "A" })
C.Banner.new({ Context = ctx, Title = "Saved", Body = "All set." })
C.Progress.new({ Context = ctx, Value = 0.68 })
C.Input.new({ Context = ctx, Placeholder = "Name" })
C.Dropdown.new({ Context = ctx, Options = { "Compact", "Comfortable" } })
C.tooltip(target, "Tooltip text", { Context = ctx, Parent = window.Overlay })
```

Convenience constructor:

```lua
local button = Aurora.Components.create("Button", {
    Context = ctx,
    Text = "Create",
    Style = "Primary",
})
```

### Component notes

- **Slider** — spring follow, hover/drag knob growth, accent glow, value pop.
- **Switch** — 46 × 28 track, 24 × 24 knob, 0.20 s Quint easing.
- **Banner** — slides in from the right, uses its own 9-slice shadow.
- **Dropdown** — opens above other content via the window overlay.
- **Progress** — 6 px track with an accent fill (set `Value` in `0..1`).
- **ColorPicker** — hue/saturation/value with a live swatch.

---

## Assets

| Asset | ID | Source |
| --- | --- | --- |
| Frost texture | `rbxassetid://112811578533426` | `public/frost.png` |
| 9-slice shadow | `rbxassetid://6014261993` | Roblox `StarterGui.DropShadowHolder` |

Asset IDs are in code:

```lua
Aurora.GlassBlur    -- frost texture
Aurora.Assets.Frost -- same value
Aurora.Assets.Shadow
```

The original images used while building the library are in [`public/`](public/):
`frost.png`, `glass-blur.png`, `frost-preview.png`, `fig-overview.png`,
`live-full.png`, `backdrop.png`, and `backdrop-blur.png`. The HTML/SVG helpers
used to generate them live in `assets/`.

---

## Repo layout

```
AuroraUI/
  init.lua            -- public entry point
  Util.lua            -- signals, tweens, drag, colour helpers
  Theme.lua           -- tokens, accents, modes, overrides
  Config.lua          -- executor JSON persistence
  Tab.lua             -- simple API: scrolling cards + Add* controls
  Window.lua          -- chrome, shadow, tabs, banner, pill, toggles
  Components/
    init.lua          -- registry + convenience constructors
    Button.lua, IconButton.lua, Switch.lua, Slider.lua,
    Segmented.lua, Chip.lua, Badge.lua, Stat.lua, Row.lua,
    Group.lua, ColorPicker.lua, Image.lua, Avatar.lua,
    Banner.lua, Tooltip.lua, Progress.lua, Input.lua, Dropdown.lua
AuroraDemo.client.lua -- Figma replica (Overview / Controls / Appearance)
AuroraKit.client.lua  -- component gallery (Buttons / Fields / Color / Media)
example.lua           -- executor example: window with the main controls
executor.lua          -- one-line GitHub loader for executors
assets/               -- Figma reference + generated frost source
public/               -- images that back the uploaded asset IDs
default.project.json  -- Rojo mapping
```

---

## Demo and gallery

`AuroraDemo` is the Figma replica. It is enabled by default.

`AuroraKit` is dormant until the place opts in:

```lua
game:SetAttribute("AuroraKit", true)
```

While the gallery is open the demo is hidden. Closing the gallery restores the
demo. Set the attribute back to `true` to reopen the same window.

Debug hooks used for automated screenshots (all optional, nothing in a normal
game sets them):

| ScreenGui attribute | Effect |
| --- | --- |
| `AuroraTab` | select tab 1–3 |
| `AuroraMode` | `"Dark"` / `"Light"` |
| `AuroraBanner` | show a banner with that title |
| `AuroraAction` | `"minimize"`, `"restore"`, `"zoom"`, `"close"`, `"open"` |
| `AuroraSlider` | set the walk-speed slider |
| `AuroraIntensity` | set glass intensity 0–100 |
| `AuroraToggle` | `"AutoApply=true"` style toggle change |
| `AuroraTheme` | hex tint or `"reset"` |
| `AuroraBackground` | image id, or empty to restore frost |
| `KitTab` | select gallery tab 1–4 |
| `KitMode` | `"Dark"` / `"Light"` |
| `KitAction` | `"close"`, `"open"`, `"minimize"`, `"restore"` |

---

## Notes on the glass

Roblox cannot blur a live backdrop inside a `GuiObject`, so “blur” here means a
neutral frost texture clipped to the window plus a dark body and tint. This is
deliberate: a screenshot of the scene would turn the window into a picture of
the world and break on every camera move. The frost is intensity-driven, can be
disabled, and can be replaced with your own texture or a background image.

The drop shadow is exactly the `StarterGui.DropShadowHolder` setup: one 9-slice
`ImageLabel`, `rbxassetid://6014261993`, `SliceCenter = (49, 49, 450, 450)`, 47
px larger than the frame on both axes, centred, 50% black.

---

## License

MIT. See `LICENSE`.

Repository: <https://github.com/xxpwnxxx420lord/auorua>

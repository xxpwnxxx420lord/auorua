--!strict
-- Aurora UI · Components
-- One entry point for every component. Each module returns a class table with
-- a `.new(props)` constructor and a `:Destroy()` method.

local Components = {}

Components.Common = require(script.Common)

Components.Button = require(script.Button)
Components.IconButton = require(script.IconButton)
Components.Switch = require(script.Switch)
Components.Slider = require(script.Slider)
Components.Segmented = require(script.Segmented)
Components.Chip = require(script.Chip)
Components.Badge = require(script.Badge)
Components.Stat = require(script.Stat)
Components.Row = require(script.Row)
Components.Group = require(script.Group)
Components.ColorPicker = require(script.ColorPicker)
Components.Image = require(script.Image)
Components.Avatar = require(script.Avatar)
Components.Banner = require(script.Banner)
Components.Tooltip = require(script.Tooltip)
Components.Progress = require(script.Progress)
Components.Input = require(script.Input)
Components.Dropdown = require(script.Dropdown)

local registry: { [string]: any } = {
	Button = Components.Button,
	IconButton = Components.IconButton,
	Switch = Components.Switch,
	Slider = Components.Slider,
	Segmented = Components.Segmented,
	Chip = Components.Chip,
	Badge = Components.Badge,
	Stat = Components.Stat,
	Row = Components.Row,
	Group = Components.Group,
	ColorPicker = Components.ColorPicker,
	Image = Components.Image,
	Avatar = Components.Avatar,
	Banner = Components.Banner,
	Progress = Components.Progress,
	Input = Components.Input,
	Dropdown = Components.Dropdown,
}

-- Convenience constructor: Components.create("Button", { ... })
function Components.create(kind: string, props: { [string]: any }?)
	local class = registry[kind]
	if not class then
		error("Aurora.Components: unknown component '" .. tostring(kind) .. "'")
	end
	return class.new(props)
end

-- Attaches a tooltip to any GuiObject. Lives on Components so callers do not
-- need to require the module separately.
function Components.tooltip(target: GuiObject, text: string, options: { [string]: any }?)
	return Components.Tooltip.attach(target, text, options)
end

return Components

--!nocheck
-- Aurora UI · example script
-- Paste this into any executor. It downloads the library and builds a window
-- with the main controls. Nothing here touches UDim2 or the internals.

local Aurora = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/xxpwnxxx420lord/auorua/main/executor.lua"
))()

local Window = Aurora:CreateWindow({
	Title = "Aurora",
	Theme = "Dark",
	Accent = Color3.fromRGB(10, 132, 255),
	Config = "aurora_example", -- optional autosave, no manager needed
})

local Main = Window:AddTab("Main")
local Settings = Window:AddTab("Settings")

--------------------------------------------------------------------------------
-- Main
--------------------------------------------------------------------------------

local auto = Main:AddToggle({
	Title = "Auto apply",
	Default = true,
	Id = "AutoApply",
})
auto:OnChanged(function(value)
	print("AutoApply =", value)
end)

Main:AddSlider({
	Title = "Walk speed",
	Min = 0,
	Max = 100,
	Default = 32,
	Suffix = " studs",
}):OnChanged(function(value)
	print("Speed =", value)
end)

Main:AddDropdown({
	Title = "Mode",
	Values = { "Low", "Medium", "High" },
	Default = "Medium",
}):OnChanged(function(value)
	print("Mode =", value)
end)

Main:AddInput({
	Title = "Name",
	Placeholder = "Type here",
	Default = "Player",
}):OnChanged(function(value)
	print("Name =", value)
end)

Main:AddButton({
	Title = "Notification",
	Callback = function()
		Window:Notify({
			Title = "Hello",
			Content = "The button works.",
		})
	end,
})

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

Settings:AddColorPicker({
	Title = "Accent",
	Default = Color3.fromRGB(10, 132, 255),
}):OnChanged(function(color)
	Window.Context:SetAccent(color)
end)

Settings:AddToggle({
	Title = "Light theme",
	Default = false,
}):OnChanged(function(value)
	Window.Context:SetMode(value and "Light" or "Dark")
end)

Window:SelectTab(1)

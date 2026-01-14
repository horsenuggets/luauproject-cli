--[[
LuauProject

CLI tool to scaffold new Luau projects from luau-package-template.
]]

local NewCommand = require("./Commands/NewCommand")

return {
	NewCommand = NewCommand,
}

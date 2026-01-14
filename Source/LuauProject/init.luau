--[[
LuauProject

CLI tool to scaffold new Luau projects from luau-package-template.
]]

local NewCommand = require("@self/Commands/NewCommand")

return {
	NewCommand = NewCommand,
}

--[[

LuauprojectCommand

The root command for the luauproject CLI. Registers all subcommands.

]]

local Commandline = require("@packages/Commandline")
local InstallCommand = require("@self/InstallCommand")
local NewCommand = require("@self/NewCommand")
local UpdateCommand = require("@self/UpdateCommand")
local __VERSION__ = require("@self/__VERSION__")

return Commandline.Command.new({
    Name = "luauproject",
    Description = "A CLI tool for instantiating new Luau projects.",
    Version = __VERSION__,
    Subcommands = {
        InstallCommand,
        NewCommand,
        UpdateCommand,
    },
})

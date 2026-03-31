--[[

LuauprojectCommand

The root command for the luauproject CLI. Registers all subcommands.

--]]

local Commandline = require("@packages/Commandline")
local NewCommand = require("@self/NewCommand")
local __VERSION__ = require("@self/__VERSION__")

local INSTALL_OPTIONS = {
    Name = "luauproject",
    InstallDir = ".luauproject-cli",
    Version = __VERSION__,
    Repository = "horsenuggets/luauproject-cli",
}

return Commandline.Command.new({
    Name = "luauproject",
    Description = "A CLI tool for instantiating new Luau projects.",
    Version = __VERSION__,
    Subcommands = {
        Commandline.Toolkit.installCommand(INSTALL_OPTIONS),
        NewCommand,
        Commandline.Toolkit.updateCommand(INSTALL_OPTIONS),
    },
})

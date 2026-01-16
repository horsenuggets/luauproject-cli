--[[

luauproject.cmd

The root command for the luauproject CLI. Registers all subcommands.

]]

local Commandline = require("@packages/Commandline")
local __VERSION__ = require("@self/__VERSION__")
local install_cmd = require("@self/install.cmd")
local new_cmd = require("@self/new.cmd")

return Commandline.Command.new({
    Name = "luauproject",
    Description = "A CLI tool for instantiating new Luau projects.",
    Version = __VERSION__,
    Subcommands = {
        install_cmd,
        new_cmd,
    },
})

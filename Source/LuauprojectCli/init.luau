#!/usr/bin/env -S lune run

--[[

LuauprojectCli

The entry point for the luauproject CLI. Registers all commands and executes
with process arguments.

--]]

const process = require("@lune/process")

const Commandline = require("@packages/Commandline")
const LuauprojectCommand = require("@luauprojectcli/LuauprojectCommand")

const function luauprojectCli()
    Commandline.registerCommand(LuauprojectCommand)
    LuauprojectCommand:Execute(process.args)
end

luauprojectCli()

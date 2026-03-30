#!/usr/bin/env -S lune run

--[[

LuauprojectCli

The entry point for the luauproject CLI. Registers all commands and executes
with process arguments.

--]]

local process = require("@lune/process")

local Commandline = require("@packages/Commandline")
local LuauprojectCommand = require("@luauprojectcli/LuauprojectCommand")

local function luauprojectCli()
    Commandline.registerCommand(LuauprojectCommand)
    LuauprojectCommand:Execute(process.args)
end

luauprojectCli()

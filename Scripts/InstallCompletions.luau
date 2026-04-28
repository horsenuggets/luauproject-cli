#!/usr/bin/env -S lune run

--[[

InstallCompletions

Installs shell completion scripts for the luauproject CLI.

--]]

local Commandline = require("@packages/Commandline")
local LuauprojectCommand = require("@luauprojectcli/LuauprojectCommand")
local process = require("@lune/process")

Commandline.Toolkit.installCompletions({
    Command = LuauprojectCommand,
    Shell = process.args[1] or "zsh",
})

#!/usr/bin/env -S lune run

--[[

GenerateCompletions

Generates shell completion scripts for the luauproject CLI.

--]]

local Commandline = require("@packages/Commandline")
local LuauprojectCommand = require("@luauprojectcli/LuauprojectCommand")
local process = require("@lune/process")

local shell = process.args[1] or "zsh"
print(Commandline.Completions.generate(LuauprojectCommand, shell))

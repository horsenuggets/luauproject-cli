#!/usr/bin/env -S lune run

--[[

GenerateCompletions.exec

Generates shell completion scripts for the luauproject CLI.

[Usage] ./Scripts/GenerateCompletions.exec.luau [bash|zsh|fish|powershell]

--]]

const Commandline = require("@packages/Commandline")
const LuauprojectCommand = require("@luauprojectcli/LuauprojectCommand")
const process = require("@lune/process")

const GenerateCompletions = {}

function GenerateCompletions.exec()
    print(Commandline.Completions.generate(LuauprojectCommand, process.args[1] or "zsh"))
end

GenerateCompletions.exec()

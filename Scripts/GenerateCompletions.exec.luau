#!/usr/bin/env -S lune run

--[[

GenerateCompletions.exec

Generates shell completion scripts for the luauproject CLI.

[Usage] ./Scripts/GenerateCompletions.exec.luau [bash|zsh|fish|powershell]

--]]

const Commandline = require("@packages/Commandline")
const ScriptHelpers = require("./Helpers/ScriptHelpers")
const process = require("@lune/process")

const GenerateCompletions = {}

function GenerateCompletions.exec()
    -- The command requires the generated version module, so load it only after generating
    ScriptHelpers.ensureVersionModule()
    const LuauprojectCommand = require("@luauprojectcli/LuauprojectCommand")
    print(Commandline.Completions.generate(LuauprojectCommand, process.args[1] or "zsh"))
end

GenerateCompletions.exec()

#!/usr/bin/env -S lune run

--[[

InstallCompletions.exec

Installs shell completion scripts for the luauproject CLI.

[Usage] ./Scripts/InstallCompletions.exec.luau [bash|zsh|fish|powershell]

--]]

const Commandline = require("@packages/Commandline")
const LuauprojectCommand = require("@luauprojectcli/LuauprojectCommand")
const process = require("@lune/process")

const InstallCompletions = {}

function InstallCompletions.exec()
    Commandline.Toolkit.installCompletions({
        Command = LuauprojectCommand,
        Shell = process.args[1] or "zsh",
    })
end

InstallCompletions.exec()

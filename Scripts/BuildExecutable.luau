#!/usr/bin/env -S lune run

--[[

BuildExecutable

Compiles the luauproject CLI to a standalone executable. Generates the version
module and patches requires for cross-platform compatibility.

[Usage] ./Scripts/BuildExecutable.luau [target]

--]]

local Toolkit = require("@packages/Commandline").Toolkit
local process = require("@lune/process")

local function buildExecutable()
    Toolkit.generateVersion({
        VersionFile = "VERSION",
        OutputPath = "Source/LuauprojectCli/luauproject.cmd/__VERSION__.luau",
    })

    Toolkit.build({
        Name = "luauproject",
        EntryPoint = "Source/LuauprojectCli/luauproject-cli.luau",
        Target = process.args[1],
        AliasDirs = {
            { alias = "@packages", dir = "Packages" },
            { alias = "@luauprojectcli", dir = "Source/LuauprojectCli" },
            { alias = "@tests", dir = "Tests" },
        },
    })
end

buildExecutable()

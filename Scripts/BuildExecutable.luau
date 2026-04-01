#!/usr/bin/env -S lune run

--[[

BuildExecutable

Compiles the luauproject CLI to a standalone executable.

[Usage] ./Scripts/BuildExecutable.luau [target]

--]]

local Toolkit = require("@packages/Commandline").Toolkit
local process = require("@lune/process")

local function buildExecutable()
    Toolkit.generateVersion({
        VersionFile = "VERSION",
        OutputPath = "Source/LuauprojectCli/LuauprojectCommand/__VERSION__.luau",
    })

    Toolkit.build({
        Name = "luauproject",
        EntryPoint = "Source/LuauprojectCli",
        Target = process.args[1],
    })
end

buildExecutable()

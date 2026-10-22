#!/usr/bin/env -S lune run

--[[

BuildExecutable

Compiles the luauproject CLI to a standalone executable. The target defaults to the host
platform and the output directory defaults to Build/.

[Usage] ./Scripts/BuildExecutable.luau [target] [outputDir]

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
        OutputDir = process.args[2],
        Target = process.args[1],
    })
end

buildExecutable()

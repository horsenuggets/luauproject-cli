#!/usr/bin/env -S lune run

--[[

BuildExecutable.exec

Compiles the luauproject CLI to a standalone executable. The target defaults to the host
platform and the output directory defaults to Build/.

[Usage] ./Scripts/BuildExecutable.exec.luau [target] [outputDir]

--]]

const Toolkit = require("@packages/Commandline").Toolkit
const process = require("@lune/process")

const BuildExecutable = {}

function BuildExecutable.exec()
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

BuildExecutable.exec()

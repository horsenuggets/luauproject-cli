#!/usr/bin/env -S lune run

--[[

GenerateVersion.exec

Reads the VERSION file and generates a version module for embedding at build time.

[Usage] ./Scripts/GenerateVersion.exec.luau

--]]

const Toolkit = require("@packages/Commandline").Toolkit

const GenerateVersion = {}

function GenerateVersion.exec()
    Toolkit.generateVersion({
        VersionFile = "VERSION",
        OutputPath = "Source/LuauprojectCli/LuauprojectCommand/__VERSION__.luau",
    })
end

GenerateVersion.exec()

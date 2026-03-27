#!/usr/bin/env -S lune run

--[[

GenerateVersion

Reads the VERSION file and generates a version module for embedding at build time.

[Usage] ./Scripts/GenerateVersion.luau

--]]

local Toolkit = require("@packages/Commandline").Toolkit

local function generateVersion()
    Toolkit.generateVersion({
        VersionFile = "VERSION",
        OutputPath = "Source/LuauprojectCli/luauproject.cmd/__VERSION__.luau",
    })
end

generateVersion()

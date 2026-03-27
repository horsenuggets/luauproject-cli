#!/usr/bin/env -S lune run

--[[

BuildLauncher

Compiles the luauproject launcher to a standalone executable. The launcher is a
minimal executable that delegates to the currently installed version.

[Usage] ./Scripts/BuildLauncher.luau [target]

--]]

local Toolkit = require("@packages/Commandline").Toolkit
local process = require("@lune/process")

local function buildLauncher()
    Toolkit.build({
        Name = "luauproject-launcher",
        EntryPoint = "Source/Launcher/luauproject-launcher.luau",
        Target = process.args[1],
    })
end

buildLauncher()

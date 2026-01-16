#!/usr/bin/env -S lune run

--[[

luauproject-cli

The entry point for building the luauproject CLI executable.

]]

local process = require("@lune/process")

local Commandline = require("@packages/Commandline")
local luauproject_cmd = require("./luauproject.cmd")

local function run()
    Commandline.registerCommand(luauproject_cmd)
    luauproject_cmd:Execute(process.args)
end

run()

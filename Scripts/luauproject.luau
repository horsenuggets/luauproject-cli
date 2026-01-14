#!/usr/bin/env lune

--[[
luauproject - CLI tool to scaffold new Luau projects

Usage:
  luauproject new - Create a new Luau project interactively
]]

local process = require("@lune/process")

local Commandline = require("@packages/Commandline")
local NewCommand = require("@self/Commands/NewCommand")

-- Register commands
Commandline.registerCommand(NewCommand)

-- Get command from args
local args = process.args
if #args == 0 then
	Commandline.execute("new")
else
	Commandline.execute(table.concat(args, " "))
end

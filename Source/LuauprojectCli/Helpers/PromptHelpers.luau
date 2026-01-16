--[[

PromptHelpers

Helper functions for prompting users for input via the command line.

--]]

local Chalk = require("@packages/Chalk")
local stdio = require("@lune/stdio")

local PromptHelpers = {}

function PromptHelpers.prompt(message: string, default: string?): string
    local displayMessage = message
    if default then
        displayMessage = `{message} [{Chalk.dim(default)}]`
    end

    local result = stdio.prompt("text", displayMessage)
    if result == "" and default then
        return default
    end
    return result
end

function PromptHelpers.promptConfirm(message: string, default: boolean?): boolean
    local defaultStr = if default == true then "Y/n" elseif default == false then "y/N" else "y/n"
    local result = stdio.prompt("text", `{message} ({Chalk.dim(defaultStr)})`)

    if result == "" and default ~= nil then
        return default
    end

    return result:lower() == "y" or result:lower() == "yes"
end

return PromptHelpers

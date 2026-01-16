--[[

shell

Helper functions for executing shell commands.

--]]

local Chalk = require("@packages/Chalk")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local function run(command: string, args: { string }?, cwd: string?): (boolean, string)
    local result = process.exec(command, args or {}, {
        cwd = cwd,
    })

    if result.ok then
        return true, result.stdout
    else
        return false, result.stderr
    end
end

local function runOrFail(command: string, args: { string }?, cwd: string?): string
    local ok, output = run(command, args, cwd)
    if not ok then
        stdio.ewrite(Chalk.red(`Error running command: {command}\n`))
        stdio.ewrite(`{output}\n`)
        process.exit(1)
    end
    return output
end

local function isCommandAvailable(command: string): boolean
    local result = process.exec("which", { command })
    return result.ok
end

return {
    isCommandAvailable = isCommandAvailable,
    run = run,
    runOrFail = runOrFail,
}

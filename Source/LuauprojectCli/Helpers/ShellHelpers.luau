--[[

ShellHelpers

Helper functions for executing shell commands.

--]]

const Chalk = require("@packages/Chalk")
const process = require("@lune/process")
const stdio = require("@lune/stdio")

const ShellHelpers = {}

function ShellHelpers.run(command: string, args: { string }?, cwd: string?): (boolean, string)
    const result = process.exec(command, args or {}, {
        cwd = cwd,
    })

    if result.ok then
        return true, result.stdout
    else
        return false, result.stderr
    end
end

function ShellHelpers.runOrFail(command: string, args: { string }?, cwd: string?): string
    const ok, output = ShellHelpers.run(command, args, cwd)
    if not ok then
        stdio.ewrite(Chalk.red(`Error running command: {command}\n`))
        stdio.ewrite(`{output}\n`)
        process.exit(1)
    end
    return output
end

function ShellHelpers.isCommandAvailable(command: string): boolean
    const result = process.exec("which", { command })
    return result.ok
end

return ShellHelpers

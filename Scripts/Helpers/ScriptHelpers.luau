--[[

ScriptHelpers

Shared helpers for the scripts in Scripts/. The CLI's command module requires a generated
version module that isn't checked in, so scripts that load the command generate it first.

--]]

const process = require("@lune/process")
const stdio = require("@lune/stdio")

const GENERATE_VERSION_SCRIPT = "./Scripts/GenerateVersion.exec.luau"

const ScriptHelpers = {}

--[[
    Generates the version module by running the GenerateVersion script in a subprocess, so
    its output doesn't mix with what the calling script prints. The script is launched
    through `lune run` rather than its shebang so this also works on Windows. Exits if
    generation fails.
]]
function ScriptHelpers.ensureVersionModule()
    const result = process.exec("lune", { "run", GENERATE_VERSION_SCRIPT })
    if not result.ok then
        stdio.ewrite(`Failed to generate the version module.\n{result.stdout}{result.stderr}\n`)
        process.exit(1)
    end
end

return ScriptHelpers

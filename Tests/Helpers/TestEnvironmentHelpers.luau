--[[

TestEnvironmentHelpers

Helper module for creating isolated test environments with temp directories. Provides
utilities for file operations, command execution, and git operations within a sandboxed
environment.

--]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local TestEnvironmentHelpers = {}

local function dedent(str: string): string
    local content = string.match(str, "^\n(.*)$") or str

    local minIndent = math.huge
    for line in string.gmatch(content, "[^\n]+") do
        local indent = string.match(line, "^(%s*)")
        if indent and #line > #indent then
            minIndent = math.min(minIndent, #indent)
        end
    end

    if minIndent == math.huge then
        minIndent = 0
    end

    local lines = {}
    for line in string.gmatch(content .. "\n", "([^\n]*)\n") do
        if #line > 0 then
            table.insert(lines, string.sub(line, minIndent + 1))
        else
            table.insert(lines, line)
        end
    end

    return table.concat(lines, "\n")
end

TestEnvironmentHelpers.dedent = dedent

export type ExecResult = {
    ok: boolean,
    code: number,
    stdout: string,
    stderr: string,
}

export type Environment = {
    path: string,
    cleanup: () -> (),
    writeDir: (relativePath: string) -> (),
    writeFile: (relativePath: string, content: string) -> (),
    readFile: (relativePath: string) -> string,
    fileExists: (relativePath: string) -> boolean,
    dirExists: (relativePath: string) -> boolean,
    exec: (command: string, args: { string }?) -> ExecResult,
    runScript: (scriptName: string, args: { string }?) -> ExecResult,
    runCli: (args: { string }?) -> ExecResult,
    initGit: () -> (),
    gitCommit: (message: string) -> (),
    gitTag: (tag: string) -> (),
}

function TestEnvironmentHelpers.create(): Environment
    local timestamp = tostring(os.time()) .. tostring(math.random(10000, 99999))
    local tempDir = `/tmp/luauproject-cli-test-{timestamp}`
    fs.writeDir(tempDir)

    local projectRoot = process.cwd
    local scriptsDir = `{projectRoot}/Scripts`
    local buildDir = `{projectRoot}/Build`

    if fs.isFile("rokit.toml") then
        fs.copy("rokit.toml", `{tempDir}/rokit.toml`)
    end

    local env: Environment = {
        path = tempDir,

        cleanup = function()
            if fs.isDir(tempDir) then
                process.exec("rm", { "-rf", tempDir })
            end
        end,

        writeDir = function(relativePath: string)
            fs.writeDir(`{tempDir}/{relativePath}`)
        end,

        writeFile = function(relativePath: string, content: string)
            local fullPath = `{tempDir}/{relativePath}`
            local dir = string.match(fullPath, "(.+)/[^/]+$")
            if dir and not fs.isDir(dir) then
                fs.writeDir(dir)
            end
            fs.writeFile(fullPath, content)
        end,

        readFile = function(relativePath: string): string
            return fs.readFile(`{tempDir}/{relativePath}`)
        end,

        fileExists = function(relativePath: string): boolean
            return fs.isFile(`{tempDir}/{relativePath}`)
        end,

        dirExists = function(relativePath: string): boolean
            return fs.isDir(`{tempDir}/{relativePath}`)
        end,

        exec = function(command: string, args: { string }?): ExecResult
            return process.exec(command, args or {}, { cwd = tempDir })
        end,

        runScript = function(scriptName: string, args: { string }?): ExecResult
            local scriptPath = `{scriptsDir}/{scriptName}.luau`
            local luneArgs = { "run", scriptPath }
            if args then
                for _, arg in args do
                    table.insert(luneArgs, arg)
                end
            end
            return process.exec("lune", luneArgs, { cwd = tempDir })
        end,

        runCli = function(args: { string }?): ExecResult
            local cliBinary = `{buildDir}/luauproject`
            local cliArgs = args or {}
            return process.exec(cliBinary, cliArgs, { cwd = tempDir })
        end,

        initGit = function()
            process.exec("git", { "init" }, { cwd = tempDir })
            process.exec("git", { "config", "user.email", "test@test.com" }, { cwd = tempDir })
            process.exec("git", { "config", "user.name", "Test User" }, { cwd = tempDir })
        end,

        gitCommit = function(message: string)
            process.exec("git", { "add", "-A" }, { cwd = tempDir })
            process.exec("git", { "commit", "-m", message, "--allow-empty" }, { cwd = tempDir })
        end,

        gitTag = function(tag: string)
            process.exec("git", { "tag", tag }, { cwd = tempDir })
        end,
    }

    return env
end

return TestEnvironmentHelpers

--[[

LogHelpers

Helper functions for logging project creation events to a persistent JSONL file.
Logs are stored in ~/.luauproject-cli/logs/project-creations.jsonl.

--]]

local PathHelpers = require("@self/PathHelpers")
local datetime = require("@lune/datetime")
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local LOG_DIR_NAME = "logs"
local LOG_FILE_NAME = "project-creations.jsonl"

local LogHelpers = {}

export type ProjectCreationEntry = {
    timestamp: string,
    args: { string },
    config: {
        name: string,
        description: string,
        owner: string,
        projectPath: string,
        createGithubRepo: boolean,
        isPrivate: boolean,
        isPrivatePackage: boolean,
    },
    pid: number,
    cwd: string,
    setup: {
        branchProtection: boolean?,
        wallyAuth: boolean?,
        copilotReview: boolean?,
    },
    warnings: { string },
}

function LogHelpers.getLogDir(): string
    local home = process.env.HOME or process.env.USERPROFILE or ""
    return PathHelpers.join(home, ".luauproject-cli", LOG_DIR_NAME)
end

function LogHelpers.getLogFilePath(): string
    return PathHelpers.join(LogHelpers.getLogDir(), LOG_FILE_NAME)
end

function LogHelpers.ensureLogDir()
    local logDir = LogHelpers.getLogDir()
    if not fs.isDir(logDir) then
        fs.writeDir(logDir)
    end
end

function LogHelpers.buildEntry(entry: ProjectCreationEntry): string
    local data = {
        args = entry.args,
        config = entry.config,
        cwd = entry.cwd,
        pid = entry.pid,
        setup = entry.setup,
        timestamp = entry.timestamp,
        warnings = entry.warnings,
    }
    return serde.encode("json", data)
end

function LogHelpers.appendEntry(entry: ProjectCreationEntry)
    LogHelpers.ensureLogDir()
    local logPath = LogHelpers.getLogFilePath()
    local line = LogHelpers.buildEntry(entry) .. "\n"

    local existing = ""
    if fs.isFile(logPath) then
        existing = fs.readFile(logPath)
    end
    fs.writeFile(logPath, existing .. line)
end

function LogHelpers.createTimestamp(): string
    return datetime.now():formatUniversalTime("%Y-%m-%dT%H:%M:%SZ")
end

return LogHelpers

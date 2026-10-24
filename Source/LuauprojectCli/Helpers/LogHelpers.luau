--[[

LogHelpers

Helper functions for logging project creation events to a persistent JSONL
file. Logs are stored in ~/.luauproject-cli/logs/project-creations.jsonl.

--]]

const PathHelpers = require("@self/PathHelpers")
const datetime = require("@lune/datetime")
const fs = require("@lune/fs")
const process = require("@lune/process")
const serde = require("@lune/serde")

const LOG_DIR_NAME = "logs"
const LOG_FILE_NAME = "project-creations.jsonl"

const LogHelpers = {}

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
    cwd: string,
    setup: {
        branchProtection: boolean?,
        wallyAuth: boolean?,
        copilotReview: boolean?,
    },
    warnings: { string },
}

function LogHelpers.getLogDir(): string
    const home = process.env.HOME or process.env.USERPROFILE or ""
    return PathHelpers.join(home, ".luauproject-cli", LOG_DIR_NAME)
end

function LogHelpers.getLogFilePath(): string
    return PathHelpers.join(LogHelpers.getLogDir(), LOG_FILE_NAME)
end

function LogHelpers.ensureLogDir()
    const logDir = LogHelpers.getLogDir()
    if not fs.isDir(logDir) then
        fs.writeDir(logDir)
    end
end

function LogHelpers.buildEntry(entry: ProjectCreationEntry): string
    const data = {
        args = entry.args,
        config = entry.config,
        cwd = entry.cwd,
        setup = entry.setup,
        timestamp = entry.timestamp,
        warnings = entry.warnings,
    }
    return serde.encode("json", data)
end

function LogHelpers.appendEntry(entry: ProjectCreationEntry)
    LogHelpers.ensureLogDir()
    const logPath = LogHelpers.getLogFilePath()
    const line = LogHelpers.buildEntry(entry) .. "\n"

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

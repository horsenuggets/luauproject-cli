--[[

luauproject-launcher

A thin launcher that delegates to the currently installed version of luauproject. On startup,
it reads the current version from ~/.luauproject-cli/current and spawns the corresponding
executable from the versions directory. It also cleans up old versions that are no longer
in use.

--]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------

local IS_WINDOWS = process.os == "windows"
local HOME_DIR = if IS_WINDOWS then process.env.USERPROFILE else process.env.HOME
local INSTALL_DIR = `{HOME_DIR}/.luauproject-cli`
local VERSIONS_DIR = `{INSTALL_DIR}/versions`
local CURRENT_FILE = `{INSTALL_DIR}/current`
local EXECUTABLE_SUFFIX = if IS_WINDOWS then ".exe" else ""

------------------------------------------------------------------------------------------
-- Path Normalization
------------------------------------------------------------------------------------------

local function normalizePath(path: string): string
    if IS_WINDOWS then
        local normalized = path:gsub("/", "\\")
        -- Preserve UNC paths
        local prefix = ""
        if normalized:sub(1, 2) == "\\\\" then
            prefix = "\\\\"
            normalized = normalized:sub(3)
        end
        return prefix .. normalized:gsub("\\\\+", "\\")
    else
        return path:gsub("//+", "/")
    end
end

------------------------------------------------------------------------------------------
-- Error Handling
------------------------------------------------------------------------------------------

local function printError(message: string)
    stdio.ewrite(`luauproject: {message}\n`)
end

local function exitWithError(message: string): never
    printError(message)
    process.exit(1)
end

------------------------------------------------------------------------------------------
-- Version Management
------------------------------------------------------------------------------------------

local function getCurrentVersion(): string?
    local currentFile = normalizePath(CURRENT_FILE)
    if not fs.isFile(currentFile) then
        return nil
    end

    local content = fs.readFile(currentFile)
    return content:match("^%s*(.-)%s*$")
end

local function cleanupOldVersions(currentVersion: string)
    local versionsDir = normalizePath(VERSIONS_DIR)
    if not fs.isDir(versionsDir) then
        return
    end

    local expectedPrefix = "luauproject-"
    local currentExecutable = `{expectedPrefix}{currentVersion}{EXECUTABLE_SUFFIX}`

    for _, entry in fs.readDir(versionsDir) do
        -- Only clean up luauproject executables, not other files
        if entry:sub(1, #expectedPrefix) == expectedPrefix and entry ~= currentExecutable then
            local filePath = normalizePath(`{versionsDir}/{entry}`)
            local success = pcall(function()
                fs.removeFile(filePath)
            end)
            if success then
                -- Silently removed old version
            end
        end
    end
end

------------------------------------------------------------------------------------------
-- Main
------------------------------------------------------------------------------------------

local function main()
    -- Get current version
    local currentVersion = getCurrentVersion()
    if not currentVersion or currentVersion == "" then
        exitWithError("No version installed. Run the installer to set up luauproject.")
    end

    -- Build path to current executable
    local executablePath = normalizePath(`{VERSIONS_DIR}/luauproject-{currentVersion}{EXECUTABLE_SUFFIX}`)

    -- Check if executable exists
    if not fs.isFile(executablePath) then
        exitWithError(`Version {currentVersion} not found. Run "luauproject update" to reinstall.`)
    end

    -- Clean up old versions before spawning (they won't be in use)
    cleanupOldVersions(currentVersion)

    -- Execute the current version with all arguments, forwarding all stdio
    local result = process.exec(executablePath, process.args, {
        stdio = "forward",
    })

    -- Exit with the same code as the executed process
    process.exit(result.code)
end

main()

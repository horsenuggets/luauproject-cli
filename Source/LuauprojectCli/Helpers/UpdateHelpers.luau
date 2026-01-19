--[[

UpdateHelpers

Helper functions for the update command. Handles GitHub API interactions, version comparison,
and binary downloads.

--]]

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

local PathHelpers = require("@luauprojectcli/Helpers/PathHelpers")

------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------

local REPOSITORY = "horsenuggets/luauproject-cli"
local API_BASE = "https://api.github.com/repos"
local IS_WINDOWS = process.os == "windows"

------------------------------------------------------------------------------------------
-- Types
------------------------------------------------------------------------------------------

export type Asset = {
    name: string,
    browser_download_url: string,
}

export type Release = {
    tag_name: string,
    assets: { Asset },
}

------------------------------------------------------------------------------------------
-- Module
------------------------------------------------------------------------------------------

local UpdateHelpers = {}

--[[
	Returns the binary name for the current platform.
	Example: "luauproject-macos-aarch64" or "luauproject-linux-x86_64"
]]
function UpdateHelpers.getBinaryName(): string
    local os = process.os
    if os == "macos" or os == "darwin" then
        os = "macos"
    end

    local arch = process.arch
    if arch == "arm64" then
        arch = "aarch64"
    end

    return `luauproject-{os}-{arch}`
end

--[[
	Fetches the latest release from GitHub.
	Returns the release data or nil if the request failed.
]]
function UpdateHelpers.getLatestRelease(): Release?
    local url = `{API_BASE}/{REPOSITORY}/releases/latest`

    local response = net.request({
        url = url,
        headers = {
            ["Accept"] = "application/vnd.github.v3+json",
            ["User-Agent"] = "luauproject-cli",
        },
    })

    if not response.ok then
        return nil
    end

    local success, data = pcall(function()
        return serde.decode("json", response.body)
    end)

    if not success then
        return nil
    end

    return data :: Release
end

--[[
	Fetches a specific release by version tag from GitHub.
	Returns the release data or nil if the request failed.
]]
function UpdateHelpers.getRelease(version: string): Release?
    assert(type(version) == "string", "version must be a string")

    local url = `{API_BASE}/{REPOSITORY}/releases/tags/{version}`

    local response = net.request({
        url = url,
        headers = {
            ["Accept"] = "application/vnd.github.v3+json",
            ["User-Agent"] = "luauproject-cli",
        },
    })

    if not response.ok then
        return nil
    end

    local success, data = pcall(function()
        return serde.decode("json", response.body)
    end)

    if not success then
        return nil
    end

    return data :: Release
end

--[[
	Finds the download URL for the current platform's binary in a release.
	Returns the URL or nil if not found.
]]
function UpdateHelpers.findBinaryUrl(release: Release): string?
    assert(type(release) == "table", "release must be a table")

    local binaryName = UpdateHelpers.getBinaryName()

    for _, asset in release.assets do
        if asset.name == binaryName then
            return asset.browser_download_url
        end
    end

    return nil
end

--[[
	Downloads a file from a URL to a destination path.
	Returns true if successful, false otherwise.
]]
function UpdateHelpers.downloadFile(url: string, destPath: string): boolean
    assert(type(url) == "string", "url must be a string")
    assert(type(destPath) == "string", "destPath must be a string")

    local response = net.request({
        url = url,
        headers = {
            ["User-Agent"] = "luauproject-cli",
        },
    })

    if not response.ok then
        return false
    end

    -- Ensure parent directory exists
    local parentDir = destPath:match("(.+)[/\\][^/\\]+$")
    if parentDir and not fs.isDir(parentDir) then
        fs.writeDir(parentDir)
    end

    fs.writeFile(destPath, response.body)

    -- Make executable on Unix systems
    if not IS_WINDOWS then
        process.exec("chmod", { "+x", destPath })
    end

    return true
end

--[[
	Parses a semantic version string into its components.
	Returns major, minor, patch as numbers, or nil for all if invalid.
]]
function UpdateHelpers.parseVersion(versionString: string): (number?, number?, number?)
    assert(type(versionString) == "string", "versionString must be a string")

    -- Trim whitespace
    local trimmed = versionString:match("^%s*(.-)%s*$") or ""

    -- Parse MAJOR.MINOR.PATCH format
    local major, minor, patch = trimmed:match("^(%d+)%.(%d+)%.(%d+)$")

    if not major or not minor or not patch then
        return nil, nil, nil
    end

    return tonumber(major), tonumber(minor), tonumber(patch)
end

--[[
	Compares two version strings.
	Returns:
	  1 if version1 > version2
	  0 if version1 == version2
	  -1 if version1 < version2
	  nil if either version is invalid
]]
function UpdateHelpers.compareVersions(version1: string, version2: string): number?
    assert(type(version1) == "string", "version1 must be a string")
    assert(type(version2) == "string", "version2 must be a string")

    local major1, minor1, patch1 = UpdateHelpers.parseVersion(version1)
    local major2, minor2, patch2 = UpdateHelpers.parseVersion(version2)

    if not major1 or not major2 then
        return nil
    end

    if major1 ~= major2 then
        return if major1 > major2 then 1 else -1
    end

    if minor1 ~= minor2 then
        return if minor1 > minor2 then 1 else -1
    end

    if patch1 ~= patch2 then
        return if patch1 > patch2 then 1 else -1
    end

    return 0
end

--[[
	Returns the installation directory paths.
]]
function UpdateHelpers.getInstallPaths(): {
    installDir: string,
    binDir: string,
    versionsDir: string,
    currentFile: string,
}
    local homeDir = if IS_WINDOWS then process.env.USERPROFILE else process.env.HOME
    local installDir = PathHelpers.normalize(`{homeDir}/.luauproject-cli`)

    return {
        installDir = installDir,
        binDir = PathHelpers.normalize(`{installDir}/bin`),
        versionsDir = PathHelpers.normalize(`{installDir}/versions`),
        currentFile = PathHelpers.normalize(`{installDir}/current`),
    }
end

--[[
	Reads the currently installed version from the current file.
	Returns the version string or nil if not found.
]]
function UpdateHelpers.getCurrentVersion(): string?
    local paths = UpdateHelpers.getInstallPaths()

    if not fs.isFile(paths.currentFile) then
        return nil
    end

    local content = fs.readFile(paths.currentFile)
    return content:match("^%s*(.-)%s*$")
end

return UpdateHelpers

--[[

update.cmd

Updates the luauproject CLI to the latest version or a specified version. Downloads the new
version to the versions directory and updates the current version pointer.

--]]

local Chalk = require("@packages/Chalk")
local Command = require("@packages/Commandline").Command
local Flag = require("@packages/Commandline").Flag
local UpdateHelpers = require("@luauprojectcli/Helpers/UpdateHelpers")
local __VERSION__ = require("@luauprojectcli/luauproject.cmd/__VERSION__")
local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------

local IS_WINDOWS = process.os == "windows"

------------------------------------------------------------------------------------------
-- Helper Functions
------------------------------------------------------------------------------------------

local function ensureDirectory(path: string)
    if not fs.isDir(path) then
        fs.writeDir(path)
    end
end

------------------------------------------------------------------------------------------
-- Print Functions
------------------------------------------------------------------------------------------

local function printHeader()
    print("Checking for updates...\n")
end

local function printFetchingRelease(version: string?)
    if version then
        print(`Looking for version {Chalk.dim(version)}...`)
    else
        print("Fetching latest release...")
    end
end

local function printReleaseNotFound(version: string?)
    if version then
        stdio.ewrite(Chalk.red(`Release version "{version}" was not found.\n`))
    else
        stdio.ewrite(Chalk.red("Failed to fetch the latest release.\n"))
    end
    stdio.ewrite(Chalk.dim("Check your network connection and try again.\n"))
end

local function printBinaryNotFound()
    local binaryName = UpdateHelpers.getBinaryName()
    stdio.ewrite(Chalk.red(`Binary "{binaryName}" was not found in the release.\n`))
    stdio.ewrite(Chalk.dim("This platform may not be supported.\n"))
end

local function printAlreadyUpToDate(version: string)
    print(Chalk.greenBright(`Already up to date at version {version}.`))
end

local function printDownloading(version: string)
    print(`Downloading version {Chalk.bold(Chalk.blueBright(version))}...`)
end

local function printDownloadFailed()
    stdio.ewrite(Chalk.red("Failed to download the binary.\n"))
    stdio.ewrite(Chalk.dim("Check your network connection and try again.\n"))
end

local function printSuccess(oldVersion: string?, newVersion: string)
    print()
    print(Chalk.bold(Chalk.greenBright("Update complete!")))
    print()
    if oldVersion then
        print(`Updated from {Chalk.dim(oldVersion)} to {Chalk.bold(newVersion)}.`)
    else
        print(`Installed version {Chalk.bold(newVersion)}.`)
    end
    print(Chalk.dim("The new version will be used on next run."))
end

------------------------------------------------------------------------------------------
-- Main Update Logic
------------------------------------------------------------------------------------------

local function update(targetVersion: string?)
    printHeader()

    -- Fetch release info
    printFetchingRelease(targetVersion)
    local release = if targetVersion then UpdateHelpers.getRelease(targetVersion) else UpdateHelpers.getLatestRelease()

    if not release then
        printReleaseNotFound(targetVersion)
        process.exit(1)
    end

    local newVersion = release.tag_name
    print(`Found version {Chalk.dim(newVersion)}.`)

    -- Check if already at this version
    local currentVersion = UpdateHelpers.getCurrentVersion() or __VERSION__
    if not targetVersion then
        local comparison = UpdateHelpers.compareVersions(newVersion, currentVersion)
        if comparison == 0 then
            printAlreadyUpToDate(currentVersion)
            return
        elseif comparison == -1 then
            print(Chalk.yellow(`Installed version {currentVersion} is newer than latest release {newVersion}.`))
            print(Chalk.dim("Use --version to install a specific version."))
            return
        end
    end

    -- Find download URL
    local downloadUrl = UpdateHelpers.findBinaryUrl(release)
    if not downloadUrl then
        printBinaryNotFound()
        process.exit(1)
    end

    -- Set up paths
    local paths = UpdateHelpers.getInstallPaths()
    ensureDirectory(paths.installDir)
    ensureDirectory(paths.versionsDir)

    local executableSuffix = if IS_WINDOWS then ".exe" else ""
    local versionedExecutable = `{paths.versionsDir}/luauproject-{newVersion}{executableSuffix}`

    -- Download new version
    printDownloading(newVersion)
    local success = UpdateHelpers.downloadFile(downloadUrl, versionedExecutable)
    if not success then
        printDownloadFailed()
        process.exit(1)
    end

    -- Update current version pointer
    fs.writeFile(paths.currentFile, newVersion)

    printSuccess(currentVersion, newVersion)
end

------------------------------------------------------------------------------------------
-- Command Definition
------------------------------------------------------------------------------------------

return Command.new({
    Name = "update",
    Description = "Update luauproject CLI to the latest version.",
    Flags = {
        Flag.new({
            Name = "version",
            Shorthand = "v",
            Description = "Install a specific version instead of the latest.",
            Type = "string",
        }),
    },
    Impl = function(_args, flags)
        local targetVersion = flags.version :: string?
        update(targetVersion)
    end,
})

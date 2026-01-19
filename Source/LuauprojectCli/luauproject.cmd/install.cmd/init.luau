--[[

install.cmd

Installs the luauproject CLI by setting up the versioned directory structure. Copies the
executable to ~/.luauproject-cli/versions, downloads the launcher to bin, sets up the current
version pointer, and adds bin to the user's PATH.

--]]

local Chalk = require("@packages/Chalk")
local Command = require("@packages/Commandline").Command
local PathHelpers = require("@luauprojectcli/Helpers/PathHelpers")
local UpdateHelpers = require("@luauprojectcli/Helpers/UpdateHelpers")
local __VERSION__ = require("@luauprojectcli/luauproject.cmd/__VERSION__")
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------

local IS_WINDOWS = process.os == "windows"
local HOME_DIR = if IS_WINDOWS then process.env.USERPROFILE else process.env.HOME
local INSTALL_DIR = PathHelpers.normalize(`{HOME_DIR}/.luauproject-cli`)
local BIN_DIR = PathHelpers.normalize(`{INSTALL_DIR}/bin`)
local VERSIONS_DIR = PathHelpers.normalize(`{INSTALL_DIR}/versions`)
local CURRENT_FILE = PathHelpers.normalize(`{INSTALL_DIR}/current`)
local EXECUTABLE_NAME = if IS_WINDOWS then "luauproject.exe" else "luauproject"
local EXECUTABLE_SUFFIX = if IS_WINDOWS then ".exe" else ""
local PATH_EXPORT_COMMENT = "# Added by luauproject-cli"
local PATH_EXPORT_LINE = `export PATH="{BIN_DIR}:$PATH"`
local REPOSITORY = "horsenuggets/luauproject-cli"
local SHELL_CONFIGS = {
    { file = ".bash_profile", shell = "bash" },
    { file = ".bashrc", shell = "bash" },
    { file = ".zshrc", shell = "zsh" },
}
local XSH_DIR = PathHelpers.normalize(`{HOME_DIR}/.xsh`)
local XSH_PATH_FILE = PathHelpers.normalize(`{HOME_DIR}/.path`)

------------------------------------------------------------------------------------------
-- Helper Functions
------------------------------------------------------------------------------------------

local function getExecutablePath(): string?
    return executable
end

local function ensureDirectory(path: string)
    if not fs.isDir(path) then
        fs.writeDir(path)
    end
end

local function copyExecutable(sourcePath: string, destPath: string)
    local contents = fs.readFile(sourcePath)
    fs.writeFile(destPath, contents)

    -- Make executable on Unix systems
    if not IS_WINDOWS then
        process.exec("chmod", { "+x", destPath })
    end
end

------------------------------------------------------------------------------------------
-- Launcher Download Functions
------------------------------------------------------------------------------------------

local function getLauncherBinaryName(): string
    local os = process.os
    if os == "macos" or os == "darwin" then
        os = "macos"
    end

    local arch = process.arch
    if arch == "arm64" then
        arch = "aarch64"
    end

    return `luauproject-launcher-{os}-{arch}`
end

local function downloadLauncher(destPath: string): boolean
    print("Downloading launcher...")

    -- Fetch latest release to get the launcher URL
    local release = UpdateHelpers.getLatestRelease()
    if not release then
        return false
    end

    local launcherName = getLauncherBinaryName()

    -- Find the launcher asset
    local downloadUrl: string? = nil
    for _, asset in release.assets do
        if asset.name == launcherName then
            downloadUrl = asset.browser_download_url
            break
        end
    end

    if not downloadUrl then
        return false
    end

    -- Download the launcher
    return UpdateHelpers.downloadFile(downloadUrl, destPath)
end

------------------------------------------------------------------------------------------
-- Windows PATH Functions
------------------------------------------------------------------------------------------

local function getWindowsUserPath(): string?
    -- Query the user's PATH from the registry
    local result = process.exec("reg", {
        "query",
        "HKCU\\Environment",
        "/v",
        "Path",
    })

    if not result.ok then
        return nil
    end

    -- Parse the output to extract the PATH value
    -- Format: "    Path    REG_SZ    <value>" or "    Path    REG_EXPAND_SZ    <value>"
    local pathValue = result.stdout:match("Path%s+REG_[A-Z_]+%s+(.+)")
    if pathValue then
        return pathValue:gsub("%s+$", "") -- Trim trailing whitespace
    end

    return nil
end

local function isInWindowsPath(): boolean
    local userPath = getWindowsUserPath()
    if not userPath then
        return false
    end

    -- Check if BIN_DIR is already in the path (case-insensitive on Windows)
    local binDirLower = BIN_DIR:lower()
    for pathEntry in userPath:gmatch("[^;]+") do
        if pathEntry:lower() == binDirLower then
            return true
        end
    end

    return false
end

local function addPathToWindows(): boolean
    local currentPath = getWindowsUserPath() or ""

    -- Build new path with BIN_DIR appended
    local newPath: string
    if currentPath == "" then
        newPath = BIN_DIR
    else
        newPath = `{currentPath};{BIN_DIR}`
    end

    -- Use setx to set the user PATH (persists across sessions)
    local result = process.exec("setx", { "PATH", newPath })

    return result.ok
end

------------------------------------------------------------------------------------------
-- Unix PATH Functions
------------------------------------------------------------------------------------------

local function getShellConfigPath(configFile: string): string
    return PathHelpers.normalize(`{HOME_DIR}/{configFile}`)
end

local function configHasPathExport(configPath: string): boolean
    if not fs.isFile(configPath) then
        return false
    end

    local content = fs.readFile(configPath)
    return content:find(BIN_DIR, 1, true) ~= nil
end

local function addPathToConfig(configPath: string): boolean
    local content = ""
    if fs.isFile(configPath) then
        content = fs.readFile(configPath)
    end

    -- Add newline if file doesn't end with one
    if content ~= "" and not content:match("\n$") then
        content = content .. "\n"
    end

    -- Add blank line before our addition if there's existing content
    if content ~= "" then
        content = content .. "\n"
    end

    content = content .. PATH_EXPORT_COMMENT .. "\n" .. PATH_EXPORT_LINE .. "\n"
    fs.writeFile(configPath, content)
    return true
end

local function findAndUpdateShellConfig(): string?
    -- Find the first existing shell config file
    for _, config in SHELL_CONFIGS do
        local configPath = getShellConfigPath(config.file)
        if fs.isFile(configPath) then
            if configHasPathExport(configPath) then
                return nil -- Already configured
            end
            addPathToConfig(configPath)
            return config.file
        end
    end

    -- No existing config found, create .zshrc (default on macOS) or .bashrc
    local defaultConfig = if process.os == "macos" then ".zshrc" else ".bashrc"
    local configPath = getShellConfigPath(defaultConfig)
    addPathToConfig(configPath)
    return defaultConfig
end

local function hasXsh(): boolean
    return fs.isDir(XSH_DIR)
end

local function xshPathFileHasBinDir(): boolean
    if not fs.isFile(XSH_PATH_FILE) then
        return false
    end
    local content = fs.readFile(XSH_PATH_FILE)
    return content:find(BIN_DIR, 1, true) ~= nil
end

local function addPathToXsh(): boolean
    local content = ""
    if fs.isFile(XSH_PATH_FILE) then
        content = fs.readFile(XSH_PATH_FILE)
    end

    -- Add newline if file doesn't end with one
    if content ~= "" and not content:match("\n$") then
        content = content .. "\n"
    end

    content = content .. BIN_DIR .. "\n"
    fs.writeFile(XSH_PATH_FILE, content)
    return true
end

------------------------------------------------------------------------------------------
-- Cross-platform PATH Functions
------------------------------------------------------------------------------------------

local function isInPath(): boolean
    if IS_WINDOWS then
        return isInWindowsPath()
    end

    local pathEnv = process.env.PATH or ""
    return pathEnv:find(BIN_DIR, 1, true) ~= nil
end

------------------------------------------------------------------------------------------
-- Print Functions
------------------------------------------------------------------------------------------

local function printHeader()
    print("Installing luauproject CLI...\n")
end

local function printNotStandalone()
    stdio.ewrite(Chalk.red("This command can only be run from a standalone executable.\n"))
    stdio.ewrite(Chalk.dim("The `executable` global is nil, which means you're running this as a Lune script.\n"))
    stdio.ewrite(Chalk.dim("Build the project first with `lune build` and run the resulting executable.\n"))
end

local function printLauncherDownloadFailed()
    stdio.ewrite(Chalk.yellow("Warning: Failed to download the launcher.\n"))
    stdio.ewrite(Chalk.dim("You may need to run the install script again or download manually.\n"))
end

local function printSuccess(updatedConfig: string?, usedXsh: boolean?, usedWindows: boolean?)
    local launcherPath = PathHelpers.normalize(`{BIN_DIR}/{EXECUTABLE_NAME}`)

    print()
    print(Chalk.bold(Chalk.greenBright("Installation complete!")))
    print()
    print(`Installed version {Chalk.bold(__VERSION__)}.`)
    print(`Launcher at {Chalk.dim(launcherPath)}.`)

    if usedWindows then
        print()
        print(`Added {Chalk.dim(BIN_DIR)} to your user PATH.`)
        print(Chalk.yellow("Restart your terminal to use luauproject."))
    elseif usedXsh then
        print()
        print(`Added {Chalk.dim(BIN_DIR)} to PATH in {Chalk.dim(XSH_PATH_FILE)}.`)
        print(Chalk.yellow("Restart your terminal to use luauproject."))
    elseif updatedConfig then
        local configPath = PathHelpers.normalize(`{HOME_DIR}/{updatedConfig}`)
        print()
        print(`Added {Chalk.dim(BIN_DIR)} to PATH in {Chalk.dim(configPath)}.`)
        print(Chalk.yellow("Restart your terminal or run the following to use luauproject:"))
        print(Chalk.dim(`  source ~/{updatedConfig}`))
    elseif isInPath() then
        print()
        print(Chalk.dim("PATH already configured. You can use `luauproject` immediately."))
    end
end

------------------------------------------------------------------------------------------
-- Main Installation Logic
------------------------------------------------------------------------------------------

local function install()
    printHeader()

    -- Check if running as standalone executable
    local execPath = getExecutablePath()
    if not execPath then
        printNotStandalone()
        process.exit(1)
    end

    -- Create installation directories
    print("Creating installation directories...")
    ensureDirectory(INSTALL_DIR)
    ensureDirectory(BIN_DIR)
    ensureDirectory(VERSIONS_DIR)

    -- Copy executable to versions directory
    local versionedPath = PathHelpers.normalize(`{VERSIONS_DIR}/luauproject-{__VERSION__}{EXECUTABLE_SUFFIX}`)
    print(`Copying executable to {Chalk.dim(versionedPath)}...`)
    copyExecutable(execPath, versionedPath)

    -- Create/update current version pointer
    print("Setting current version...")
    fs.writeFile(CURRENT_FILE, __VERSION__)

    -- Download launcher to bin directory
    local launcherPath = PathHelpers.normalize(`{BIN_DIR}/{EXECUTABLE_NAME}`)
    local launcherExists = fs.isFile(launcherPath)

    if not launcherExists then
        local launcherDownloaded = downloadLauncher(launcherPath)
        if not launcherDownloaded then
            printLauncherDownloadFailed()
        end
    else
        print(Chalk.dim("Launcher already installed."))
    end

    -- Update PATH based on platform
    print("Configuring PATH...")
    local updatedConfig: string? = nil
    local usedXsh = false
    local usedWindows = false

    if IS_WINDOWS then
        if not isInWindowsPath() then
            addPathToWindows()
            usedWindows = true
        end
    elseif hasXsh() then
        if not xshPathFileHasBinDir() then
            addPathToXsh()
            usedXsh = true
        end
    else
        updatedConfig = findAndUpdateShellConfig()
    end

    printSuccess(updatedConfig, usedXsh, usedWindows)
end

------------------------------------------------------------------------------------------
-- Command Definition
------------------------------------------------------------------------------------------

return Command.new({
    Name = "install",
    Description = "Install luauproject CLI to ~/.luauproject-cli and add to PATH.",
    Impl = function()
        install()
    end,
})

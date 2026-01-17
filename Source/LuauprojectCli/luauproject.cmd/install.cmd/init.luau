--[[

install.cmd

Installs the luauproject CLI by copying the executable to ~/.luauproject-cli/bin and adding
it to the user's PATH.

]]

local Chalk = require("@packages/Chalk")
local Command = require("@packages/Commandline").Command
local PathHelpers = require("@luauprojectcli/Helpers/PathHelpers")
local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------

local IS_WINDOWS = process.os == "windows"
local HOME_DIR = if IS_WINDOWS then process.env.USERPROFILE else process.env.HOME
local INSTALL_DIR = PathHelpers.normalize(`{HOME_DIR}/.luauproject-cli`)
local BIN_DIR = PathHelpers.normalize(`{INSTALL_DIR}/bin`)
local EXECUTABLE_NAME = if IS_WINDOWS then "luauproject.exe" else "luauproject"
local PATH_EXPORT_COMMENT = "# Added by luauproject-cli"
local PATH_EXPORT_LINE = `export PATH="{BIN_DIR}:$PATH"`
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

local function printSuccess(updatedConfig: string?, usedXsh: boolean?, usedWindows: boolean?)
    local installedPath = PathHelpers.normalize(`{BIN_DIR}/{EXECUTABLE_NAME}`)

    print()
    print(Chalk.bold(Chalk.greenBright("Installation complete!")))
    print()
    print(`Installed to {Chalk.dim(installedPath)}.`)

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

local function printAlreadyInstalled()
    local installedPath = PathHelpers.normalize(`{BIN_DIR}/{EXECUTABLE_NAME}`)
    print(Chalk.yellow("luauproject is already installed and PATH is configured."))
    print(Chalk.dim(`Location: {installedPath}`))
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

    local destPath = PathHelpers.normalize(`{BIN_DIR}/{EXECUTABLE_NAME}`)

    -- Create installation directory
    print("Creating installation directory...")
    ensureDirectory(INSTALL_DIR)
    ensureDirectory(BIN_DIR)

    -- Copy executable
    print(`Copying executable to {Chalk.dim(destPath)}...`)
    copyExecutable(execPath, destPath)

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
    Description = "Install luauproject CLI to ~/.luauproject-cli/bin and add to PATH.",
    Impl = function()
        install()
    end,
})

--[[

TerraformHelpers

Helper functions for managing Terraform installation and applying
branch protection rules via the luau-cicd Terraform configuration.

--]]

local Chalk = require("@packages/Chalk")
local PathHelpers = require("@luauprojectcli/Helpers/PathHelpers")
local PromptHelpers = require("@luauprojectcli/Helpers/PromptHelpers")
local ShellHelpers = require("@luauprojectcli/Helpers/ShellHelpers")
local UpdateHelpers = require("@luauprojectcli/Helpers/UpdateHelpers")
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------

local TERRAFORM_VERSION = "1.14.8"
local DOWNLOAD_BASE_URL = `https://releases.hashicorp.com/terraform/{TERRAFORM_VERSION}`
local IS_WINDOWS = process.os == "windows"
local CONFIG_FILE_NAME = "config.toml"
local BINARY_NAME = if IS_WINDOWS then "terraform.exe" else "terraform"

-- Map owner names to their Terraform .tf filenames and provider aliases.
-- Owners not in this table are unsupported.
local OWNER_CONFIG: { [string]: { file: string, provider: string? } } = {
    horsenuggets = { file = "HorseNuggets.tf", provider = nil },
    jedfgames = { file = "JedfGames.tf", provider = "github.jedfgames" },
}

------------------------------------------------------------------------------------------
-- Module
------------------------------------------------------------------------------------------

local TerraformHelpers = {}

--[[
    Returns the Terraform download platform string for the
    current OS and architecture.
]]
function TerraformHelpers.getPlatformString(): string
    local os = process.os
    local arch = process.arch

    local osMap: { [string]: string } = {
        macos = "darwin",
        linux = "linux",
        windows = "windows",
    }

    local archMap: { [string]: string } = {
        x86_64 = "amd64",
        arm64 = "arm64",
        aarch64 = "arm64",
    }

    local tfOs = osMap[os]
    local tfArch = archMap[arch]

    if not tfOs or not tfArch then
        stdio.ewrite(Chalk.red(`Unsupported platform "{os}-{arch}" for Terraform.\n`))
        process.exit(1)
    end

    return `{tfOs}_{tfArch}`
end

--[[
    Returns the path to the Terraform binary in the
    luauproject-cli bin directory.
]]
function TerraformHelpers.getInstallPath(): string
    local paths = UpdateHelpers.getInstallPaths()
    return PathHelpers.normalize(`{paths.binDir}/{BINARY_NAME}`)
end

--[[
    Returns the path to the luauproject-cli config file.
]]
function TerraformHelpers.getConfigPath(): string
    local paths = UpdateHelpers.getInstallPaths()
    return PathHelpers.normalize(`{paths.installDir}/{CONFIG_FILE_NAME}`)
end

--[[
    Checks the installed version of Terraform at the given path.
    Returns the version string or nil if not found or not
    parseable.
]]
function TerraformHelpers.getInstalledVersion(binaryPath: string): string?
    local result = process.exec(binaryPath, { "--version" })
    if not result.ok then
        return nil
    end

    -- Output format: "Terraform v1.14.8\non ..."
    local version = result.stdout:match("Terraform v([%d%.]+)")
    return version
end

--[[
    Downloads and installs Terraform to the luauproject-cli bin
    directory.
]]
function TerraformHelpers.install(): boolean
    local platform = TerraformHelpers.getPlatformString()
    local zipName = `terraform_{TERRAFORM_VERSION}_{platform}.zip`
    local url = `{DOWNLOAD_BASE_URL}/{zipName}`

    print(`Downloading Terraform {TERRAFORM_VERSION}...`)

    local response = net.request({
        url = url,
        headers = {
            ["User-Agent"] = "luauproject-cli",
        },
    })

    if not response.ok then
        print(Chalk.red(`Failed to download Terraform (HTTP {response.statusCode}).`))
        return false
    end

    local installPath = TerraformHelpers.getInstallPath()
    local installDir = installPath:match("(.+)[/\\][^/\\]+$")

    -- Ensure install directory exists
    if installDir and not fs.isDir(installDir) then
        fs.writeDir(installDir)
    end

    -- Write zip to temp location and extract
    local tempDir = if IS_WINDOWS
        then PathHelpers.normalize(`{process.env.TEMP or "/tmp"}/terraform-install`)
        else "/tmp/terraform-install"

    if fs.isDir(tempDir) then
        fs.removeDir(tempDir)
    end
    fs.writeDir(tempDir)

    local zipPath = `{tempDir}/{zipName}`
    fs.writeFile(zipPath, response.body)

    -- Extract the zip
    local extractOk: boolean
    if IS_WINDOWS then
        local result = process.exec("powershell", {
            "-Command",
            `Expand-Archive -Path '{zipPath}' -DestinationPath '{tempDir}' -Force`,
        })
        extractOk = result.ok
    else
        local result = process.exec("unzip", { "-o", zipPath, "-d", tempDir })
        extractOk = result.ok
    end

    if not extractOk then
        print(Chalk.red("Failed to extract Terraform archive."))
        fs.removeDir(tempDir)
        return false
    end

    -- Move binary to install path
    local extractedBinary = `{tempDir}/{BINARY_NAME}`
    if not fs.isFile(extractedBinary) then
        print(Chalk.red("Terraform binary not found in archive."))
        fs.removeDir(tempDir)
        return false
    end

    -- Remove existing binary if present
    if fs.isFile(installPath) then
        fs.removeFile(installPath)
    end

    fs.move(extractedBinary, installPath)

    -- Set executable permission on Unix
    if not IS_WINDOWS then
        process.exec("chmod", { "+x", installPath })
    end

    -- Clean up temp directory
    fs.removeDir(tempDir)

    return true
end

--[[
    Ensures Terraform is installed at the correct version.
    Prompts the user to install if not found. Exits if the user
    declines.
]]
function TerraformHelpers.ensureInstalled()
    -- Check PATH first
    if ShellHelpers.isCommandAvailable("terraform") then
        local version = TerraformHelpers.getInstalledVersion("terraform")
        if version == TERRAFORM_VERSION then
            return
        end
    end

    -- Check install path
    local installPath = TerraformHelpers.getInstallPath()
    if fs.isFile(installPath) then
        local version = TerraformHelpers.getInstalledVersion(installPath)
        if version == TERRAFORM_VERSION then
            return
        end
    end

    print(Chalk.yellow(`Terraform {TERRAFORM_VERSION} is required but not found.`))
    print()

    local shouldInstall = PromptHelpers.promptConfirm("Would you like to install it automatically?", true)
    if not shouldInstall then
        print()
        print("Please install Terraform manually and try again.")
        print(Chalk.dim(`Download from {DOWNLOAD_BASE_URL}`))
        process.exit(1)
    end

    print()
    local ok = TerraformHelpers.install()
    if not ok then
        print()
        print(Chalk.red("Failed to install Terraform."))
        process.exit(1)
    end

    print(Chalk.green(`Terraform {TERRAFORM_VERSION} installed successfully.`))
    print()
end

--[[
    Returns the path to the Terraform binary, preferring the
    system PATH version if it matches the required version.
]]
function TerraformHelpers.getBinaryPath(): string
    if ShellHelpers.isCommandAvailable("terraform") then
        local version = TerraformHelpers.getInstalledVersion("terraform")
        if version == TERRAFORM_VERSION then
            return "terraform"
        end
    end

    return TerraformHelpers.getInstallPath()
end

--[[
    Reads the luauproject-cli config file and returns the parsed
    table, or an empty table if the file does not exist.
]]
function TerraformHelpers.readConfig(): { [string]: any }
    local configPath = TerraformHelpers.getConfigPath()
    if not fs.isFile(configPath) then
        return {}
    end

    local ok, config = pcall(function()
        return serde.decode("toml", fs.readFile(configPath))
    end)

    if not ok then
        return {}
    end

    return config :: { [string]: any }
end

--[[
    Writes a key-value pair to the luauproject-cli config file.
    Creates the file if it does not exist.
]]
function TerraformHelpers.writeConfigValue(key: string, value: string)
    local config = TerraformHelpers.readConfig()
    config[key] = value

    local configPath = TerraformHelpers.getConfigPath()
    local configDir = configPath:match("(.+)[/\\][^/\\]+$")

    if configDir and not fs.isDir(configDir) then
        fs.writeDir(configDir)
    end

    fs.writeFile(configPath, serde.encode("toml", config))
end

--[[
    Discovers the path to the luau-cicd Terraform directory.
    Checks environment variable, config file, then prompts the
    user. Validates the path and offers to save it.
]]
function TerraformHelpers.getLuauCicdTerraformPath(): string
    -- Check environment variable
    local envPath = process.env.LUAU_CICD_TERRAFORM_PATH
    if envPath and envPath ~= "" then
        local normalized = PathHelpers.normalize(envPath)
        if fs.isFile(`{normalized}/Main.tf`) then
            return normalized
        end
        print(Chalk.yellow(`LUAU_CICD_TERRAFORM_PATH is set to "{envPath}" but does not contain Main.tf.`))
    end

    -- Check config file
    local config = TerraformHelpers.readConfig()
    local configPath = config.luau_cicd_terraform_path
    if type(configPath) == "string" and configPath ~= "" then
        local normalized = PathHelpers.normalize(configPath)
        if fs.isFile(`{normalized}/Main.tf`) then
            return normalized
        end
        print(Chalk.yellow(`Saved Terraform path "{configPath}" no longer valid.`))
    end

    -- Prompt the user
    print()
    print("The luau-cicd Terraform directory is needed for branch protection setup.")
    print(Chalk.dim("This is the directory containing Main.tf in your luau-cicd repo."))
    print()

    while true do
        local input = PromptHelpers.prompt("Path to luau-cicd Terraform directory")
        if input == "" then
            stdio.ewrite(Chalk.red("Path is required.\n"))
            continue
        end

        -- Expand ~ to home directory
        if input:sub(1, 1) == "~" then
            local home = if IS_WINDOWS then process.env.USERPROFILE else process.env.HOME
            input = home .. input:sub(2)
        end

        local normalized = PathHelpers.normalize(input)
        if not fs.isFile(`{normalized}/Main.tf`) then
            stdio.ewrite(Chalk.red(`Directory does not contain Main.tf. Check the path.\n`))
            continue
        end

        if not fs.isDir(`{normalized}/Modules/LuauRepo`) then
            stdio.ewrite(Chalk.red(`Directory does not contain Modules/LuauRepo/. Check the path.\n`))
            continue
        end

        -- Offer to save
        local shouldSave = PromptHelpers.promptConfirm("Save this path for future use?", true)
        if shouldSave then
            TerraformHelpers.writeConfigValue("luau_cicd_terraform_path", normalized)
            print(Chalk.dim("Path saved to config."))
        end

        return normalized
    end
end

--[[
    Returns the owner configuration for Terraform. Returns nil
    if the owner is not supported.
]]
function TerraformHelpers.getOwnerConfig(owner: string): { file: string, provider: string? }?
    return OWNER_CONFIG[owner:lower()]
end

--[[
    Generates an HCL module block for a new repository.
]]
function TerraformHelpers.generateModuleBlock(name: string, owner: string, isPrivatePackage: boolean): string
    local releaseChecksVar = if isPrivatePackage
        then "var.standard_release_checks_no_wally"
        else "var.standard_release_checks"

    local ownerConfig = TerraformHelpers.getOwnerConfig(owner)

    if ownerConfig and ownerConfig.provider then
        -- Non-default provider (e.g., jedfgames)
        return `\nmodule "{name}" \{\n`
            .. `  source = "./Modules/LuauRepo"\n`
            .. `  providers = \{\n`
            .. `    github = {ownerConfig.provider}\n`
            .. `  \}\n`
            .. `  repository     = "{name}"\n`
            .. `  main_checks    = var.standard_main_checks\n`
            .. `  release_checks = {releaseChecksVar}\n`
            .. `\}\n`
    end

    -- Default provider (horsenuggets)
    return `\nmodule "{name}" \{\n`
        .. `  source         = "./Modules/LuauRepo"\n`
        .. `  repository     = "{name}"\n`
        .. `  main_checks    = var.standard_main_checks\n`
        .. `  release_checks = {releaseChecksVar}\n`
        .. `\}\n`
end

--[[
    Extracts a GitHub token from the gh CLI for use with the
    Terraform GitHub provider.
]]
function TerraformHelpers.getGitHubToken(): string?
    local result = process.exec("gh", { "auth", "token" })
    if result.ok then
        local token = result.stdout:gsub("%s+$", "")
        if token ~= "" then
            return token
        end
    end
    return nil
end

--[[
    Applies branch protection rules for a new repository using
    Terraform. Appends a module block to the appropriate .tf
    file and runs terraform apply.

    Returns true if successful, false otherwise.
]]
function TerraformHelpers.applyBranchProtection(name: string, owner: string, isPrivatePackage: boolean): boolean
    local ownerConfig = TerraformHelpers.getOwnerConfig(owner)
    if not ownerConfig then
        print(Chalk.yellow(`Owner "{owner}" is not configured in Terraform. Skipping branch protection.`))
        return false
    end

    local terraformDir = TerraformHelpers.getLuauCicdTerraformPath()
    local tfFilePath = `{terraformDir}/{ownerConfig.file}`

    if not fs.isFile(tfFilePath) then
        print(Chalk.yellow(`Terraform file "{ownerConfig.file}" not found.`))
        return false
    end

    -- Get GitHub token for Terraform provider
    local token = TerraformHelpers.getGitHubToken()
    if not token then
        print(Chalk.yellow("Could not get GitHub token from gh CLI. Skipping Terraform."))
        return false
    end

    -- Read existing file and append module block
    local originalContent = fs.readFile(tfFilePath)
    local moduleBlock = TerraformHelpers.generateModuleBlock(name, owner, isPrivatePackage)
    fs.writeFile(tfFilePath, originalContent .. moduleBlock)

    local terraformBin = TerraformHelpers.getBinaryPath()
    local env = {
        GITHUB_TOKEN = token,
        PATH = process.env.PATH,
        HOME = process.env.HOME,
    }

    -- Run terraform init
    local initResult = process.exec(terraformBin, { "init" }, {
        cwd = terraformDir,
        env = env,
    })

    if not initResult.ok then
        print(Chalk.yellow("Terraform init failed. Rolling back."))
        if initResult.stderr ~= "" then
            print(Chalk.dim(initResult.stderr))
        end
        fs.writeFile(tfFilePath, originalContent)
        return false
    end

    -- Run terraform apply targeting only the new module
    local applyResult = process.exec(terraformBin, {
        "apply",
        "-auto-approve",
        `-target=module.{name}`,
    }, {
        cwd = terraformDir,
        env = env,
    })

    if not applyResult.ok then
        print(Chalk.yellow("Terraform apply failed. Rolling back."))
        if applyResult.stderr ~= "" then
            print(Chalk.dim(applyResult.stderr))
        end
        fs.writeFile(tfFilePath, originalContent)
        return false
    end

    return true
end

return TerraformHelpers

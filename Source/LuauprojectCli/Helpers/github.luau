--[[

github

Helper functions for interacting with the GitHub CLI.

--]]

local Chalk = require("@packages/Chalk")
local process = require("@lune/process")
local prompts = require("@self/prompts")
local shell = require("@self/shell")

local function getUsername(): string?
    local result = process.exec("gh", { "api", "user", "--jq", ".login" })
    if result.ok then
        local username = result.stdout:gsub("%s+$", "")
        if username ~= "" then
            return username
        end
    end
    return nil
end

local function getOrganizations(): { string }
    local result = process.exec("gh", { "api", "user/orgs", "--jq", ".[].login" })
    if result.ok then
        local orgs = {}
        for org in result.stdout:gmatch("[^\n]+") do
            local trimmed = org:gsub("%s+$", "")
            if trimmed ~= "" then
                table.insert(orgs, trimmed)
            end
        end
        return orgs
    end
    return {}
end

local function getAvailableOwners(): { string }
    local owners = {}

    local username = getUsername()
    if username then
        table.insert(owners, username)
    end

    local orgs = getOrganizations()
    for _, org in ipairs(orgs) do
        table.insert(owners, org)
    end

    return owners
end

local function installCli(): boolean
    print("Installing GitHub CLI...")

    local os = process.os
    if os == "macos" then
        local result = process.exec("brew", { "install", "gh" })
        return result.ok
    elseif os == "linux" then
        local hasApt = shell.isCommandAvailable("apt-get")
        if hasApt then
            local result = process.exec("sudo", { "apt-get", "install", "-y", "gh" })
            return result.ok
        end

        local hasDnf = shell.isCommandAvailable("dnf")
        if hasDnf then
            local result = process.exec("sudo", { "dnf", "install", "-y", "gh" })
            return result.ok
        end

        print(Chalk.red("Could not detect package manager. Please install gh manually."))
        print(Chalk.dim("Visit https://cli.github.com for installation instructions."))
        return false
    elseif os == "windows" then
        local hasWinget = shell.isCommandAvailable("winget")
        if hasWinget then
            local result = process.exec("winget", { "install", "--id", "GitHub.cli" })
            return result.ok
        end

        local hasChoco = shell.isCommandAvailable("choco")
        if hasChoco then
            local result = process.exec("choco", { "install", "gh", "-y" })
            return result.ok
        end

        print(Chalk.red("Could not detect package manager. Please install gh manually."))
        print(Chalk.dim("Visit https://cli.github.com for installation instructions."))
        return false
    end

    print(Chalk.red(`Unsupported operating system "{os}". Please install gh manually.`))
    print(Chalk.dim("Visit https://cli.github.com for installation instructions."))
    return false
end

local function ensureInstalled()
    if shell.isCommandAvailable("gh") then
        return
    end

    print(Chalk.yellow("GitHub CLI (gh) is not installed."))
    print()

    local shouldInstall = prompts.promptConfirm("Would you like to install it automatically?", true)
    if not shouldInstall then
        print()
        print("Please install gh manually and try again.")
        print(Chalk.dim("Visit https://cli.github.com for installation instructions."))
        process.exit(1)
    end

    print()
    local ok = installCli()
    if not ok then
        print()
        print(Chalk.red("Failed to install GitHub CLI."))
        process.exit(1)
    end

    print(Chalk.green("GitHub CLI installed successfully."))
    print()
end

return {
    ensureInstalled = ensureInstalled,
    getAvailableOwners = getAvailableOwners,
    getOrganizations = getOrganizations,
    getUsername = getUsername,
    installCli = installCli,
}

--[[

GitHubHelpers

Helper functions for interacting with the GitHub CLI.

--]]

local Chalk = require("@packages/Chalk")
local PromptHelpers = require("@self/PromptHelpers")
local ShellHelpers = require("@self/ShellHelpers")
local process = require("@lune/process")

local GitHubHelpers = {}

function GitHubHelpers.getUsername(): string?
    local result = process.exec("gh", { "api", "user", "--jq", ".login" })
    if result.ok then
        local username = result.stdout:gsub("%s+$", "")
        if username ~= "" then
            return username
        end
    end
    return nil
end

function GitHubHelpers.getOrganizations(): { string }
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

function GitHubHelpers.getAvailableOwners(): { string }
    local owners = {}

    local username = GitHubHelpers.getUsername()
    if username then
        table.insert(owners, username)
    end

    local orgs = GitHubHelpers.getOrganizations()
    for _, org in ipairs(orgs) do
        table.insert(owners, org)
    end

    return owners
end

function GitHubHelpers.installCli(): boolean
    print("Installing GitHub CLI...")

    local os = process.os
    if os == "macos" then
        local result = process.exec("brew", { "install", "gh" })
        return result.ok
    elseif os == "linux" then
        local hasApt = ShellHelpers.isCommandAvailable("apt-get")
        if hasApt then
            local result = process.exec("sudo", { "apt-get", "install", "-y", "gh" })
            return result.ok
        end

        local hasDnf = ShellHelpers.isCommandAvailable("dnf")
        if hasDnf then
            local result = process.exec("sudo", { "dnf", "install", "-y", "gh" })
            return result.ok
        end

        print(Chalk.red("Could not detect package manager. Please install gh manually."))
        print(Chalk.dim("Visit https://cli.github.com for installation instructions."))
        return false
    elseif os == "windows" then
        local hasWinget = ShellHelpers.isCommandAvailable("winget")
        if hasWinget then
            local result = process.exec("winget", { "install", "--id", "GitHub.cli" })
            return result.ok
        end

        local hasChoco = ShellHelpers.isCommandAvailable("choco")
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

function GitHubHelpers.ensureInstalled()
    if ShellHelpers.isCommandAvailable("gh") then
        return
    end

    print(Chalk.yellow("GitHub CLI (gh) is not installed."))
    print()

    local shouldInstall = PromptHelpers.promptConfirm("Would you like to install it automatically?", true)
    if not shouldInstall then
        print()
        print("Please install gh manually and try again.")
        print(Chalk.dim("Visit https://cli.github.com for installation instructions."))
        process.exit(1)
    end

    print()
    local ok = GitHubHelpers.installCli()
    if not ok then
        print()
        print(Chalk.red("Failed to install GitHub CLI."))
        process.exit(1)
    end

    print(Chalk.green("GitHub CLI installed successfully."))
    print()
end

return GitHubHelpers

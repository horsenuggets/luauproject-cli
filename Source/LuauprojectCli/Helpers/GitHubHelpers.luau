--[[

GitHubHelpers

Helper functions for interacting with the GitHub CLI.

--]]

const Chalk = require("@packages/Chalk")
const PromptHelpers = require("@self/PromptHelpers")
const ShellHelpers = require("@self/ShellHelpers")
const process = require("@lune/process")

const GitHubHelpers = {}

function GitHubHelpers.getUsername(): string?
    const result = process.exec("gh", { "api", "user", "--jq", ".login" })
    if result.ok then
        const username = result.stdout:gsub("%s+$", "")
        if username ~= "" then
            return username
        end
    end
    return nil
end

function GitHubHelpers.getOrganizations(): { string }
    const result = process.exec("gh", { "api", "user/orgs", "--jq", ".[].login" })
    if result.ok then
        const orgs = {}
        for org in result.stdout:gmatch("[^\n]+") do
            const trimmed = org:gsub("%s+$", "")
            if trimmed ~= "" then
                table.insert(orgs, trimmed)
            end
        end
        return orgs
    end
    return {}
end

function GitHubHelpers.getAvailableOwners(): { string }
    const owners = {}

    const username = GitHubHelpers.getUsername()
    if username then
        table.insert(owners, username)
    end

    const orgs = GitHubHelpers.getOrganizations()
    for _, org in ipairs(orgs) do
        table.insert(owners, org)
    end

    return owners
end

function GitHubHelpers.installCli(): boolean
    print("Installing GitHub CLI...")

    const os = process.os
    if os == "macos" then
        const result = process.exec("brew", { "install", "gh" })
        return result.ok
    elseif os == "linux" then
        const hasApt = ShellHelpers.isCommandAvailable("apt-get")
        if hasApt then
            const result = process.exec("sudo", { "apt-get", "install", "-y", "gh" })
            return result.ok
        end

        const hasDnf = ShellHelpers.isCommandAvailable("dnf")
        if hasDnf then
            const result = process.exec("sudo", { "dnf", "install", "-y", "gh" })
            return result.ok
        end

        print(Chalk.red("Could not detect package manager. Please install gh manually."))
        print(Chalk.dim("Visit https://cli.github.com for installation instructions."))
        return false
    elseif os == "windows" then
        const hasWinget = ShellHelpers.isCommandAvailable("winget")
        if hasWinget then
            const result = process.exec("winget", { "install", "--id", "GitHub.cli" })
            return result.ok
        end

        const hasChoco = ShellHelpers.isCommandAvailable("choco")
        if hasChoco then
            const result = process.exec("choco", { "install", "gh", "-y" })
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

    const shouldInstall = PromptHelpers.promptConfirm("Would you like to install it automatically?", true)
    if not shouldInstall then
        print()
        print("Please install gh manually and try again.")
        print(Chalk.dim("Visit https://cli.github.com for installation instructions."))
        process.exit(1)
    end

    print()
    const ok = GitHubHelpers.installCli()
    if not ok then
        print()
        print(Chalk.red("Failed to install GitHub CLI."))
        process.exit(1)
    end

    print(Chalk.green("GitHub CLI installed successfully."))
    print()
end

return GitHubHelpers

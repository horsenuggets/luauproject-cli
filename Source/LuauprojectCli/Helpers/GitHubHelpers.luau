--[[

GitHubHelpers

Helper functions for interacting with the GitHub CLI.

--]]

const Chalk = require("@packages/Chalk")
const PromptHelpers = require("@self/PromptHelpers")
const ShellHelpers = require("@self/ShellHelpers")
const process = require("@lune/process")
const serde = require("@lune/serde")

export type RepoMode = "Existing" | "New" | "None"

export type RepoModeFlags = {
    Existing: boolean,
    Github: boolean,
    NoGithub: boolean,
    Private: boolean,
}

export type RepoInfo = {
    IsEmpty: boolean,
    IsPrivate: boolean,
}

const REPO_MODE_CHOICES: { { Label: string, Mode: RepoMode } } = {
    { Label = "Create a new repository", Mode = "New" },
    { Label = "Connect to an existing repository", Mode = "Existing" },
    { Label = "Skip GitHub setup", Mode = "None" },
}

const GitHubHelpers = {}

GitHubHelpers.RepoModeChoices = REPO_MODE_CHOICES

--[[
    Normalizes a GitHub owner or organization name to lowercase. GitHub treats owner names
    case-insensitively, while tools like Wally only accept lowercase scopes.
]]
function GitHubHelpers.normalizeOwner(owner: string): string
    assert(type(owner) == "string", "owner must be a string")
    return (owner:gsub("^%s+", ""):gsub("%s+$", ""):lower())
end

--[[
    Decides how the GitHub repository is set up from command-line flags. Returns the mode,
    or nil when the user should be prompted. Returns an error message as the second value
    when the flags conflict.
]]
function GitHubHelpers.resolveRepoMode(flags: RepoModeFlags): (RepoMode?, string?)
    assert(type(flags) == "table", "flags must be a table")

    if flags.NoGithub and (flags.Existing or flags.Github or flags.Private) then
        return nil, "The --nogithub flag cannot be combined with --existing, --github, or --private."
    end
    if flags.Existing and (flags.Github or flags.Private) then
        return nil, "The --existing flag cannot be combined with --github or --private."
    end

    if flags.NoGithub then
        return "None", nil
    end
    if flags.Existing then
        return "Existing", nil
    end
    if flags.Github or flags.Private then
        return "New", nil
    end
    return nil, nil
end

--[[
    Parses the JSON output of `gh repo view --json isEmpty,isPrivate`.
]]
function GitHubHelpers.parseRepoInfo(json: string): RepoInfo?
    assert(type(json) == "string", "json must be a string")

    const ok, decoded = pcall(function()
        return serde.decode("json", json)
    end)
    if not ok or type(decoded) ~= "table" then
        return nil
    end
    if type(decoded.isEmpty) ~= "boolean" or type(decoded.isPrivate) ~= "boolean" then
        return nil
    end
    return {
        IsEmpty = decoded.isEmpty,
        IsPrivate = decoded.isPrivate,
    }
end

--[[
    Builds the Git remote URL for a repository from the Git protocol configured in the
    GitHub CLI. Anything other than "ssh" uses HTTPS, matching the CLI's own default.
]]
function GitHubHelpers.getRemoteUrl(fullName: string, protocol: string?): string
    assert(type(fullName) == "string", "fullName must be a string")
    assert(protocol == nil or type(protocol) == "string", "protocol must be a string or nil")

    if protocol and protocol:match("^%s*(.-)%s*$") == "ssh" then
        return `git@github.com:{fullName}.git`
    end
    return `https://github.com/{fullName}.git`
end

--[[
    Builds the arguments for a `git push` that authenticates HTTPS remotes through the
    GitHub CLI, the same way `gh auth setup-git` does but without changing the user's Git
    config. Git doesn't otherwise see the credentials `gh` was logged in with. SSH remotes
    ignore credential helpers, so this is safe for both protocols.
]]
function GitHubHelpers.getPushArgs(branch: string): { string }
    assert(type(branch) == "string", "branch must be a string")

    return {
        "-c",
        "credential.https://github.com.helper=",
        "-c",
        "credential.https://github.com.helper=!gh auth git-credential",
        "push",
        "-u",
        "origin",
        branch,
    }
end

--[[
    Returns the Git protocol the GitHub CLI uses for github.com, or nil if it can't be read.
]]
function GitHubHelpers.getGitProtocol(): string?
    const result = process.exec("gh", { "config", "get", "git_protocol", "--host", "github.com" })
    if not result.ok then
        return nil
    end
    return result.stdout
end

--[[
    Looks up an existing repository. Returns nil if it doesn't exist or can't be accessed.
]]
function GitHubHelpers.getRepoInfo(owner: string, name: string): RepoInfo?
    assert(type(owner) == "string", "owner must be a string")
    assert(type(name) == "string", "name must be a string")

    const result = process.exec("gh", { "repo", "view", `{owner}/{name}`, "--json", "isEmpty,isPrivate" })
    if not result.ok then
        return nil
    end
    return GitHubHelpers.parseRepoInfo(result.stdout)
end

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
        table.insert(owners, GitHubHelpers.normalizeOwner(username))
    end

    const orgs = GitHubHelpers.getOrganizations()
    for _, org in ipairs(orgs) do
        table.insert(owners, GitHubHelpers.normalizeOwner(org))
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

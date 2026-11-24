--[[

NewCommand

Creates a new Luau project from the luau-package-template. Supports both interactive
prompts and command-line flags.

--]]

const AliasHelpers = require("@luauprojectcli/Helpers/AliasHelpers")
const Chalk = require("@packages/Chalk")
const Command = require("@packages/Commandline").Command
const Flag = require("@packages/Commandline").Flag
const GitHubHelpers = require("@luauprojectcli/Helpers/GitHubHelpers")
const LogHelpers = require("@luauprojectcli/Helpers/LogHelpers")
const PathHelpers = require("@luauprojectcli/Helpers/PathHelpers")
const PromptHelpers = require("@luauprojectcli/Helpers/PromptHelpers")
const ShellHelpers = require("@luauprojectcli/Helpers/ShellHelpers")
const StringHelpers = require("@luauprojectcli/Helpers/StringHelpers")
const TerraformHelpers = require("@luauprojectcli/Helpers/TerraformHelpers")
const WallyHelpers = require("@luauprojectcli/Helpers/WallyHelpers")
const WorkflowHelpers = require("@luauprojectcli/Helpers/WorkflowHelpers")
const fs = require("@lune/fs")
const process = require("@lune/process")
const serde = require("@lune/serde")
const stdio = require("@lune/stdio")

------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------

const TEMPLATE_REPO = "horsenuggets/luau-package-template"

------------------------------------------------------------------------------------------
-- Types
------------------------------------------------------------------------------------------

type ProjectConfig = {
    Name: string,
    PascalName: string,
    Description: string,
    Owner: string,
    ProjectPath: string,
    RepoMode: GitHubHelpers.RepoMode,
    IsPrivate: boolean,
    IsPrivatePackage: boolean
}

type SetupResults = {
    BranchProtection: boolean?,
    Terraform: boolean?,
    WallyAuth: boolean?,
    CopilotReview: boolean?,
    Warnings: { string }
}

------------------------------------------------------------------------------------------
-- Utility Functions
------------------------------------------------------------------------------------------

const function replaceInFile(filePath: string, replacements: { { string } })
    if not fs.isFile(filePath) then
        return
    end
    local content = fs.readFile(filePath)
    for _, pair in ipairs(replacements) do
        content = content:gsub(pair[1], pair[2])
    end
    fs.writeFile(filePath, content)
end

------------------------------------------------------------------------------------------
-- Print Functions
------------------------------------------------------------------------------------------

const function printHeader()
    print("Creating a new Luau project...\n")
end

const function printCreatingProject(name: string, projectPath: string)
    print()
    print(
        `Creating project {Chalk.bold(Chalk.blueBright(name))} at {Chalk.dim(PathHelpers.formatDirectory(projectPath))}...`
    )
end

const function printStep(message: string)
    print(message)
end

const function printSuccess(config: ProjectConfig)
    print()
    print(Chalk.bold(Chalk.greenBright("Project created successfully!")))
    print()
    print(`Location is {Chalk.dim(PathHelpers.formatDirectory(config.ProjectPath))}.`)

    if config.RepoMode ~= "None" then
        print(`Repository is at {Chalk.bold(Chalk.blueBright(`https://github.com/{config.Owner}/{config.Name}`))}.`)
    end
end

const function printWallyTokenWarning(owner: string, name: string)
    print()
    print(Chalk.yellow("WALLY_AUTH not found in environment."))
    print(Chalk.dim("To enable Wally publishing, add the secret manually:"))
    print(Chalk.dim(`> gh secret set WALLY_AUTH --repo {owner}/{name}`))
end

------------------------------------------------------------------------------------------
-- Input Gathering Functions
------------------------------------------------------------------------------------------

const function getProjectName(flags: any): string
    if flags.name.Value and flags.name.Value ~= "" then
        const corrected = StringHelpers.toKebabCase(flags.name.Value)
        if corrected == "" then
            stdio.ewrite(Chalk.red("Project name is empty after correction.\n"))
            process.exit(1)
        end
        const aliasName = AliasHelpers.toAliasName(corrected)
        if AliasHelpers.isReservedAlias(aliasName) then
            stdio.ewrite(Chalk.red(`Project name "{corrected}" conflicts with reserved alias "{aliasName}".\n`))
            process.exit(1)
        end
        if corrected ~= flags.name.Value then
            print(`Using "{Chalk.bold(corrected)}" as the project name.`)
        end
        return corrected
    end

    while true do
        const input = PromptHelpers.prompt("Project name (kebab-case)")
        if input == "" then
            stdio.ewrite(Chalk.red("Project name is required.\n"))
            continue
        end

        const corrected = StringHelpers.toKebabCase(input)
        if corrected == "" then
            print(Chalk.yellow("Project name is empty after correction. Please try again."))
            continue
        end

        const aliasName = AliasHelpers.toAliasName(corrected)
        if AliasHelpers.isReservedAlias(aliasName) then
            print(
                Chalk.yellow(
                    `Project name "{corrected}" conflicts with reserved alias "{aliasName}". Please try again.`
                )
            )
            continue
        end

        if corrected ~= input then
            print(`Using "{Chalk.bold(corrected)}" as the project name.`)
        end

        return corrected
    end
end

const function getDescription(flags: any): string
    if flags.description.Value and flags.description.Value ~= "" then
        return flags.description.Value
    end
    return PromptHelpers.prompt("Description", "A Luau project.")
end

const function getOwner(flags: any): string
    if flags.owner.Value and flags.owner.Value ~= "" then
        const owner = GitHubHelpers.normalizeOwner(flags.owner.Value)
        if owner == "" then
            stdio.ewrite(Chalk.red("GitHub owner is empty after correction.\n"))
            process.exit(1)
        end
        if owner ~= flags.owner.Value then
            print(`Using "{Chalk.bold(owner)}" as the GitHub owner.`)
        end
        return owner
    end

    const owners = GitHubHelpers.getAvailableOwners()

    while true do
        if #owners <= 1 then
            const result = GitHubHelpers.normalizeOwner(PromptHelpers.prompt("GitHub owner or organization", owners[1]))
            if result ~= "" then
                return result
            end
        else
            const index = stdio.prompt("select", "GitHub owner or organization", owners)
            if index then
                return owners[index]
            end
        end

        stdio.ewrite(Chalk.red("GitHub owner is required.\n"))
    end
end

const function promptRepoMode(): GitHubHelpers.RepoMode
    const labels = {}
    for _, choice in GitHubHelpers.RepoModeChoices do
        table.insert(labels, choice.Label)
    end

    while true do
        const index = stdio.prompt("select", "GitHub repository", labels)
        if index then
            return GitHubHelpers.RepoModeChoices[index].Mode
        end
        stdio.ewrite(Chalk.red("Please choose how to set up the GitHub repository.\n"))
    end
end

-- Returns whether the repository is private if it can be connected to, or prints an error
-- and returns nil if it doesn't exist or already has commits
const function checkExistingRepo(owner: string, name: string): boolean?
    const fullName = `{owner}/{name}`
    const info = GitHubHelpers.getRepoInfo(owner, name)
    if not info then
        stdio.ewrite(Chalk.red(`Repository "{fullName}" was not found or is not accessible.\n`))
        return nil
    end
    if not info.IsEmpty then
        stdio.ewrite(Chalk.red(`Repository "{fullName}" is not empty, so the project can't be pushed to it.\n`))
        return nil
    end
    return info.IsPrivate
end

const function getRepoSetup(flags: any, owner: string, name: string): (GitHubHelpers.RepoMode, boolean)
    const flagMode, flagError = GitHubHelpers.resolveRepoMode({
        Existing = flags.existing.Value == true,
        Github = flags.github.Value == true,
        NoGithub = flags.nogithub.Value == true,
        Private = flags.private.Value == true
    })
    if flagError then
        stdio.ewrite(Chalk.red(`{flagError}\n`))
        process.exit(1)
    end

    while true do
        const mode = flagMode or promptRepoMode()

        if mode == "None" then
            return mode, false
        end

        if mode == "New" then
            if flagMode then
                return mode, flags.private.Value == true
            end
            return mode, PromptHelpers.promptConfirm("Private repository?", false)
        end

        const isPrivate = checkExistingRepo(owner, name)
        if isPrivate ~= nil then
            return mode, isPrivate
        end
        if flagMode then
            process.exit(1)
        end
    end
end

const function shouldBePrivatePackage(flags: any): boolean
    if flags.privatepackage.Value then
        return true
    end
    return PromptHelpers.promptConfirm("Private package? (will not publish to Wally)", false)
end

-- Prints an error and returns false if the project path cannot be used
const function validateProjectPath(projectPath: string): boolean
    if fs.isDir(projectPath) then
        const entries = fs.readDir(projectPath)
        if #entries > 0 then
            const displayPath = Chalk.dim(PathHelpers.formatDirectory(projectPath))
            stdio.ewrite(`{Chalk.red("Directory")} {displayPath} {Chalk.red("already exists and is not empty.")}\n`)
            return false
        end
    end

    if fs.isFile(projectPath) then
        const displayPath = Chalk.dim(PathHelpers.formatFile(projectPath))
        stdio.ewrite(`{Chalk.red("A file already exists at")} {displayPath}{Chalk.red(".")}\n`)
        return false
    end

    return true
end

const function getProjectPath(flags: any, name: string): string
    -- LUAUPROJECT_CWD is set by the wrapper script when running from a different
    -- directory
    const basePath = process.env.LUAUPROJECT_CWD or process.cwd
    const defaultPath = PathHelpers.trimTrailingSeparators(PathHelpers.join(basePath, name))

    if flags.path.Value and flags.path.Value ~= "" then
        const projectPath = PathHelpers.trimTrailingSeparators(PathHelpers.normalize(flags.path.Value))
        if not validateProjectPath(projectPath) then
            process.exit(1)
        end
        return projectPath
    end

    local projectPath = PromptHelpers.prompt("Project location", PathHelpers.formatDirectory(defaultPath))
    if projectPath == "" then
        projectPath = defaultPath
    end

    -- Expand ~ back to the home directory
    if string.sub(projectPath, 1, 1) == "~" then
        const home = process.env.HOME or ""
        projectPath = home .. string.sub(projectPath, 2)
    end

    projectPath = PathHelpers.trimTrailingSeparators(PathHelpers.normalize(projectPath))
    if not validateProjectPath(projectPath) then
        -- The path came from the interactive prompt, so ask again
        return getProjectPath(flags, name)
    end
    return projectPath
end

const function gatherProjectConfig(flags: any): ProjectConfig
    const name = getProjectName(flags)
    const description = getDescription(flags)
    const owner = getOwner(flags)
    const repoMode, isPrivate = getRepoSetup(flags, owner, name)
    const isPrivatePackage = shouldBePrivatePackage(flags)
    const projectPath = getProjectPath(flags, name)

    return {
        Name = name,
        PascalName = StringHelpers.toPascalCase(name),
        Description = description,
        Owner = owner,
        ProjectPath = projectPath,
        RepoMode = repoMode,
        IsPrivate = isPrivate,
        IsPrivatePackage = isPrivatePackage
    }
end

------------------------------------------------------------------------------------------
-- Project Setup Functions
------------------------------------------------------------------------------------------

const function cloneTemplate(projectPath: string)
    printStep("Cloning template repository...")
    ShellHelpers.runOrFail("gh", { "repo", "clone", TEMPLATE_REPO, projectPath, "--", "--depth=1" })
    fs.removeDir(`{projectPath}/.git`)
end

const function initializeGitRepo(projectPath: string)
    printStep("Initializing Git repository...")
    ShellHelpers.runOrFail("git", { "init", "--initial-branch=main" }, projectPath)
end

const function updateWallyToml(config: ProjectConfig)
    const wallyPath = `{config.ProjectPath}/wally.toml`
    if not fs.isFile(wallyPath) then
        return
    end

    local content = fs.readFile(wallyPath)

    -- Standard replacements
    content = content:gsub("horsenuggets/luau%-package%-template", `{config.Owner}/{config.Name}`)
    content = content:gsub("luau%-package%-template", config.Name)
    content = content:gsub("A template for creating Luau packages%.", config.Description)

    -- Add private = true for private packages (after the version line)
    if config.IsPrivatePackage then
        content = content:gsub('(version = "[^"]+")\n', "%1\nprivate = true\n")
    end

    fs.writeFile(wallyPath, content)
end

const function updateProjectJson(config: ProjectConfig)
    -- default.project.json: update name and source path
    replaceInFile(`{config.ProjectPath}/default.project.json`, {
        { '"luau%-package%-template"', `"{config.Name}"` },
        { "Source/LuauPackageTemplate", `Source/{config.PascalName}` }
    })

    -- dev.project.json: update name with -dev suffix (no source path in new structure)
    replaceInFile(`{config.ProjectPath}/dev.project.json`, {
        { '"luau%-package%-template%-dev"', `"{config.Name}-dev"` }
    })
end

const function updateRootInit(config: ProjectConfig)
    replaceInFile(`{config.ProjectPath}/init.luau`, {
        { "LuauPackageTemplate", config.PascalName }
    })
end

const function updateReadme(config: ProjectConfig)
    replaceInFile(`{config.ProjectPath}/README.md`, {
        { "# luau%-package%-template", `# {config.Name}` },
        { "A template for creating Luau packages%.", config.Description }
    })
end

const function updateLicense(config: ProjectConfig)
    replaceInFile(`{config.ProjectPath}/LICENSE`, {
        { "HorseNuggets", config.Owner }
    })
end

const function renameSourceDirectory(config: ProjectConfig)
    const oldPath = `{config.ProjectPath}/Source/LuauPackageTemplate`
    const newPath = `{config.ProjectPath}/Source/{config.PascalName}`

    if not fs.isDir(oldPath) then
        return
    end

    replaceInFile(`{oldPath}/init.luau`, {
        { "LuauPackageTemplate", config.PascalName }
    })
    fs.move(oldPath, newPath)
end

const function renameWorkspaceFile(config: ProjectConfig)
    const oldPath = `{config.ProjectPath}/luau-package-template.code-workspace`
    const newPath = `{config.ProjectPath}/{config.Name}.code-workspace`

    if fs.isFile(oldPath) then
        fs.move(oldPath, newPath)
    end
end

const function createVersionFiles(config: ProjectConfig)
    fs.writeFile(`{config.ProjectPath}/VERSION`, "0.0.0\n")
    fs.writeFile(`{config.ProjectPath}/CHANGELOG.md`, "# Changelog\n\n## 0.0.1\n- Initial release\n")
end

const function updateLuaurc(config: ProjectConfig)
    const luaurcPath = `{config.ProjectPath}/.luaurc`
    if not fs.isFile(luaurcPath) then
        return
    end

    const content = fs.readFile(luaurcPath)
    const luaurc = serde.decode("json", content)

    -- Update aliases: remove template alias and add project alias
    const aliases = luaurc.aliases or {}
    aliases.luaupackagetemplate = nil
    const aliasName = AliasHelpers.toAliasName(config.Name)
    aliases[aliasName] = `./Source/{config.PascalName}/`

    -- Get sorted alias keys
    const aliasKeys = {}
    for key in aliases do
        table.insert(aliasKeys, key)
    end
    table.sort(aliasKeys)

    -- Get sorted global keys
    const globals = luaurc.globals or {}
    table.sort(globals)

    -- Build JSON manually with 4-space indentation and sorted keys
    const lines = {
        "{",
        '    "aliases": {'
    }

    for i, key in aliasKeys do
        const comma = if i < #aliasKeys then "," else ""
        table.insert(lines, `        "{key}": "{aliases[key]}"{comma}`)
    end

    table.insert(lines, "    },")
    table.insert(lines, '    "globals": [')

    for i, global in globals do
        const comma = if i < #globals then "," else ""
        table.insert(lines, `        "{global}"{comma}`)
    end

    table.insert(lines, "    ]")
    table.insert(lines, "}")

    fs.writeFile(luaurcPath, table.concat(lines, "\n") .. "\n")
end

const function updateConfigFiles(config: ProjectConfig)
    printStep("Updating project configuration files...")
    updateLuaurc(config)
    updateWallyToml(config)
    updateProjectJson(config)
    updateRootInit(config)
    updateReadme(config)
    updateLicense(config)
    renameSourceDirectory(config)
    renameWorkspaceFile(config)
    createVersionFiles(config)
end

const function removeEmptySubmodules(config: ProjectConfig)
    const submodulesPath = `{config.ProjectPath}/Submodules`
    if fs.isDir(submodulesPath) then
        fs.removeDir(submodulesPath)
    end
end

const function parseGitmodules(projectPath: string): { { path: string, url: string } }
    const gitmodulesPath = `{projectPath}/.gitmodules`
    if not fs.isFile(gitmodulesPath) then
        return {}
    end

    const content = fs.readFile(gitmodulesPath)
    const submodules: { { path: string, url: string } } = {}
    local current: { path: string?, url: string? } = {}

    for line in content:gmatch("[^\n]+") do
        if line:match("^%[submodule") then
            if current.path and current.url then
                table.insert(submodules, {
                    path = current.path,
                    url = current.url
                })
            end
            current = {}
        end

        const path = line:match("^%s*path%s*=%s*(.+)%s*$")
        if path then
            current.path = path
        end

        local url = line:match("^%s*url%s*=%s*(.+)%s*$")
        if url then
            -- Convert SSH URLs to HTTPS
            const sshMatch = url:match("^git@github%.com:(.+)$")
            if sshMatch then
                url = `https://github.com/{sshMatch}`
            end
            current.url = url
        end
    end

    if current.path and current.url then
        table.insert(submodules, {
            path = current.path,
            url = current.url
        })
    end

    return submodules
end

const function setupSubmodules(config: ProjectConfig)
    printStep("Setting up Git submodules...")

    const submodules = parseGitmodules(config.ProjectPath)
    removeEmptySubmodules(config)

    -- Also remove the .gitmodules file from the template since
    -- Git submodule add will recreate it
    const gitmodulesPath = `{config.ProjectPath}/.gitmodules`
    if fs.isFile(gitmodulesPath) then
        fs.removeFile(gitmodulesPath)
    end

    for _, submodule in submodules do
        ShellHelpers.runOrFail("git", {
            "submodule",
            "add",
            submodule.url,
            submodule.path
        }, config.ProjectPath)
    end
end

const function copyWorkflows(config: ProjectConfig)
    printStep("Setting up CI workflows...")

    const workflowsSourceDir = `{config.ProjectPath}/Submodules/luau-cicd/Templates/workflows`
    const workflowsTargetDir = `{config.ProjectPath}/.github/workflows`

    -- Create workflows directory if it doesn't exist
    if not fs.isDir(workflowsTargetDir) then
        fs.writeDir(workflowsTargetDir)
    end

    -- Copy all workflow files, dropping Wally configuration for private packages
    if fs.isDir(workflowsSourceDir) then
        for _, entry in fs.readDir(workflowsSourceDir) do
            const sourcePath = `{workflowsSourceDir}/{entry}`
            if fs.isFile(sourcePath) then
                const content = WorkflowHelpers.prepareWorkflow(entry, fs.readFile(sourcePath), config.IsPrivatePackage)
                fs.writeFile(`{workflowsTargetDir}/{entry}`, content)
            end
        end
    end
end

const function installTools(config: ProjectConfig)
    if process.env.LUAUPROJECT_SKIP_INSTALL then
        printStep("Skipping Rokit tools installation (LUAUPROJECT_SKIP_INSTALL set)...")
        return
    end
    printStep("Installing Rokit tools...")
    ShellHelpers.runOrFail("rokit", { "install" }, config.ProjectPath)
end

const function installDependencies(config: ProjectConfig)
    if process.env.LUAUPROJECT_SKIP_INSTALL then
        printStep("Skipping Wally dependencies installation (LUAUPROJECT_SKIP_INSTALL set)...")
        return
    end
    printStep("Installing Wally dependencies...")
    ShellHelpers.runOrFail("wally", { "install" }, config.ProjectPath)
end

const function createInitialCommit(config: ProjectConfig)
    printStep("Creating initial commit...")
    ShellHelpers.runOrFail("git", { "add", "-A" }, config.ProjectPath)
    ShellHelpers.runOrFail("git", { "commit", "-m", "Initial commit from luauproject-cli" }, config.ProjectPath)
end

------------------------------------------------------------------------------------------
-- GitHub Setup Functions
------------------------------------------------------------------------------------------

const function createGithubRepository(config: ProjectConfig)
    printStep("Creating GitHub repository...")

    const visibility = if config.IsPrivate then "--private" else "--public"
    ShellHelpers.runOrFail("gh", {
        "repo",
        "create",
        `{config.Owner}/{config.Name}`,
        visibility,
        "--source",
        config.ProjectPath,
        "--push"
    })
end

const function connectExistingRepository(config: ProjectConfig)
    printStep("Connecting to existing GitHub repository...")

    const remoteUrl = GitHubHelpers.getRemoteUrl(`{config.Owner}/{config.Name}`, GitHubHelpers.getGitProtocol())

    ShellHelpers.runOrFail("git", { "remote", "add", "origin", remoteUrl }, config.ProjectPath)
    ShellHelpers.runOrFail("git", GitHubHelpers.getPushArgs("main"), config.ProjectPath)
end

const function configureRepoSettings(config: ProjectConfig)
    printStep("Configuring repository settings...")

    ShellHelpers.runOrFail("gh", {
        "api",
        `repos/{config.Owner}/{config.Name}`,
        "-X",
        "PATCH",
        "-f",
        "allow_squash_merge=true",
        "-f",
        "allow_merge_commit=false",
        "-f",
        "allow_rebase_merge=false",
        "-f",
        "delete_branch_on_merge=true",
        "-f",
        "allow_auto_merge=true",
        "-f",
        "has_wiki=false",
        "-f",
        "has_projects=false",
        "-f",
        "has_downloads=false"
    })
end

const function createDevBranch(config: ProjectConfig)
    printStep("Creating dev branch...")
    ShellHelpers.runOrFail("git", { "checkout", "-b", "dev" }, config.ProjectPath)
    ShellHelpers.runOrFail("git", GitHubHelpers.getPushArgs("dev"), config.ProjectPath)
    ShellHelpers.runOrFail("git", { "checkout", "main" }, config.ProjectPath)
end

const function createReleaseBranch(config: ProjectConfig)
    printStep("Creating release branch...")
    ShellHelpers.runOrFail("git", { "checkout", "-b", "release" }, config.ProjectPath)
    ShellHelpers.runOrFail("git", GitHubHelpers.getPushArgs("release"), config.ProjectPath)
    ShellHelpers.runOrFail("git", { "checkout", "main" }, config.ProjectPath)
end

const function getDevBranchProtectionJson(): string
    return [[{
        "required_status_checks": null,
        "enforce_admins": true,
        "required_pull_request_reviews": null,
        "restrictions": null,
        "allow_force_pushes": false,
        "allow_deletions": false
    }]]
end

const function getCopilotCodeReviewRulesetJson(): string
    return [[{
        "name": "Copilot Code Review",
        "target": "branch",
        "enforcement": "active",
        "conditions": {
            "ref_name": {
                "include": ["refs/heads/main", "refs/heads/release"],
                "exclude": []
            }
        },
        "rules": [
            {
                "type": "copilot_code_review",
                "parameters": {
                    "review_draft_pull_requests": false,
                    "review_on_push": true
                }
            }
        ]
    }]]
end

const function applyDevBranchProtection(owner: string, name: string): boolean
    const tempFile = "/tmp/dev-protection.json"
    fs.writeFile(tempFile, getDevBranchProtectionJson())

    const ok, _ = ShellHelpers.run("gh", {
        "api",
        `repos/{owner}/{name}/branches/dev/protection`,
        "-X",
        "PUT",
        "-H",
        "Accept: application/vnd.github+json",
        "--input",
        tempFile
    })

    return ok
end

const function setupBranchProtection(config: ProjectConfig): (boolean, boolean)
    printStep("Setting up branch protection rules...")

    -- Main and release branches are managed via Terraform
    const terraformOk = TerraformHelpers.applyBranchProtection(config.Name, config.Owner, config.IsPrivatePackage)

    if not terraformOk then
        print(Chalk.yellow("Terraform branch protection failed. Set up manually."))
    end

    -- Dev branch is managed via gh API (not in Terraform module)
    const devOk = applyDevBranchProtection(config.Owner, config.Name)
    if not devOk then
        print(Chalk.yellow("Failed to set dev branch protection (requires GitHub Pro for private repos)."))
    end

    return terraformOk, devOk
end

const function setupCopilotCodeReview(config: ProjectConfig): boolean
    printStep("Enabling Copilot code review for all PRs...")

    const tempFile = "/tmp/copilot-ruleset.json"
    fs.writeFile(tempFile, getCopilotCodeReviewRulesetJson())

    const ok, _ = ShellHelpers.run("gh", {
        "api",
        `repos/{config.Owner}/{config.Name}/rulesets`,
        "-X",
        "POST",
        "-H",
        "Accept: application/vnd.github+json",
        "--input",
        tempFile
    })

    if not ok then
        print(Chalk.yellow("Failed to set up Copilot code review (requires Copilot subscription)."))
    end

    return ok
end

const function setupWallyToken(config: ProjectConfig): boolean
    const wallyToken = WallyHelpers.getAuthToken()

    if not wallyToken then
        printWallyTokenWarning(config.Owner, config.Name)
        return false
    end

    printStep("Setting up Wally authentication token...")

    const ok, _ = ShellHelpers.run("gh", {
        "secret",
        "set",
        "WALLY_AUTH",
        "--body",
        wallyToken,
        "--repo",
        `{config.Owner}/{config.Name}`
    })

    if ok then
        print(Chalk.dim("Wally token configured for publishing..."))
    else
        print(Chalk.yellow("Failed to set Wally token. Set it manually in the repository settings."))
    end

    return ok
end

const function setupGithubRepository(config: ProjectConfig): SetupResults
    const warnings: { string } = {}

    if config.RepoMode == "Existing" then
        connectExistingRepository(config)
    else
        createGithubRepository(config)
    end
    configureRepoSettings(config)
    createDevBranch(config)
    createReleaseBranch(config)

    const terraformOk, devProtectionOk = setupBranchProtection(config)
    const branchProtectionOk = terraformOk and devProtectionOk
    if not branchProtectionOk then
        table.insert(warnings, "Failed to set branch protection (requires GitHub Pro for private repos)")
    end

    const copilotReviewOk = setupCopilotCodeReview(config)
    if not copilotReviewOk then
        table.insert(warnings, "Failed to set up Copilot code review (requires Copilot subscription)")
    end

    local wallyAuthOk: boolean? = nil
    -- Skip Wally token setup for private packages (they won't be published to Wally)
    if not config.IsPrivatePackage then
        wallyAuthOk = setupWallyToken(config)
        if not wallyAuthOk then
            table.insert(warnings, "WALLY_AUTH_TOKEN not configured")
        end
    end

    return {
        BranchProtection = branchProtectionOk,
        Terraform = terraformOk,
        WallyAuth = wallyAuthOk,
        CopilotReview = copilotReviewOk,
        Warnings = warnings
    }
end

------------------------------------------------------------------------------------------
-- Main Orchestration Functions
------------------------------------------------------------------------------------------

const function setupLocalProject(config: ProjectConfig)
    cloneTemplate(config.ProjectPath)
    initializeGitRepo(config.ProjectPath)
    updateConfigFiles(config)
    setupSubmodules(config)
    copyWorkflows(config)
    installTools(config)
    installDependencies(config)
    createInitialCommit(config)
end

const function logProjectCreation(config: ProjectConfig, results: SetupResults?)
    pcall(function()
        LogHelpers.appendEntry({
            timestamp = LogHelpers.createTimestamp(),
            args = process.args,
            config = {
                name = config.Name,
                description = config.Description,
                owner = config.Owner,
                projectPath = config.ProjectPath,
                createGithubRepo = config.RepoMode == "New",
                repoMode = config.RepoMode,
                isPrivate = config.IsPrivate,
                isPrivatePackage = config.IsPrivatePackage
            },
            cwd = process.cwd,
            setup = {
                branchProtection = if results then results.BranchProtection else nil,
                copilotReview = if results then results.CopilotReview else nil,
                terraform = if results then results.Terraform else nil,
                wallyAuth = if results then results.WallyAuth else nil
            },
            warnings = if results then results.Warnings else {}
        })
    end)
end

const function createProject(config: ProjectConfig)
    printCreatingProject(config.Name, config.ProjectPath)
    setupLocalProject(config)

    local results: SetupResults? = nil
    if config.RepoMode ~= "None" then
        results = setupGithubRepository(config)
    end

    logProjectCreation(config, results)
    printSuccess(config)
end

------------------------------------------------------------------------------------------
-- Command Definition
------------------------------------------------------------------------------------------

return Command.new({
    Name = "new",
    Description = "Create a new Luau project from template.",
    Flags = {
        Flag.new({
            Name = "name",
            Shorthand = "n",
            Description = "Project name in kebab-case.",
            Type = "string"
        }),
        Flag.new({
            Name = "description",
            Shorthand = "d",
            Description = "Project description.",
            Type = "string"
        }),
        Flag.new({
            Name = "owner",
            Shorthand = "o",
            Description = "GitHub owner or organization.",
            Type = "string"
        }),
        Flag.new({
            Name = "github",
            Description = "Create a GitHub repository (skips confirmation prompt)."
        }),
        Flag.new({
            Name = "existing",
            Description = "Connect to an existing empty GitHub repository at <owner>/<name>."
        }),
        Flag.new({
            Name = "private",
            Description = "Create a private repository."
        }),
        Flag.new({
            Name = "nogithub",
            Description = "Skip GitHub repository creation."
        }),
        Flag.new({
            Name = "path",
            Shorthand = "p",
            Description = "Full path for the new project directory.",
            Type = "string"
        }),
        Flag.new({
            Name = "privatepackage",
            Description = "Make this a private package (will not publish to Wally)."
        })
    },
    Impl = function(_args, flags)
        GitHubHelpers.ensureInstalled()
        printHeader()
        const config = gatherProjectConfig(flags)
        if config.RepoMode ~= "None" then
            TerraformHelpers.ensureInstalled()
        end
        createProject(config)
    end
})

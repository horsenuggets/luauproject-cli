--[[

new.cmd

Creates a new Luau project from the luau-package-template. Supports both interactive
prompts and command-line flags.

]]

local Chalk = require("@packages/Chalk")
local Command = require("@packages/Commandline").Command
local Flag = require("@packages/Commandline").Flag
local GitHubHelpers = require("@luauprojectcli/Helpers/GitHubHelpers")
local PromptHelpers = require("@luauprojectcli/Helpers/PromptHelpers")
local ShellHelpers = require("@luauprojectcli/Helpers/ShellHelpers")
local StringHelpers = require("@luauprojectcli/Helpers/StringHelpers")
local WallyHelpers = require("@luauprojectcli/Helpers/WallyHelpers")
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------

local TEMPLATE_REPO = "horsenuggets/luau-package-template"

-- These alias names are reserved in .luaurc and cannot be used as project names
local RESERVED_ALIASES = {
    "devpackages",
    "lune",
    "packages",
    "tests",
}

------------------------------------------------------------------------------------------
-- Types
------------------------------------------------------------------------------------------

type ProjectConfig = {
    Name: string,
    PascalName: string,
    Description: string,
    Owner: string,
    ProjectPath: string,
    CreateGithubRepo: boolean,
    IsPrivate: boolean,
    IsPrivatePackage: boolean,
}

------------------------------------------------------------------------------------------
-- Utility Functions
------------------------------------------------------------------------------------------

local function toAliasName(kebabName: string): string
    return kebabName:gsub("-", "")
end

local function isReservedAlias(aliasName: string): boolean
    for _, reserved in RESERVED_ALIASES do
        if aliasName == reserved then
            return true
        end
    end
    return false
end

local function replaceInFile(filePath: string, replacements: { { string } })
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

local function printHeader()
    print("Creating a new Luau project...\n")
end

local function printCreatingProject(name: string, projectPath: string)
    print()
    print(`Creating project {Chalk.bold(Chalk.blueBright(name))} at {Chalk.dim(projectPath)}...`)
end

local function printStep(message: string)
    print(message)
end

local function printSuccess(config: ProjectConfig)
    print()
    print(Chalk.bold(Chalk.greenBright("Project created successfully!")))
    print()
    print(`Location is {Chalk.dim(config.ProjectPath)}.`)

    if config.CreateGithubRepo then
        print(`Repository is at {Chalk.bold(Chalk.blueBright(`https://github.com/{config.Owner}/{config.Name}`))}.`)
    end
end

local function printWallyTokenWarning(owner: string, name: string)
    print()
    print(Chalk.yellow("WALLY_AUTH not found in environment."))
    print(Chalk.dim("To enable Wally publishing, add the secret manually:"))
    print(Chalk.dim(`> gh secret set WALLY_AUTH --repo {owner}/{name}`))
end

------------------------------------------------------------------------------------------
-- Input Gathering Functions
------------------------------------------------------------------------------------------

local function getProjectName(flags: any): string
    if flags.name.Value and flags.name.Value ~= "" then
        local corrected = StringHelpers.toKebabCase(flags.name.Value)
        if corrected == "" then
            stdio.ewrite(Chalk.red("Project name is empty after correction.\n"))
            process.exit(1)
        end
        local aliasName = toAliasName(corrected)
        if isReservedAlias(aliasName) then
            stdio.ewrite(Chalk.red(`Project name "{corrected}" conflicts with reserved alias "{aliasName}".\n`))
            process.exit(1)
        end
        if corrected ~= flags.name.Value then
            print(`Using "{Chalk.bold(corrected)}" as the project name.`)
        end
        return corrected
    end

    while true do
        local input = PromptHelpers.prompt("Project name (kebab-case)")
        if input == "" then
            stdio.ewrite(Chalk.red("Project name is required.\n"))
            process.exit(1)
        end

        local corrected = StringHelpers.toKebabCase(input)
        if corrected == "" then
            print(Chalk.yellow("Project name is empty after correction. Please try again."))
            continue
        end

        local aliasName = toAliasName(corrected)
        if isReservedAlias(aliasName) then
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

local function getDescription(flags: any): string
    if flags.description.Value and flags.description.Value ~= "" then
        return flags.description.Value
    end
    return PromptHelpers.prompt("Description", "A Luau package.")
end

local function getOwner(flags: any): string
    if flags.owner.Value and flags.owner.Value ~= "" then
        return flags.owner.Value
    end

    local owners = GitHubHelpers.getAvailableOwners()

    if #owners == 0 then
        local result = PromptHelpers.prompt("GitHub owner or organization")
        if result == "" then
            stdio.ewrite(Chalk.red("GitHub owner is required.\n"))
            process.exit(1)
        end
        return result
    elseif #owners == 1 then
        return PromptHelpers.prompt("GitHub owner or organization", owners[1])
    end

    local index = stdio.prompt("select", "GitHub owner or organization", owners)
    if index then
        return owners[index]
    end

    stdio.ewrite(Chalk.red("GitHub owner is required.\n"))
    process.exit(1)
    return "" -- Unreachable, but satisfies type checker
end

local function shouldCreateGithubRepo(flags: any): boolean
    if flags.nogithub.Value then
        return false
    end
    if flags.github.Value or flags.private.Value then
        return true
    end
    return PromptHelpers.promptConfirm("Create GitHub repository?", true)
end

local function shouldBePrivate(flags: any, createGithubRepo: boolean): boolean
    if not createGithubRepo then
        return false
    end
    if flags.private.Value then
        return true
    end
    if flags.nogithub.Value or flags.github.Value then
        return false
    end
    return PromptHelpers.promptConfirm("Private repository?", false)
end

local function shouldBePrivatePackage(flags: any): boolean
    if flags.privatepackage.Value then
        return true
    end
    return PromptHelpers.promptConfirm("Private package? (will not publish to Wally)", false)
end

local function getBasePath(flags: any): string
    -- LUAUPROJECT_CWD is set by the wrapper script when running from a different directory
    local basePath = flags.path.Value or process.env.LUAUPROJECT_CWD or process.cwd
    return basePath:gsub("/$", "")
end

local function gatherProjectConfig(flags: any): ProjectConfig
    local name = getProjectName(flags)
    local description = getDescription(flags)
    local owner = getOwner(flags)
    local createGithubRepo = shouldCreateGithubRepo(flags)
    local isPrivate = shouldBePrivate(flags, createGithubRepo)
    local isPrivatePackage = shouldBePrivatePackage(flags)
    local basePath = getBasePath(flags)

    return {
        Name = name,
        PascalName = StringHelpers.toPascalCase(name),
        Description = description,
        Owner = owner,
        ProjectPath = `{basePath}/{name}`,
        CreateGithubRepo = createGithubRepo,
        IsPrivate = isPrivate,
        IsPrivatePackage = isPrivatePackage,
    }
end

------------------------------------------------------------------------------------------
-- Project Setup Functions
------------------------------------------------------------------------------------------

local function cloneTemplate(projectPath: string)
    printStep("Cloning template repository...")
    ShellHelpers.runOrFail("gh", { "repo", "clone", TEMPLATE_REPO, projectPath, "--", "--depth=1" })
    fs.removeDir(`{projectPath}/.git`)
end

local function initializeGitRepo(projectPath: string)
    printStep("Initializing git repository...")
    ShellHelpers.runOrFail("git", { "init" }, projectPath)
end

local function updateWallyToml(config: ProjectConfig)
    local wallyPath = `{config.ProjectPath}/wally.toml`
    if not fs.isFile(wallyPath) then
        return
    end

    local content = fs.readFile(wallyPath)

    -- Standard replacements
    content = content:gsub("horsenuggets/luau%-package%-template", `{config.Owner}/{config.Name}`)
    content = content:gsub("luau%-package%-template", config.Name)
    content = content:gsub("A template for creating Luau packages%.", config.Description)

    -- Add private = true for private packages (after the name line)
    if config.IsPrivatePackage then
        content = content:gsub('(name = "[^"]+")\n', "%1\nprivate = true\n")
    end

    fs.writeFile(wallyPath, content)
end

local function updateProjectJson(config: ProjectConfig)
    -- default.project.json: update name and source path
    replaceInFile(`{config.ProjectPath}/default.project.json`, {
        { '"luau%-package%-template"', `"{config.Name}"` },
        { "Source/LuauPackageTemplate", `Source/{config.PascalName}` },
    })

    -- dev.project.json: update name with -dev suffix (no source path in new structure)
    replaceInFile(`{config.ProjectPath}/dev.project.json`, {
        { '"luau%-package%-template%-dev"', `"{config.Name}-dev"` },
    })
end

local function updateRootInit(config: ProjectConfig)
    replaceInFile(`{config.ProjectPath}/init.luau`, {
        { "LuauPackageTemplate", config.PascalName },
    })
end

local function updateReadme(config: ProjectConfig)
    replaceInFile(`{config.ProjectPath}/README.md`, {
        { "# luau%-package%-template", `# {config.Name}` },
        { "A template for creating Luau packages%.", config.Description },
    })
end

local function updateLicense(config: ProjectConfig)
    replaceInFile(`{config.ProjectPath}/LICENSE`, {
        { "HorseNuggets", config.Owner },
    })
end

local function renameSourceDirectory(config: ProjectConfig)
    local oldPath = `{config.ProjectPath}/Source/LuauPackageTemplate`
    local newPath = `{config.ProjectPath}/Source/{config.PascalName}`

    if not fs.isDir(oldPath) then
        return
    end

    replaceInFile(`{oldPath}/init.luau`, {
        { "LuauPackageTemplate", config.PascalName },
    })
    fs.move(oldPath, newPath)
end

local function renameWorkspaceFile(config: ProjectConfig)
    local oldPath = `{config.ProjectPath}/luau-package-template.code-workspace`
    local newPath = `{config.ProjectPath}/{config.Name}.code-workspace`

    if fs.isFile(oldPath) then
        fs.move(oldPath, newPath)
    end
end

local function createVersionFiles(config: ProjectConfig)
    fs.writeFile(`{config.ProjectPath}/VERSION`, "0.0.0\n")
    fs.writeFile(`{config.ProjectPath}/CHANGELOG.md`, "# Changelog\n\n## 0.0.1\n- Initial release\n")
end

local function updateLuaurc(config: ProjectConfig)
    local luaurcPath = `{config.ProjectPath}/.luaurc`
    if not fs.isFile(luaurcPath) then
        return
    end

    local content = fs.readFile(luaurcPath)
    local luaurc = serde.decode("json", content)

    -- Update aliases: remove template alias and add project alias
    local aliases = luaurc.aliases or {}
    aliases.luaupackagetemplate = nil
    local aliasName = toAliasName(config.Name)
    aliases[aliasName] = `./Source/{config.PascalName}/`

    -- Get sorted alias keys
    local aliasKeys = {}
    for key in aliases do
        table.insert(aliasKeys, key)
    end
    table.sort(aliasKeys)

    -- Get sorted global keys
    local globals = luaurc.globals or {}
    table.sort(globals)

    -- Build JSON manually with 4-space indentation and sorted keys
    local lines = {
        "{",
        '    "aliases": {',
    }

    for i, key in aliasKeys do
        local comma = if i < #aliasKeys then "," else ""
        table.insert(lines, `        "{key}": "{aliases[key]}"{comma}`)
    end

    table.insert(lines, "    },")
    table.insert(lines, '    "globals": [')

    for i, global in globals do
        local comma = if i < #globals then "," else ""
        table.insert(lines, `        "{global}"{comma}`)
    end

    table.insert(lines, "    ]")
    table.insert(lines, "}")

    fs.writeFile(luaurcPath, table.concat(lines, "\n") .. "\n")
end

local function updateConfigFiles(config: ProjectConfig)
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

local function removeEmptySubmodules(config: ProjectConfig)
    local submodulesPath = `{config.ProjectPath}/Submodules`
    if fs.isDir(submodulesPath) then
        fs.removeDir(submodulesPath)
    end
end

local function setupSubmodules(config: ProjectConfig)
    printStep("Setting up git submodules...")
    removeEmptySubmodules(config)

    ShellHelpers.runOrFail("git", {
        "submodule",
        "add",
        "https://github.com/horsenuggets/claude-md-luau.git",
        "Submodules/claude-md-luau",
    }, config.ProjectPath)

    ShellHelpers.runOrFail("git", {
        "submodule",
        "add",
        "https://github.com/horsenuggets/luau-cicd.git",
        "Submodules/luau-cicd",
    }, config.ProjectPath)
end

local function copyWorkflows(config: ProjectConfig)
    printStep("Setting up GitHub workflows...")

    local workflowsSourceDir = `{config.ProjectPath}/Submodules/luau-cicd/Templates/workflows`
    local workflowsTargetDir = `{config.ProjectPath}/.github/workflows`

    -- Create workflows directory if it doesn't exist
    if not fs.isDir(workflowsTargetDir) then
        fs.writeDir(workflowsTargetDir)
    end

    -- Copy all workflow files
    if fs.isDir(workflowsSourceDir) then
        for _, entry in fs.readDir(workflowsSourceDir) do
            local sourcePath = `{workflowsSourceDir}/{entry}`
            local targetPath = `{workflowsTargetDir}/{entry}`
            if fs.isFile(sourcePath) then
                fs.copy(sourcePath, targetPath)
            end
        end
    end
end

local function installTools(config: ProjectConfig)
    if process.env.LUAUPROJECT_SKIP_INSTALL then
        printStep("Skipping Rokit tools installation (LUAUPROJECT_SKIP_INSTALL set)...")
        return
    end
    printStep("Installing Rokit tools...")
    ShellHelpers.runOrFail("rokit", { "install" }, config.ProjectPath)
end

local function installDependencies(config: ProjectConfig)
    if process.env.LUAUPROJECT_SKIP_INSTALL then
        printStep("Skipping Wally dependencies installation (LUAUPROJECT_SKIP_INSTALL set)...")
        return
    end
    printStep("Installing Wally dependencies...")
    ShellHelpers.runOrFail("wally", { "install" }, config.ProjectPath)
end

local function createInitialCommit(config: ProjectConfig)
    printStep("Creating initial commit...")
    ShellHelpers.runOrFail("git", { "add", "-A" }, config.ProjectPath)
    ShellHelpers.runOrFail("git", { "commit", "-m", "Initial commit from luauproject-cli" }, config.ProjectPath)
end

------------------------------------------------------------------------------------------
-- GitHub Setup Functions
------------------------------------------------------------------------------------------

local function createGithubRepository(config: ProjectConfig)
    printStep("Creating GitHub repository...")

    local visibility = if config.IsPrivate then "--private" else "--public"
    ShellHelpers.runOrFail("gh", {
        "repo",
        "create",
        `{config.Owner}/{config.Name}`,
        visibility,
        "--source",
        config.ProjectPath,
        "--push",
    })
end

local function configureRepoSettings(config: ProjectConfig)
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
        "has_downloads=false",
    })
end

local function createReleaseBranch(config: ProjectConfig)
    printStep("Creating release branch...")
    ShellHelpers.runOrFail("git", { "checkout", "-b", "release" }, config.ProjectPath)
    ShellHelpers.runOrFail("git", { "push", "-u", "origin", "release" }, config.ProjectPath)
    ShellHelpers.runOrFail("git", { "checkout", "main" }, config.ProjectPath)
end

local function getMainBranchProtectionJson(): string
    return [[{
		"required_status_checks": {
			"strict": true,
			"checks": [
				{ "context": "Check formatting" },
				{ "context": "Run tests" },
				{ "context": "Static analysis" },
				{ "context": "Validate branch name" }
			]
		},
		"enforce_admins": true,
		"required_pull_request_reviews": null,
		"restrictions": null,
		"allow_force_pushes": false,
		"allow_deletions": false
	}]]
end

local function getReleaseBranchProtectionJson(): string
    return [[{
		"required_status_checks": {
			"strict": true,
			"checks": [
				{ "context": "Validate PR title" },
				{ "context": "Verify diff matches main" },
				{ "context": "Check formatting" },
				{ "context": "Run tests" },
				{ "context": "Static analysis" },
				{ "context": "Validate version" }
			]
		},
		"enforce_admins": true,
		"required_pull_request_reviews": null,
		"restrictions": null,
		"allow_force_pushes": false,
		"allow_deletions": false
	}]]
end

local function getCopilotCodeReviewRulesetJson(): string
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

local function applyBranchProtection(owner: string, name: string, branch: string, protectionJson: string): boolean
    local tempFile = `/tmp/{branch}-protection.json`
    fs.writeFile(tempFile, protectionJson)

    local ok, _ = ShellHelpers.run("gh", {
        "api",
        `repos/{owner}/{name}/branches/{branch}/protection`,
        "-X",
        "PUT",
        "-H",
        "Accept: application/vnd.github+json",
        "--input",
        tempFile,
    })

    return ok
end

local function setupBranchProtection(config: ProjectConfig)
    printStep("Setting up branch protection rules...")

    local mainOk = applyBranchProtection(config.Owner, config.Name, "main", getMainBranchProtectionJson())
    local releaseOk = applyBranchProtection(config.Owner, config.Name, "release", getReleaseBranchProtectionJson())

    if not mainOk or not releaseOk then
        print(Chalk.yellow("Failed to set branch protection (requires GitHub Pro for private repos)."))
    end
end

local function setupCopilotCodeReview(config: ProjectConfig)
    printStep("Setting up Copilot code review...")

    local tempFile = "/tmp/copilot-ruleset.json"
    fs.writeFile(tempFile, getCopilotCodeReviewRulesetJson())

    local ok, _ = ShellHelpers.run("gh", {
        "api",
        `repos/{config.Owner}/{config.Name}/rulesets`,
        "-X",
        "POST",
        "-H",
        "Accept: application/vnd.github+json",
        "--input",
        tempFile,
    })

    if ok then
        print(Chalk.dim("Copilot code review enabled for all PRs..."))
    else
        print(Chalk.yellow("Failed to set up Copilot code review (requires Copilot subscription)."))
    end
end

local function setupWallyToken(config: ProjectConfig)
    local wallyToken = WallyHelpers.getAuthToken()

    if not wallyToken then
        printWallyTokenWarning(config.Owner, config.Name)
        return
    end

    printStep("Setting up Wally authentication token...")

    local ok, _ = ShellHelpers.run("gh", {
        "secret",
        "set",
        "WALLY_AUTH",
        "--body",
        wallyToken,
        "--repo",
        `{config.Owner}/{config.Name}`,
    })

    if ok then
        print(Chalk.dim("Wally token configured for publishing..."))
    else
        print(Chalk.yellow("Failed to set Wally token. Set it manually in the repository settings."))
    end
end

local function setupGithubRepository(config: ProjectConfig)
    createGithubRepository(config)
    configureRepoSettings(config)
    createReleaseBranch(config)
    setupBranchProtection(config)
    setupCopilotCodeReview(config)

    -- Skip Wally token setup for private packages (they won't be published to Wally)
    if not config.IsPrivatePackage then
        setupWallyToken(config)
    end
end

------------------------------------------------------------------------------------------
-- Main Orchestration Functions
------------------------------------------------------------------------------------------

local function setupLocalProject(config: ProjectConfig)
    cloneTemplate(config.ProjectPath)
    initializeGitRepo(config.ProjectPath)
    updateConfigFiles(config)
    setupSubmodules(config)
    copyWorkflows(config)
    installTools(config)
    installDependencies(config)
    createInitialCommit(config)
end

local function createProject(config: ProjectConfig)
    printCreatingProject(config.Name, config.ProjectPath)
    setupLocalProject(config)

    if config.CreateGithubRepo then
        setupGithubRepository(config)
    end

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
            Type = "string",
        }),
        Flag.new({
            Name = "description",
            Shorthand = "d",
            Description = "Project description.",
            Type = "string",
        }),
        Flag.new({
            Name = "owner",
            Shorthand = "o",
            Description = "GitHub owner or organization.",
            Type = "string",
        }),
        Flag.new({
            Name = "github",
            Description = "Create a GitHub repository (skips confirmation prompt).",
        }),
        Flag.new({
            Name = "private",
            Description = "Create a private repository.",
        }),
        Flag.new({
            Name = "nogithub",
            Description = "Skip GitHub repository creation.",
        }),
        Flag.new({
            Name = "path",
            Shorthand = "p",
            Description = "Directory to create project in.",
            Type = "string",
        }),
        Flag.new({
            Name = "privatepackage",
            Description = "Make this a private package (will not publish to Wally).",
        }),
    },
    Impl = function(_args, flags)
        GitHubHelpers.ensureInstalled()
        printHeader()
        local config = gatherProjectConfig(flags)
        createProject(config)
    end,
})

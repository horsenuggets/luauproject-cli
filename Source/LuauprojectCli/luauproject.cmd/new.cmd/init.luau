--[[

new.cmd

Creates a new Luau project from the luau-package-template. Supports both interactive
prompts and command-line flags.

]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local Chalk = require("@packages/Chalk")
local Commandline = require("@packages/Commandline")
local Command = Commandline.Command
local Flag = Commandline.Flag

------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------

local TEMPLATE_REPO = "horsenuggets/luau-package-template"

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
}

------------------------------------------------------------------------------------------
-- Utility Functions
------------------------------------------------------------------------------------------

local function prompt(message: string, default: string?): string
    local displayMessage = message
    if default then
        displayMessage = `{message} [{Chalk.dim(default)}]`
    end

    local result = stdio.prompt("text", displayMessage)
    if result == "" and default then
        return default
    end
    return result
end

local function promptConfirm(message: string, default: boolean?): boolean
    local defaultStr = if default == true then "Y/n" elseif default == false then "y/N" else "y/n"
    local result = stdio.prompt("text", `{message} ({Chalk.dim(defaultStr)})`)

    if result == "" and default ~= nil then
        return default
    end

    return result:lower() == "y" or result:lower() == "yes"
end

local function run(command: string, args: { string }?, cwd: string?): (boolean, string)
    local result = process.exec(command, args or {}, {
        cwd = cwd,
    })

    if result.ok then
        return true, result.stdout
    else
        return false, result.stderr
    end
end

local function runOrFail(command: string, args: { string }?, cwd: string?): string
    local ok, output = run(command, args, cwd)
    if not ok then
        stdio.ewrite(Chalk.red(`Error running command: {command}\n`))
        stdio.ewrite(`{output}\n`)
        process.exit(1)
    end
    return output
end

local function toKebabCase(str: string): string
    return str:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
end

local function toPascalCase(kebab: string): string
    return kebab:gsub("^%l", string.upper):gsub("%-(%l)", function(c)
        return c:upper()
    end)
end

local function getGitHubUsername(): string?
    local result = process.exec("gh", { "api", "user", "--jq", ".login" })
    if result.ok then
        local username = result.stdout:gsub("%s+$", "")
        if username ~= "" then
            return username
        end
    end
    return nil
end

local function getGitHubOrganizations(): { string }
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

    local username = getGitHubUsername()
    if username then
        table.insert(owners, username)
    end

    local orgs = getGitHubOrganizations()
    for _, org in ipairs(orgs) do
        table.insert(owners, org)
    end

    return owners
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
    print(Chalk.yellow("WALLY_AUTH_TOKEN not found in environment."))
    print(Chalk.dim("To enable Wally publishing, add the secret manually:"))
    print(Chalk.dim(`> gh secret set WALLY_AUTH_TOKEN --repo {owner}/{name}`))
end

------------------------------------------------------------------------------------------
-- Input Gathering Functions
------------------------------------------------------------------------------------------

local function getProjectName(flags: any): string
    if flags.name.Value and flags.name.Value ~= "" then
        local corrected = toKebabCase(flags.name.Value)
        if corrected == "" then
            stdio.ewrite(Chalk.red("Project name is empty after correction.\n"))
            process.exit(1)
        end
        if corrected ~= flags.name.Value then
            print(`Using "{Chalk.bold(corrected)}" as the project name.`)
        end
        return corrected
    end

    while true do
        local input = prompt("Project name (kebab-case)")
        if input == "" then
            stdio.ewrite(Chalk.red("Project name is required.\n"))
            process.exit(1)
        end

        local corrected = toKebabCase(input)
        if corrected == "" then
            print(Chalk.yellow("Project name is empty after correction. Please try again."))
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
    return prompt("Description", "A Luau package.")
end

local function getOwner(flags: any): string
    if flags.owner.Value and flags.owner.Value ~= "" then
        return flags.owner.Value
    end

    local owners = getAvailableOwners()

    if #owners == 0 then
        local result = prompt("GitHub owner or organization")
        if result == "" then
            stdio.ewrite(Chalk.red("GitHub owner is required.\n"))
            process.exit(1)
        end
        return result
    elseif #owners == 1 then
        return prompt("GitHub owner or organization", owners[1])
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
    if flags.private.Value then
        return true
    end
    return promptConfirm("Create GitHub repository?", true)
end

local function shouldBePrivate(flags: any, createGithubRepo: boolean): boolean
    if not createGithubRepo then
        return false
    end
    if flags.private.Value then
        return true
    end
    if flags.nogithub.Value then
        return false
    end
    return promptConfirm("Private repository?", false)
end

local function getBasePath(flags: any): string
    local basePath = flags.path.Value or process.cwd
    return basePath:gsub("/$", "")
end

local function gatherProjectConfig(flags: any): ProjectConfig
    local name = getProjectName(flags)
    local description = getDescription(flags)
    local owner = getOwner(flags)
    local createGithubRepo = shouldCreateGithubRepo(flags)
    local isPrivate = shouldBePrivate(flags, createGithubRepo)
    local basePath = getBasePath(flags)

    return {
        Name = name,
        PascalName = toPascalCase(name),
        Description = description,
        Owner = owner,
        ProjectPath = `{basePath}/{name}`,
        CreateGithubRepo = createGithubRepo,
        IsPrivate = isPrivate,
    }
end

------------------------------------------------------------------------------------------
-- Project Setup Functions
------------------------------------------------------------------------------------------

local function cloneTemplate(projectPath: string)
    printStep("Cloning template repository...")
    runOrFail("gh", { "repo", "clone", TEMPLATE_REPO, projectPath, "--", "--depth=1" })
    fs.removeDir(`{projectPath}/.git`)
end

local function initializeGitRepo(projectPath: string)
    printStep("Initializing git repository...")
    runOrFail("git", { "init" }, projectPath)
end

local function updateWallyToml(config: ProjectConfig)
    replaceInFile(`{config.ProjectPath}/wally.toml`, {
        { "horsenuggets/luau%-package%-template", `{config.Owner}/{config.Name}` },
        { "luau%-package%-template", config.Name },
        { "A template for creating Luau packages%.", config.Description },
    })
end

local function updateProjectJson(config: ProjectConfig)
    replaceInFile(`{config.ProjectPath}/default.project.json`, {
        { '"luau%-package%-template"', `"{config.Name}"` },
        { "Source/LuauPackageTemplate", `Source/{config.PascalName}` },
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
    fs.writeFile(`{config.ProjectPath}/VERSION`, "0.0.1\n")
    fs.writeFile(`{config.ProjectPath}/CHANGELOG.md`, "# Changelog\n\n## 0.0.1\n\n- Initial release\n")
end

local function updateConfigFiles(config: ProjectConfig)
    printStep("Updating project configuration files...")
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

    runOrFail("git", {
        "submodule",
        "add",
        "https://github.com/horsenuggets/claude-md-luau.git",
        "Submodules/claude-md-luau",
    }, config.ProjectPath)

    runOrFail("git", {
        "submodule",
        "add",
        "https://github.com/horsenuggets/luau-cicd.git",
        "Submodules/luau-cicd",
    }, config.ProjectPath)
end

local function installDependencies(config: ProjectConfig)
    printStep("Installing wally dependencies...")
    runOrFail("wally", { "install" }, config.ProjectPath)
end

local function createInitialCommit(config: ProjectConfig)
    printStep("Creating initial commit...")
    runOrFail("git", { "add", "-A" }, config.ProjectPath)
    runOrFail("git", { "commit", "-m", "Initial commit from luauproject-cli" }, config.ProjectPath)
end

------------------------------------------------------------------------------------------
-- GitHub Setup Functions
------------------------------------------------------------------------------------------

local function createGithubRepository(config: ProjectConfig)
    printStep("Creating GitHub repository...")

    local visibility = if config.IsPrivate then "--private" else "--public"
    runOrFail("gh", {
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

    runOrFail("gh", {
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
    runOrFail("git", { "checkout", "-b", "release" }, config.ProjectPath)
    runOrFail("git", { "push", "-u", "origin", "release" }, config.ProjectPath)
    runOrFail("git", { "checkout", "main" }, config.ProjectPath)
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
		"required_pull_request_reviews": {
			"dismiss_stale_reviews": true,
			"require_code_owner_reviews": false,
			"required_approving_review_count": 1
		},
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
		"required_pull_request_reviews": {
			"dismiss_stale_reviews": true,
			"require_code_owner_reviews": false,
			"required_approving_review_count": 1
		},
		"restrictions": null,
		"allow_force_pushes": false,
		"allow_deletions": false
	}]]
end

local function applyBranchProtection(owner: string, name: string, branch: string, protectionJson: string): boolean
    local tempFile = `/tmp/{branch}-protection.json`
    fs.writeFile(tempFile, protectionJson)

    local ok, _ = run("gh", {
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

local function setupWallyToken(config: ProjectConfig)
    local wallyToken = process.env.WALLY_AUTH_TOKEN

    if not wallyToken or wallyToken == "" then
        printWallyTokenWarning(config.Owner, config.Name)
        return
    end

    printStep("Setting up Wally authentication token...")

    local ok, _ = run("gh", {
        "secret",
        "set",
        "WALLY_AUTH_TOKEN",
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
    setupWallyToken(config)
end

------------------------------------------------------------------------------------------
-- Main Orchestration Functions
------------------------------------------------------------------------------------------

local function setupLocalProject(config: ProjectConfig)
    cloneTemplate(config.ProjectPath)
    initializeGitRepo(config.ProjectPath)
    updateConfigFiles(config)
    setupSubmodules(config)
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
    Description = "Create a new Luau project from template",
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
    },
    Impl = function(_args, flags)
        printHeader()
        local config = gatherProjectConfig(flags)
        createProject(config)
    end,
})

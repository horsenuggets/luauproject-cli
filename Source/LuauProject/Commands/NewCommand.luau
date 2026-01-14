--[[
NewCommand

Creates a new Luau project from the luau-package-template.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local Commandline = require("@packages/Commandline")
local Command = Commandline.Command
local _Arg = Commandline.Arg
local Flag = Commandline.Flag

local TEMPLATE_REPO = "horsenuggets/luau-package-template"
local GITHUB_ORG = "horsenuggets"

local function prompt(message: string, default: string?): string
	local displayMessage = message
	if default then
		displayMessage = `{message} [{default}]`
	end

	local result = stdio.prompt("text", displayMessage)
	if result == "" and default then
		return default
	end
	return result
end

local function promptConfirm(message: string, default: boolean?): boolean
	local defaultStr = if default == true then "Y/n" elseif default == false then "y/N" else "y/n"
	local result = stdio.prompt("text", `{message} ({defaultStr})`)

	if result == "" and default ~= nil then
		return default
	end

	return result:lower() == "y" or result:lower() == "yes"
end

local function run(command: string, args: { string }?, cwd: string?): (boolean, string)
	local result = process.spawn(command, args or {}, {
		cwd = cwd,
		shell = true,
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
		stdio.ewrite(`Error running command: {command}\n{output}\n`)
		process.exit(1)
	end
	return output
end

local function kebabCase(str: string): string
	return str:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
end

local function replaceInFile(filePath: string, replacements: { [string]: string })
	local content = fs.readFile(filePath)
	for find, replace in replacements do
		content = content:gsub(find, replace)
	end
	fs.writeFile(filePath, content)
end

local NewCommand = Command.new({
	Name = "new",
	Description = "Create a new Luau project from template",
	Flags = {
		Flag.new({
			Name = "path",
			Shorthand = "p",
			Description = "Directory to create project in (default: current directory)",
			Type = "string",
		}),
	},
	Impl = function(_args, flags)
		print("\n🚀 Create a new Luau project\n")

		-- Get project details
		local name = prompt("Project name (kebab-case)")
		if name == "" then
			stdio.ewrite("Project name is required.\n")
			process.exit(1)
		end
		name = kebabCase(name)

		local description = prompt("Description", "A Luau package")
		local author = prompt("Author/GitHub username", GITHUB_ORG)
		local createGithubRepo = promptConfirm("Create GitHub repository?", true)
		local isPrivate = false
		if createGithubRepo then
			isPrivate = promptConfirm("Private repository?", false)
		end

		-- Determine target directory
		local basePath = flags.path.Value or process.cwd
		local projectPath = `{basePath}/{name}`

		print(`\nCreating project "{name}" at {projectPath}...\n`)

		-- Clone template
		print("📦 Cloning template...")
		runOrFail("gh", { "repo", "clone", TEMPLATE_REPO, projectPath, "--", "--depth=1" })

		-- Remove template's .git directory
		fs.removeDir(`{projectPath}/.git`)

		-- Initialize fresh git repo
		print("🔧 Initializing git repository...")
		runOrFail("git", { "init" }, projectPath)

		-- Update wally.toml
		print("📝 Updating project files...")
		replaceInFile(`{projectPath}/wally.toml`, {
			["luau%-package%-template"] = name,
			["A Luau package template"] = description,
			["horsenuggets"] = author,
		})

		-- Update VERSION
		fs.writeFile(`{projectPath}/VERSION`, "0.0.1\n")

		-- Update CHANGELOG
		fs.writeFile(`{projectPath}/CHANGELOG.md`, "# Changelog\n\n## 0.0.1\n\n- Initial release\n")

		-- Rename source directory if needed
		if fs.isDir(`{projectPath}/Source/PackageName`) then
			-- The template might have a placeholder source dir
			local sourceDir = `{projectPath}/Source`
			for _, entry in fs.readDir(sourceDir) do
				if entry ~= ".git" and fs.isDir(`{sourceDir}/{entry}`) then
					-- Rename to proper name
					local pascalName = name:gsub("^%l", string.upper):gsub("-%l", function(s)
						return s:sub(2):upper()
					end)
					if entry ~= pascalName then
						fs.move(`{sourceDir}/{entry}`, `{sourceDir}/{pascalName}`)
					end
					break
				end
			end
		end

		-- Initialize submodules
		print("📚 Setting up submodules...")
		runOrFail("git", {
			"submodule",
			"add",
			"https://github.com/horsenuggets/claude-md-luau.git",
			"Submodules/claude-md-luau",
		}, projectPath)
		runOrFail("git", {
			"submodule",
			"add",
			"https://github.com/horsenuggets/luau-cicd.git",
			"Submodules/luau-cicd",
		}, projectPath)

		-- Install dependencies
		print("📥 Installing dependencies...")
		runOrFail("wally", { "install" }, projectPath)

		-- Initial commit
		print("💾 Creating initial commit...")
		runOrFail("git", { "add", "-A" }, projectPath)
		runOrFail("git", { "commit", "-m", "Initial commit from luauproject-cli" }, projectPath)

		if createGithubRepo then
			print("🌐 Creating GitHub repository...")

			local visibility = if isPrivate then "--private" else "--public"
			runOrFail("gh", {
				"repo",
				"create",
				`{author}/{name}`,
				visibility,
				"--source",
				projectPath,
				"--push",
			})

			-- Configure repository settings
			print("⚙️  Configuring repository settings...")

			-- Set squash-only merging
			runOrFail("gh", {
				"api",
				`repos/{author}/{name}`,
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
			})

			-- Create release branch
			print("🌿 Creating release branch...")
			runOrFail("git", { "checkout", "-b", "release" }, projectPath)
			runOrFail("git", { "push", "-u", "origin", "release" }, projectPath)
			runOrFail("git", { "checkout", "main" }, projectPath)

			-- Set up branch protection for main
			print("🔒 Setting up branch protection...")
			local mainProtection = [[{
				"required_status_checks": {
					"strict": true,
					"checks": [
						{"context": "Check formatting"},
						{"context": "Run tests"},
						{"context": "Static analysis"},
						{"context": "Validate branch name"}
					]
				},
				"enforce_admins": true,
				"required_pull_request_reviews": {
					"dismiss_stale_reviews": false,
					"require_code_owner_reviews": false,
					"required_approving_review_count": 0
				},
				"restrictions": null,
				"allow_force_pushes": false,
				"allow_deletions": false
			}]]

			local tempMainFile = "/tmp/main-protection.json"
			fs.writeFile(tempMainFile, mainProtection)
			runOrFail("gh", {
				"api",
				`repos/{author}/{name}/branches/main/protection`,
				"-X",
				"PUT",
				"-H",
				"Accept: application/vnd.github+json",
				"--input",
				tempMainFile,
			})

			-- Set up branch protection for release
			local releaseProtection = [[{
				"required_status_checks": {
					"strict": true,
					"checks": [
						{"context": "Validate PR title"},
						{"context": "Verify diff matches main"},
						{"context": "Check formatting"},
						{"context": "Run tests"},
						{"context": "Static analysis"},
						{"context": "Validate version"}
					]
				},
				"enforce_admins": true,
				"required_pull_request_reviews": {
					"dismiss_stale_reviews": false,
					"require_code_owner_reviews": false,
					"required_approving_review_count": 0
				},
				"restrictions": null,
				"allow_force_pushes": false,
				"allow_deletions": false
			}]]

			local tempReleaseFile = "/tmp/release-protection.json"
			fs.writeFile(tempReleaseFile, releaseProtection)
			runOrFail("gh", {
				"api",
				`repos/{author}/{name}/branches/release/protection`,
				"-X",
				"PUT",
				"-H",
				"Accept: application/vnd.github+json",
				"--input",
				tempReleaseFile,
			})

			print(`\n✅ Project created successfully!`)
			print(`\n📍 Location: {projectPath}`)
			print(`🔗 Repository: https://github.com/{author}/{name}`)
		else
			print(`\n✅ Project created successfully!`)
			print(`\n📍 Location: {projectPath}`)
		end

		print("\n📋 Next steps:")
		print(`   cd {name}`)
		print("   # Start coding!")
		print("")
	end,
})

return NewCommand

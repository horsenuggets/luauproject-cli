#!/usr/bin/env -S lune run

--[[

BuildExecutable

Compiles the luauproject CLI to a standalone executable. Embeds the VERSION at build time
since compiled executables cannot read files at runtime.

--]]

local Chalk = require("@packages/Chalk")
local fs = require("@lune/fs")
local process = require("@lune/process")

-- Use script global to resolve paths relative to this script's location
-- script.Parent = Scripts/, script.Parent.Parent = project root
local PROJECT_ROOT = tostring(script.Parent.Parent)
local BUILD_DIR = `{PROJECT_ROOT}/Build`
local ENTRY_POINT = `{PROJECT_ROOT}/Source/LuauprojectCli`
local GENERATE_VERSION_SCRIPT = `{PROJECT_ROOT}/Scripts/GenerateVersion.luau`
local OUTPUT_NAME = "luauproject"

local function run(command: string, args: { string }, options: { cwd: string? }?): (boolean, string)
    local result = process.exec(command, args, options)
    if result.ok then
        return true, result.stdout
    else
        return false, result.stderr
    end
end

-- Compiled Lune executables on Windows resolve relative paths
-- ("./", "../", "@self/") against the drive root instead of the
-- virtual filesystem, breaking requires at runtime. This
-- function rewrites all relative requires to use alias paths
-- which go through Lune's alias resolution and work correctly
-- on all platforms.
local ALIAS_DIRS = {
    { alias = "@packages", dir = "Packages" },
    { alias = "@luauprojectcli", dir = "Source/LuauprojectCli" },
    { alias = "@tests", dir = "Tests" },
}

local function getParentDir(path: string): string
    return path:match("^(.*)/[^/]+$") or ""
end

-- Find the alias for a file path relative to PROJECT_ROOT
local function resolveAlias(projectRelPath: string): (string?, string?)
    for _, entry in ALIAS_DIRS do
        local prefix = entry.dir .. "/"
        if projectRelPath:sub(1, #prefix) == prefix then
            local rest = projectRelPath:sub(#prefix + 1)
            return entry.alias, rest
        end
    end
    return nil
end

type FileBackup = { path: string, content: string }

local function patchRelativeRequires(): { FileBackup }
    local backups: { FileBackup } = {}
    local patched = 0

    local function processFile(filePath: string, projectRelPath: string)
        local content = fs.readFile(filePath)
        local originalContent = content
        local modified = false
        local fileName = filePath:match("([^/]+)$") or ""
        local isInit = fileName == "init.luau"
        local fileDir = getParentDir(projectRelPath)

        -- Replace @self requires (used in init.luau files, @self
        -- = containing directory)
        if content:find("@self/", 1, true) then
            local selfDir = fileDir
            local newContent = content:gsub('require%("@self/([^"]+)"', function(target)
                local fullPath = if selfDir == "" then target else `{selfDir}/{target}`
                local alias, rest = resolveAlias(fullPath)
                if alias then
                    modified = true
                    return `require("{alias}/{rest}"`
                end
                return nil -- no change
            end)
            content = newContent
        end

        -- Replace "./" relative requires
        if content:find('require("./', 1, true) then
            local newContent = content:gsub('require%("(%./[^"]+)"', function(relTarget)
                local target = relTarget:sub(3)
                local fullPath = if fileDir == "" then target else `{fileDir}/{target}`
                local alias, rest = resolveAlias(fullPath)
                if alias then
                    modified = true
                    return `require("{alias}/{rest}"`
                end
                return nil
            end)
            content = newContent
        end

        -- Replace "../" relative requires
        if content:find('require("../', 1, true) then
            local newContent = content:gsub('require%("(%.%./[^"]+)"', function(relTarget)
                local target = relTarget:sub(4)
                local parentDir = getParentDir(fileDir)
                local fullPath = if parentDir == "" then target else `{parentDir}/{target}`
                local alias, rest = resolveAlias(fullPath)
                if alias then
                    modified = true
                    return `require("{alias}/{rest}"`
                end
                return nil
            end)
            content = newContent
        end

        if modified then
            table.insert(backups, { path = filePath, content = originalContent })
            fs.writeFile(filePath, content)
            patched += 1
        end
    end

    local function processDir(dirPath: string, projectRelPrefix: string)
        for _, entry in fs.readDir(dirPath) do
            local fullPath = `{dirPath}/{entry}`
            local relPath = if projectRelPrefix == "" then entry else `{projectRelPrefix}/{entry}`

            if fs.isDir(fullPath) then
                processDir(fullPath, relPath)
            elseif entry:match("%.luau$") then
                processFile(fullPath, relPath)
            end
        end
    end

    -- Delete sub-package .luaurc files so @packages falls
    -- through to the project root definition
    local function deleteSubLuaurcs(dirPath: string)
        for _, entry in fs.readDir(dirPath) do
            local fullPath = `{dirPath}/{entry}`
            if fs.isDir(fullPath) then
                deleteSubLuaurcs(fullPath)
            elseif entry == ".luaurc" then
                table.insert(backups, { path = fullPath, content = fs.readFile(fullPath) })
                fs.removeFile(fullPath)
            end
        end
    end

    local packagesIndexDir = `{PROJECT_ROOT}/Packages/_Index`
    if fs.isDir(packagesIndexDir) then
        deleteSubLuaurcs(packagesIndexDir)
    end

    for _, entry in ALIAS_DIRS do
        local dirPath = `{PROJECT_ROOT}/{entry.dir}`
        if fs.isDir(dirPath) then
            processDir(dirPath, entry.dir)
        end
    end

    if patched > 0 then
        print(`Patched {patched} {if patched == 1 then "file" else "files"} for cross-platform compatibility.`)
    end

    return backups
end

local function restoreFiles(backups: { FileBackup })
    for _, backup in backups do
        fs.writeFile(backup.path, backup.content)
    end
end

local function buildExecutable()
    local target = process.args[1]

    print()
    print(`Building {Chalk.bold(Chalk.blueBright("luauproject"))} executable...`)

    -- Generate version module (run from project root so rokit shim finds manifest)
    local versionResult = process.exec("lune", { "run", GENERATE_VERSION_SCRIPT }, { cwd = PROJECT_ROOT })
    if not versionResult.ok then
        print(Chalk.red("Failed to generate version module."))
        print(versionResult.stderr)
        process.exit(1)
    end

    local entryInitPath = `{ENTRY_POINT}/init.luau`
    if not fs.isFile(entryInitPath) then
        print(Chalk.red(`Entry point "{entryInitPath}" not found.`))
        process.exit(1)
    end

    local backups = patchRelativeRequires()

    -- Ensure Build directory exists
    if not fs.isDir(BUILD_DIR) then
        fs.writeDir(BUILD_DIR)
    end

    -- Remove existing binary to avoid corruption issues
    local outputPath = `{BUILD_DIR}/{OUTPUT_NAME}`
    if fs.isFile(outputPath) then
        fs.removeFile(outputPath)
    end
    if fs.isFile(`{outputPath}.exe`) then
        fs.removeFile(`{outputPath}.exe`)
    end

    -- Strip shebang for building (lune build doesn't support shebangs).
    -- Replace init.luau in-place (will be restored from backups).
    local entryContent = fs.readFile(entryInitPath)
    local strippedContent = entryContent:gsub("^#![^\n]*\n", "")
    table.insert(backups, { path = entryInitPath, content = entryContent })
    fs.writeFile(entryInitPath, strippedContent)

    local args = { "build", ENTRY_POINT, "--output", outputPath }

    if target then
        table.insert(args, "--target")
        table.insert(args, target)
        print(`Target is {Chalk.dim(target)}.`)
    else
        print(`Target is {Chalk.dim(`{process.os}-{process.arch}`)}.`)
    end

    print(`Entry point is {Chalk.dim(ENTRY_POINT)}.`)

    local ok, output = run("lune", args, { cwd = PROJECT_ROOT })

    -- Restore patched files (including shebang-stripped init.luau)
    restoreFiles(backups)

    if ok then
        local outputFile = outputPath
        if target and target:find("windows") then
            outputFile = `{outputPath}.exe`
        elseif not target and process.os == "windows" then
            outputFile = `{outputPath}.exe`
        end

        if fs.isFile(outputFile) then
            print(`Output file is {Chalk.dim(outputFile)}.`)
        end

        print()
        print(Chalk.bold(Chalk.greenBright("Build completed successfully!")))
    else
        print(Chalk.redBright("Build failed."))
        print(output)
        process.exit(1)
    end
end

buildExecutable()

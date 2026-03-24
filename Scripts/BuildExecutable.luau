#!/usr/bin/env -S lune run

--[[

BuildExecutable

Compiles the luauproject CLI to a standalone executable. Embeds the VERSION
at build time since compiled executables cannot read files at runtime.

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

local function buildExecutable()
    local target = process.args[1]

    print()
    print(`Building {Chalk.bold(Chalk.blueBright(OUTPUT_NAME))} executable...`)

    -- Generate version module (run from project root so rokit shim finds
    -- manifest)
    local versionResult = process.exec("lune", { "run", GENERATE_VERSION_SCRIPT }, { cwd = PROJECT_ROOT })
    if not versionResult.ok then
        print(Chalk.red("Failed to generate version module."))
        print(versionResult.stderr)
        process.exit(1)
    end

    if not fs.isDir(ENTRY_POINT) then
        print(Chalk.red(`Entry point "{ENTRY_POINT}" not found.`))
        process.exit(1)
    end

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

    local args = { "build", ENTRY_POINT, "--output", outputPath }

    if target then
        table.insert(args, "--target")
        table.insert(args, target)
        print(`Target is {Chalk.dim(target)}.`)
    else
        print(`Target is {Chalk.dim(`{process.os}-{process.arch}`)}.`)
    end

    print(`Entry point is {Chalk.dim(ENTRY_POINT)}.`)

    local result = process.exec("lune", args, { cwd = PROJECT_ROOT })

    if result.ok then
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
        print(result.stderr)
        process.exit(1)
    end
end

buildExecutable()

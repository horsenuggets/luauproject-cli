#!/usr/bin/env -S lune run

--[[

BuildLauncher

Compiles the luauproject launcher to a standalone executable. The launcher is a minimal
executable that delegates to the currently installed version.

--]]

local Chalk = require("@packages/Chalk")
local fs = require("@lune/fs")
local process = require("@lune/process")

-- Use script global to resolve paths relative to this script's location
-- script.Parent = Scripts/, script.Parent.Parent = project root
local PROJECT_ROOT = tostring(script.Parent.Parent)
local BUILD_DIR = `{PROJECT_ROOT}/Build`
local ENTRY_POINT = `{PROJECT_ROOT}/Source/Launcher/luauproject-launcher.luau`
local OUTPUT_NAME = "luauproject-launcher"

local function run(command: string, args: { string }, options: { cwd: string? }?): (boolean, string)
    local result = process.exec(command, args, options)
    if result.ok then
        return true, result.stdout
    else
        return false, result.stderr
    end
end

local function buildLauncher()
    local target = process.args[1]

    print()
    print(`Building {Chalk.bold(Chalk.blueBright("luauproject-launcher"))} executable...`)

    if not fs.isFile(ENTRY_POINT) then
        print(Chalk.red(`Entry point "{ENTRY_POINT}" not found.`))
        process.exit(1)
    end

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
        print(Chalk.bold(Chalk.greenBright("Launcher build completed successfully!")))
    else
        print(Chalk.redBright("Launcher build failed."))
        print(output)
        process.exit(1)
    end
end

buildLauncher()

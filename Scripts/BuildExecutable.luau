#!/usr/bin/env -S lune run

--[[

BuildExecutable

Compiles the luauproject CLI to a standalone executable. Embeds the VERSION at build time
since compiled executables cannot read files at runtime.

--]]

local Chalk = require("@packages/Chalk")
local fs = require("@lune/fs")
local process = require("@lune/process")

local ENTRY_POINT = "Source/LuauprojectCli/luauproject-cli.luau"
local BUILD_DIR = "Build"
local OUTPUT_NAME = "luauproject"

local function run(command: string, args: { string }): (boolean, string)
    local result = process.exec(command, args)
    if result.ok then
        return true, result.stdout
    else
        return false, result.stderr
    end
end

local function buildExecutable()
    local target = process.args[1]

    print()
    print(`Building {Chalk.bold(Chalk.blueBright("luauproject"))} executable...`)

    -- Generate version module
    local versionResult = process.exec("lune", { "run", "Scripts/GenerateVersion.luau" })
    if not versionResult.ok then
        print(Chalk.red("Failed to generate version module."))
        print(versionResult.stderr)
        process.exit(1)
    end

    if not fs.isFile(ENTRY_POINT) then
        print(Chalk.red(`Entry point "{ENTRY_POINT}" not found.`))
        process.exit(1)
    end

    -- Ensure Build directory exists
    if not fs.isDir(BUILD_DIR) then
        fs.writeDir(BUILD_DIR)
    end

    -- Strip shebang for building (lune build doesn't support shebangs).
    -- Temp file goes in same directory so relative requires resolve correctly.
    local entryContent = fs.readFile(ENTRY_POINT)
    local entryDir = ENTRY_POINT:match("(.*/)")
    local tempEntryPoint = `{entryDir}_build_entry.luau`
    local strippedContent = entryContent:gsub("^#![^\n]*\n", "")
    fs.writeFile(tempEntryPoint, strippedContent)

    local outputPath = `{BUILD_DIR}/{OUTPUT_NAME}`
    local args = { "build", tempEntryPoint, "--output", outputPath }

    if target then
        table.insert(args, "--target")
        table.insert(args, target)
        print(`Target is {Chalk.dim(target)}.`)
    else
        print(`Target is {Chalk.dim(`{process.os}-{process.arch}`)}.`)
    end

    print(`Entry point is {Chalk.dim(ENTRY_POINT)}.`)

    local ok, output = run("lune", args)

    -- Clean up temporary entry point
    if fs.isFile(tempEntryPoint) then
        fs.removeFile(tempEntryPoint)
    end

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

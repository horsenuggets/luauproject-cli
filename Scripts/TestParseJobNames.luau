#!/usr/bin/env -S lune run

--[[

TestParseJobNames

Tests the parseJobNames function against real workflow files to verify
it correctly extracts CI job names for branch protection.

--]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

-- Copy of parseJobNames from NewCommand/init.luau for isolated testing
local function parseJobNames(workflowPath: string): { string }
    local names: { string } = {}
    if not fs.isFile(workflowPath) then
        return names
    end

    local content = fs.readFile(workflowPath)
    local inJobs = false
    local indentUnit = 0
    local inJob = false

    for line in content:gmatch("[^\n]+") do
        if line:match("^jobs:%s*$") then
            inJobs = true
            continue
        end

        if not inJobs then
            continue
        end

        if line:match("^%S") then
            break
        end

        if line:match("^%s*$") then
            continue
        end

        local spaces = #(line:match("^( *)") or "")

        if indentUnit == 0 and spaces > 0 then
            indentUnit = spaces
        end

        if indentUnit == 0 then
            continue
        end

        if spaces == indentUnit and line:match("^%s+[%w_-]+:%s*$") then
            inJob = true
            continue
        end

        if inJob and spaces == indentUnit * 2 then
            local jobName = line:match("^%s+name:%s*(.+)%s*$")
            if jobName then
                if not jobName:match("%${{") then
                    table.insert(names, jobName)
                end
                inJob = false
            end
        end

        if spaces <= indentUnit then
            inJob = false
        end
    end

    return names
end

local passed = 0
local failed = 0

local function test(description: string, actual: { string }, expected: { string })
    local ok = #actual == #expected
    if ok then
        for i, v in actual do
            if v ~= expected[i] then
                ok = false
                break
            end
        end
    end

    if ok then
        passed += 1
        print(stdio.color("green") .. "[PASS]" .. stdio.color("reset") .. " " .. description)
    else
        failed += 1
        print(stdio.color("red") .. "[FAIL]" .. stdio.color("reset") .. " " .. description)
        print("  Expected:")
        for _, v in expected do
            print("    - " .. v)
        end
        print("  Got:")
        for _, v in actual do
            print("    - " .. v)
        end
    end
end

-- Test 1: Luau template CI (2-space indent)
local luauCi = "Submodules/luau-cicd/Templates/workflows/ci.yml"
test("Luau template CI workflow (2-space)", parseJobNames(luauCi), {
    "Validate branch name",
    "Check formatting",
    "Run tests",
    "Static analysis",
    "Check version match",
})

-- Test 2: Luau template release-checks (2-space indent)
local luauRelease = "Submodules/luau-cicd/Templates/workflows/release-checks.yml"
test("Luau template release-checks workflow (2-space)", parseJobNames(luauRelease), {
    "Validate PR title",
    "Verify diff matches main",
    "Check formatting",
    "Run tests",
    "Static analysis",
    "Validate version",
})

-- Test 3: Write a 4-space indented workflow and parse it
local fourSpaceYaml = [[name: CI

on:
    pull_request:
        branches:
            - main

jobs:
    format:
        name: Check formatting
        runs-on: ubuntu-latest
        steps:
            - name: Checkout code
              uses: actions/checkout@v4

    typecheck:
        name: Type check
        runs-on: ubuntu-latest
        steps:
            - name: Checkout code
              uses: actions/checkout@v4

    build:
        name: Build binary
        runs-on: ubuntu-latest
        steps:
            - name: Build
              run: bun run build
]]

local fourSpacePath = "/tmp/test-4space-ci.yml"
fs.writeFile(fourSpacePath, fourSpaceYaml)
test("4-space indented workflow", parseJobNames(fourSpacePath), {
    "Check formatting",
    "Type check",
    "Build binary",
})

-- Test 4: Workflow with matrix (should skip ${{ }} names)
local matrixYaml = [[name: Build

on:
  push:
    branches:
      - release

jobs:
  build:
    name: Build ${{ matrix.platform }}
    runs-on: ${{ matrix.runner }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

  release:
    name: Create release
    runs-on: ubuntu-latest
    steps:
      - name: Tag
        run: git tag
]]

local matrixPath = "/tmp/test-matrix-ci.yml"
fs.writeFile(matrixPath, matrixYaml)
test("Workflow with matrix names (should skip dynamic names)", parseJobNames(matrixPath), {
    "Create release",
})

-- Test 5: Non-existent file returns empty
test("Non-existent file returns empty", parseJobNames("/tmp/does-not-exist.yml"), {})

-- Test 6: Bloxgen-cli CI workflow (4-space, from the actual project)
local bloxgenCi = "../bloxgen-cli/.github/workflows/ci.yml"
if fs.isFile(bloxgenCi) then
    test("Bloxgen-cli CI workflow (real file, 2-space)", parseJobNames(bloxgenCi), {
        "Validate branch name",
        "Check formatting",
        "Type check",
        "Build binary",
        "Check version match",
    })
else
    print(stdio.color("yellow") .. "[SKIP]" .. stdio.color("reset") .. " Bloxgen-cli CI workflow (file not found)")
end

-- Test 7: Bloxgen-cli release-checks
local bloxgenRelease = "../bloxgen-cli/.github/workflows/release-checks.yml"
if fs.isFile(bloxgenRelease) then
    test("Bloxgen-cli release-checks workflow (real file, 2-space)", parseJobNames(bloxgenRelease), {
        "Validate PR title",
        "Verify diff matches main",
        "Check formatting",
        "Type check",
        "Build binary",
        "Validate version",
    })
else
    print(
        stdio.color("yellow")
            .. "[SKIP]"
            .. stdio.color("reset")
            .. " Bloxgen-cli release-checks workflow (file not found)"
    )
end

-- Summary
print()
print(`{passed} passed, {failed} failed.`)
process.exit(if failed == 0 then 0 else 1)

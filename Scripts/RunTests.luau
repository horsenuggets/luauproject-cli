#!/usr/bin/env -S lune run

--[[

RunTests

Executes all test suites and exits with appropriate status code. Supports running tests
locally or in a Docker container for full isolation.

[Usage]
> Scripts/RunTests.luau              # Run all tests
> Scripts/RunTests.luau --no-docker  # Skip Docker tests
> Scripts/RunTests.luau --docker     # Only run Docker tests

--]]

local Testable = require("@devpackages/Testable")
local process = require("@lune/process")

local UNIT_TESTS = {
    { Name = "BuildTest", Func = require("@tests/BuildTest.spec") },
    { Name = "HelpersTest", Func = require("@tests/HelpersTest.spec") },
    { Name = "StringsTest", Func = require("@tests/StringsTest.spec") },
    { Name = "TestEnvironmentTest", Func = require("@tests/TestEnvironmentTest.spec") },
}

local DOCKER_TESTS = {
    { Name = "NewCommandTest", Func = require("@tests/NewCommandTest.spec") },
}

local function parseArgs(): { noDocker: boolean, dockerOnly: boolean }
    local args = process.args
    local noDocker = false
    local dockerOnly = false

    for _, arg in args do
        if arg == "--no-docker" then
            noDocker = true
        elseif arg == "--docker" then
            dockerOnly = true
        end
    end

    return { noDocker = noDocker, dockerOnly = dockerOnly }
end

local function runTests()
    local options = parseArgs()
    local tests = {}

    if not options.dockerOnly then
        for _, test in UNIT_TESTS do
            table.insert(tests, test)
        end
    end

    if not options.noDocker then
        for _, test in DOCKER_TESTS do
            table.insert(tests, test)
        end
    end

    if #tests == 0 then
        print("No tests to run.")
        process.exit(0)
    end

    Testable.configure({ PrintSkipped = true })
    local _, passed = Testable.run(tests)
    process.exit(if passed then 0 else 1)
end

runTests()

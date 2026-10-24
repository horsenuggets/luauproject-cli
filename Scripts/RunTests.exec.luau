#!/usr/bin/env -S lune run

--[[

RunTests.exec

Executes all test suites and exits with appropriate status code. Supports running tests
locally or in a Docker container for full isolation.

[Usage]
> ./Scripts/RunTests.exec.luau              # Run all tests
> ./Scripts/RunTests.exec.luau --no-docker  # Skip Docker tests
> ./Scripts/RunTests.exec.luau --docker     # Only run Docker tests

--]]

const Testable = require("@devpackages/Testable")
const process = require("@lune/process")

const UNIT_TESTS = {
    { Name = "BuildTest", Func = require("@tests/BuildTest.spec") },
    { Name = "DockerEnvironmentHelpersTest", Func = require("@tests/DockerEnvironmentHelpersTest.spec") },
    { Name = "HelpersTest", Func = require("@tests/HelpersTest.spec") },
    { Name = "LogHelpersTest", Func = require("@tests/LogHelpersTest.spec") },
    { Name = "PathHelpersTest", Func = require("@tests/PathHelpersTest.spec") },
    { Name = "PathValidationTest", Func = require("@tests/PathValidationTest.spec") },
    { Name = "StringsTest", Func = require("@tests/StringsTest.spec") },
    { Name = "TestEnvironmentTest", Func = require("@tests/TestEnvironmentTest.spec") },
}

const DOCKER_TESTS = {
    { Name = "NewCommandTest", Func = require("@tests/NewCommandTest.spec") },
}

const function parseArgs(): { noDocker: boolean, dockerOnly: boolean }
    const args = process.args
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

const RunTests = {}

function RunTests.exec()
    const options = parseArgs()
    const tests = {}

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
    const _, passed = Testable.run(tests)
    process.exit(if passed then 0 else 1)
end

RunTests.exec()

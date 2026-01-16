--[[

RunTests

Executes all test suites and exits with appropriate status code. Supports running tests
locally or in a Docker container for full isolation.

--]]

local Testable = require("@devpackages/Testable")
local process = require("@lune/process")

local TESTS = {
    { Name = "BuildTest", Func = require("@tests/BuildTest.spec") },
    { Name = "HelpersTest", Func = require("@tests/HelpersTest.spec") },
    { Name = "StringsTest", Func = require("@tests/StringsTest.spec") },
    { Name = "TestEnvironmentTest", Func = require("@tests/TestEnvironmentTest.spec") },
}

local function runTests()
    local _, passed = Testable.run(TESTS)
    process.exit(if passed then 0 else 1)
end

runTests()

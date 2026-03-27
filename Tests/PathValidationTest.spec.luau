--[[

PathValidationTest

Tests for project path validation in the new command. Verifies that the CLI correctly
rejects non-empty directories, file conflicts, and validates the --path flag.

--]]

local TestEnvironmentHelpers = require("./Helpers/TestEnvironmentHelpers")

local ALL_FLAGS = {
    "--nogithub",
    "--privatepackage",
    "--description",
    "A test project.",
    "--owner",
    "testowner",
}

local function buildArgs(name: string, path: string): { string }
    local args = { "new", "--name", name, "--path", path }
    for _, flag in ALL_FLAGS do
        table.insert(args, flag)
    end
    return args
end

return function()
    describe("path validation", function()
        it("should fail when directory exists and is not empty", function()
            local env = TestEnvironmentHelpers.create()
            local projectPath = `{env.path}/existing-project`
            env.writeDir("existing-project")
            env.writeFile("existing-project/some-file.txt", "content")
            local result = env.runCli(buildArgs("existing-project", projectPath))
            expect(result.ok).to.equal(false)
            expect(string.find(result.stderr, "already exists and is not empty")).to.be.ok()
            env.cleanup()
        end)

        it("should fail when a file exists at the target path", function()
            local env = TestEnvironmentHelpers.create()
            local projectPath = `{env.path}/blocked-path`
            env.writeFile("blocked-path", "this is a file, not a directory")
            local result = env.runCli(buildArgs("blocked-project", projectPath))
            expect(result.ok).to.equal(false)
            expect(string.find(result.stderr, "file already exists")).to.be.ok()
            env.cleanup()
        end)

        it("should fail when directory has subdirectories", function()
            local env = TestEnvironmentHelpers.create()
            local projectPath = `{env.path}/has-subdirs`
            env.writeDir("has-subdirs")
            env.writeDir("has-subdirs/nested")
            local result = env.runCli(buildArgs("subdir-project", projectPath))
            expect(result.ok).to.equal(false)
            expect(string.find(result.stderr, "already exists and is not empty")).to.be.ok()
            env.cleanup()
        end)

        it("should fail when directory has hidden files", function()
            local env = TestEnvironmentHelpers.create()
            local projectPath = `{env.path}/has-hidden`
            env.writeDir("has-hidden")
            env.writeFile("has-hidden/.gitkeep", "")
            local result = env.runCli(buildArgs("hidden-project", projectPath))
            expect(result.ok).to.equal(false)
            expect(string.find(result.stderr, "already exists and is not empty")).to.be.ok()
            env.cleanup()
        end)

        it("should fail when directory has multiple files", function()
            local env = TestEnvironmentHelpers.create()
            local projectPath = `{env.path}/multi-files`
            env.writeDir("multi-files")
            env.writeFile("multi-files/a.txt", "a")
            env.writeFile("multi-files/b.txt", "b")
            env.writeFile("multi-files/c.txt", "c")
            local result = env.runCli(buildArgs("multi-project", projectPath))
            expect(result.ok).to.equal(false)
            expect(string.find(result.stderr, "already exists and is not empty")).to.be.ok()
            env.cleanup()
        end)

        it("should include the path in the error message", function()
            local env = TestEnvironmentHelpers.create()
            local projectPath = `{env.path}/specific-path-name`
            env.writeDir("specific-path-name")
            env.writeFile("specific-path-name/file.txt", "content")
            local result = env.runCli(buildArgs("specific-project", projectPath))
            expect(result.ok).to.equal(false)
            expect(string.find(result.stderr, "specific%-path%-name")).to.be.ok()
            env.cleanup()
        end)

        it("should not fail when directory exists but is empty", function()
            local env = TestEnvironmentHelpers.create()
            local projectPath = `{env.path}/empty-dir`
            env.writeDir("empty-dir")
            local result = env.runCli(buildArgs("empty-dir-project", projectPath))
            -- Should not fail on validation, but may fail later due to missing
            -- gh/network. The key is that it does NOT fail with the directory
            -- error.
            if not result.ok then
                expect(string.find(result.stderr, "already exists and is not empty")).to.equal(nil)
                expect(string.find(result.stderr, "file already exists")).to.equal(nil)
            end
            env.cleanup()
        end)

        it("should not fail when directory does not exist", function()
            local env = TestEnvironmentHelpers.create()
            local projectPath = `{env.path}/brand-new-dir`
            local result = env.runCli(buildArgs("new-project", projectPath))
            -- Should not fail on validation, but may fail later due to missing
            -- gh/network.
            if not result.ok then
                expect(string.find(result.stderr, "already exists and is not empty")).to.equal(nil)
                expect(string.find(result.stderr, "file already exists")).to.equal(nil)
            end
            env.cleanup()
        end)
    end)
end

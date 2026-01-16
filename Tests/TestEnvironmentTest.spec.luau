--[[

TestEnvironmentTest

Tests for the TestEnvironmentHelpers module to ensure it properly creates isolated test
environments.

--]]

local TestEnvironmentHelpers = require("@tests/Helpers/TestEnvironmentHelpers")

return function()
    describe("TestEnvironmentHelpers", function()
        describe("create", function()
            it("should create a temp directory", function()
                local env = TestEnvironmentHelpers.create()
                expect(env.path).to.be.ok()
                expect(env.path:match("^/tmp/")).to.be.ok()
                env.cleanup()
            end)
        end)

        describe("writeFile and readFile", function()
            it("should write and read files", function()
                local env = TestEnvironmentHelpers.create()
                env.writeFile("test.txt", "hello world")
                local content = env.readFile("test.txt")
                expect(content).to.equal("hello world")
                env.cleanup()
            end)

            it("should create parent directories automatically", function()
                local env = TestEnvironmentHelpers.create()
                env.writeFile("nested/dir/test.txt", "nested content")
                expect(env.fileExists("nested/dir/test.txt")).to.equal(true)
                expect(env.readFile("nested/dir/test.txt")).to.equal("nested content")
                env.cleanup()
            end)
        end)

        describe("writeDir", function()
            it("should create directories", function()
                local env = TestEnvironmentHelpers.create()
                env.writeDir("mydir")
                expect(env.dirExists("mydir")).to.equal(true)
                env.cleanup()
            end)
        end)

        describe("fileExists and dirExists", function()
            it("should correctly detect file existence", function()
                local env = TestEnvironmentHelpers.create()
                expect(env.fileExists("nonexistent.txt")).to.equal(false)
                env.writeFile("exists.txt", "content")
                expect(env.fileExists("exists.txt")).to.equal(true)
                env.cleanup()
            end)

            it("should correctly detect directory existence", function()
                local env = TestEnvironmentHelpers.create()
                expect(env.dirExists("nonexistent")).to.equal(false)
                env.writeDir("exists")
                expect(env.dirExists("exists")).to.equal(true)
                env.cleanup()
            end)
        end)

        describe("exec", function()
            it("should execute commands in the temp directory", function()
                local env = TestEnvironmentHelpers.create()
                env.writeFile("test.txt", "content")
                local result = env.exec("ls")
                expect(result.ok).to.equal(true)
                expect(result.stdout:match("test.txt")).to.be.ok()
                env.cleanup()
            end)
        end)

        describe("initGit", function()
            it("should initialize a git repository", function()
                local env = TestEnvironmentHelpers.create()
                env.initGit()
                expect(env.dirExists(".git")).to.equal(true)
                env.cleanup()
            end)
        end)

        describe("gitCommit", function()
            it("should create commits", function()
                local env = TestEnvironmentHelpers.create()
                env.initGit()
                env.writeFile("test.txt", "content")
                env.gitCommit("Initial commit")

                local result = env.exec("git", { "log", "--oneline" })
                expect(result.ok).to.equal(true)
                expect(result.stdout:match("Initial commit")).to.be.ok()
                env.cleanup()
            end)
        end)

        describe("cleanup", function()
            it("should remove the temp directory", function()
                local env = TestEnvironmentHelpers.create()
                local path = env.path
                env.cleanup()

                local result = require("@lune/process").exec("test", { "-d", path })
                expect(result.ok).to.equal(false)
            end)
        end)

        describe("dedent", function()
            it("should remove leading indentation", function()
                local result = TestEnvironmentHelpers.dedent([[
					hello
					world
				]])
                expect(result).to.equal("hello\nworld\n")
            end)

            it("should preserve relative indentation", function()
                local result = TestEnvironmentHelpers.dedent([[
					outer
						inner
					outer again
				]])
                expect(result).to.equal("outer\n\tinner\nouter again\n")
            end)
        end)
    end)
end

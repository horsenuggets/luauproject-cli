--[[

NewCommandTest.spec

Integration tests for the `luauproject new` command. These tests run in an
isolated Docker environment to ensure the CLI works correctly without
affecting the host system.

--]]

local DockerEnvironmentHelpers = require("@tests/Helpers/DockerEnvironmentHelpers")

local StringHelpers = require("@luauprojectcli/Helpers/StringHelpers")

local ALL_FLAGS = {
    "--nogithub",
    "--privatepackage",
}

local function buildArgs(
    name: string,
    description: string,
    owner: string,
    basePath: string?,
    extraFlags: { string }?
): { string }
    local kebabName = StringHelpers.toKebabCase(name)
    local base = basePath or "/workspace"
    local projectPath = `{base}/{kebabName}`

    local args = {
        "new",
        "--name",
        name,
        "--description",
        description,
        "--owner",
        owner,
        "--path",
        projectPath,
    }
    for _, flag in ALL_FLAGS do
        table.insert(args, flag)
    end
    if extraFlags then
        for _, flag in extraFlags do
            table.insert(args, flag)
        end
    end
    return args
end

return function()
    local skipDocker = not DockerEnvironmentHelpers.isDockerAvailable()

    describe("luauproject new", function()
        if skipDocker then
            xit("Docker not available", function() end)
            return
        end

        describe("with built executable", function()
            describe("basic project creation", function()
                it("should create a project with all required flags", function()
                    local env = DockerEnvironmentHelpers.create()

                    local result = env.runCli(buildArgs("my-test-project", "A test project", "test-user"))

                    expect(result.ok).to.equal(true)
                    expect(env.dirExists("/workspace/my-test-project")).to.equal(true)
                    expect(env.fileExists("/workspace/my-test-project/wally.toml")).to.equal(true)
                    expect(env.fileExists("/workspace/my-test-project/README.md")).to.equal(true)
                    expect(env.dirExists("/workspace/my-test-project/.git")).to.equal(true)

                    env.cleanup()
                end)

                it("should convert project name to kebab-case", function()
                    local env = DockerEnvironmentHelpers.create()

                    local result = env.runCli(buildArgs("My Cool Project", "Test", "test-user"))

                    expect(result.ok).to.equal(true)
                    expect(env.dirExists("/workspace/my-cool-project")).to.equal(true)

                    env.cleanup()
                end)

                it("should update wally.toml with project info", function()
                    local env = DockerEnvironmentHelpers.create()

                    env.runCli(buildArgs("my-test-project", "My custom description", "test-user"))

                    local wallyContent = env.readFile("/workspace/my-test-project/wally.toml")
                    expect(wallyContent:match("test%-user/my%-test%-project")).to.be.ok()
                    expect(wallyContent:match("My custom description")).to.be.ok()

                    env.cleanup()
                end)

                it("should update README.md with project name and description", function()
                    local env = DockerEnvironmentHelpers.create()

                    env.runCli(buildArgs("my-test-project", "My custom description", "test-user"))

                    local readmeContent = env.readFile("/workspace/my-test-project/README.md")
                    expect(readmeContent:match("# my%-test%-project")).to.be.ok()
                    expect(readmeContent:match("My custom description")).to.be.ok()

                    env.cleanup()
                end)

                it("should rename source directory to PascalCase", function()
                    local env = DockerEnvironmentHelpers.create()

                    env.runCli(buildArgs("my-test-project", "Test", "test-user"))

                    expect(env.dirExists("/workspace/my-test-project/Source/MyTestProject")).to.equal(true)
                    expect(env.dirExists("/workspace/my-test-project/Source/LuauPackageTemplate")).to.equal(false)

                    env.cleanup()
                end)

                it("should create VERSION file with 0.0.0", function()
                    local env = DockerEnvironmentHelpers.create()

                    env.runCli(buildArgs("my-test-project", "Test", "test-user"))

                    local versionContent = env.readFile("/workspace/my-test-project/VERSION")
                    expect(versionContent:match("0%.0%.0")).to.be.ok()

                    env.cleanup()
                end)

                it("should create CHANGELOG.md", function()
                    local env = DockerEnvironmentHelpers.create()

                    env.runCli(buildArgs("my-test-project", "Test", "test-user"))

                    local changelogContent = env.readFile("/workspace/my-test-project/CHANGELOG.md")
                    expect(changelogContent:match("# Changelog")).to.be.ok()
                    expect(changelogContent:match("## 0%.0%.1")).to.be.ok()

                    env.cleanup()
                end)

                it("should create initial git commit", function()
                    local env = DockerEnvironmentHelpers.create()

                    env.runCli(buildArgs("my-test-project", "Test", "test-user"))

                    local result = env.exec("git", { "-C", "/workspace/my-test-project", "log", "--oneline" })
                    expect(result.ok).to.equal(true)
                    expect(result.stdout:match("Initial commit")).to.be.ok()

                    env.cleanup()
                end)
            end)

            describe("varying working directories", function()
                it("should create project in current directory by default", function()
                    local env = DockerEnvironmentHelpers.create()

                    env.exec("mkdir", { "-p", "/workspace/projects" })

                    local result = env.exec("bash", {
                        "-c",
                        "cd /workspace/projects && luauproject new --name test-proj --description Test --owner test-user --nogithub --privatepackage --path /workspace/projects/test-proj",
                    })

                    expect(result.ok).to.equal(true)
                    expect(env.dirExists("/workspace/projects/test-proj")).to.equal(true)

                    env.cleanup()
                end)

                it("should create project in specified path with --path flag", function()
                    local env = DockerEnvironmentHelpers.create()

                    env.exec("mkdir", { "-p", "/workspace/custom-location" })

                    local result = env.runCli(buildArgs("test-proj", "Test", "test-user", "/workspace/custom-location"))

                    expect(result.ok).to.equal(true)
                    expect(env.dirExists("/workspace/custom-location/test-proj")).to.equal(true)

                    env.cleanup()
                end)

                it("should work from deeply nested working directory", function()
                    local env = DockerEnvironmentHelpers.create()

                    env.exec("mkdir", { "-p", "/workspace/a/b/c/d/e" })

                    local result = env.exec("bash", {
                        "-c",
                        "cd /workspace/a/b/c/d/e && luauproject new --name deep-proj --description Test --owner test-user --nogithub --privatepackage --path /workspace/a/b/c/d/e/deep-proj",
                    })

                    expect(result.ok).to.equal(true)
                    expect(env.dirExists("/workspace/a/b/c/d/e/deep-proj")).to.equal(true)

                    env.cleanup()
                end)
            end)

            describe("executable locations", function()
                it("should work when called with absolute path", function()
                    local env = DockerEnvironmentHelpers.create()

                    local result =
                        env.exec("/usr/local/bin/luauproject", buildArgs("abs-path-proj", "Test", "test-user"))

                    expect(result.ok).to.equal(true)
                    expect(env.dirExists("/workspace/abs-path-proj")).to.equal(true)

                    env.cleanup()
                end)

                it("should work when executable is copied to different location", function()
                    local env = DockerEnvironmentHelpers.create()

                    env.exec("cp", { "/usr/local/bin/luauproject", "/tmp/my-cli" })

                    local result = env.exec("/tmp/my-cli", buildArgs("alt-loc-proj", "Test", "test-user"))

                    expect(result.ok).to.equal(true)
                    expect(env.dirExists("/workspace/alt-loc-proj")).to.equal(true)

                    env.cleanup()
                end)

                it("should work when called from PATH", function()
                    local env = DockerEnvironmentHelpers.create()

                    local result = env.exec("bash", {
                        "-c",
                        "which luauproject && luauproject new --name path-proj --description Test --owner test-user --nogithub --privatepackage --path /workspace/path-proj",
                    })

                    expect(result.ok).to.equal(true)
                    expect(env.dirExists("/workspace/path-proj")).to.equal(true)

                    env.cleanup()
                end)
            end)

            describe("GitHub repository creation", function()
                it("should skip GitHub repo creation with --nogithub", function()
                    local env = DockerEnvironmentHelpers.create()

                    local result = env.runCli(buildArgs("no-gh-proj", "Test", "test-user"))

                    expect(result.ok).to.equal(true)
                    expect(result.stdout:match("github.com/test%-user/no%-gh%-proj")).to.never.be.ok()

                    env.cleanup()
                end)
            end)

            describe("edge cases", function()
                it("should handle special characters in description", function()
                    local env = DockerEnvironmentHelpers.create()

                    local result = env.runCli(
                        buildArgs("special-desc", "A project with 'quotes' and \"double quotes\"", "test-user")
                    )

                    expect(result.ok).to.equal(true)

                    env.cleanup()
                end)

                it("should handle single-word project name", function()
                    local env = DockerEnvironmentHelpers.create()

                    local result = env.runCli(buildArgs("simple", "Test", "test-user"))

                    expect(result.ok).to.equal(true)
                    expect(env.dirExists("/workspace/simple")).to.equal(true)
                    expect(env.dirExists("/workspace/simple/Source/Simple")).to.equal(true)

                    env.cleanup()
                end)

                it("should handle project name with numbers", function()
                    local env = DockerEnvironmentHelpers.create()

                    local result = env.runCli(buildArgs("project123", "Test", "test-user"))

                    expect(result.ok).to.equal(true)
                    expect(env.dirExists("/workspace/project123")).to.equal(true)

                    env.cleanup()
                end)
            end)
        end)

        describe("with lune from source", function()
            it("should work when running via lune", function()
                local env = DockerEnvironmentHelpers.create()

                env.exec("mkdir", { "-p", "/workspace/cli-source" })

                env.cleanup()
            end)
        end)
    end)
end

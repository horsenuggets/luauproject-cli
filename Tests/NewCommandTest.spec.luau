--[[

NewCommandTest.spec

Integration tests for the `luauproject new` command. These tests run in an isolated
Docker environment to ensure the CLI works correctly without affecting the host system.
They cover both the standalone executable built from the current source and running the
source directly via lune.

--]]

const fs = require("@lune/fs")

const DockerEnvironmentHelpers = require("@tests/Helpers/DockerEnvironmentHelpers")

const StringHelpers = require("@luauprojectcli/Helpers/StringHelpers")

const ALL_FLAGS = {
    "--nogithub",
    "--privatepackage",
}

const expectSuccess = DockerEnvironmentHelpers.expectSuccess

const function buildArgs(
    name: string,
    description: string,
    owner: string,
    basePath: string?,
    extraFlags: { string }?
): { string }
    const kebabName = StringHelpers.toKebabCase(name)
    const base = basePath or "/workspace"
    const projectPath = `{base}/{kebabName}`

    const args = {
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
    const skipDocker = not DockerEnvironmentHelpers.isDockerAvailable()

    describe("luauproject new", function()
        if skipDocker then
            xit("Docker not available", function() end)
            return
        end

        beforeAll(function()
            DockerEnvironmentHelpers.prepare()
        end)

        afterAll(function()
            DockerEnvironmentHelpers.cleanupAll()
        end)

        describe("with built executable", function()
            describe("standalone executable", function()
                it("should be a compiled binary rather than a script", function()
                    const env = DockerEnvironmentHelpers.create()

                    const result = env.exec("head", { "-c", "4", "/usr/local/bin/luauproject" })

                    expectSuccess(result)
                    expect(result.stdout).to.equal("\127ELF")

                    env.cleanup()
                end)

                it("should report the version from the VERSION file", function()
                    const env = DockerEnvironmentHelpers.create()

                    const result = env.runCli({ "--version" })

                    expectSuccess(result)
                    const expectedVersion = fs.readFile("VERSION"):gsub("%s+", "")
                    const reportedVersion = result.stdout:match("(%S+)%s*$")
                    expect(reportedVersion).to.equal(expectedVersion)

                    env.cleanup()
                end)
            end)

            describe("basic project creation", function()
                it("should create a project with all required flags", function()
                    const env = DockerEnvironmentHelpers.create()

                    const result = env.runCli(buildArgs("my-test-project", "A test project", "test-user"))

                    expectSuccess(result)
                    expect(env.dirExists("/workspace/my-test-project")).to.equal(true)
                    expect(env.fileExists("/workspace/my-test-project/wally.toml")).to.equal(true)
                    expect(env.fileExists("/workspace/my-test-project/README.md")).to.equal(true)
                    expect(env.dirExists("/workspace/my-test-project/.git")).to.equal(true)

                    env.cleanup()
                end)

                it("should convert project name to kebab-case", function()
                    const env = DockerEnvironmentHelpers.create()

                    const result = env.runCli(buildArgs("My Cool Project", "Test", "test-user"))

                    expectSuccess(result)
                    expect(env.dirExists("/workspace/my-cool-project")).to.equal(true)

                    env.cleanup()
                end)

                it("should update wally.toml with project info", function()
                    const env = DockerEnvironmentHelpers.create()

                    expectSuccess(env.runCli(buildArgs("my-test-project", "My custom description", "test-user")))

                    const wallyContent = env.readFile("/workspace/my-test-project/wally.toml")
                    expect(wallyContent:match("test%-user/my%-test%-project")).to.be.ok()
                    expect(wallyContent:match("My custom description")).to.be.ok()

                    env.cleanup()
                end)

                it("should update README.md with project name and description", function()
                    const env = DockerEnvironmentHelpers.create()

                    expectSuccess(env.runCli(buildArgs("my-test-project", "My custom description", "test-user")))

                    const readmeContent = env.readFile("/workspace/my-test-project/README.md")
                    expect(readmeContent:match("# my%-test%-project")).to.be.ok()
                    expect(readmeContent:match("My custom description")).to.be.ok()

                    env.cleanup()
                end)

                it("should rename source directory to PascalCase", function()
                    const env = DockerEnvironmentHelpers.create()

                    expectSuccess(env.runCli(buildArgs("my-test-project", "Test", "test-user")))

                    expect(env.dirExists("/workspace/my-test-project/Source/MyTestProject")).to.equal(true)
                    expect(env.dirExists("/workspace/my-test-project/Source/LuauPackageTemplate")).to.equal(false)

                    env.cleanup()
                end)

                it("should create VERSION file with 0.0.0", function()
                    const env = DockerEnvironmentHelpers.create()

                    expectSuccess(env.runCli(buildArgs("my-test-project", "Test", "test-user")))

                    const versionContent = env.readFile("/workspace/my-test-project/VERSION")
                    expect(versionContent:match("0%.0%.0")).to.be.ok()

                    env.cleanup()
                end)

                it("should create CHANGELOG.md", function()
                    const env = DockerEnvironmentHelpers.create()

                    expectSuccess(env.runCli(buildArgs("my-test-project", "Test", "test-user")))

                    const changelogContent = env.readFile("/workspace/my-test-project/CHANGELOG.md")
                    expect(changelogContent:match("# Changelog")).to.be.ok()
                    expect(changelogContent:match("## 0%.0%.1")).to.be.ok()

                    env.cleanup()
                end)

                it("should create initial git commit", function()
                    const env = DockerEnvironmentHelpers.create()

                    expectSuccess(env.runCli(buildArgs("my-test-project", "Test", "test-user")))

                    const result = env.exec("git", { "-C", "/workspace/my-test-project", "log", "--oneline" })
                    expectSuccess(result)
                    expect(result.stdout:match("Initial commit")).to.be.ok()

                    env.cleanup()
                end)
            end)

            describe("varying working directories", function()
                it("should create project in current directory by default", function()
                    const env = DockerEnvironmentHelpers.create()

                    env.exec("mkdir", { "-p", "/workspace/projects" })

                    const result = env.exec("bash", {
                        "-c",
                        "cd /workspace/projects && luauproject new --name test-proj --description Test --owner test-user --nogithub --privatepackage --path /workspace/projects/test-proj",
                    })

                    expectSuccess(result)
                    expect(env.dirExists("/workspace/projects/test-proj")).to.equal(true)

                    env.cleanup()
                end)

                it("should create project in specified path with --path flag", function()
                    const env = DockerEnvironmentHelpers.create()

                    env.exec("mkdir", { "-p", "/workspace/custom-location" })

                    const result = env.runCli(buildArgs("test-proj", "Test", "test-user", "/workspace/custom-location"))

                    expectSuccess(result)
                    expect(env.dirExists("/workspace/custom-location/test-proj")).to.equal(true)

                    env.cleanup()
                end)

                it("should work from deeply nested working directory", function()
                    const env = DockerEnvironmentHelpers.create()

                    env.exec("mkdir", { "-p", "/workspace/a/b/c/d/e" })

                    const result = env.exec("bash", {
                        "-c",
                        "cd /workspace/a/b/c/d/e && luauproject new --name deep-proj --description Test --owner test-user --nogithub --privatepackage --path /workspace/a/b/c/d/e/deep-proj",
                    })

                    expectSuccess(result)
                    expect(env.dirExists("/workspace/a/b/c/d/e/deep-proj")).to.equal(true)

                    env.cleanup()
                end)
            end)

            describe("executable locations", function()
                it("should work when called with absolute path", function()
                    const env = DockerEnvironmentHelpers.create()

                    const result =
                        env.exec("/usr/local/bin/luauproject", buildArgs("abs-path-proj", "Test", "test-user"))

                    expectSuccess(result)
                    expect(env.dirExists("/workspace/abs-path-proj")).to.equal(true)

                    env.cleanup()
                end)

                it("should work when executable is copied to different location", function()
                    const env = DockerEnvironmentHelpers.create()

                    expectSuccess(env.exec("cp", { "/usr/local/bin/luauproject", "/tmp/my-cli" }))

                    const result = env.exec("/tmp/my-cli", buildArgs("alt-loc-proj", "Test", "test-user"))

                    expectSuccess(result)
                    expect(env.dirExists("/workspace/alt-loc-proj")).to.equal(true)

                    env.cleanup()
                end)

                it("should work when called from PATH", function()
                    const env = DockerEnvironmentHelpers.create()

                    const result = env.exec("bash", {
                        "-c",
                        "which luauproject && luauproject new --name path-proj --description Test --owner test-user --nogithub --privatepackage --path /workspace/path-proj",
                    })

                    expectSuccess(result)
                    expect(env.dirExists("/workspace/path-proj")).to.equal(true)

                    env.cleanup()
                end)
            end)

            describe("GitHub repository creation", function()
                it("should skip GitHub repo creation with --nogithub", function()
                    const env = DockerEnvironmentHelpers.create()

                    const result = env.runCli(buildArgs("no-gh-proj", "Test", "test-user"))

                    expectSuccess(result)
                    expect(result.stdout:match("github.com/test%-user/no%-gh%-proj")).to.never.be.ok()

                    env.cleanup()
                end)

                it("should lowercase a mixed-case owner in wally.toml", function()
                    const env = DockerEnvironmentHelpers.create()

                    const result = env.runCli(buildArgs("case-proj", "Test", "My-Org"))

                    expectSuccess(result)
                    const wallyContent = env.readFile("/workspace/case-proj/wally.toml")
                    expect(wallyContent:match('name = "my%-org/case%-proj"')).to.be.ok()

                    env.cleanup()
                end)
            end)

            describe("existing repository connection", function()
                const function existingArgs(name: string): { string }
                    return {
                        "new",
                        "--name",
                        name,
                        "--description",
                        "Test",
                        "--owner",
                        "Test-User",
                        "--path",
                        `/workspace/{name}`,
                        "--existing",
                        "--privatepackage",
                    }
                end

                it("should push to an existing empty repository", function()
                    const env = DockerEnvironmentHelpers.create()

                    -- Stand in for Terraform, and route the test owner's GitHub remotes
                    -- to a local bare repository so the push can be verified offline. The
                    -- template is still cloned from GitHub, so only the owner is rerouted.
                    env.writeFile("/usr/local/bin/terraform", '#!/bin/bash\necho "Terraform v1.14.8"\n')
                    expectSuccess(env.exec("chmod", { "+x", "/usr/local/bin/terraform" }))
                    expectSuccess(env.exec("git", { "init", "--bare", "-q", "/remotes/test-user/connected-proj.git" }))
                    expectSuccess(env.exec("git", {
                        "config",
                        "--global",
                        "url./remotes/test-user/.insteadOf",
                        "https://github.com/test-user/",
                    }))

                    const result = env.runCli(existingArgs("connected-proj"))

                    expectSuccess(result)
                    expect(result.stdout:match("Connecting to existing GitHub repository")).to.be.ok()

                    const remote = env.exec("git", { "-C", "/workspace/connected-proj", "config", "remote.origin.url" })
                    expectSuccess(remote)
                    expect(remote.stdout:match("^https://github%.com/test%-user/connected%-proj%.git")).to.be.ok()

                    const branches = env.exec("git", {
                        "-C",
                        "/remotes/test-user/connected-proj.git",
                        "branch",
                        "--format=%(refname:short)",
                    })
                    expectSuccess(branches)
                    for _, branch in { "dev", "main", "release" } do
                        expect(branches.stdout:match(`%f[%w]{branch}%f[%W]`)).to.be.ok()
                    end

                    env.cleanup()
                end)

                it("should reject a repository that doesn't exist", function()
                    const env = DockerEnvironmentHelpers.create()

                    const result = env.runCli(existingArgs("missing-proj"))

                    expect(result.ok).to.equal(false)
                    expect(result.stderr:match("was not found or is not accessible")).to.be.ok()
                    expect(env.dirExists("/workspace/missing-proj")).to.equal(false)

                    env.cleanup()
                end)

                it("should reject a repository that isn't empty", function()
                    const env = DockerEnvironmentHelpers.create()

                    const result = env.runCli(existingArgs("nonempty-proj"))

                    expect(result.ok).to.equal(false)
                    expect(result.stderr:match("is not empty")).to.be.ok()
                    expect(env.dirExists("/workspace/nonempty-proj")).to.equal(false)

                    env.cleanup()
                end)

                it("should reject --existing combined with --nogithub", function()
                    const env = DockerEnvironmentHelpers.create()

                    const args = existingArgs("conflict-proj")
                    table.insert(args, "--nogithub")
                    const result = env.runCli(args)

                    expect(result.ok).to.equal(false)
                    expect(result.stderr:match("cannot be combined")).to.be.ok()

                    env.cleanup()
                end)
            end)

            describe("edge cases", function()
                it("should handle special characters in description", function()
                    const env = DockerEnvironmentHelpers.create()

                    const result = env.runCli(
                        buildArgs("special-desc", "A project with 'quotes' and \"double quotes\"", "test-user")
                    )

                    expectSuccess(result)

                    env.cleanup()
                end)

                it("should handle single-word project name", function()
                    const env = DockerEnvironmentHelpers.create()

                    const result = env.runCli(buildArgs("simple", "Test", "test-user"))

                    expectSuccess(result)
                    expect(env.dirExists("/workspace/simple")).to.equal(true)
                    expect(env.dirExists("/workspace/simple/Source/Simple")).to.equal(true)

                    env.cleanup()
                end)

                it("should handle project name with numbers", function()
                    const env = DockerEnvironmentHelpers.create()

                    const result = env.runCli(buildArgs("project123", "Test", "test-user"))

                    expectSuccess(result)
                    expect(env.dirExists("/workspace/project123")).to.equal(true)

                    env.cleanup()
                end)
            end)
        end)

        describe("with lune from source", function()
            it("should create a project when running via lune", function()
                const env = DockerEnvironmentHelpers.create()

                const result = env.runCliFromSource(buildArgs("source-proj", "A source project", "test-user"))

                expectSuccess(result)
                expect(result.stdout:match("Project created successfully")).to.be.ok()
                expect(env.dirExists("/workspace/source-proj/.git")).to.equal(true)
                expect(env.dirExists("/workspace/source-proj/Source/SourceProj")).to.equal(true)

                const wallyContent = env.readFile("/workspace/source-proj/wally.toml")
                expect(wallyContent:match("test%-user/source%-proj")).to.be.ok()
                expect(wallyContent:match("A source project")).to.be.ok()

                const readmeContent = env.readFile("/workspace/source-proj/README.md")
                expect(readmeContent:match("# source%-proj")).to.be.ok()

                env.cleanup()
            end)
        end)
    end)
end

--[[

DockerEnvironmentHelpers

Helper module for running tests inside an isolated Docker container. The container has
git, gh (GitHub CLI), rokit, wally, and lune pre-installed for testing the full CLI
workflow without affecting the host system. It also contains the standalone executable
built from the current source, and the source itself for running via lune.

Call prepare() once in a beforeAll hook before creating any environments, and
cleanupAll() in an afterAll hook to remove containers left behind by failed tests.

--]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local BUILD_OUTPUT_DIR = "Build/Docker"
local BUILD_TARGET = "linux-x86_64"
local CLI_SOURCE_DIR = "/opt/luauproject-cli"
local CONTAINER_WORK_DIR = "/workspace"
local DOCKER_IMAGE = "luauproject-cli-test"

local DockerEnvironmentHelpers = {}

local activeContainers: { [string]: boolean } = {}
local isPrepared = false

export type DockerEnv = {
    containerId: string,
    cleanup: () -> (),
    exec: (command: string, args: { string }?) -> ExecResult,
    writeFile: (containerPath: string, content: string) -> (),
    readFile: (containerPath: string) -> string,
    fileExists: (containerPath: string) -> boolean,
    dirExists: (containerPath: string) -> boolean,
    copyToContainer: (hostPath: string, containerPath: string) -> (),
    copyFromContainer: (containerPath: string, hostPath: string) -> (),
    runCli: (args: { string }?) -> ExecResult,
    runCliFromSource: (args: { string }?) -> ExecResult,
    initGit: () -> (),
    gitCommit: (message: string) -> (),
}

export type ExecResult = {
    ok: boolean,
    code: number,
    stdout: string,
    stderr: string,
}

local function formatOutput(output: string): string
    if output:match("^%s*$") then
        return "(empty)"
    end
    return (output:gsub("%s+$", ""))
end

--[[
    Formats an exec result into a readable block containing the exit code, stdout, and
    stderr, for use in assertion failures and error messages.

    > result - The result to format
]]
function DockerEnvironmentHelpers.formatExecResult(result: ExecResult): string
    local stdout = formatOutput(result.stdout)
    local stderr = formatOutput(result.stderr)
    return `Exited with code {result.code}.\n\n[stdout]\n{stdout}\n\n[stderr]\n{stderr}`
end

--[[
    Fails the current test with the exit code, stdout, and stderr if the result is not
    ok, so that failed CLI runs are diagnosable from the test output alone.

    > result - The result to check
]]
function DockerEnvironmentHelpers.expectSuccess(result: ExecResult)
    if not result.ok then
        error(`Expected command to succeed. {DockerEnvironmentHelpers.formatExecResult(result)}`, 2)
    end
end

local function buildExecutable()
    print(`Building "{BUILD_TARGET}" executable for Docker tests...`)
    local result = process.exec("lune", {
        "run",
        "Scripts/BuildExecutable.exec.luau",
        BUILD_TARGET,
        BUILD_OUTPUT_DIR,
    })
    assert(result.ok, `Failed to build executable. {DockerEnvironmentHelpers.formatExecResult(result)}`)
end

local function buildImage()
    local dockerfilePath = `{process.cwd}/Tests/Dockerfile`
    assert(fs.isFile(dockerfilePath), `Dockerfile not found at "{dockerfilePath}".`)

    -- Always build so the image never goes stale. Docker's layer cache makes this fast
    -- when nothing has changed.
    print(`Building "{DOCKER_IMAGE}" Docker image...`)
    local result = process.exec("docker", {
        "build",
        "-t",
        DOCKER_IMAGE,
        "-f",
        dockerfilePath,
        process.cwd,
    })
    assert(result.ok, `Failed to build Docker image. {DockerEnvironmentHelpers.formatExecResult(result)}`)
end

--[[
    Builds the standalone executable and the Docker test image from the current source.
    Only does work on the first call, so it's safe to call from several beforeAll hooks.
]]
function DockerEnvironmentHelpers.prepare()
    if isPrepared then
        return
    end
    buildExecutable()
    buildImage()
    isPrepared = true
end

--[[
    Removes every container created by create() that hasn't been cleaned up yet, such as
    those left behind by tests that failed before calling cleanup().
]]
function DockerEnvironmentHelpers.cleanupAll()
    for containerId in activeContainers do
        process.exec("docker", { "rm", "-f", containerId })
    end
    table.clear(activeContainers)
end

function DockerEnvironmentHelpers.isDockerAvailable(): boolean
    local result = process.exec("docker", { "info" })
    return result.ok
end

function DockerEnvironmentHelpers.create(): DockerEnv
    assert(isPrepared, "Call DockerEnvironmentHelpers.prepare() in a beforeAll hook before create().")

    local timestamp = tostring(os.time()) .. tostring(math.random(10000, 99999))
    local containerName = `luauproject-test-{timestamp}`

    local startResult = process.exec("docker", {
        "run",
        "-d",
        "--name",
        containerName,
        "-w",
        CONTAINER_WORK_DIR,
        DOCKER_IMAGE,
        "sleep",
        "3600",
    })

    assert(startResult.ok, `Failed to start Docker container. {DockerEnvironmentHelpers.formatExecResult(startResult)}`)

    local containerId = startResult.stdout:gsub("%s+", "")
    activeContainers[containerId] = true

    local env: DockerEnv = {
        containerId = containerId,

        cleanup = function()
            process.exec("docker", { "rm", "-f", containerId })
            activeContainers[containerId] = nil
        end,

        exec = function(command: string, args: { string }?): ExecResult
            local dockerArgs = { "exec", containerId, command }
            if args then
                for _, arg in args do
                    table.insert(dockerArgs, arg)
                end
            end
            return process.exec("docker", dockerArgs)
        end,

        writeFile = function(containerPath: string, content: string)
            local timestamp = tostring(os.time()) .. tostring(math.random(10000, 99999))
            local tempFile = `/tmp/docker-write-{timestamp}`
            fs.writeFile(tempFile, content)

            local result = process.exec("docker", {
                "cp",
                tempFile,
                `{containerId}:{containerPath}`,
            })

            fs.removeFile(tempFile)
            assert(result.ok, `Failed to write file to container: {result.stderr}`)
        end,

        readFile = function(containerPath: string): string
            local timestamp = tostring(os.time()) .. tostring(math.random(10000, 99999))
            local tempFile = `/tmp/docker-read-{timestamp}`

            local result = process.exec("docker", {
                "cp",
                `{containerId}:{containerPath}`,
                tempFile,
            })

            assert(result.ok, `Failed to read file from container: {result.stderr}`)

            local content = fs.readFile(tempFile)
            fs.removeFile(tempFile)
            return content
        end,

        fileExists = function(containerPath: string): boolean
            local result = process.exec("docker", {
                "exec",
                containerId,
                "test",
                "-f",
                containerPath,
            })
            return result.ok
        end,

        dirExists = function(containerPath: string): boolean
            local result = process.exec("docker", {
                "exec",
                containerId,
                "test",
                "-d",
                containerPath,
            })
            return result.ok
        end,

        copyToContainer = function(hostPath: string, containerPath: string)
            local result = process.exec("docker", {
                "cp",
                hostPath,
                `{containerId}:{containerPath}`,
            })
            assert(result.ok, `Failed to copy to container: {result.stderr}`)
        end,

        copyFromContainer = function(containerPath: string, hostPath: string)
            local result = process.exec("docker", {
                "cp",
                `{containerId}:{containerPath}`,
                hostPath,
            })
            assert(result.ok, `Failed to copy from container: {result.stderr}`)
        end,

        runCli = function(args: { string }?): ExecResult
            local dockerArgs = { "exec", containerId, "luauproject" }
            if args then
                for _, arg in args do
                    table.insert(dockerArgs, arg)
                end
            end
            return process.exec("docker", dockerArgs)
        end,

        runCliFromSource = function(args: { string }?): ExecResult
            -- Run from the source directory so the rokit shim resolves the lune version
            -- pinned in its rokit.toml, and pass LUAUPROJECT_CWD so the CLI still treats
            -- the workspace as the directory it was invoked from
            local dockerArgs = {
                "exec",
                "-w",
                CLI_SOURCE_DIR,
                "-e",
                `LUAUPROJECT_CWD={CONTAINER_WORK_DIR}`,
                containerId,
                "lune",
                "run",
                "Source/LuauprojectCli",
            }
            if args then
                for _, arg in args do
                    table.insert(dockerArgs, arg)
                end
            end
            return process.exec("docker", dockerArgs)
        end,

        initGit = function()
            process.exec("docker", { "exec", containerId, "git", "init" })
            process.exec("docker", {
                "exec",
                containerId,
                "git",
                "config",
                "user.email",
                "test@test.com",
            })
            process.exec("docker", {
                "exec",
                containerId,
                "git",
                "config",
                "user.name",
                "Test User",
            })
        end,

        gitCommit = function(message: string)
            process.exec("docker", { "exec", containerId, "git", "add", "-A" })
            process.exec("docker", {
                "exec",
                containerId,
                "git",
                "commit",
                "-m",
                message,
                "--allow-empty",
            })
        end,
    }

    return env
end

return DockerEnvironmentHelpers

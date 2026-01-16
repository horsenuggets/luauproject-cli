--[[

DockerEnvironmentHelpers

Helper module for running tests inside an isolated Docker container. The container has
git, gh (GitHub CLI), rokit, wally, and lune pre-installed for testing the full CLI
workflow without affecting the host system.

--]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local DockerEnvironmentHelpers = {}

local DOCKER_IMAGE = "luauproject-cli-test"
local CONTAINER_WORK_DIR = "/workspace"

export type ExecResult = {
    ok: boolean,
    code: number,
    stdout: string,
    stderr: string,
}

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
    initGit: () -> (),
    gitCommit: (message: string) -> (),
}

local function ensureImageExists()
    local result = process.exec("docker", { "image", "inspect", DOCKER_IMAGE })
    if not result.ok then
        local dockerfilePath = `{process.cwd}/Tests/Dockerfile`
        assert(fs.isFile(dockerfilePath), `Dockerfile not found at {dockerfilePath}`)

        print("Building Docker test image...")
        local buildResult = process.exec("docker", {
            "build",
            "-t",
            DOCKER_IMAGE,
            "-f",
            dockerfilePath,
            process.cwd,
        })

        assert(buildResult.ok, `Failed to build Docker image: {buildResult.stderr}`)
    end
end

function DockerEnvironmentHelpers.isDockerAvailable(): boolean
    local result = process.exec("docker", { "info" })
    return result.ok
end

function DockerEnvironmentHelpers.create(): DockerEnv
    ensureImageExists()

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

    assert(startResult.ok, `Failed to start Docker container: {startResult.stderr}`)

    local containerId = startResult.stdout:gsub("%s+", "")

    local copyResult = process.exec("docker", {
        "cp",
        `{process.cwd}/Build/luauproject`,
        `{containerId}:/usr/local/bin/luauproject`,
    })

    if not copyResult.ok then
        process.exec("docker", { "rm", "-f", containerId })
        error(`Failed to copy CLI binary to container: {copyResult.stderr}`)
    end

    local env: DockerEnv = {
        containerId = containerId,

        cleanup = function()
            process.exec("docker", { "rm", "-f", containerId })
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

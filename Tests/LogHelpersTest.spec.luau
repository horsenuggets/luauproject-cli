--[[

LogHelpersTest.spec

Tests for the LogHelpers module covering entry building, file appending,
directory creation, and handling of missing or nil values.

--]]

const LogHelpers = require("@luauprojectcli/Helpers/LogHelpers")
const PathHelpers = require("@luauprojectcli/Helpers/PathHelpers")
const fs = require("@lune/fs")
const serde = require("@lune/serde")

const LOG_FILE_NAME = "project-creations.jsonl"

const function makeSampleEntry(overrides: { [string]: any }?): LogHelpers.ProjectCreationEntry
    const entry: LogHelpers.ProjectCreationEntry = {
        timestamp = "2026-03-21T12:00:00Z",
        args = { "new", "-n", "test-project", "--github" },
        config = {
            name = "test-project",
            description = "A test project.",
            owner = "testuser",
            projectPath = "/tmp/test-project",
            createGithubRepo = true,
            isPrivate = false,
            isPrivatePackage = false,
        },
        cwd = "/tmp",
        setup = {
            branchProtection = true,
            wallyAuth = true,
            copilotReview = true,
        },
        warnings = {},
    }

    if overrides then
        for key, value in overrides do
            (entry :: any)[key] = value
        end
    end

    return entry
end

const function createTempDir(): string
    const dir = `/tmp/loghelpers-test-{os.clock()}-{math.random(100000)}`
    fs.writeDir(dir)
    return dir
end

const function cleanupDir(dir: string)
    if fs.isDir(dir) then
        fs.removeDir(dir)
    end
end

const function writeEntryToDir(dir: string, entry: LogHelpers.ProjectCreationEntry)
    const logPath = PathHelpers.join(dir, LOG_FILE_NAME)
    const line = LogHelpers.buildEntry(entry) .. "\n"
    local existing = ""
    if fs.isFile(logPath) then
        existing = fs.readFile(logPath)
    end
    fs.writeFile(logPath, existing .. line)
end

return function()
    describe("buildEntry", function()
        it("should produce valid JSON with all expected fields", function()
            const entry = makeSampleEntry()
            const json = LogHelpers.buildEntry(entry)
            const decoded = serde.decode("json", json)

            expect(decoded.timestamp).to.equal("2026-03-21T12:00:00Z")
            expect(decoded.cwd).to.equal("/tmp")
            expect(decoded.config.name).to.equal("test-project")
            expect(decoded.config.description).to.equal("A test project.")
            expect(decoded.config.owner).to.equal("testuser")
            expect(decoded.config.projectPath).to.equal("/tmp/test-project")
            expect(decoded.config.createGithubRepo).to.equal(true)
            expect(decoded.config.isPrivate).to.equal(false)
            expect(decoded.config.isPrivatePackage).to.equal(false)
            expect(decoded.setup.branchProtection).to.equal(true)
            expect(decoded.setup.wallyAuth).to.equal(true)
            expect(decoded.setup.copilotReview).to.equal(true)
            expect(#decoded.args).to.equal(4)
            expect(#decoded.warnings).to.equal(0)
        end)

        it("should handle nil setup values for local-only projects", function()
            const entry = makeSampleEntry({
                setup = {
                    branchProtection = nil,
                    wallyAuth = nil,
                    copilotReview = nil,
                },
            })
            const json = LogHelpers.buildEntry(entry)
            const decoded = serde.decode("json", json)

            expect(decoded.setup.branchProtection).to.equal(nil)
            expect(decoded.setup.wallyAuth).to.equal(nil)
            expect(decoded.setup.copilotReview).to.equal(nil)
        end)

        it("should include warnings when present", function()
            const entry = makeSampleEntry({
                warnings = { "Branch protection failed", "Wally token missing" },
            })
            const json = LogHelpers.buildEntry(entry)
            const decoded = serde.decode("json", json)

            expect(#decoded.warnings).to.equal(2)
            expect(decoded.warnings[1]).to.equal("Branch protection failed")
            expect(decoded.warnings[2]).to.equal("Wally token missing")
        end)

        it("should include command line args", function()
            const entry = makeSampleEntry({
                args = { "new", "--nogithub", "-n", "my-lib" },
            })
            const json = LogHelpers.buildEntry(entry)
            const decoded = serde.decode("json", json)

            expect(#decoded.args).to.equal(4)
            expect(decoded.args[1]).to.equal("new")
            expect(decoded.args[3]).to.equal("-n")
        end)

        it("should handle empty args", function()
            const entry = makeSampleEntry({ args = {} })
            const json = LogHelpers.buildEntry(entry)
            const decoded = serde.decode("json", json)

            expect(#decoded.args).to.equal(0)
        end)
    end)

    describe("ensureLogDir", function()
        it("should create the log directory if it does not exist", function()
            expect(function()
                LogHelpers.ensureLogDir()
            end).never.to.throw()

            const logDir = LogHelpers.getLogDir()
            expect(fs.isDir(logDir)).to.equal(true)
        end)

        it("should not error if the directory already exists", function()
            LogHelpers.ensureLogDir()
            expect(function()
                LogHelpers.ensureLogDir()
            end).never.to.throw()
        end)
    end)

    describe("appendEntry", function()
        it("should create the log file and write an entry", function()
            const dir = createTempDir()
            const entry = makeSampleEntry()
            writeEntryToDir(dir, entry)

            const logPath = PathHelpers.join(dir, LOG_FILE_NAME)
            expect(fs.isFile(logPath)).to.equal(true)

            const content = fs.readFile(logPath)
            const lines = content:split("\n")
            const nonEmptyLines = {}
            for _, line in lines do
                if line ~= "" then
                    table.insert(nonEmptyLines, line)
                end
            end
            expect(#nonEmptyLines >= 1).to.equal(true)

            const decoded = serde.decode("json", nonEmptyLines[#nonEmptyLines])
            expect(decoded.config.name).to.equal("test-project")
            cleanupDir(dir)
        end)

        it("should append to an existing log file", function()
            const dir = createTempDir()
            const entry1 = makeSampleEntry()
            const entry2 = makeSampleEntry({
                config = {
                    name = "second-project",
                    description = "Another project.",
                    owner = "testuser",
                    projectPath = "/tmp/second-project",
                    createGithubRepo = false,
                    isPrivate = false,
                    isPrivatePackage = false,
                },
            })

            writeEntryToDir(dir, entry1)
            writeEntryToDir(dir, entry2)

            const logPath = PathHelpers.join(dir, LOG_FILE_NAME)
            const content = fs.readFile(logPath)
            const lines = {}
            for line in content:gmatch("[^\n]+") do
                table.insert(lines, line)
            end
            expect(#lines >= 2).to.equal(true)

            const first = serde.decode("json", lines[#lines - 1])
            const second = serde.decode("json", lines[#lines])
            expect(first.config.name).to.equal("test-project")
            expect(second.config.name).to.equal("second-project")
            cleanupDir(dir)
        end)
    end)

    describe("createTimestamp", function()
        it("should return an ISO 8601 formatted string", function()
            const timestamp = LogHelpers.createTimestamp()
            expect(timestamp:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$")).to.be.ok()
        end)
    end)
end

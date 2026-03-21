--[[

LogHelpersTest.spec

Tests for the LogHelpers module covering entry building, file appending, directory
creation, and handling of missing or nil values.

--]]

local LogHelpers = require("@luauprojectcli/Helpers/LogHelpers")
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local function makeSampleEntry(overrides: { [string]: any }?): LogHelpers.ProjectCreationEntry
    local entry: LogHelpers.ProjectCreationEntry = {
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
        pid = 12345,
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

return function()
    local testDir: string

    beforeEach(function()
        testDir = `/tmp/loghelpers-test-{os.clock()}`
        if fs.isDir(testDir) then
            fs.removeDir(testDir)
        end
    end)

    afterEach(function()
        if testDir and fs.isDir(testDir) then
            fs.removeDir(testDir)
        end
    end)

    describe("buildEntry", function()
        it("should produce valid JSON with all expected fields", function()
            local entry = makeSampleEntry()
            local json = LogHelpers.buildEntry(entry)
            local decoded = serde.decode("json", json)

            expect(decoded.timestamp).to.equal("2026-03-21T12:00:00Z")
            expect(decoded.pid).to.equal(12345)
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
            local entry = makeSampleEntry({
                setup = {
                    branchProtection = nil,
                    wallyAuth = nil,
                    copilotReview = nil,
                },
            })
            local json = LogHelpers.buildEntry(entry)
            local decoded = serde.decode("json", json)

            expect(decoded.setup.branchProtection).to.equal(nil)
            expect(decoded.setup.wallyAuth).to.equal(nil)
            expect(decoded.setup.copilotReview).to.equal(nil)
        end)

        it("should include warnings when present", function()
            local entry = makeSampleEntry({
                warnings = { "Branch protection failed", "Wally token missing" },
            })
            local json = LogHelpers.buildEntry(entry)
            local decoded = serde.decode("json", json)

            expect(#decoded.warnings).to.equal(2)
            expect(decoded.warnings[1]).to.equal("Branch protection failed")
            expect(decoded.warnings[2]).to.equal("Wally token missing")
        end)

        it("should include command line args", function()
            local entry = makeSampleEntry({
                args = { "new", "--nogithub", "-n", "my-lib" },
            })
            local json = LogHelpers.buildEntry(entry)
            local decoded = serde.decode("json", json)

            expect(#decoded.args).to.equal(4)
            expect(decoded.args[1]).to.equal("new")
            expect(decoded.args[3]).to.equal("-n")
        end)

        it("should handle empty args", function()
            local entry = makeSampleEntry({ args = {} })
            local json = LogHelpers.buildEntry(entry)
            local decoded = serde.decode("json", json)

            expect(#decoded.args).to.equal(0)
        end)
    end)

    describe("ensureLogDir", function()
        it("should create the log directory if it does not exist", function()
            -- We can only test the function doesn't error; the actual path
            -- depends on HOME which we don't want to modify in tests
            expect(function()
                LogHelpers.ensureLogDir()
            end).never.to.throw()

            local logDir = LogHelpers.getLogDir()
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
            local entry = makeSampleEntry()
            LogHelpers.appendEntry(entry)

            local logPath = LogHelpers.getLogFilePath()
            expect(fs.isFile(logPath)).to.equal(true)

            local content = fs.readFile(logPath)
            local lines = content:split("\n")
            -- Last element after split on trailing newline is empty
            local nonEmptyLines = {}
            for _, line in lines do
                if line ~= "" then
                    table.insert(nonEmptyLines, line)
                end
            end
            expect(#nonEmptyLines >= 1).to.equal(true)

            local decoded = serde.decode("json", nonEmptyLines[#nonEmptyLines])
            expect(decoded.config.name).to.equal("test-project")
        end)

        it("should append to an existing log file", function()
            local entry1 = makeSampleEntry()
            local entry2 = makeSampleEntry({
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

            LogHelpers.appendEntry(entry1)
            LogHelpers.appendEntry(entry2)

            local logPath = LogHelpers.getLogFilePath()
            local content = fs.readFile(logPath)
            local lines = {}
            for line in content:gmatch("[^\n]+") do
                table.insert(lines, line)
            end
            expect(#lines >= 2).to.equal(true)

            local first = serde.decode("json", lines[#lines - 1])
            local second = serde.decode("json", lines[#lines])
            expect(first.config.name).to.equal("test-project")
            expect(second.config.name).to.equal("second-project")
        end)
    end)

    describe("createTimestamp", function()
        it("should return an ISO 8601 formatted string", function()
            local timestamp = LogHelpers.createTimestamp()
            expect(timestamp:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$")).to.be.ok()
        end)
    end)
end

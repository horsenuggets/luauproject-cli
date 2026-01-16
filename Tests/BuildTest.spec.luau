--[[

BuildTest

Tests that verify the CLI builds correctly and the built executable works as expected.

--]]

local fs = require("@lune/fs")
local process = require("@lune/process")

return function()
    describe("Build", function()
        describe("BuildExecutable script", function()
            it("should create the Build directory if it does not exist", function()
                -- This test just verifies the build script can run
                -- The actual build is tested separately
                expect(fs.isDir("Build")).to.equal(true)
            end)

            it("should create the luauproject executable", function()
                local expectedPath = "Build/luauproject"
                if process.os == "windows" then
                    expectedPath = "Build/luauproject.exe"
                end
                expect(fs.isFile(expectedPath)).to.equal(true)
            end)
        end)

        describe("Built CLI", function()
            local cliBinary = "Build/luauproject"

            beforeAll(function()
                if process.os == "windows" then
                    cliBinary = "Build/luauproject.exe"
                end
            end)

            it("should run without errors", function()
                local result = process.exec(cliBinary, { "--help" })
                expect(result.ok).to.equal(true)
            end)

            it("should display help when called with --help", function()
                local result = process.exec(cliBinary, { "--help" })
                expect(result.ok).to.equal(true)
                expect(result.stdout:match("luauproject")).to.be.ok()
            end)

            it("should display version when called with --version", function()
                local result = process.exec(cliBinary, { "--version" })
                expect(result.ok).to.equal(true)
                -- Version should match semver pattern
                expect(result.stdout:match("%d+%.%d+%.%d+")).to.be.ok()
            end)

            it("should have new subcommand", function()
                local result = process.exec(cliBinary, { "--help" })
                expect(result.ok).to.equal(true)
                expect(result.stdout:match("new")).to.be.ok()
            end)
        end)
    end)
end

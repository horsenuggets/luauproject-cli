--[[

HelpersTest

Tests for shell helper module including command execution and availability checks.

--]]

local ShellHelpers = require("@luauprojectcli/Helpers/ShellHelpers")

return function()
    describe("ShellHelpers.isCommandAvailable", function()
        it("should return true for common commands", function()
            expect(ShellHelpers.isCommandAvailable("ls")).to.equal(true)
            expect(ShellHelpers.isCommandAvailable("echo")).to.equal(true)
        end)

        it("should return false for non-existent commands", function()
            expect(ShellHelpers.isCommandAvailable("nonexistent-command-12345")).to.equal(false)
        end)
    end)

    describe("ShellHelpers.run", function()
        it("should return ok=true for successful commands", function()
            local ok, output = ShellHelpers.run("echo", { "hello" })
            expect(ok).to.equal(true)
            expect(output:match("hello")).to.be.ok()
        end)

        it("should return ok=false for failed commands", function()
            local ok, _ = ShellHelpers.run("ls", { "/nonexistent-path-12345" })
            expect(ok).to.equal(false)
        end)
    end)
end

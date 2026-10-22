--[[

DockerEnvironmentHelpersTest.spec

Tests for the Docker test helpers that don't need Docker, covering how failed command
results are formatted and reported.

--]]

local DockerEnvironmentHelpers = require("@tests/Helpers/DockerEnvironmentHelpers")

local FAILED_RESULT = {
    code = 127,
    ok = false,
    stderr = "lune: command not found\n",
    stdout = "Creating project...\n",
}

return function()
    describe("DockerEnvironmentHelpers.formatExecResult", function()
        it("should include the exit code, stdout, and stderr", function()
            local formatted = DockerEnvironmentHelpers.formatExecResult(FAILED_RESULT)
            expect(formatted).to.equal(
                "Exited with code 127.\n\n[stdout]\nCreating project...\n\n[stderr]\nlune: command not found"
            )
        end)

        it("should mark empty output explicitly", function()
            local formatted = DockerEnvironmentHelpers.formatExecResult({
                code = 127,
                ok = false,
                stderr = "",
                stdout = "  \n",
            })
            expect(formatted).to.equal("Exited with code 127.\n\n[stdout]\n(empty)\n\n[stderr]\n(empty)")
        end)

        it("should return the same output for the same input", function()
            local first = DockerEnvironmentHelpers.formatExecResult(FAILED_RESULT)
            local second = DockerEnvironmentHelpers.formatExecResult(FAILED_RESULT)
            expect(first).to.equal(second)
        end)
    end)

    describe("DockerEnvironmentHelpers.expectSuccess", function()
        it("should not error for successful results", function()
            expect(function()
                DockerEnvironmentHelpers.expectSuccess({ code = 0, ok = true, stderr = "", stdout = "" })
            end).never.to.throw()
        end)

        it("should error with the exit code, stdout, and stderr for failed results", function()
            local ok, err = pcall(DockerEnvironmentHelpers.expectSuccess, FAILED_RESULT)
            expect(ok).to.equal(false)
            expect(tostring(err):find("Exited with code 127.", 1, true)).to.be.ok()
            expect(tostring(err):find("Creating project...", 1, true)).to.be.ok()
            expect(tostring(err):find("lune: command not found", 1, true)).to.be.ok()
        end)
    end)
end

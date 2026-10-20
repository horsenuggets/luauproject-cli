--[[

PathHelpersTest.spec

Tests for path normalization and display formatting.

--]]

local PathHelpers = require("@luauprojectcli/Helpers/PathHelpers")
local process = require("@lune/process")

local IS_WINDOWS = process.os == "windows"
local SEP = if IS_WINDOWS then "\\" else "/"

local function native(path: string): string
    return (string.gsub(path, "/", SEP))
end

return function()
    describe("PathHelpers.normalize", function()
        it("should collapse repeated separators", function()
            expect(PathHelpers.normalize("/a//b///c")).to.equal(native("/a/b/c"))
        end)

        it("should convert mixed separators to the native separator", function()
            expect(PathHelpers.normalize("a\\b/c\\\\d")).to.equal(native("a/b/c/d"))
        end)
    end)

    describe("PathHelpers.trimTrailingSeparators", function()
        it("should remove trailing separators", function()
            expect(PathHelpers.trimTrailingSeparators("/a/b//")).to.equal("/a/b")
        end)

        it("should preserve a bare root", function()
            expect(PathHelpers.trimTrailingSeparators("/")).to.equal(SEP)
        end)

        it("should keep the separator on a drive root", function()
            expect(PathHelpers.trimTrailingSeparators("C:\\")).to.equal(`C:{SEP}`)
            expect(PathHelpers.trimTrailingSeparators("C:\\\\")).to.equal(`C:{SEP}`)
        end)

        it("should leave a drive-relative path unchanged", function()
            expect(PathHelpers.trimTrailingSeparators("C:")).to.equal("C:")
        end)
    end)

    describe("PathHelpers.formatDirectory", function()
        it("should normalize and end with a single separator", function()
            expect(PathHelpers.formatDirectory("/tmp//project")).to.equal(native("/tmp/project/"))
            expect(PathHelpers.formatDirectory("/tmp/project//")).to.equal(native("/tmp/project/"))
        end)

        it("should replace the home directory with ~", function()
            local home = process.env.HOME
            if not home or home == "" then
                return
            end
            expect(PathHelpers.formatDirectory(`{home}//git/project`)).to.equal(native("~/git/project/"))
        end)
    end)

    describe("PathHelpers.formatFile", function()
        it("should normalize without a trailing separator", function()
            expect(PathHelpers.formatFile("/tmp//project/file.txt")).to.equal(native("/tmp/project/file.txt"))
        end)
    end)
end

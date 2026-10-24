--[[

PathHelpersTest.spec

Tests for path normalization and display formatting.

--]]

const PathHelpers = require("@luauprojectcli/Helpers/PathHelpers")
const process = require("@lune/process")

const IS_WINDOWS = process.os == "windows"
const SEP = if IS_WINDOWS then "\\" else "/"

const function native(path: string): string
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

        it("should keep the separator on a drive root only on Windows", function()
            const expected = if IS_WINDOWS then `C:{SEP}` else "C:"
            expect(PathHelpers.trimTrailingSeparators("C:\\")).to.equal(expected)
            expect(PathHelpers.trimTrailingSeparators("C:\\\\")).to.equal(expected)
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
            const home = process.env.HOME
            if not home or home == "" then
                return
            end
            expect(PathHelpers.formatDirectory(`{home}//git/project`)).to.equal(native("~/git/project/"))
        end)

        it("should not replace a sibling of the home directory with ~", function()
            const home = process.env.HOME
            if not home or home == "" then
                return
            end
            const sibling = PathHelpers.normalize(`{home}-backup/project`)
            expect(PathHelpers.formatDirectory(sibling)).to.equal(sibling .. SEP)
        end)

        it("should show a drive-relative path as the drive's current directory on Windows", function()
            -- On POSIX "C:" is an ordinary directory name
            const expected = if IS_WINDOWS then `C:.{SEP}` else "C:/"
            expect(PathHelpers.formatDirectory("C:")).to.equal(expected)
        end)
    end)

    describe("PathHelpers.formatFile", function()
        it("should normalize without a trailing separator", function()
            expect(PathHelpers.formatFile("/tmp//project/file.txt")).to.equal(native("/tmp/project/file.txt"))
        end)
    end)
end

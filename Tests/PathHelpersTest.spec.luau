--[[

PathHelpersTest.spec

Tests for path normalization and display formatting.

--]]

const Testable = require("@devpackages/Testable")

const PathHelpers = require("@luauprojectcli/Helpers/PathHelpers")
const process = require("@lune/process")

const describe, expect, it = Testable.describe, Testable.expect, Testable.it

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

        it("should treat backslashes as separators only on Windows", function()
            -- On Unix a backslash is an ordinary filename character
            const expected = if IS_WINDOWS then native("a/b/c/d") else "a\\b/c\\\\d"
            expect(PathHelpers.normalize("a\\b/c\\\\d")).to.equal(expected)
            expect(PathHelpers.normalize("/tmp/team\\project")).to.equal(
                if IS_WINDOWS then native("/tmp/team/project") else "/tmp/team\\project"
            )
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
            expect(PathHelpers.trimTrailingSeparators("C:/")).to.equal(expected)
            expect(PathHelpers.trimTrailingSeparators("C://")).to.equal(expected)
        end)

        it("should only trim trailing backslashes on Windows", function()
            const expected = if IS_WINDOWS then "/a/b" else "/a/b\\"
            expect(PathHelpers.trimTrailingSeparators("/a/b\\")).to.equal(expected)
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

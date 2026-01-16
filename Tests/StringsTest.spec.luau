--[[

StringsTest

Tests for the strings helper module including toKebabCase and toPascalCase conversions.

--]]

local StringHelpers = require("@luauprojectcli/Helpers/StringHelpers")

return function()
    describe("toKebabCase", function()
        it("should convert spaces to hyphens", function()
            expect(StringHelpers.toKebabCase("hello world")).to.equal("hello-world")
        end)

        it("should convert to lowercase", function()
            expect(StringHelpers.toKebabCase("HelloWorld")).to.equal("helloworld")
        end)

        it("should remove non-alphanumeric characters except hyphens", function()
            expect(StringHelpers.toKebabCase("hello@world!")).to.equal("helloworld")
        end)

        it("should collapse multiple spaces to single hyphen", function()
            expect(StringHelpers.toKebabCase("hello   world")).to.equal("hello-world")
        end)

        it("should handle mixed case with spaces", function()
            expect(StringHelpers.toKebabCase("My Cool Project")).to.equal("my-cool-project")
        end)

        it("should preserve existing hyphens", function()
            expect(StringHelpers.toKebabCase("my-project")).to.equal("my-project")
        end)

        it("should return empty string for non-alphanumeric input", function()
            expect(StringHelpers.toKebabCase("!!!")).to.equal("")
        end)

        it("should handle numbers", function()
            expect(StringHelpers.toKebabCase("project123")).to.equal("project123")
        end)
    end)

    describe("toPascalCase", function()
        it("should capitalize first letter", function()
            expect(StringHelpers.toPascalCase("hello")).to.equal("Hello")
        end)

        it("should convert kebab-case to PascalCase", function()
            expect(StringHelpers.toPascalCase("hello-world")).to.equal("HelloWorld")
        end)

        it("should handle multiple hyphens", function()
            expect(StringHelpers.toPascalCase("my-cool-project")).to.equal("MyCoolProject")
        end)

        it("should handle single word", function()
            expect(StringHelpers.toPascalCase("project")).to.equal("Project")
        end)

        it("should handle already PascalCase input", function()
            expect(StringHelpers.toPascalCase("Project")).to.equal("Project")
        end)
    end)
end

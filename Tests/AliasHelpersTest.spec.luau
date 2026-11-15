--[[

AliasHelpersTest.spec

Tests for the alias helper module, covering how project names become .luaurc aliases and
which aliases are reserved by the template.

--]]

const AliasHelpers = require("@luauprojectcli/Helpers/AliasHelpers")

return function()
    describe("toAliasName", function()
        it("should remove hyphens", function()
            expect(AliasHelpers.toAliasName("my-cool-project")).to.equal("mycoolproject")
        end)

        it("should leave names without hyphens unchanged", function()
            expect(AliasHelpers.toAliasName("project")).to.equal("project")
        end)

        it("should return a single value", function()
            expect(select("#", AliasHelpers.toAliasName("a-b"))).to.equal(1)
        end)
    end)

    describe("isReservedAlias", function()
        it("should reserve every alias in the template's .luaurc", function()
            for _, alias in { "devpackages", "lune", "packages", "submodules", "tests" } do
                expect(AliasHelpers.isReservedAlias(alias)).to.equal(true)
            end
        end)

        it("should reserve a hyphenated name that collapses to a reserved alias", function()
            expect(AliasHelpers.isReservedAlias(AliasHelpers.toAliasName("sub-modules"))).to.equal(true)
        end)

        it("should not reserve ordinary project names", function()
            for _, alias in { "myproject", "submodule", "testsuite", "luaupackagetemplate" } do
                expect(AliasHelpers.isReservedAlias(alias)).to.equal(false)
            end
        end)
    end)

    describe("ReservedAliases", function()
        it("should list the reserved aliases in sorted order", function()
            expect(table.concat(AliasHelpers.ReservedAliases, ",")).to.equal(
                "devpackages,lune,packages,submodules,tests"
            )
        end)

        it("should be frozen", function()
            expect(table.isfrozen(AliasHelpers.ReservedAliases)).to.equal(true)
        end)
    end)
end

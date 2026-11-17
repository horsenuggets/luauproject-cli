--[[

WorkflowHelpersTest.spec

Tests for preparing the luau-cicd workflow templates for a new project, covering Wally
stripping for private packages and leaving everything else untouched.

--]]

const Testable = require("@devpackages/Testable")

const WorkflowHelpers = require("@luauprojectcli/Helpers/WorkflowHelpers")

const describe, expect, it = Testable.describe, Testable.expect, Testable.it

const RELEASE_CI = [[
name: Release / CI

jobs:
  check-script-executability:
    name: check-script-executability
    runs-on: ubuntu-latest
    steps:
      - name: Check script executability
        run: ./Submodules/luau-cicd/Scripts/CheckScriptExecutability.exec.luau

  verify-wally-auth:
    name: verify-wally-auth
    runs-on: ubuntu-latest
    steps:
      - name: Check WALLY_AUTH exists
        env:
          WALLY_AUTH: ${{ secrets.WALLY_AUTH }}
        run: |
          echo "WALLY_AUTH is configured."

  validate-pr-title:
    name: validate-pr-title
    runs-on: ubuntu-latest
]]
const RELEASE_CD = [[
name: Release / CD

jobs:
  publish-release:
    name: publish-release
    runs-on: ubuntu-latest
    steps:
      - name: Create git tag
        run: |
          git tag 1.0.0

      - name: Publish to Wally
        env:
          WALLY_AUTH: ${{ secrets.WALLY_AUTH }}
        run: |
          wally publish

      - name: Create GitHub release
        run: |
          gh release create 1.0.0
]]
const MAIN_CI = [[
name: Main / CI

jobs:
  verify-wally-auth:
    name: verify-wally-auth
    steps:
      - name: Publish to Wally
]]
const FILES = {
    ["main.ci.yml"] = MAIN_CI,
    ["release.cd.yml"] = RELEASE_CD,
    ["release.ci.yml"] = RELEASE_CI,
}

return function()
    describe("prepareWorkflow", function()
        it("should only strip Wally from the release workflows of private packages", function()
            for fileName, content in FILES do
                for _, isPrivatePackage in { false, true } do
                    const result = WorkflowHelpers.prepareWorkflow(fileName, content, isPrivatePackage)
                    const shouldStrip = isPrivatePackage and fileName ~= "main.ci.yml"
                    expect(result == content).to.equal(not shouldStrip)
                end
            end
        end)

        it("should remove the Wally auth job and keep its neighbors", function()
            const result = WorkflowHelpers.prepareWorkflow("release.ci.yml", RELEASE_CI, true)
            expect(result:find("verify-wally-auth", 1, true)).to.equal(nil)
            expect(result:find("WALLY_AUTH", 1, true)).to.equal(nil)
            expect(result:find("  check-script-executability:", 1, true)).to.be.ok()
            expect(result:find("CheckScriptExecutability.exec.luau", 1, true)).to.be.ok()
            expect(result:find("  validate-pr-title:", 1, true)).to.be.ok()
        end)

        it("should remove the Wally publish step and keep its neighbors", function()
            const result = WorkflowHelpers.prepareWorkflow("release.cd.yml", RELEASE_CD, true)
            expect(result:find("Publish to Wally", 1, true)).to.equal(nil)
            expect(result:find("wally publish", 1, true)).to.equal(nil)
            expect(result:find("- name: Create git tag", 1, true)).to.be.ok()
            expect(result:find("git tag 1.0.0", 1, true)).to.be.ok()
            expect(result:find("- name: Create GitHub release", 1, true)).to.be.ok()
        end)

        it("should keep both Wally pieces for public packages", function()
            expect(WorkflowHelpers.prepareWorkflow("release.ci.yml", RELEASE_CI, false)).to.equal(RELEASE_CI)
            expect(WorkflowHelpers.prepareWorkflow("release.cd.yml", RELEASE_CD, false)).to.equal(RELEASE_CD)
        end)

        it("should return the same result when called twice with the same input", function()
            for fileName, content in FILES do
                const first = WorkflowHelpers.prepareWorkflow(fileName, content, true)
                expect(WorkflowHelpers.prepareWorkflow(fileName, content, true)).to.equal(first)
            end
        end)
    end)
end

--[[

GitHubHelpersTest.spec

Tests for the pure GitHub helpers, covering owner normalization, deciding how the
repository is set up from flags, and parsing repository info from the GitHub CLI.

--]]

const Testable = require("@devpackages/Testable")

const GitHubHelpers = require("@luauprojectcli/Helpers/GitHubHelpers")

const describe, expect, it = Testable.describe, Testable.expect, Testable.it

const function expectedRepoMode(flags: GitHubHelpers.RepoModeFlags): (string?, boolean)
    if flags.NoGithub and (flags.Existing or flags.Github or flags.Private) then
        return nil, true
    end
    if flags.Existing and (flags.Github or flags.Private) then
        return nil, true
    end
    if flags.NoGithub then
        return "None", false
    end
    if flags.Existing then
        return "Existing", false
    end
    if flags.Github or flags.Private then
        return "New", false
    end
    return nil, false
end

return function()
    describe("GitHubHelpers.normalizeOwner", function()
        it("should lowercase mixed-case owners", function()
            expect(GitHubHelpers.normalizeOwner("ExpeditionsEntertainment")).to.equal("expeditionsentertainment")
            expect(GitHubHelpers.normalizeOwner("MyOrg")).to.equal("myorg")
        end)

        it("should trim surrounding whitespace", function()
            expect(GitHubHelpers.normalizeOwner("  MyOrg \n")).to.equal("myorg")
        end)

        it("should leave lowercase owners unchanged", function()
            expect(GitHubHelpers.normalizeOwner("my-org-2")).to.equal("my-org-2")
            expect(GitHubHelpers.normalizeOwner("")).to.equal("")
        end)

        it("should be idempotent", function()
            const once = GitHubHelpers.normalizeOwner("My-Org")
            expect(GitHubHelpers.normalizeOwner(once)).to.equal(once)
        end)
    end)

    describe("GitHubHelpers.resolveRepoMode", function()
        it("should match the expected mode for every flag combination", function()
            for bits = 0, 15 do
                const flags = {
                    Existing = bit32.btest(bits, 1),
                    Github = bit32.btest(bits, 2),
                    NoGithub = bit32.btest(bits, 4),
                    Private = bit32.btest(bits, 8)
                }
                const mode, err = GitHubHelpers.resolveRepoMode(flags)
                const expectedMode, expectError = expectedRepoMode(flags)
                expect(mode).to.equal(expectedMode)
                expect(err ~= nil).to.equal(expectError)
                -- A mode and an error are never returned together
                expect(mode == nil or err == nil).to.equal(true)
            end
        end)

        it("should prompt when no flags are given", function()
            const mode, err = GitHubHelpers.resolveRepoMode({
                Existing = false,
                Github = false,
                NoGithub = false,
                Private = false
            })
            expect(mode).to.equal(nil)
            expect(err).to.equal(nil)
        end)

        it("should connect to an existing repository with --existing", function()
            const mode = GitHubHelpers.resolveRepoMode({
                Existing = true,
                Github = false,
                NoGithub = false,
                Private = false
            })
            expect(mode).to.equal("Existing")
        end)
    end)

    describe("GitHubHelpers.RepoModeChoices", function()
        it("should list each mode once in a fixed order", function()
            const modes = {}
            for _, choice in GitHubHelpers.RepoModeChoices do
                table.insert(modes, choice.Mode)
            end
            expect(table.concat(modes, ",")).to.equal("New,Existing,None")
        end)
    end)

    describe("GitHubHelpers.getRemoteUrl", function()
        it("should use SSH when the protocol is ssh", function()
            expect(GitHubHelpers.getRemoteUrl("my-org/my-proj", "ssh\n")).to.equal("git@github.com:my-org/my-proj.git")
        end)

        it("should use HTTPS for https, unknown, or missing protocols", function()
            const expected = "https://github.com/my-org/my-proj.git"
            expect(GitHubHelpers.getRemoteUrl("my-org/my-proj", "https")).to.equal(expected)
            expect(GitHubHelpers.getRemoteUrl("my-org/my-proj", "")).to.equal(expected)
            expect(GitHubHelpers.getRemoteUrl("my-org/my-proj", "not-ssh")).to.equal(expected)
            expect(GitHubHelpers.getRemoteUrl("my-org/my-proj", nil)).to.equal(expected)
        end)
    end)

    describe("GitHubHelpers.getPushArgs", function()
        it("should push the branch to origin with gh as the github.com credential helper", function()
            const args = GitHubHelpers.getPushArgs("dev")
            expect(table.concat(args, " ")).to.equal(
                "-c credential.https://github.com.helper= "
                    .. "-c credential.https://github.com.helper=!gh auth git-credential "
                    .. "push -u origin dev"
            )
        end)

        it("should reset inherited helpers before adding the gh helper", function()
            const args = GitHubHelpers.getPushArgs("main")
            expect(args[2]).to.equal("credential.https://github.com.helper=")
            expect(args[4]).to.equal("credential.https://github.com.helper=!gh auth git-credential")
        end)
    end)

    describe("GitHubHelpers.parseRepoInfo", function()
        it("should parse an empty private repository", function()
            const info = GitHubHelpers.parseRepoInfo('{"isEmpty":true,"isPrivate":true}')
            assert(info, "info should be parsed")
            expect(info.IsEmpty).to.equal(true)
            expect(info.IsPrivate).to.equal(true)
        end)

        it("should parse a non-empty public repository", function()
            const info = GitHubHelpers.parseRepoInfo('{"isEmpty":false,"isPrivate":false}\n')
            assert(info, "info should be parsed")
            expect(info.IsEmpty).to.equal(false)
            expect(info.IsPrivate).to.equal(false)
        end)

        it("should return nil for invalid or incomplete output", function()
            expect(GitHubHelpers.parseRepoInfo("")).to.equal(nil)
            expect(GitHubHelpers.parseRepoInfo("not json")).to.equal(nil)
            expect(GitHubHelpers.parseRepoInfo('{"isEmpty":true}')).to.equal(nil)
            expect(GitHubHelpers.parseRepoInfo("[]")).to.equal(nil)
        end)
    end)
end

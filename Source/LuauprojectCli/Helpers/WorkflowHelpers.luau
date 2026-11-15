--[[

WorkflowHelpers

Pure helpers for adjusting the CI workflow templates a new project copies from
luau-cicd. Private packages don't publish to Wally, so their release workflows drop the
Wally auth check and the publish step.

--]]

const RELEASE_CD_FILE = "release.cd.yml"
const RELEASE_CI_FILE = "release.ci.yml"
const WALLY_AUTH_JOB_PATTERN = "^%s+verify%-wally%-auth:%s*$"
const WALLY_PUBLISH_STEP_PATTERN = "name: Publish to Wally"

const WorkflowHelpers = {}

--[[
    Removes a YAML job block from workflow content. Finds the job key matching the
    pattern and removes everything until the next job key at the same indent level.
]]
function WorkflowHelpers.removeJobBlock(content: string, jobKeyPattern: string): string
    assert(type(content) == "string")
    assert(type(jobKeyPattern) == "string")

    const lines = {}
    local removing = false
    local jobIndent = 0

    for line in (content .. "\n"):gmatch("(.-)\n") do
        const indent = #(line:match("^( *)") or "")
        if not removing then
            if line:match(jobKeyPattern) then
                removing = true
                jobIndent = indent
                continue
            end
            table.insert(lines, line)
        else
            -- Blank lines and deeper-indented content belong to the job being removed
            const isBlank = line:match("^%s*$")
            if not isBlank and indent <= jobIndent and line:match("^%s+%S") then
                removing = false
                table.insert(lines, line)
            end
        end
    end

    return table.concat(lines, "\n") .. "\n"
end

--[[
    Removes a YAML step block from workflow content. Finds the step whose line matches
    the pattern and removes it through to the next step or the end of the steps.
]]
function WorkflowHelpers.removeStepBlock(content: string, stepNamePattern: string): string
    assert(type(content) == "string")
    assert(type(stepNamePattern) == "string")

    const lines = {}
    local removing = false
    local stepIndent = 0

    for line in (content .. "\n"):gmatch("(.-)\n") do
        const indent = #(line:match("^( *)") or "")
        if not removing then
            if line:match(stepNamePattern) then
                removing = true
                stepIndent = indent
                -- Drop the step's "- name:" line if it was already kept
                if #lines > 0 and lines[#lines]:match("^%s+%- name:") then
                    table.remove(lines)
                end
                continue
            end
            table.insert(lines, line)
        else
            const isBlank = line:match("^%s*$")
            if not isBlank and indent <= stepIndent and line:match("^%s+%- name:") then
                removing = false
                table.insert(lines, line)
            elseif not isBlank and indent < stepIndent then
                removing = false
                table.insert(lines, line)
            end
        end
    end

    return table.concat(lines, "\n") .. "\n"
end

--[[
    Returns a copied workflow's content for a new project. Private packages lose the
    Wally auth check in the release CI workflow and the Wally publish step in the
    release CD workflow. Everything else is returned unchanged.
]]
function WorkflowHelpers.prepareWorkflow(fileName: string, content: string, isPrivatePackage: boolean): string
    assert(type(fileName) == "string")
    assert(type(content) == "string")
    assert(type(isPrivatePackage) == "boolean")

    if not isPrivatePackage then
        return content
    end
    if fileName == RELEASE_CI_FILE then
        return WorkflowHelpers.removeJobBlock(content, WALLY_AUTH_JOB_PATTERN)
    end
    if fileName == RELEASE_CD_FILE then
        return WorkflowHelpers.removeStepBlock(content, WALLY_PUBLISH_STEP_PATTERN)
    end
    return content
end

return WorkflowHelpers

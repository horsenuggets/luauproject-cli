--[[

AliasHelpers

Helper functions for the .luaurc alias that a new project gets. The alias is the project
name without hyphens, and it can't reuse a name the template's .luaurc already defines.

--]]

-- Every alias in the template's .luaurc except the template's own, which is replaced by
-- the project alias
const RESERVED_ALIASES = {
    "devpackages",
    "lune",
    "packages",
    "submodules",
    "tests",
}

const AliasHelpers = {}

AliasHelpers.ReservedAliases = table.freeze(table.clone(RESERVED_ALIASES))

function AliasHelpers.toAliasName(kebabName: string): string
    assert(type(kebabName) == "string", "kebabName must be a string")
    return (kebabName:gsub("-", ""))
end

function AliasHelpers.isReservedAlias(aliasName: string): boolean
    assert(type(aliasName) == "string", "aliasName must be a string")
    return table.find(RESERVED_ALIASES, aliasName) ~= nil
end

return AliasHelpers

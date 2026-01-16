--[[

strings

Helper functions for string transformations.

--]]

local function toKebabCase(str: string): string
    return str:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
end

local function toPascalCase(kebab: string): string
    return kebab:gsub("^%l", string.upper):gsub("%-(%l)", function(c)
        return c:upper()
    end)
end

return {
    toKebabCase = toKebabCase,
    toPascalCase = toPascalCase,
}

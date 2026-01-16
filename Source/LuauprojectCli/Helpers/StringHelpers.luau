--[[

StringHelpers

Helper functions for string transformations.

--]]

local StringHelpers = {}

function StringHelpers.toKebabCase(str: string): string
    return str:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
end

function StringHelpers.toPascalCase(kebab: string): string
    return kebab:gsub("^%l", string.upper):gsub("%-(%l)", function(c)
        return c:upper()
    end)
end

return StringHelpers

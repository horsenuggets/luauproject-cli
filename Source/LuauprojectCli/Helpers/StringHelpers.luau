--[[

StringHelpers

Helper functions for string transformations.

--]]

const StringHelpers = {}

function StringHelpers.toKebabCase(str: string): string
    return str:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
end

const TWO_LETTER_EXCEPTIONS: { [string]: boolean } = {
    id = true,
    my = true,
}

function StringHelpers.toPascalCase(kebab: string): string
    const parts = kebab:split("-")
    const result = {}
    for _, part in parts do
        if #part == 2 and not TWO_LETTER_EXCEPTIONS[part:lower()] then
            table.insert(result, part:upper())
        else
            table.insert(result, part:sub(1, 1):upper() .. part:sub(2))
        end
    end
    return table.concat(result)
end

return StringHelpers

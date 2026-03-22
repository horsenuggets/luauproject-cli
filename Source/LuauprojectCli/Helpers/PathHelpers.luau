--[[

PathHelpers

Helper functions for path normalization and formatting. Ensures consistent path separators
across platforms and removes duplicate slashes.

--]]

local process = require("@lune/process")

local IS_WINDOWS = process.os == "windows"
local NATIVE_SEP = if IS_WINDOWS then "\\" else "/"

local PathHelpers = {}

--[[
	Normalizes a path to use the native separator for the current OS and removes duplicate
	separators.

	Examples:
	- On Windows: "C:/Users/name/.config" -> "C:\Users\name\.config"
	- On Unix: "/home/user//config" -> "/home/user/config"
	- Mixed: "C:\Users/name//.config" -> "C:\Users\name\.config" (Windows)
]]
function PathHelpers.normalize(path: string): string
    assert(type(path) == "string", "path must be a string")

    -- Replace all slashes with native separator
    local normalized = path:gsub("[/\\]", NATIVE_SEP)

    -- Remove duplicate separators (but preserve UNC paths on Windows like \\server\share)
    if IS_WINDOWS then
        -- Preserve leading \\ for UNC paths, then dedupe the rest
        local prefix = ""
        if normalized:sub(1, 2) == "\\\\" then
            prefix = "\\\\"
            normalized = normalized:sub(3)
        end
        normalized = prefix .. normalized:gsub("\\\\+", "\\")
    else
        normalized = normalized:gsub("//+", "/")
    end

    return normalized
end

--[[
	Joins path segments using the native separator.

	Example: PathHelpers.join("home", "user", ".config") -> "home/user/.config" (Unix)
]]
function PathHelpers.join(...: string): string
    local parts = { ... }
    assert(#parts > 0, "at least one path segment is required")

    local result = table.concat(parts, NATIVE_SEP)
    return PathHelpers.normalize(result)
end

--[[
	Replaces the home directory prefix with ~ for display purposes.

	Example: "/Users/chris/git/my-project" -> "~/git/my-project"
]]
function PathHelpers.tildify(path: string): string
    assert(type(path) == "string", "path must be a string")

    local home = process.env.HOME
    if not home or home == "" then
        return path
    end

    -- Ensure home doesn't end with a separator
    home = string.gsub(home, "[/\\]+$", "")

    if string.sub(path, 1, #home) == home then
        return "~" .. string.sub(path, #home + 1)
    end

    return path
end

return PathHelpers

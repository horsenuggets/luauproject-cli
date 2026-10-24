--[[

PathHelpers

Helper functions for path normalization and formatting. Ensures consistent path separators
across platforms and removes duplicate slashes.

--]]

const process = require("@lune/process")

const IS_WINDOWS = process.os == "windows"
const NATIVE_SEP = if IS_WINDOWS then "\\" else "/"

const PathHelpers = {}

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
    const parts = { ... }
    assert(#parts > 0, "at least one path segment is required")

    const result = table.concat(parts, NATIVE_SEP)
    return PathHelpers.normalize(result)
end

--[[
    Replaces the home directory prefix with ~ for display purposes.

    Example: "/home/user/git/my-project" -> "~/git/my-project"
]]
function PathHelpers.tildify(path: string): string
    assert(type(path) == "string", "path must be a string")

    local home = process.env.HOME
    if not home or home == "" then
        return path
    end

    -- Ensure home uses the same separators as the path and doesn't end with one
    home = string.gsub(PathHelpers.normalize(home), "[/\\]+$", "")
    if home == "" then
        return path
    end

    -- Only substitute a whole home directory, not a sibling like "/home/user-backup"
    const nextChar = string.sub(path, #home + 1, #home + 1)
    if string.sub(path, 1, #home) == home and (nextChar == "" or nextChar == "/" or nextChar == "\\") then
        return "~" .. string.sub(path, #home + 1)
    end

    return path
end

--[[
    Removes trailing separators from a path, preserving a bare root. On Windows, drive roots like
    "C:\" keep their separator, since "C:" alone means the drive's current directory on Windows.

    Example: "/home/user/project//" -> "/home/user/project"
]]
function PathHelpers.trimTrailingSeparators(path: string): string
    assert(type(path) == "string", "path must be a string")

    const trimmed = string.gsub(path, "[/\\]+$", "")
    if trimmed == path then
        return path
    end
    if trimmed == "" then
        return NATIVE_SEP
    end
    if IS_WINDOWS and string.match(trimmed, "^%a:$") then
        return trimmed .. NATIVE_SEP
    end
    return trimmed
end

--[[
    Formats a file path for display: normalized, with the home directory replaced by ~.

    Example: "/home/user//git/file.txt" -> "~/git/file.txt"
]]
function PathHelpers.formatFile(path: string): string
    return PathHelpers.tildify(PathHelpers.trimTrailingSeparators(PathHelpers.normalize(path)))
end

--[[
    Formats a directory path for display: normalized, with the home directory replaced by ~,
    and ending in a separator to mark it as a directory. On Windows, a drive-relative "C:" is
    shown as "C:.\" so the trailing separator doesn't make it look like the drive root.

    Example: "/home/user//git/project" -> "~/git/project/"
]]
function PathHelpers.formatDirectory(path: string): string
    const formatted = PathHelpers.formatFile(path)
    if IS_WINDOWS and string.match(formatted, "^%a:$") then
        return formatted .. "." .. NATIVE_SEP
    end
    if string.sub(formatted, -1) == NATIVE_SEP then
        return formatted
    end
    return formatted .. NATIVE_SEP
end

return PathHelpers

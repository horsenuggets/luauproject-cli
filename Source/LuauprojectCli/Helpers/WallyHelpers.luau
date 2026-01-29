--[[

WallyHelpers

Helper functions for interacting with the Wally package manager.

--]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local WallyHelpers = {}

function WallyHelpers.getAuthToken(): string?
    -- First check for env variable containing entire auth.toml content
    local envToken = process.env.WALLY_AUTH
    if envToken and envToken ~= "" then
        return envToken
    end

    local home = process.env.HOME
    if not home then
        return nil
    end

    local authPath = `{home}/.wally/auth.toml`
    if not fs.isFile(authPath) then
        return nil
    end

    -- Verify the file has valid content before returning it
    local content = fs.readFile(authPath)
    local ok, authData = pcall(function()
        return serde.decode("toml", content)
    end)

    if not ok or not authData or not authData.tokens then
        return nil
    end

    -- Check if there's a valid token for wally.run
    local token = authData.tokens["https://api.wally.run/"]
    if not token or token == "" then
        return nil
    end

    -- Return the entire auth.toml content (workflow writes it directly to file)
    return content
end

return WallyHelpers

--[[

WallyHelpers

Helper functions for interacting with the Wally package manager.

--]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local WallyHelpers = {}

function WallyHelpers.getAuthToken(): string?
    local envToken = process.env.WALLY_AUTH_TOKEN
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

    local ok, authData = pcall(function()
        return serde.decode("toml", fs.readFile(authPath))
    end)

    if not ok or not authData or not authData.tokens then
        return nil
    end

    local token = authData.tokens["https://api.wally.run/"]
    if token and token ~= "" then
        return token
    end

    return nil
end

return WallyHelpers

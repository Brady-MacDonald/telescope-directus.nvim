---@class Config
---@field url string The directus url
---@field token string Access token with admin credentials
---@field show_hidden boolean Display hidden collections/fields

--------------------------------------------------------------------------------

---@type Config
local config = {
    url = "http://localhost:8055",
    token = "",
    show_hidden = false,
}

local M = {}

---Set configuration options
---@param opts Config
M.set = function(opts)
    config = vim.tbl_extend("force", config, opts)
end

---Get the config
---@return Config
M.get = function()
    return config
end

return M

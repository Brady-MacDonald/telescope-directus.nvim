-- Query Directus

local plenary = require("plenary")

Q = {}

---Build the directus URL for getting items
---@param config config Users config
---@param collection string Directus collection to query
---@return string url
Q.items_url = function(config, collection, fields)
    local url = config.url .. "/items/" .. collection

    local filter = "?"
    for _, val in ipairs(fields) do
        filter = filter .. "&filter[" .. val.field .. "]=" .. "best-sportsbooks"
    end

    url = url .. filter
    return url
end

---Make HTTP request to directus
---@param url string Directus URL
---@param token string access token with admin credentials
---@return table | nil data The directus response data or nil on error
Q.directus_fetch = function(url, token)
    local auth = "Authorization: Bearer " .. token
    local plenary_res = plenary.job:new({
        command = "curl",
        args = { "-H", auth, "-g", url }
    }):sync()

    if #plenary_res == 0 then
        vim.notify("Unable to make curl request", "error", { title = "Plenary Error" })
        return nil
    end

    local data = vim.json.decode(plenary_res[1])
    if data.errors ~= nil then
        local directus_err = data.errors[1].message
        local err = directus_err .. "\n" .. url
        vim.notify(err, "error", { title = "Directus Error" })
        return nil
    end

    return data.data
end

return Q

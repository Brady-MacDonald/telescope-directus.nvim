local plenary = require("plenary")

Q = {}

---Build the directus URL for getting items
---@param config user_config Users config
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

---Create closure for auth_header
---@param token string Directus admin token
---@return function directus_api Used to query Directus
Q.make_directus_api = function(token)
    local auth_header = "Authorization: Bearer " .. token

    ---Make HTTP request to directus
    ---@param url string Directus URL
    ---@return table | nil data The directus response data or nil on error
    return function(url)
        local plenary_res = plenary.job:new({
            command = "curl",
            args = { "-H", auth_header, "-g", url }
        }):sync()

        if not plenary_res or #plenary_res == 0 then
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
end

return Q

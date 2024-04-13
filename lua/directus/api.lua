local plenary = require("plenary")

local API = {}

---
---@param collection string
---@param query table|nil
---@return table|nil
API.get_items = function(collection, query)
    local directus = require("directus")
    local utils = require("directus.utils")

    local data = directus._directus_api("/items/" .. collection)
    if data == nil then
        return nil
    end

    return data
end

API.get_fields = function(collection)
    local directus = require("directus")
    local utils = require("directus.utils")

    local data = directus._directus_api("/fields/" .. collection)
    if data == nil then
        return nil
    end

    -- top level fields have a meta-group = vim.NIL

    local fields = utils.filter_hidden(data)
    utils.merge_sort(fields)

    return fields
end

---Get Collection info
---@param collection string|nil Collection to get info for, or all collections if nil
---@return table|nil
API.get_collections = function(collection)
    local directus = require("directus")
    local utils = require("directus.utils")

    local data = directus._directus_api("/collections/" .. (collection or ""))
    if data == nil then
        return nil
    end

    local collections = utils.filter_hidden(data)
    return collections
end

---Build the directus URL for getting items
---@param config user_config Users config
---@param collection string Directus collection to query
---@return string url
API.items_url = function(config, collection, fields)
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
---@param url string Directus URL
---@return function directus_api Used to make authenticated requests to directus
API.make_directus_api = function(token, url)
    local auth_header = "Authorization: Bearer " .. token

    ---Make HTTP request to directus
    ---@param query string Directus query appended to url
    ---@return table|nil data The directus response data or nil on error
    return function(query)
        local plenary_res = plenary.job:new({
            command = "curl",
            args = { "-H", auth_header, "-g", url .. query }
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

return API

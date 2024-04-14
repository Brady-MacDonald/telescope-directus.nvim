local utils = require("directus.utils")
local plenary = require("plenary")

local API = {}

---Get the items in a collection
---@param collection string Directus collection to get items for
---@param filter table|nil Filter to apply to query
---@param fields string|nil Fields to populate values for
---@return table|nil
API.get_items = function(collection, filter, fields)
    local directus = require("directus")

    local dir_fields = "?fields=*"
    if fields ~= nil then
        dir_fields = "?fields=" .. fields
    end

    local dir_filter = ""
    if filter ~= nil then
        dir_filter = "&filter=" .. vim.json.encode(filter)
    end

    local url = "/items/" .. collection .. dir_fields .. dir_filter

    local data = directus._directus_api(url)
    if data == nil then
        return nil
    end

    return data
end

---Get all fields for a given collection
---@param collection string
---@return nil
API.get_fields = function(collection)
    local directus = require("directus")

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
---@return Collection|Collection[]|nil
API.get_collections = function(collection)
    local directus = require("directus")

    local data = directus._directus_api("/collections/" .. (collection or ""))
    if data == nil then
        return nil
    end

    local collections = utils.filter_hidden(data)
    return collections
end

---Create closure for directus token and url
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

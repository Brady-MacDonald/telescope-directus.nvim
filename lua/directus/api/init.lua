local utils = require("directus.utils")
local plenary = require("plenary")

local API = {}

---Get the items in a collection
---@param collection string Directus collection to get items for
---@param params DirectusParams|nil
---@return table|nil
API.get_items = function(collection, params)
    local directus = require("directus")

    local url = "/items/" .. collection

    if params ~= nil then
        local fields = "?fields=*"
        if params.fields ~= nil then
            fields = "?fields=" .. fields
        end

        local filter = ""
        if params.filter ~= nil then
            filter = "&filter=" .. vim.json.encode(params.filter)
        end

        local limit = ""
        if params.limit ~= nil then
            limit = "&limit=" .. tostring(params.limit)
        end

        url = url .. fields .. filter .. limit
    end

    local data = directus._directus_api.get(url)
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

    local data = directus._directus_api.get("/fields/" .. collection)
    if data == nil then
        return nil
    end

    -- top level fields have a meta-group = vim.NIL

    local fields = utils.filter_hidden(data)
    utils.merge_sort(fields)

    return fields
end

---Delete a field from a collection
---@param collection string
---@param field string
API.delete_field = function(collection, field)
    local directus = require("directus")

    local res_status = directus._directus_api.delete("/fields/" .. collection .. "/" .. field)
    if not res_status then
        return nil
    end

    return res_status
end
---
---Delete a field from a collection
---@param collection string
---@param field Field
API.create_field = function(collection, field)
    local directus = require("directus")

    field.collection = collection
    field.meta.collection = collection
    field.meta.id = nil
    field.meta.sort = nil
    field.meta.group = nil
    field.schema = nil

    local data = directus._directus_api.post("/fields/" .. collection, field)
    if data == nil then
        return nil
    end

    return data
end

---Get Collection info
---@param collection string|nil Collection to get info for, or all collections if nil
---@return Collection|Collection[]|nil
API.get_collections = function(collection)
    local directus = require("directus")

    local data = directus._directus_api.get("/collections/" .. (collection or ""))
    if data == nil then
        return nil
    end

    local collections = utils.filter_hidden(data)
    return collections
end

---@class DirectusApi
---@field get function
---@field post function
---@field delete function

---Create closure for directus token and url
---@param token string Directus admin token
---@param url string Directus URL
---@return DirectusApi directus_api Used to make authenticated requests to directus
API.make_directus_api = function(token, url)
    local auth_header = "Authorization: Bearer " .. token

    ---Make HTTP GET request to directus
    ---@param query string Directus query appended to url
    ---@return table|nil data The directus response data or nil on error
    local function get(query)
        local plenary_res = plenary.job:new({
            command = "curl",
            args = { "-H", auth_header, "-g", url .. query }
        }):sync()

        if not plenary_res or #plenary_res == 0 then
            vim.notify("Unable to make GET request", "error", { title = "Plenary Error" })
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

    ---Make HTTP DELETE request to directus
    ---@param query string Directus query appended to url
    ---@param body table Directus post content
    ---@return table|nil data The directus response data or nil on error
    local function post(query, body)
        local content_header = "Content-Type: application/json"
        local body_json = vim.json.encode(body)

        local plenary_res = plenary.job:new({
            command = "curl",
            args = { "-H", auth_header, "-H", content_header, "-X", "POST", "-d", body_json, "-g", url .. query }
        }):sync()

        if not plenary_res or #plenary_res == 0 then
            vim.notify("Unable to make POST request", "error", { title = "Plenary Error" })
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

    ---Make HTTP DELETE request to directus
    ---@param query string Directus query appended to url
    ---@return boolean data Indicate if delete was a success
    local function delete(query)
        local plenary_res = plenary.job:new({
            command = "curl",
            args = { "-H", auth_header, "-X", "DELETE", "-g", url .. query }
        }):sync()

        if not plenary_res then
            vim.notify("Unable to make DELETE request", "error", { title = "Plenary Error" })
            return false
        end

        return true
    end

    return {
        get = get,
        post = post,
        delete = delete
    }
end

return API

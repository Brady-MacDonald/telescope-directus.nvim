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
---@return table
Q.directus_fetch = function(url, token)
    local auth = "Authorization: Bearer " .. token
    local plenary_res = plenary.job:new({
        command = "curl",
        args = { "-H", auth, "-g", url }
    }):sync()

    if #plenary_res == 0 then
        vim.notify("Bad")
        return {
            errors = {
                message = "Unable to make plenary curl request"
            }
        }
    end

    local data = vim.json.decode(plenary_res[1])
    return data
end

return Q

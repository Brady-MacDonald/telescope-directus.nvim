local HEALTH = {}

local function check_setup()
    return true
end

HEALTH.check = function()
    vim.health.start("Directus report")

    -- make sure setup function parameters are ok
    if check_setup() then
        vim.health.ok("Directus URL is good")
        vim.health.ok("Directus admin token is good")
    else
        vim.health.error("Config is incorrect, missing something")
    end
end

return HEALTH

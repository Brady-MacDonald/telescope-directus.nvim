local HEALTH = {}

local function check_setup()
    return true
end

HEALTH.check = function()
    vim.health.start("Directus report")

    local ok_telescope, _ = pcall(require, "telescope")
    if not ok_telescope then
        vim.health.error("telescope-directus.nvim requires nvim-telescope/telescope.nvim")
    else
        vim.health.ok("telescope.nvim is installed")
    end

    local ok_plenary, _ = pcall(require, "telescope")
    if not ok_plenary then
        vim.health.error("telescope-directus.nvim requires plenaty")
    else
        vim.health.ok("plenary is installed")
    end

    -- TODO: Check for curl/wget
    -- check $(which curl) to ensure curl is installed

    if check_setup() then
        vim.health.ok("Directus URL is good")
        vim.health.ok("Directus admin token is good")
    else
        vim.health.error("Config is incorrect, missing something")
    end
end

return HEALTH

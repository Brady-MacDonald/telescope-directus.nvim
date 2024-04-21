local M = {}

function M.telescope(opts)
    local directus = require("directus")
    directus.directus_collections(opts)
end

return require("telescope").register_extension({
    exports = {
        directus = M.telescope
    },
})

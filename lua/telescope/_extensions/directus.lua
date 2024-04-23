local ok, telescope = pcall(require, "telescope")

if not ok then
    error("telescope-directus.nvim requires nvim-telescope/telescope.nvim")
end

return telescope.register_extension({
    exports = {
        directus = require("directus").directus_collections
    },
})

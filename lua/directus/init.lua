local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local finders = require("telescope.finders")
local config = require("telescope.config").values

local filter = require("directus.filter")
local api = require("directus.api")
local utils = require("directus.utils")

M = {}

---@class CollectionsConfig
---@field collection string Name of the collection in Directus
---@field filters table Default filters to apply

---@class config
---@field url string The directus url
---@field token string Access token with admin credentials
---@field collections CollectionsConfig Configured Directus collections
M.config = {}


--------------------------------------------------------------------------------
---Get all Directus Collections
---@param opts any
M.directus_collections = function(opts)
    pickers.new(opts, {
        prompt_title = "Collection",
        sorter = config.generic_sorter(opts),

        finder = finders.new_dynamic({
            fn = function()
                local url = M.config.url .. "/collections"
                local data = api.directus_fetch(url, M.config.token)
                if data.errors ~= nil then
                    local err = data.errors[1].message
                    vim.notify(err, "error", { title = "Directus Collections" })
                    return {}
                end

                -- filter hidden collections
                local collections = {}
                for _, collection in ipairs(data.data) do
                    if not collection.meta.hidden then
                        table.insert(collections, collection)
                    end
                end

                -- Missing some collections without a meta.sort property
                -- utils.merge_sort(collections)

                return collections
            end,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.collection,
                    ordinal = entry.collection,
                }
            end
        }),

        previewer = previewers.new_buffer_previewer({
            title = "Collection Info",
            define_preview = function(self, entry)
                local item_data = vim.split(vim.inspect(entry.value), "\n")
                local display = vim.tbl_flatten({ "", item_data })
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, 0, true, display)
            end
        }),

        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                -- open new buffer with JSON data
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                M.directus_fields(opts, selection.display)
            end)
            return true
        end,
    }):find()
end

--------------------------------------------------------------------------------
---Get fields for a given collection
---@param opts any
M.directus_fields = function(opts, collection)
    pickers.new(opts, {
        prompt_title = "Field",
        sorter = config.generic_sorter(opts),

        finder = finders.new_dynamic({
            fn = function()
                local url = M.config.url .. "/fields/" .. collection
                local data = api.directus_fetch(url, M.config.token)
                if data.errors ~= nil then
                    local err = data.errors[1].message
                    vim.notify(err, "error", { title = "Directus Fields" })
                    return {}
                end

                -- filter hidden fields
                local fields = {}
                for _, field in ipairs(data.data) do
                    if not field.meta.hidden and field.meta.group == vim.NIL then
                        table.insert(fields, field)
                    end
                end

                -- top level fields have a meta-group = vim.NIL

                -- sort fields
                utils.merge_sort(fields)

                return fields
            end,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.field,
                    ordinal = entry.field,
                }
            end
        }),

        previewer = previewers.new_buffer_previewer({
            title = "Fields: " .. collection,
            define_preview = function(self, entry)
                local item_data = vim.split(vim.inspect(entry.value), "\n")
                local display = vim.tbl_flatten({ "", item_data })

                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, 0, true, display)
            end
        }),

        attach_mappings = function(prompt_bufnr, map)
            map("i", "bb", function()
                M.directus_collections(opts)
            end)

            actions.select_default:replace(function()
                local single_selection = action_state.get_selected_entry()
                local picker = action_state.get_current_picker(prompt_bufnr)
                local multi_selections = picker:get_multi_selection()

                local selected_fields = { single_selection.value }
                for _, selection in ipairs(multi_selections) do
                    table.insert(selected_fields, selection.value)
                end

                actions.close(prompt_bufnr)

                local drop_down = require("telescope.themes").get_dropdown({})
                M.directus_filters(drop_down, collection, selected_fields)
            end)
            return true
        end,
    }):find()
end

--------------------------------------------------------------------------------
---Update the filter for a given collection
---@param opts any The telescope display options (drop_down)
---@param collection string Directus collection
---@param fields table List of selected fields
M.directus_filters = function(opts, collection, fields)
    local url = M.config.url .. "/items/" .. collection .. "?filter={}"

    pickers.new(opts, {
        prompt_title = "Filters",
        sorter = config.generic_sorter(opts),

        finder = finders.new_table({
            results = fields,
            entry_maker = function(entry)
                return {
                    display = entry.field,
                    ordinal = entry.field,
                    value = entry
                }
            end
        }),

        previewer = previewers.new_buffer_previewer({
            title = collection .. " query",
            define_preview = function(self, entry)
                local data = vim.split(vim.inspect(entry.value), "\n")
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, 0, true,
                    vim.tbl_flatten({ url, "", data }))
            end
        }),

        attach_mappings = function(prompt_bufnr, map)
            map("i", "bb", function(bufnr)
                M.directus_fields({}, collection)
            end)

            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                local current_picker = action_state.get_current_picker(prompt_bufnr)
                local prompt = current_picker:_get_prompt()

                -- capture promt vaue and update filter

                M.directus_items({}, url, collection)
            end)
            return true
        end,

    }):find()
end


--------------------------------------------------------------------------------
---Build the filters for query
---@param opts any
---@param url string
---@param collection string
M.directus_items = function(opts, url, collection)
    pickers.new(opts, {
        prompt_title = "Items",
        sorter = config.generic_sorter(opts),

        finder = finders.new_dynamic({
            fn = function()
                local data = api.directus_fetch(url, M.config.token)
                if data.errors ~= nil then
                    local err = data.errors[1].message
                    vim.notify(err, "error", { title = collection })
                    return {}
                end

                return data.data
            end,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.slug .. " " .. entry.region,
                    ordinal = entry.slug,
                }
            end
        }),

        previewer = previewers.new_buffer_previewer({
            title = "" .. collection,
            define_preview = function(self, entry)
                local item_data = vim.split(vim.inspect(entry.value), "\n")
                local display = vim.tbl_flatten({ "", item_data })

                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, 0, true, display)
            end
        }),

        attach_mappings = function(prompt_bufnr, map)
            map("i", "bb", function()
                M.directus_collections(opts)
            end)
            return true
        end,
    }):find()
end

--------------------------------------------------------------------------------
---Set up the directus.nvim plugin
---@param directus_config config
M.setup = function(directus_config)
    M.config = directus_config

    vim.api.nvim_create_user_command("Directus", function(args)
        if args.args == "collections" then
            M.directus_collections({})
        end
    end, {
        nargs = 1,
        desc = "Directus user command",
        complete = function(args, cmd, cursos)
            return { "collections" }
        end
    })
end

return M

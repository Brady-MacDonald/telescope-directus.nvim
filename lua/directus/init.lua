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

---@class config
---@field url string The directus url
---@field token string Access token with admin credentials
---@field show_hidden boolean Display any hidden collection/fields

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

                local collections = utils.filter_hidden(data.data)
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
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)

                M.directus_fields(opts, selection.display)
            end)
            return true
        end,
    }):find()
end

--------------------------------------------------------------------------------
---Get fields for a given collection
---@param opts table telescope options
---@param collection string Directus collection name
M.directus_fields = function(opts, collection)
    if collection == nil then
        vim.notify("Must provide collection", "error", { title = "Directus Fields" })
        return
    end

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

                -- top level fields have a meta-group = vim.NIL

                local fields = utils.filter_hidden(data.data)
                utils.merge_sort(fields)

                -- for idx, val in ipairs(fields) do
                --     if val.meta.group ~= vim.NIL then
                --         for group_idx, group_val in ipairs(fields) do
                --             if group_val.field == val.meta.group then
                --                 -- P(group_val.field)
                --                 -- P("-> " .. val.field)
                --
                --                 table.insert(fields, group_idx + 2, val)
                --                 table.remove(fields, idx)
                --             end
                --         end
                --     end
                -- end
                return fields
            end,
            entry_maker = function(entry)
                local prefix = ""
                if entry.meta.group ~= vim.NIL then
                    prefix = " -> "
                end

                return {
                    value = entry,
                    display = prefix .. entry.field,
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
            map("i", "cc", function()
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
                M.directus_filters(drop_down, collection, selected_fields, {})
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
M.directus_filters = function(opts, collection, fields, collection_filter)
    if collection == nil then
        vim.notify("Must provide collection", "error", { title = "Directus Filters" })
        return
    end

    local url = M.config.url .. "/items/" .. collection .. "?filter="
    local prev_bufnr

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
                local data = vim.split(vim.inspect(collection_filter), "\n")
                local display = vim.tbl_flatten({ url, data })

                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, 0, true, display)
                prev_bufnr = self.state.bufnr
            end
        }),

        attach_mappings = function(prompt_bufnr, map)
            map("i", "cc", function(bufnr)
                M.directus_collections({})
            end)

            map("i", "ff", function(bufnr)
                M.directus_fields({}, collection)
            end)

            map("i", "ss", function(bufnr)
                url = url .. vim.json.encode(collection_filter)
                M.directus_items({}, url, collection)
            end)

            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                local filter_field = selection.value.field

                if selection.value.meta.interface == "select-dropdown" then
                    local options = {}
                    for _, val in ipairs(selection.value.meta.options.choices) do
                        table.insert(options, val.value)
                    end

                    local x = vim.ui.select(options, {
                        prompt = collection .. ": " .. filter_field,
                        format_item = function(item)
                            return item
                        end,
                    }, function(choice)
                        collection_filter[filter_field] = {
                            _eq = choice
                        }

                        M.directus_filters(opts, collection, fields, collection_filter)
                    end)
                elseif selection.value.meta.interface == "select-dropdown-m2o" then
                    local related_url = M.config.url .. "/items/" .. selection.value.schema.foreign_key_table
                    local related_items = api.directus_fetch(related_url, M.config.token)

                    local options = {}
                    for _, val in ipairs(related_items.data) do
                        table.insert(options, { id = val.id, slug = val.slug })
                    end

                    vim.ui.select(options, {
                        prompt = collection .. ": " .. filter_field,
                        format_item = function(item)
                            return filter_field .. ": " .. item.id .. " -> " .. item.slug
                        end,
                    }, function(choice)
                        collection_filter[filter_field] = {
                            _eq = choice.id
                        }

                        M.directus_filters(opts, collection, fields, collection_filter)
                    end)
                elseif selection.value.meta.interface == "input" then
                    local input = vim.fn.input("Filter value for " .. filter_field .. ": ")
                    collection_filter[filter_field] = {
                        _eq = input
                    }

                    local data = vim.split(vim.inspect(collection_filter), "\n")
                    local display = vim.tbl_flatten({ url, data })
                    vim.api.nvim_buf_set_lines(prev_bufnr, 0, -1, true, display)
                end
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
            map("i", "cc", function(bufnr)
                M.directus_collections({})
            end)

            map("i", "ff", function(bufnr)
                M.directus_fields({}, collection)
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

    vim.api.nvim_create_user_command("Directus", function(opts)
        if opts.fargs[1] == "collections" then
            M.directus_collections({})
        elseif opts.fargs[1] == "fields" then
            local collection = opts.fargs[2]
            if collection == nil then
                vim.notify("Must specify collection", "info", { title = "Directus Fields" })
            else
                M.directus_fields({}, collection)
            end
        end
    end, {
        nargs = "+",
        desc = "Directus user command",
        complete = function(arg_lead, cmd, cursor_pos)
            if string.match(cmd, "fields") then
                -- :Directus Fields
                local url = M.config.url .. "/collections"
                local data = api.directus_fetch(url, M.config.token)

                local collections = {}
                for _, val in ipairs(utils.filter_hidden(data.data)) do
                    table.insert(collections, val.collection)
                end

                local filtered_collections = {}
                if arg_lead ~= "" then
                    for _, collection in ipairs(collections) do
                        if string.match(collection, arg_lead) then
                            table.insert(filtered_collections, collection)
                        end
                    end
                    return filtered_collections
                else
                    return collections
                end
            elseif string.match(cmd, "collections") then
                -- :Directus collections
                return {}
            else
                return { "collections", "fields" }
            end
        end
    })
end

return M

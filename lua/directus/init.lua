local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local finders = require("telescope.finders")
local config = require("telescope.config").values

local api = require("directus.api")
local utils = require("directus.utils")

M = {}

---@class Field
---@field collection string
---@field type string
---@field meta table
---@field schema table

---@class user_config
---@field url string The directus url
---@field token string Access token with admin credentials
---@field show_hidden boolean Display any hidden collection/fields

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
                local data = M._directus_api(url)
                if data == nil then
                    return
                end

                local collections = utils.filter_hidden(data)
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
            map("n", "f", function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)

                M.directus_fields(opts, selection.display)
            end)

            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                local drop_down = require("telescope.themes").get_dropdown({})

                local url = M.config.url .. "/fields/" .. selection.value.collection
                local data = api._directus_api(url)
                if data == nil then
                    return
                end

                local fields = utils.filter_hidden(data)
                utils.merge_sort(fields)

                actions.close(prompt_bufnr)
                M.directus_filters(drop_down, selection.value.collection, fields, {})
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
                local data = api._directus_api(url)
                if data == nil then
                    return
                end

                -- top level fields have a meta-group = vim.NIL

                local fields = utils.filter_hidden(data)
                utils.merge_sort(fields)

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
            map("n", "c", function()
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
            map("n", "c", function(bufnr)
                M.directus_collections({})
            end)

            map("n", "f", function(bufnr)
                M.directus_fields({}, collection)
            end)

            map("n", "s", function(bufnr)
                url = url .. vim.json.encode(collection_filter)
                M.directus_items({}, url, collection)
            end)

            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()

                local directus_field = selection.value.field
                local directus_interface = selection.value.meta.interface

                if directus_interface == "select-dropdown" then
                    vim.ui.select(selection.value.meta.options.choices, {
                        prompt = collection .. ": " .. directus_field,
                        format_item = function(opt)
                            return opt.text
                        end,
                    }, function(selected)
                        collection_filter[directus_field] = {
                            _eq = selected.value
                        }

                        M.directus_filters(opts, collection, fields, collection_filter)
                    end)
                elseif directus_interface == "select-dropdown-m2o" then
                    local foreign_key = selection.value.schema.foreign_key_column
                    local foreign_table = selection.value.schema.foreign_key_table

                    local related_url = M.config.url .. "/items/" .. foreign_table
                    local data = api.directus_fetch(related_url, M.config.token)
                    if data == nil then
                        return
                    end

                    vim.ui.select(data, {
                        prompt = collection .. ": " .. directus_field,
                        format_item = function(item)
                            return directus_field .. ": " .. item[foreign_key] .. " -> " .. item.slug
                        end,
                    }, function(choice)
                        collection_filter[directus_field] = {
                            _eq = choice[foreign_key]
                        }

                        M.directus_filters(opts, collection, fields, collection_filter)
                    end)
                elseif directus_interface == "input" or directus_interface == "input-multiline" then
                    local input = vim.fn.input("Filter value for " .. directus_field .. ": ")
                    collection_filter[directus_field] = {
                        _eq = input
                    }

                    local data = vim.split(vim.inspect(collection_filter), "\n")
                    local display = vim.tbl_flatten({ url, data })
                    vim.api.nvim_buf_set_lines(prev_bufnr, 0, -1, true, display)
                elseif directus_interface == "boolean" then
                    vim.ui.select({ { display = "True", val = "1" }, { display = "False", val = "0" } }, {
                        prompt = collection .. ": " .. directus_field,
                        format_item = function(item)
                            return item.display
                        end,
                    }, function(choice)
                        collection_filter[directus_field] = {
                            _eq = choice.val
                        }

                        M.directus_filters(opts, collection, fields, collection_filter)
                    end)
                else
                    vim.notify("Not sure how to handle: " .. tostring(directus_interface), "info",
                        { title = "Directus Filter" })
                    print(vim.inspect(selection))
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
---@param collection string | table
M.directus_items = function(opts, url, collection)
    if type(collection) == "string" then
        local collection_url = M.config.url .. "/collections/" .. collection
        local data = api._directus_api(collection_url)
        if data == nil then
            return
        end

        collection = data
    end

    pickers.new(opts, {
        prompt_title = "Items",
        sorter = config.generic_sorter(opts),

        finder = finders.new_dynamic({
            fn = function()
                local data = api._directus_api(url)
                if data == nil then
                    return
                elseif #data == 0 then
                    vim.notify(url .. "\nNo items found", "info", { title = "Directus Items" })
                end

                return data
            end,
            entry_maker = function(entry)
                local display_template = collection.meta.display_template
                if display_template ~= vim.NIL then
                    -- Must not just replace
                    -- Need to insert the value into the template {{field}}
                    display_template = string.gsub(display_template, "{", "")
                    display_template = string.gsub(display_template, "}", "")
                end

                return {
                    value = entry,
                    display = entry.slug,
                    ordinal = entry.slug,
                }
            end
        }),

        previewer = previewers.new_buffer_previewer({
            title = collection.collection,
            define_preview = function(self, entry)
                local item_data = vim.split(vim.inspect(entry.value), "\n")
                local display = vim.tbl_flatten({ "", item_data })

                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, 0, true, display)
            end
        }),

        attach_mappings = function(prompt_bufnr, map)
            map("n", "c", function(bufnr)
                M.directus_collections({})
            end)

            map("n", "f", function(bufnr)
                M.directus_fields({}, collection.collection)
            end)

            return true
        end,
    }):find()
end

--------------------------------------------------------------------------------
---Set up the telescope-directus.nvim
---@param directus_config user_config
M.setup = function(directus_config)
    M._directus_api = api.make_directus_api(directus_config.token)
    M.config = {
        url = directus_config.url,
        show_hidden = directus_config.show_hidden
    }

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
                local data = api._directus_api(url)
                if data == nil then
                    return
                end

                local collections = {}
                for _, val in ipairs(utils.filter_hidden(data)) do
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

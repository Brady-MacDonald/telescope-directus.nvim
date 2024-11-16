local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local finders = require("telescope.finders")
local themes = require("telescope.themes")
local telescope_config = require("telescope.config").values

local api = require("directus.api")
local utils = require("directus.utils")
local config = require("directus.config")

M = {}

---@class FieldMeta
---@field id number
---@field sort number
---@field group string
---@field field string
---@field collection string
---@field display string

---@class FieldSchema
---@field default_value any
---@field comment string

---@class Field
---@field collection string
---@field field string
---@field type string
---@field meta FieldMeta
---@field schema FieldSchema

--------------------------------------------------------------------------------

---@class CollectionMeta
---@field id number
---@field sort number
---@field field string
---@field collection string
---@field display string

---@class CollectionSchema
---@field default_value any
---@field comment string

---@class Collection
---@field collection string
---@field meta CollectionMeta
---@field schema CollectionSchema

--------------------------------------------------------------------------------

---Get all Directus Collections
---@param opts any
M.directus_collections = function(opts)
    pickers.new(opts, {
        prompt_title = "Collection",
        sorter = telescope_config.generic_sorter(opts),

        finder = finders.new_dynamic({
            fn = function()
                local collections = api.get_collections()
                if collections == nil then
                    return
                end

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

                M.directus_fields(opts, selection.value)
            end)

            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                local drop_down = themes.get_dropdown(opts)

                local data = api.get_fields(selection.value.collection)
                if data == nil then
                    return
                end

                local fields = utils.filter_hidden(data)
                utils.merge_sort(fields)

                actions.close(prompt_bufnr)
                M.directus_params(drop_down, selection.value, fields, nil)
            end)
            return true
        end,
    }):find()
end

--------------------------------------------------------------------------------
---Get fields for a given collection
---@param opts table telescope options
---@param collection Collection Directus collection name
M.directus_fields = function(opts, collection)
    if collection == nil then
        vim.notify("Must provide collection", "error", { title = "Directus Fields" })
        return
    elseif type(collection) == "string" then
        local collection_data = api.get_collections(collection)
        if collection_data == nil then return end
        collection = collection_data
    end

    pickers.new(opts, {
        prompt_title = "Field",
        sorter = telescope_config.generic_sorter(opts),

        finder = finders.new_dynamic({
            fn = function()
                local fields = api.get_fields(collection.collection)
                if fields == nil then
                    return
                end

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
            title = "Fields: " .. collection.collection,
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

            -- Delete Field
            map("n", "d", function()
                local single_selection = action_state.get_selected_entry()
                local picker = action_state.get_current_picker(prompt_bufnr)
                local multi_selections = picker:get_multi_selection()

                local selected_fields = { single_selection.value }
                for _, selection in ipairs(multi_selections) do
                    table.insert(selected_fields, selection.value)
                end

                api.delete_field(collection.collection, selected_fields)
                M.directus_fields(opts, collection)
            end)

            -- Create Field
            map("n", "p", function()
                local selected_field = action_state.get_selected_entry().value
                local collections = api.get_collections()
                if collections == nil then return end

                vim.ui.select(collections, {
                    prompt = "Collection to create field",
                    format_item = function(opt)
                        return opt.collection
                    end,
                }, function(choice)
                    if not choice then return end
                    api.create_field(choice.collection, selected_field)
                    M.directus_fields(opts, choice)
                end)
            end)

            map("n", "o", function()
                -- Open fields content in buffer
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

                local drop_down = themes.get_dropdown(opts)
                M.directus_params(drop_down, collection, selected_fields, nil)
            end)
            return true
        end,
    }):find()
end

--------------------------------------------------------------------------------
---Build the params for Directus query
---@param opts any The telescope display options (drop_down)
---@param collection Collection|string Directus collection
---@param fields Field[] List of selected fields
---@param params DirectusParams|nil
M.directus_params = function(opts, collection, fields, params)
    if collection == nil then
        vim.notify("Must provide collection", "error", { title = "Directus Fields" })
        return
    elseif type(collection) == "string" then
        local collection_data = api.get_collections(collection)
        if collection_data == nil then return end
        collection = collection_data
    end

    if fields == nil or #fields == 0 then
        local fields_data = api.get_fields(collection.collection)
        if fields_data == nil then return end
        fields = fields_data
    end

    if params == nil then
        params = utils.new_query_params()
    end

    local prev_bufnr

    pickers.new(opts, {
        prompt_title = "Query Filters",
        sorter = telescope_config.generic_sorter(opts),

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
            title = collection.collection .. " query",
            define_preview = function(self, entry)
                local params_json = vim.split(vim.inspect(params), "\n")
                local display = vim.tbl_flatten({ M.config.url .. "/items?", params_json })

                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, 0, true, display)
                prev_bufnr = self.state.bufnr
            end
        }),

        attach_mappings = function(prompt_bufnr, map)
            map("n", "c", function(bufnr)
                M.directus_collections()
            end)

            map("n", "f", function(bufnr)
                M.directus_fields(nil, collection)
            end)

            map("n", "s", function(bufnr)
                M.directus_items(nil, collection, params)
            end)

            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()

                local directus_field = selection.value.field
                local directus_interface = selection.value.meta.interface

                if directus_interface == "select-dropdown" then
                    vim.ui.select(selection.value.meta.options.choices, {
                        prompt = collection.collection .. ": " .. directus_field,
                        format_item = function(opt)
                            return opt.text
                        end,
                    }, function(choice)
                        if not choice then return end
                        params.filter[directus_field] = {
                            _eq = choice.value
                        }

                        M.directus_params(opts, collection, fields, params)
                    end)
                elseif directus_interface == "select-dropdown-m2o" then
                    local foreign_key = selection.value.schema.foreign_key_column
                    local foreign_table = selection.value.schema.foreign_key_table

                    local data = api.get_items(foreign_table)
                    if data == nil then return end

                    vim.ui.select(data, {
                        prompt = collection.collection .. ": " .. directus_field,
                        format_item = function(item)
                            local slug = ""
                            if item.slug ~= nil then
                                slug = " -> " .. item.slug
                            end

                            return directus_field .. ": " .. item[foreign_key] .. slug
                        end,
                    }, function(choice, idx)
                        if not choice then return end

                        params.filter[directus_field] = {
                            _eq = choice[foreign_key]
                        }

                        M.directus_params(opts, collection, fields, params)
                    end)
                elseif directus_interface == "input" or directus_interface == "input-multiline" then
                    local input = vim.fn.input("Filter value for " .. directus_field .. ": ")
                    params.filter[directus_field] = {
                        _eq = input
                    }

                    local filter = vim.split(vim.inspect(params), "\n")
                    local display = vim.tbl_flatten({ M.config.url .. "/items?", filter })

                    vim.api.nvim_buf_set_lines(prev_bufnr, 0, -1, true, display)
                elseif directus_interface == "boolean" then
                    vim.ui.select({ { display = "True", val = "1" }, { display = "False", val = "0" } }, {
                        prompt = collection .. ": " .. directus_field,
                        format_item = function(item)
                            return item.display
                        end,
                    }, function(choice)
                        if not choice then return end
                        params.filter[directus_field] = {
                            _eq = choice.val
                        }

                        M.directus_params(opts, collection, fields, params)
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

---@class DirectusParams
---@field filter table|nil
---@field fields string|nil
---@field limit integer|nil

---Build the filters for query
---@param opts any
---@param collection string|Collection Name of collection of the Collection data object
---@param filter DirectusParams|nil
M.directus_items = function(opts, collection, filter)
    if type(collection) == "string" then
        local collection_data = api.get_collections(collection)
        if collection_data == nil then return end
        collection = collection_data
    end

    pickers.new(opts, {
        prompt_title = "Items",
        sorter = telescope_config.generic_sorter(opts),

        finder = finders.new_dynamic({
            fn = function()
                local data = api.get_items(collection.collection, filter)
                if data == nil then
                    return
                elseif #data == 0 then
                    vim.notify(collection.collection .. "\nNo items found", "info", { title = "Directus Items" })
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
            end)

            return true
        end,
    }):find()
end

--------------------------------------------------------------------------------
---@param opts Config
M.setup = function(opts)
    vim.print(vim.inspect(opts))
    if not opts or not opts.token then
        vim.notify("Must provide Config", vim.log.levels.ERROR, { title = "Directus Telescope" })
        return
    end

    config.set(opts)
    M.config = config.get()

    M._directus_api = api.make_directus_api(M.config.token, M.config.url)

    vim.api.nvim_create_user_command("Directus", function(opts)
        if opts.fargs[1] == "collections" then
            M.directus_collections()
        elseif opts.fargs[1] == "fields" then
            local collection = opts.fargs[2]
            if collection == nil then
                vim.notify("Must specify collection", vim.log.levels.WARN, { title = "Directus Fields" })
            else
                M.directus_fields(nil, collection)
            end
        elseif opts.fargs[1] == "params" then
            local collection = opts.fargs[2]
            M.directus_params(themes.get_dropdown({}), collection, {}, nil)
        end
    end, {
        nargs = "+",
        desc = "Directus user command",
        complete = function(arg_lead, cmd, cursor_pos)
            local is_fields = string.match(cmd, "fields")
            local is_params = string.match(cmd, "params")
            local is_collections = string.match(cmd, "collections")

            if is_fields or is_params then
                -- :Directus Fields
                -- :Directus Params

                local data = api.get_collections()
                if data == nil then return end

                local collections = {}
                for _, val in ipairs(utils.filter_hidden(data)) do
                    table.insert(collections, val.collection)
                end

                if arg_lead ~= "" then
                    local filtered_collections = {}
                    for _, collection in ipairs(collections) do
                        if string.match(collection, arg_lead) then
                            table.insert(filtered_collections, collection)
                        end
                    end
                    collections = filtered_collections
                end

                return collections
            elseif is_collections then
                -- :Directus collections
                return {}
            else
                if arg_lead == "" then
                    return { "collections", "fields", "params" }
                end

                local fields = string.match("fields", arg_lead)
                local params = string.match("params", arg_lead)
                local collections = string.match("collections", arg_lead)

                if collections then
                    return { "collections" }
                elseif fields then
                    return { "fields" }
                elseif params then
                    return { "params" }
                end
            end
        end
    })
end

return M

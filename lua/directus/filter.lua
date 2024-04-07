-- Construct filter
--

D = {}

---Get the config for the given collection
---@param config config
---@param collection string Colleciton located in config
---@return CollectionsConfig selected_collection The collection specific config
D.get_collection_config = function(config, collection)
    local selected_collection = {}
    for _, val in ipairs(config.collections) do
        if val.collection == collection then
            selected_collection = val
        end
    end

    return selected_collection
end

return D

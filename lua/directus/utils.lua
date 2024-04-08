U = {}

---Merge the two input arrays into one sorted array
---@param left table
---@param right table
---@param arr table
local function merge(left, right, arr)
    local i = 1
    local r = 1
    local l = 1

    while l <= #left and r <= #right do
        -- Missing some collections without a meta.sort property

        local leftSort = left[l].meta.sort
        if leftSort == nil or leftSort == vim.NIL then
            leftSort = 1001
        end

        local rightSort = right[r].meta.sort
        if rightSort == nil or vim.NIL then
            rightSort = 1000
        end


        if leftSort > rightSort then
            arr[i] = left[l]
            l = l + 1
            i = i + 1
        else
            arr[i] = right[r]
            r = r + 1
            i = i + 1
        end
    end

    -- check for remaining elements in split
    while l <= #left do
        arr[i] = left[l]
        l = l + 1
        i = i + 1
    end

    while r <= #right do
        arr[i] = right[r]
        r = r + 1
        i = i + 1
    end
end

---Sort given input array on meta.sort property
---Uses MergeSort algorithm
---@param arr table Sort table
U.merge_sort = function(arr)
    if #arr <= 1 then
        return
    end

    local middle = #arr / 2

    local left = {}
    local right = {}
    for idx, val in ipairs(arr) do
        if idx <= middle then
            table.insert(left, val)
        else
            table.insert(right, val)
        end
    end

    U.merge_sort(left)
    U.merge_sort(right)

    merge(left, right, arr)
end

---Filter the input
---@param data table Input data
---@return table collections The filtered data
U.filter_hidden = function(data)
    if M.config.show_hidden then
        return data
    end

    local filtered_data = {}
    for _, item in ipairs(data) do
        if not item.meta.hidden then
            table.insert(filtered_data, item)
        end
    end

    return filtered_data
end

return U

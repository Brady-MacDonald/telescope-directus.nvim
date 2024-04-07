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
        if left[l].meta.sort > right[r].meta.sort then
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

return U

import "table"

local std = {}

---@param t table
function std.spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

---@param tbl table
---@param tableName string|nil
---@param indent string|nil
function std.dump_table(tbl, tableName, indent)
    local result = ""
    indent = indent or ""

    if type(tbl) == "table" then
        if tableName == nil then
            result = result .. "{\n"
        else
            result = result .. tableName .. " = {\n"
        end

        for key, value in std.spairs(tbl) do
            local keyString = tostring(key)
            if type(key) == "number" then
                keyString = string.format("[%q]", key)
            end

            local valueString = ""
            if type(value) == "table" then
                valueString = std.dump_table(value, nil, indent .. "    ")
            elseif type(value) == "string" then
                valueString = string.format("%q", value)
            else
                valueString = tostring(value)
            end

            result = result .. indent .. "    " .. keyString .. " = " .. valueString .. ",\n"
        end

        result = result .. indent .. "}"
    else
        result = tostring(tbl)
    end

    return result
end

return std

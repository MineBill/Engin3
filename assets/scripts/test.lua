require "math"

-- Convert a lua table into a lua syntactically correct string
local function table_to_string(tbl)
    local result = "{"
    for k, v in pairs(tbl) do
        -- Check the key type (ignore any numerical keys - assume its an array)
        if type(k) == "string" then
            result = result .. "[\"" .. k .. "\"]" .. "="
        end

        -- Check the value type
        if type(v) == "table" then
            result = result .. table_to_string(v)
        elseif type(v) == "boolean" then
            result = result .. tostring(v)
        elseif type(v) == "function" then
            result = result .. "function()"
        else
            result = result .. "\"" .. v .. "\""
        end
        result = result .. ","
    end
    -- Remove leading commas from the result
    if result ~= "" then
        result = result:sub(1, result:len() - 1)
    end
    return result .. "}"
end

CoolComponent = {
    Properties = {
        Name = "Some Awesome Name",
    },
    Export = {
        movement_speed = {
            Default = 2.0,
            Description = "This is a description for the field movement_speed.",
            Tag = 'range: "1.0, 30.0"',
        },
        should_do_thing = {
            Default = false,
            Description = "This is a description for the field movement_speed.",
        },
        pepegas = {
            Default = false,
            Description = "",
        },
        max_stuff_to_do = {
            Default = 42,
            Description = "",
        }
    },
    Instance = {
        timer = 0.0,
    },
}

function CoolComponent:on_init()
    local v = v3(2, 3, 4)
    local meta = getmetatable(v)
    print(table_to_string(meta))
    print(v)
    print("pepegas is " .. tostring(self.pepegas))
    print("should_do_thing is " .. tostring(self.should_do_thing))
    print("speed is " .. tostring(self.movement_speed))
    print("max_stuff_to_do is " .. tostring(self.max_stuff_to_do))
end

---@class self LuaEntity
function CoolComponent:on_update(delta)
    self.timer = self.timer + delta

    local pos = self.entity:get_position()
    pos.y = pos.y + self.movement_speed * delta
    self.entity:set_position(pos)
end

return CoolComponent

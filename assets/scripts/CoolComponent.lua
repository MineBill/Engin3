---@class CoolComponent
---@field entity LuaEntity
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
        another_speed = 0.0,
    },
    instance_field_one = false,
}

function CoolComponent:on_init()
    print(self.entity:get_position())
    self.entity:do_barrel_roll()
end

function CoolComponent:on_update(delta)
    local function bool_to_number(value)
      return value and 1 or 0
    end

    local x = bool_to_number(Input.is_key_down(Keys.D)) - bool_to_number(Input.is_key_down(Keys.A))
    local y = bool_to_number(Input.is_key_down(Keys.W)) - bool_to_number(Input.is_key_down(Keys.S))

    local pos = self.entity:get_position()
    pos.y = pos.y + y  * self.movement_speed * delta
    pos.x = pos.x + x * self.movement_speed * delta
    self.entity:set_position(pos)
end

return CoolComponent

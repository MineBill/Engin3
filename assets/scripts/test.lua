require "math"

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
    print(self.entity:get_position())
end

function bool_to_number(value)
  return value and 1 or 0
end

---@class self LuaEntity
function CoolComponent:on_update(delta)
    self.timer = self.timer + delta

    if is_key_just_pressed(Keys.Space) then
        print("Space!")
        self.entity:set_active(not self.entity:is_active())
    end

    local x = bool_to_number(is_key_down(Keys.D)) - bool_to_number(is_key_down(Keys.A))
    local y = bool_to_number(is_key_down(Keys.W)) - bool_to_number(is_key_down(Keys.S))

    local pos = self.entity:get_position()
    pos.y = pos.y + y  * self.movement_speed * delta
    pos.x = pos.x + x * self.movement_speed * delta
    self.entity:set_position(pos)
end

return CoolComponent

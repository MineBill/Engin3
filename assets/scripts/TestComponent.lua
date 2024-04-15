---@class TestComponent
---@field entity LuaEntity
TestComponent = {
    Properties = {
        Name = "Test Name",
    },
    Export = {
        movement_speed = {
            Default = 2.0,
            Description = [[
            This is a description for the field movement_speed.
            It can be used to do stuff.
            ]],
        },
    },
}

function TestComponent:on_init()
    print("I am the TestComponent and my entity's position is " .. tostring(self.entity:get_position()))
end

function TestComponent:on_update(delta)
    local translation = make_vec3(0, 1 * delta, 0)
    self.entity:translate(translation)
end

return TestComponent

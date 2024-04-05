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
    Instance = {
    },
}

---@param self LuaEntity
function TestComponent:on_init()
    -- print("Hi, my name is " .. self:name())
    print("My position is " .. tostring(self:get_position()))

    --[[ print(self.movement_speed)
    print(self.a_field)
    print(self.will_not_be_serialized) ]]
end

---@param self LuaEntity
function TestComponent:on_update(delta)
    local translation = v3(0, 1 * delta, 0)
    self:translate(translation)
end

return TestComponent

package gpu
import vk "vendor:vulkan"

Shader :: struct {
    id: UUID,
    device: ^Device,

    vertex_module: vk.ShaderModule,
    fragment_module: vk.ShaderModule,
}

ShaderSpecification :: struct {
    vertex_spirv: []byte,
    fragment_spirv: []byte,
}

create_shader :: proc(device: ^Device, spec: ShaderSpecification) -> (shader: Shader) {
    shader.device = device

    shader_create_info := vk.ShaderModuleCreateInfo {
        sType = .SHADER_MODULE_CREATE_INFO,
        pCode = raw_data(transmute([]u32) spec.vertex_spirv),
        codeSize = len(spec.vertex_spirv),
    }

    check(vk.CreateShaderModule(device.handle, &shader_create_info, nil, &shader.vertex_module))

    shader_create_info = vk.ShaderModuleCreateInfo {
        sType = .SHADER_MODULE_CREATE_INFO,
        pCode = raw_data(transmute([]u32) spec.fragment_spirv),
        codeSize = len(spec.fragment_spirv),
    }

    check(vk.CreateShaderModule(device.handle, &shader_create_info, nil, &shader.fragment_module))
    return
}

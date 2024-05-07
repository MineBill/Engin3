package engine
import "gpu"

when USE_EDITOR {
    EditorPushConstants :: struct {
        local_entity_id: int,
    }
} else {
    EditorPushConstants :: struct {}
}

PushConstants :: struct {
    model: mat4,
    using _ : EditorPushConstants,
}

DepthPassPushConstants :: struct {
    model: mat4,
    light_space: mat4,
}

GlobalUniform :: struct {
    projection: mat4,
    view: mat4,
    screen_size: vec2,
}

SceneData :: struct {
    view_position: vec3, _: f32,
    view_direction: vec3, _: f32,
    ambient_color: Color,
}

// Maybe we could make this work??
// @(shader_export)
SSAO_KERNEL_SIZE :: 64

SSAOData :: struct {
    params: vec4,
    kernel: [SSAO_KERNEL_SIZE]vec3,

    // radius, bias: f32,
}

when USE_EDITOR {
    EditorPerObjectData :: struct {
        entity_id: int,
    }
} else {
    EditorPerObjectData :: struct {}
}

PerObjectData :: struct {
    model: mat4,

    using _ : EditorPerObjectData,
}

DepthPassPerObjectData :: struct {
    model, light_space: mat4,
}

MAX_SPOTLIGHTS :: 10
MAX_POINTLIGHTS :: 10

LightData :: struct {
    directional: struct {
        direction: vec4,
        color: Color,
        light_space_matrix: [4]mat4,
    },
    point_lights: [MAX_POINTLIGHTS]struct {
        color: Color,
        position: vec4,

        constant: f32,
        linear: f32,
        quadratic: f32,
        _: f32,
    },
    spot_lights: [MAX_SPOTLIGHTS]struct {
        _: vec4,
    },

    shadow_split_distances: vec4,
}

GlobalSet :: struct {
    resource: gpu.Resource,
    layout: gpu.ResourceLayout,
    // pool: gpu.ResourcePool,

    uniform_buffer: UniformBuffer(GlobalUniform),
    debug_options: UniformBuffer(ShaderVisualizationOptions),
}

SceneSet :: struct {
    resource: gpu.Resource,
    layout: gpu.ResourceLayout,
    // pool: gpu.ResourcePool,

    scene_data: UniformBuffer(SceneData),
    light_data: UniformBuffer(LightData),
    shadow_map: gpu.Image,
}

ObjectSet :: struct {
    resource: gpu.Resource,
    layout: gpu.ResourceLayout,
    // pool: gpu.ResourcePool,

    material: PbrMaterial,

    albedo_image: gpu.Image,
    normal_image: gpu.Image,
}

ShaderVisualizationOptions :: struct {
    shadow_cascade_boxes: b32,
    shadow_cascade_colors: b32,
}

VisualizationOption :: enum {
    None,

    ShadowCascadeBoxes,
    ShadowCascadeColors,
}

VisualizationOptions :: bit_set[VisualizationOption]

visualization_options_to_shader :: proc(options: VisualizationOptions) -> (s: ShaderVisualizationOptions) {
    if .ShadowCascadeBoxes in options do s.shadow_cascade_boxes = true
    if .ShadowCascadeColors in options do s.shadow_cascade_colors = true
    return
}
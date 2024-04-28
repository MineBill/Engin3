package engine
import gl "vendor:OpenGL"
import "core:math"
import "core:math/linalg"
import "core:sync"
import "gpu"
import "core:mem"

MAX_LINES :: 10_000

LinePoint :: struct {
    point: vec3,
    thickness: f32,
    color: Color,
}

LINE_VERTEX_SIZE :: size_of(vec3) + size_of(f32)

DebugDrawContext :: struct {
    mutex: sync.Mutex,
    vao, vbo: u32,

    shader: Shader,
    pipeline: gpu.Pipeline,
    vertex_buffer: gpu.Buffer,

    lines: [dynamic]LinePoint,
}

g_dbg_context: ^DebugDrawContext

dbg_init :: proc(d: ^DebugDrawContext, render_pass: gpu.RenderPass) {
    shader, ok := shader_load_from_file("assets/shaders/new/debug.shader")

    resource_layout := gpu.create_resource_layout(Renderer3DInstance.device, Renderer3DInstance.global_uniform_resource_usage)

    pipeline_layout_spec := gpu.PipelineLayoutSpecification {
        tag = "Debug Draw PL",
        device = &Renderer3DInstance.device,
        layouts = gpu.make_list([]gpu.ResourceLayout{resource_layout}),
    }
    layout := gpu.create_pipeline_layout(pipeline_layout_spec)

    vertex_layout := gpu.vertex_layout({
        name = "Position",
        type = .Float3,
    }, {
        name = "Thickness",
        type = .Float,
    }, {
        name = "Color",
        type = .Float4,
    })

    config := gpu.default_pipeline_config()
    config.input_assembly_info.topology = .LINE_LIST
    config.rasterization_info.lineWidth = 1.0

    pipeline_spec := gpu.PipelineSpecification {
        tag = "Debug Draw Pipeline",
        shader = shader.shader,
        layout = layout,
        renderpass = render_pass,
        attribute_layout = vertex_layout,
        config = config,
    }

    err: gpu.Error
    d.pipeline, err = gpu.create_pipeline(&Renderer3DInstance.device, pipeline_spec)

    buffer_spec := gpu.BufferSpecification {
        name = "Debug Drawing Vertex Buffer",
        size = MAX_LINES * LINE_VERTEX_SIZE,
        usage = {.Vertex},
        device = &Renderer3DInstance.device,
        mapped = true,
    }
    d.vertex_buffer = gpu.create_buffer(buffer_spec)
}

dbg_deinit :: proc(d: DebugDrawContext) {
    delete(d.lines)
}

dbg_draw_line :: proc(d: ^DebugDrawContext, s, e: vec3, thickness: f32 = 1.0, color := COLOR_GREEN) {
    if sync.mutex_guard(&d.mutex) {
        append(&d.lines, LinePoint{s, thickness, color})
        append(&d.lines, LinePoint{e, thickness, color})
    }
}

dbg_draw_cube :: proc(d: ^DebugDrawContext, center: vec3, angles: vec3, size: vec3, thickness: f32 = 1.0, color := COLOR_GREEN) {
    half := size / 2

    AXIS_X :: vec3{1, 0, 0}
    AXIS_Y :: vec3{0, 1, 0}
    AXIS_Z :: vec3{0, 0, 1}

    rot := linalg.matrix3_from_euler_angles_yxz(
             angles.y * math.RAD_PER_DEG,
             angles.x * math.RAD_PER_DEG,
             angles.z * math.RAD_PER_DEG)

    dbg_draw_line(d, center + rot * (vec3{-1, -1, 1}   * half), center + rot * (vec3{1, -1, 1}   * half), thickness, color)
    dbg_draw_line(d, center + rot * (vec3{-1, 1,  1}   * half), center + rot * (vec3{1, 1,  1}   * half), thickness, color)

    dbg_draw_line(d, center + rot * (vec3{-1, -1, -1}  * half), center + rot * (vec3{1, -1, -1}  * half), thickness, color)
    dbg_draw_line(d, center + rot * (vec3{-1, 1,  -1}  * half), center + rot * (vec3{1, 1,  -1}  * half), thickness, color)

    dbg_draw_line(d, center + rot * (vec3{1, -1, -1}   * half), center + rot * (vec3{1, -1, 1}   * half), thickness, color)
    dbg_draw_line(d, center + rot * (vec3{1, 1,  -1}   * half), center + rot * (vec3{1, 1,  1}   * half), thickness, color)

    dbg_draw_line(d, center + rot * (vec3{-1, -1, -1}  * half), center + rot * (vec3{-1, -1, 1}  * half), thickness, color)
    dbg_draw_line(d, center + rot * (vec3{-1, 1,  -1}  * half), center + rot * (vec3{-1, 1,  1}  * half), thickness, color)

    dbg_draw_line(d, center + rot * (vec3{-1, -1, -1}  * half), center + rot * (vec3{-1, 1, -1}  * half), thickness, color)
    dbg_draw_line(d, center + rot * (vec3{1, -1,  -1}  * half), center + rot * (vec3{1, 1,  -1}  * half), thickness, color)

    dbg_draw_line(d, center + rot * (vec3{-1, -1, 1}   * half), center + rot * (vec3{-1, 1, 1}   * half), thickness, color)
    dbg_draw_line(d, center + rot * (vec3{1, -1,  1}   * half), center + rot * (vec3{1, 1,  1}   * half), thickness, color)
}

dbg_draw_sphere :: proc(
    d: ^DebugDrawContext,
    #no_broadcast center: vec3,
    #no_broadcast euler_rotation: vec3 = {},
    radius: f32 = 1.0,
    thickness: f32 = 1.0,
    color := COLOR_GREEN) {

    SEGMENTS :: 10  // Number of segments per circle
    LATITUDE_SEGMENTS :: SEGMENTS
    LONGITUDE_SEGMENTS :: SEGMENTS

    rot := linalg.matrix3_from_euler_angles_yxz(
             euler_rotation.y * math.RAD_PER_DEG,
             euler_rotation.x * math.RAD_PER_DEG,
             euler_rotation.z * math.RAD_PER_DEG)

    // Draw latitude lines
    for lat in 0..<LATITUDE_SEGMENTS {
        lat0 := math.PI * (-0.5 + (f32(lat) / f32(LATITUDE_SEGMENTS)))
        lat1 := math.PI * (-0.5 + (f32(lat + 1) / f32(LATITUDE_SEGMENTS)))

        z0 := radius * math.sin(lat0)
        z1 := radius * math.sin(lat1)

        r0 := radius * math.cos(lat0)
        r1 := radius * math.cos(lat1)

        for lon in 0..<LONGITUDE_SEGMENTS {
            lon0 := 2 * math.PI * (f32(lon) / f32(LONGITUDE_SEGMENTS))
            lon1 := 2 * math.PI * (f32(lon + 1) / f32(LONGITUDE_SEGMENTS))

            x0 := math.cos(lon0) * r0
            y0 := math.sin(lon0) * r0

            x1 := math.cos(lon1) * r0
            y1 := math.sin(lon1) * r0

            x2 := math.cos(lon1) * r1
            y2 := math.sin(lon1) * r1

            x3 := math.cos(lon0) * r1
            y3 := math.sin(lon0) * r1

            // Draw the quad formed by these four points
            dbg_draw_line(d, center + rot * vec3{x0, y0, z0}, center + rot * vec3{x1, y1, z0}, thickness, color)
            dbg_draw_line(d, center + rot * vec3{x1, y1, z0}, center + rot * vec3{x2, y2, z1}, thickness, color)
            dbg_draw_line(d, center + rot * vec3{x2, y2, z1}, center + rot * vec3{x3, y3, z1}, thickness, color)
            dbg_draw_line(d, center + rot * vec3{x3, y3, z1}, center + rot * vec3{x0, y0, z0}, thickness, color)
        }
    }
}

dbg_render :: proc(d: ^DebugDrawContext, cmd: gpu.CommandBuffer) {
    line_count := len(d.lines)
    if line_count == 0 do return
    assert(line_count % 2 == 0)

    gpu.pipeline_bind(cmd, d.pipeline)

    mem.copy(d.vertex_buffer.alloc_info.pMappedData, raw_data(d.lines), line_count * size_of(LinePoint))
    gpu.bind_buffers(cmd, d.vertex_buffer)
    gpu.draw(cmd, line_count, 1)

    clear(&d.lines)
}

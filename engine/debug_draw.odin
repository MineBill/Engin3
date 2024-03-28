package engine
import gl "vendor:OpenGL"

// 

MAX_LINES :: 10_000

LinePoint :: struct {
    point: vec3,
    thickness: f32,
    color: Color,
}

LINE_VERTEX_SIZE :: size_of(vec3) + size_of(f32)

DebugDrawContext :: struct {
    vao, vbo: u32,
    shader: Shader,

    lines: [dynamic]LinePoint,
}

g_dbg_context: ^DebugDrawContext

dbg_init :: proc(d: ^DebugDrawContext) {
    ok: bool
    d.shader, ok = shader_load_from_file(
        "assets/shaders/line.vert.glsl",
        "assets/shaders/line.frag.glsl",
    )
    assert(ok)

    gl.CreateBuffers(1, &d.vbo)
    gl.NamedBufferData(d.vbo, MAX_LINES * 2 * size_of(LinePoint), nil, gl.DYNAMIC_DRAW)

    gl.CreateVertexArrays(1, &d.vao)

    gl.VertexArrayVertexBuffer(d.vao, 0, d.vbo, 0, size_of(LinePoint))

    gl.EnableVertexArrayAttrib(d.vao, 0)
    gl.EnableVertexArrayAttrib(d.vao, 1)
    gl.EnableVertexArrayAttrib(d.vao, 2)
    gl.VertexArrayAttribFormat(d.vao, 0, 3, gl.FLOAT, false, 0)
    gl.VertexArrayAttribFormat(d.vao, 1, 1, gl.FLOAT, false, u32(offset_of(LinePoint, thickness)))
    gl.VertexArrayAttribFormat(d.vao, 2, 4, gl.FLOAT, false, u32(offset_of(LinePoint, color)))
    gl.VertexArrayAttribBinding(d.vao, 0, 0)
    gl.VertexArrayAttribBinding(d.vao, 1, 0)
    gl.VertexArrayAttribBinding(d.vao, 2, 0)
}

dbg_deinit :: proc(d: DebugDrawContext) {
    delete(d.lines)
}

dbg_draw_line :: proc(d: ^DebugDrawContext, s, e: vec3, thickness: f32 = 1.0, color := COLOR_RED) {
    append(&d.lines, LinePoint{s, thickness, color})
    append(&d.lines, LinePoint{e, thickness, color})
}

dbg_draw_cube :: proc(d: ^DebugDrawContext, center: vec3, size: vec3, thickness: f32 = 1.0, color := COLOR_BLUE) {
    half := size / 2

    AXIS_X :: vec3{1, 0, 0}
    AXIS_Y :: vec3{0, 1, 0}
    AXIS_Z :: vec3{0, 0, 1}

    dbg_draw_line(d, center + vec3{-1, -1, 1}  * half, center + vec3{1, -1, 1}  * half, thickness, color)
    dbg_draw_line(d, center + vec3{-1, 1,  1}  * half, center + vec3{1, 1,  1}  * half, thickness, color)

    dbg_draw_line(d, center + vec3{-1, -1, -1} * half, center + vec3{1, -1, -1} * half, thickness, color)
    dbg_draw_line(d, center + vec3{-1, 1,  -1} * half, center + vec3{1, 1,  -1} * half, thickness, color)

    // ===

    dbg_draw_line(d, center + vec3{1, -1, -1}  * half, center + vec3{1, -1, 1}  * half, thickness, color)
    dbg_draw_line(d, center + vec3{1, 1,  -1}  * half, center + vec3{1, 1,  1}  * half, thickness, color)

    dbg_draw_line(d, center + vec3{-1, -1, -1} * half, center + vec3{-1, -1, 1} * half, thickness, color)
    dbg_draw_line(d, center + vec3{-1, 1,  -1} * half, center + vec3{-1, 1,  1} * half, thickness, color)

    // ===

    dbg_draw_line(d, center + vec3{-1, -1, -1}  * half, center + vec3{-1, 1, -1}  * half, thickness, color)
    dbg_draw_line(d, center + vec3{1, -1,  -1}  * half, center + vec3{1, 1,  -1}  * half, thickness, color)

    dbg_draw_line(d, center + vec3{-1, -1, 1} * half, center + vec3{-1, 1, 1} * half, thickness, color)
    dbg_draw_line(d, center + vec3{1, -1,  1} * half, center + vec3{1, 1,  1} * half, thickness, color)
}

dbg_render :: proc(d: ^DebugDrawContext) {
    if len(d.lines) == 0 do return
    gl.NamedBufferSubData(d.vbo, 0, len(d.lines) * size_of(LinePoint), raw_data(d.lines))

    gl.UseProgram(d.shader.program)
    gl.BindVertexArray(d.vao)
    gl.LineWidth(1)
    gl.DrawArrays(gl.LINES, 0, i32(len(d.lines) ))

    clear(&d.lines)
}

package engine
import gl "vendor:OpenGL"
import "core:math"
import "core:math/linalg"
import "core:sync"

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
    gl.NamedBufferStorage(d.vbo, MAX_LINES * 2 * size_of(LinePoint), nil, gl.DYNAMIC_STORAGE_BIT)

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
    if sync.mutex_guard(&d.mutex) {
        append(&d.lines, LinePoint{s, thickness, color})
        append(&d.lines, LinePoint{e, thickness, color})
    }
}

dbg_draw_cube :: proc(d: ^DebugDrawContext, center: vec3, angles: vec3, size: vec3, thickness: f32 = 1.0, color := COLOR_BLUE) {
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

dbg_draw_sphere :: proc(d: ^DebugDrawContext, position: vec3, radius: f32, thickness: f32 = 1.0, color := COLOR_GREEN) {
    SEGMENTS :: 16  // Number of segments per circle
    LATITUDE_SEGMENTS :: SEGMENTS
    LONGITUDE_SEGMENTS :: SEGMENTS

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
            dbg_draw_line(d, position + vec3{x0, y0, z0}, position + vec3{x1, y1, z0}, thickness, color)
            dbg_draw_line(d, position + vec3{x1, y1, z0}, position + vec3{x2, y2, z1}, thickness, color)
            dbg_draw_line(d, position + vec3{x2, y2, z1}, position + vec3{x3, y3, z1}, thickness, color)
            dbg_draw_line(d, position + vec3{x3, y3, z1}, position + vec3{x0, y0, z0}, thickness, color)
        }
    }
}

dbg_render :: proc(d: ^DebugDrawContext) {
    line_count := len(d.lines)
    if line_count == 0 do return
    assert(line_count % 2 == 0)

    gl.UseProgram(d.shader.program)
    gl.BindVertexArray(d.vao)
    gl.LineWidth(2)

    gl.NamedBufferSubData(d.vbo, 0, line_count * size_of(LinePoint), raw_data(d.lines))
    draw_arrays(gl.LINES, 0, line_count)

    clear(&d.lines)
}

package engine
import gl "vendor:OpenGL"
import "core:log"
import "core:os"
import "core:strings"
import "core:path/slashpath"

Shader :: struct {
    program: u32,
    uniforms: map[string]i32,

    vertex_path, fragment_path: string,
}

shader_deinit :: proc(shader: ^Shader) {
    delete(shader.uniforms)
}

shader_cache_uniforms :: proc(shader: ^Shader, uniforms: []string) {
    for name in uniforms {
        loc := gl.GetUniformLocation(shader.program, strings.clone_to_cstring(name, context.temp_allocator))
        log.debugf("Location for uniform %v is %v", name, loc)
        shader.uniforms[name] = loc
    }
}

shader_load_from_file :: proc(vertex_path, fragment_path: string) -> (shader: Shader, ok: bool) {
    vertex := load_shader(vertex_path, gl.VERTEX_SHADER) or_return
    fragment := load_shader(fragment_path, gl.FRAGMENT_SHADER) or_return

    program := gl.CreateProgram()
    gl.AttachShader(program, vertex)
    gl.AttachShader(program, fragment)
    gl.LinkProgram(program)

    success: i32
    gl.GetProgramiv(program, gl.LINK_STATUS, &success)
    if success == 0 {
        log_buffer: [512]byte
        length: i32
        gl.GetProgramInfoLog(program, len(log_buffer), &length, raw_data(log_buffer[:]))
        log.errorf("Error linking shader program: \n%v", string(log_buffer[:length]))
        return {}, false
    }

    return {
        program = program,
        vertex_path = vertex_path,
        fragment_path = fragment_path,
    }, true
}

shader_load_from_memory :: proc(vertex_src, fragment_src: []byte) -> (shader: Shader, ok: bool) {
    vertex := load_shader_memory(vertex_src, gl.VERTEX_SHADER) or_return
    fragment := load_shader_memory(fragment_src, gl.FRAGMENT_SHADER) or_return

    program := gl.CreateProgram()
    gl.AttachShader(program, vertex)
    gl.AttachShader(program, fragment)
    gl.LinkProgram(program)

    success: i32
    gl.GetProgramiv(program, gl.LINK_STATUS, &success)
    if b32(success) != gl.TRUE {
        log_buffer: [512]byte
        length: i32
        gl.GetProgramInfoLog(program, len(log_buffer), &length, raw_data(log_buffer[:]))
        log.errorf("Error linking shader program: \n%v", string(log_buffer[:length]))
        return {}, false
    }

    return {
        program = program,
    }, true
}

@(private = "file")
load_shader :: proc(path: string, type: u32) -> (u32, bool) {
    data, ok := os.read_entire_file(path)
    if !ok {
        log.errorf("Failed to open file: %v", path)
        return {}, false
    }
    defer delete(data)

    cwd := os.get_current_directory()
    defer delete(cwd)

    full := slashpath.join({cwd, slashpath.dir(path, allocator = context.temp_allocator)}, allocator = context.temp_allocator)

    included_files := map[string]int{}
    defer delete(included_files)
    src := process_shader_source(full, slashpath.base(path, allocator = context.temp_allocator), &included_files)

    return load_shader_memory(transmute([]u8)src, type)
}

@(private = "file")
load_shader_memory :: proc(src: []byte, type: u32) -> (u32, bool) {
    shader := gl.CreateShader(type)

    sources := []cstring {
        cstring(raw_data(src)),
    }
    lenghts := []i32 {
        i32(len(src)),
    }
    gl.ShaderSource(shader, 1, raw_data(sources), nil)
    gl.CompileShader(shader)
    
    success: i32
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success)
    if success == 0 {
        log_buffer: [512]byte
        length: i32
        gl.GetShaderInfoLog(shader, len(log_buffer), &length, raw_data(log_buffer[:]))
        log.errorf("Error compiling shader: \n%v", string(log_buffer[:length]))
        return {}, false
    }

    return shader, true
}

uniform :: #force_inline proc(s: ^Shader, name: string) -> i32 {
    loc, ok := s.uniforms[name]
    if !ok {
        loc = gl.GetUniformLocation(s.program, strings.clone_to_cstring(name, context.temp_allocator))
    }
    return loc
}

shader_reload :: proc(shader: ^Shader) -> (ok: bool) {
    uniforms := clone_map(shader.uniforms, context.temp_allocator)
    shader^ = shader_load_from_file(shader.vertex_path, shader.fragment_path) or_return
    return true
}

clone_map :: proc(m: map[$K]$V, allocator := context.allocator) -> map[K]V {
    r := make(map[K]V, len(m), allocator)
    for k, v in m {
        r[k] = v
    }
    return r
}

process_shader_source :: proc(cwd: string, file_path: string, included_files: ^map[string]int) -> string {
    file := slashpath.join({cwd, file_path}, allocator = context.allocator)
    included_files[file] += 1
    data, ok := os.read_entire_file(file); assert(ok)
    defer delete(data)
    log.debug("Processing file: ", file)

    sb: strings.Builder

    s := string(data)
    for line in strings.split_lines_iterator(&s) {
        if len(line) == 0 {
            continue
        }

        if line[0] == '#' && strings.contains(line, "include") {
            first_quote := strings.index(line, "\"")
            if first_quote == -1 {
                log.error("Not quote found for include macro.")
                os.exit(-1)
            }

            second_quote := strings.last_index(line, "\"")
            if second_quote == -1 {
                log.error("Didn't find a closing quote for include macro path.")
                os.exit(-1)
            }

            path := line[first_quote + 1:second_quote]
            joined := slashpath.join({cwd, path}, allocator = context.allocator)
            if joined not_in included_files {
                included := process_shader_source(cwd, path, included_files)
                strings.write_string(&sb, included)
            } else {
                log.error("Prevented cyclic import")
                return ""
            }
            continue
        }
        strings.write_string(&sb, line)
        strings.write_string(&sb, "\n")
    }
    return strings.to_string(sb)
}

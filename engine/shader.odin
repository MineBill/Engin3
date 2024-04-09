package engine
import gl "vendor:OpenGL"
import "core:log"
import "core:os"
import "core:strings"
import "core:path/slashpath"
import "core:fmt"
import "core:c"
import "core:path/filepath"
import "core:runtime"

ShaderKind :: enum {
    Vertex,
    Fragment,
}

// Shader :: struct {
//     program: u32,
//     uniforms: map[string]i32,

//     vertex_path, fragment_path: string,
// }

// shader_deinit :: proc(shader: ^Shader) {
//     delete(shader.uniforms)
// }

// shader_cache_uniforms :: proc(shader: ^Shader, uniforms: []string) {
//     for name in uniforms {
//         loc := gl.GetUniformLocation(shader.program, strings.clone_to_cstring(name, context.temp_allocator))
//         log.debugf("Location for uniform %v is %v", name, loc)
//         shader.uniforms[name] = loc
//     }
// }

// shader_load_from_file :: proc(vertex_path, fragment_path: string) -> (shader: Shader, ok: bool) {
//     vertex := load_shader(vertex_path, gl.VERTEX_SHADER) or_return
//     fragment := load_shader(fragment_path, gl.FRAGMENT_SHADER) or_return

//     program := gl.CreateProgram()
//     gl.AttachShader(program, vertex)
//     gl.AttachShader(program, fragment)
//     gl.LinkProgram(program)

//     success: i32
//     gl.GetProgramiv(program, gl.LINK_STATUS, &success)
//     if success == 0 {
//         log_buffer: [512]byte
//         length: i32
//         gl.GetProgramInfoLog(program, len(log_buffer), &length, raw_data(log_buffer[:]))
//         log.errorf("Error linking shader program: \n%v", string(log_buffer[:length]))
//         return {}, false
//     }

//     return {
//         program = program,
//         vertex_path = vertex_path,
//         fragment_path = fragment_path,
//     }, true
// }

// shader_load_from_memory :: proc(vertex_src, fragment_src: []byte) -> (shader: Shader, ok: bool) {
//     vertex := load_shader_memory(vertex_src, gl.VERTEX_SHADER) or_return
//     fragment := load_shader_memory(fragment_src, gl.FRAGMENT_SHADER) or_return

//     program := gl.CreateProgram()
//     gl.AttachShader(program, vertex)
//     gl.AttachShader(program, fragment)
//     gl.LinkProgram(program)

//     success: i32
//     gl.GetProgramiv(program, gl.LINK_STATUS, &success)
//     if b32(success) != gl.TRUE {
//         log_buffer: [512]byte
//         length: i32
//         gl.GetProgramInfoLog(program, len(log_buffer), &length, raw_data(log_buffer[:]))
//         log.errorf("Error linking shader program: \n%v", string(log_buffer[:length]))
//         return {}, false
//     }

//     return {
//         program = program,
//     }, true
// }

// @(private = "file")
// load_shader :: proc(path: string, type: u32) -> (u32, bool) {
//     data, ok := os.read_entire_file(path)
//     if !ok {
//         log.errorf("Failed to open file: %v", path)
//         return {}, false
//     }
//     defer delete(data)

//     cwd := os.get_current_directory()
//     defer delete(cwd)

//     full := slashpath.join({cwd, slashpath.dir(path, context.temp_allocator)}, context.temp_allocator)

//     included_files := map[string]int{}
//     defer delete(included_files)
//     src := process_shader_source(full, slashpath.base(path, allocator = context.temp_allocator), &included_files)

//     return load_shader_memory(transmute([]u8)src, type)
// }

// @(private = "file")
// load_shader_memory :: proc(src: []byte, type: u32) -> (u32, bool) {
//     shader := gl.CreateShader(type)

//     sources := []cstring {
//         cstring(raw_data(src)),
//     }
//     lenghts := []i32 {
//         i32(len(src)),
//     }
//     gl.ShaderSource(shader, 1, raw_data(sources), nil)
//     gl.CompileShader(shader)
    
//     success: i32
//     gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success)
//     if success == 0 {
//         log_buffer: [512]byte
//         length: i32
//         gl.GetShaderInfoLog(shader, len(log_buffer), &length, raw_data(log_buffer[:]))
//         log.errorf("Error compiling %v shader: \n%v", "vertex" if type == gl.VERTEX_SHADER else "fragment", string(log_buffer[:length]))
//         return {}, false
//     }

//     return shader, true
// }

// uniform :: #force_inline proc(s: ^Shader, name: string) -> i32 {
//     loc, ok := s.uniforms[name]
//     if !ok {
//         loc = gl.GetUniformLocation(s.program, cstr(name))
//     }
//     return loc
// }

// shader_reload :: proc(shader: ^Shader) -> (ok: bool) {
//     uniforms := clone_map(shader.uniforms, context.temp_allocator)
//     shader^ = shader_load_from_file(shader.vertex_path, shader.fragment_path) or_return
//     return true
// }

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

// === NEW SHADER STUFF ===
import "shaderc"
import spvc "spirv-cross"

Shader :: struct {
    using base: Asset,

    program: RenderHandle,
}

@(private="file")
check_shader_cache :: proc(path: string) -> (bytecode: []byte, ok: bool) {
    base := filepath.base(path)
    cached_path := filepath.join({"cache/shaders", base}, context.temp_allocator)
    full_path := strings.join({cached_path, "cache"}, ".", context.temp_allocator)
    return os.read_entire_file(full_path)
}

load_shader_stage :: proc(path: string, shader_kind: ShaderKind) -> (handle: RenderHandle, ok: bool) {
    cache, found := check_shader_cache(path)
    if !found {
        cache = compile_shader(path, shader_kind)
        // Save to disk
        make_directory_recursive("cache/shaders")
        base := filepath.base(path)
        cached_path := filepath.join({"cache/shaders", base}, context.temp_allocator)
        full_path := strings.join({cached_path, "cache"}, ".", context.temp_allocator)
        log.debugf("Will write cache to %v", full_path)
        os.write_entire_file(full_path, cache)
    }

    shader := gl.CreateShader(gl.VERTEX_SHADER if shader_kind == .Vertex else gl.FRAGMENT_SHADER)

    gl.ShaderBinary(1, &shader, gl.SHADER_BINARY_FORMAT_SPIR_V, raw_data(cache), cast(i32)len(cache))
    gl.SpecializeShader(shader, "main", 0, nil, nil)

    success: i32
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success)
    if success == 0 {
        log_buffer: [512]byte
        length: i32
        gl.GetShaderInfoLog(shader, len(log_buffer), &length, raw_data(log_buffer[:]))
        log.errorf("Error compiling %v shader: \n%v", shader_kind, string(log_buffer[:length]))
        return {}, false
    }

    return shader, true
}

shader_load_from_file :: proc(vertex_path, fragment_path: string) -> (shader: Shader, ok: bool) {
    vertex, vertex_ok := load_shader_stage(vertex_path, .Vertex)
    assert(vertex_ok, "Failed to load vertex shader.")

    fragment, frag_ok := load_shader_stage(fragment_path, .Fragment)
    assert(frag_ok, "Failed to load fragment shader.")

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

// Editor-Only
compile_shader :: proc(file: string, shader_kind: ShaderKind) -> (bytecode: []byte) {
    data, ok := os.read_entire_file(file)
    fmt.assertf(ok, "Could not read shader filed '%v'", file)

    vulkan_spirv := compile_to_spirv_vulkan(data, shader_kind, file)
    // If we were targeting Vulkan, we would stop here.

    glsl_source := compile_to_glsl(vulkan_spirv)
    return compile_to_spirv_opengl(glsl_source, shader_kind, file)
}

include_resolve :: proc "c" (
    user_data: rawptr,
    requested_source: cstring,
    type: shaderc.IncludeType,
    requesting_source: cstring,
    include_depth: c.size_t,
) -> ^shaderc.IncludeResult {
    context = (cast(^runtime.Context)user_data)^
    result := new(shaderc.IncludeResult)

    switch type {
    case .relative:
        project_path := filepath.join({"assets", "shaders", string(requested_source)}, context.temp_allocator)
        full_path, found := filepath.abs(project_path, context.temp_allocator)
        assert(found)

        log.debugf("Resolved '%v' to '%v'", requested_source, full_path)

        data, ok := os.read_entire_file(full_path)
        if !ok {
            result.source = ""
            result.content = "Could not open file."
        } else {
            result.source = full_path
            result.content = transmute(string)data
        }

    case .standard:
        unimplemented()
    }
    return result
}

include_result_release :: proc "c" (user_data: rawptr, include_result: ^shaderc.IncludeResult) {}

compile_to_spirv_vulkan :: proc(source: []byte, shader_kind: ShaderKind, name: string) -> (bytecode: []byte) {
    shader_kind_to_shaderc :: proc(kind: ShaderKind) -> shaderc.ShaderKind {
        switch kind {
        case .Vertex: return .glsl_vertex_shader
        case .Fragment: return .glsl_fragment_shader
        }
        unreachable()
    }
    compiler := shaderc.compiler_initialize()
    if compiler == nil {
        log.errorf("Failed to initialize shader compiler for Vulkan.")
        return
    }

    options := shaderc.compile_options_initialize()
    shaderc.compile_options_set_target_env(options, .vulkan, .vulkan_1_3)
    shaderc.compile_options_set_optimization_level(options, .performance)

    def_name: cstring = "EDITOR"
    shaderc.compile_options_add_macro_definition(options, def_name, len(def_name), nil, 0)

    ctx := context
    shaderc.compile_options_set_include_callbacks(options, include_resolve, include_result_release, &ctx)
    shaderc.compile_options_set_source_language(options, .glsl)

    result := shaderc.compile_into_spv(
        compiler, 
        cstring(&source[0]), 
        len(source), 
        shader_kind_to_shaderc(shader_kind), 
        cstr(name), "main", options)

    status := shaderc.result_get_compilation_status(result)
    if status != .success {
        errors := shaderc.result_get_num_errors(result)
        warnings := shaderc.result_get_num_warnings(result)
        log.errorf("Error compiling shader to Vulkan SPIR-V: %v", status)
        log.errorf("\t%v errors, %v warnings", errors, warnings)
        log.errorf("\tError from SPIR-V compiler:\n%v", shaderc.result_get_error_message(result))
        return
    }

    bytecode = shaderc.result_get_bytes(result)[:shaderc.result_get_length(result)]
    return
}

compile_to_spirv_opengl :: proc(source: []byte, shader_kind: ShaderKind, name: string) -> (bytecode: []byte) {
    shader_kind_to_shaderc :: proc(kind: ShaderKind) -> shaderc.ShaderKind {
        switch kind {
        case .Vertex: return .glsl_vertex_shader
        case .Fragment: return .glsl_fragment_shader
        }
        unreachable()
    }
    compiler := shaderc.compiler_initialize()
    if compiler == nil {
        log.errorf("Failed to initialize shader compiler for OpenGL")
        return
    }

    options := shaderc.compile_options_initialize()
    shaderc.compile_options_set_target_env(options, .opengl, .opengl_4_5)
    shaderc.compile_options_set_source_language(options, .glsl)
    shaderc.compile_options_set_auto_bind_uniforms(options, true)
    shaderc.compile_options_set_vulkan_rules_relaxed(options, true)
    shaderc.compile_options_set_optimization_level(options, .performance)

    ctx := context
    shaderc.compile_options_set_include_callbacks(options, include_resolve, include_result_release, &ctx)

    result := shaderc.compile_into_spv(
        compiler, 
        cstring(&source[0]), 
        len(source), 
        shader_kind_to_shaderc(shader_kind), 
        cstr(name), "main", options)

    status := shaderc.result_get_compilation_status(result)
    if status != .success {
        errors := shaderc.result_get_num_errors(result)
        warnings := shaderc.result_get_num_warnings(result)
        log.errorf("Error compiling shader to OpenGL SPIR-V: %v", status)
        log.errorf("\t%v errors, %v warnings", errors, warnings)
        log.errorf("\tError from SPIR-V compiler:\n%v", shaderc.result_get_error_message(result))
        return
    }


    bytecode = shaderc.result_get_bytes(result)[:shaderc.result_get_length(result)]
    return
}

compile_to_glsl :: proc(spirv_bytecode: []byte) -> (glsl_source: []byte) {
    glsl_ctx: spvc.Context
    res := spvc.context_create(&glsl_ctx)
    assert(res == .SUCCESS, "Failed to create spvc context.")

    parsed_ir: spvc.ParsedIR
    res = spvc.context_parse_spirv(glsl_ctx, transmute(^u32)&spirv_bytecode[0], len(spirv_bytecode) / 4, &parsed_ir)
    if res != .SUCCESS {
        log.errorf("Failed to parse SPIR-V IR: %v", res)
        return
    }

    glsl_compiler: spvc.Compiler
    res = spvc.context_create_compiler(glsl_ctx, .GLSL, parsed_ir, .TAKE_OWNERSHIP, &glsl_compiler)
    assert(res == .SUCCESS, "Error creating GLSL compiler")

    options: spvc.CompilerOptions
    spvc.compiler_create_compiler_options(glsl_compiler, &options)
    spvc.compiler_options_set_uint(options, .GLSL_VERSION, 450)
    spvc.compiler_options_set_bool(options, .GLSL_ENABLE_420PACK_EXTENSION, true)
    spvc.compiler_options_set_bool(options, .GLSL_ES, false)
    spvc.compiler_options_set_bool(options, .GLSL_ENABLE_ROW_MAJOR_LOAD_WORKAROUND, true)
    spvc.compiler_options_set_bool(options, .ENABLE_STORAGE_IMAGE_QUALIFIER_DEDUCTION, true)
    spvc.compiler_options_set_bool(options, .GLSL_SUPPORT_NONZERO_BASE_INSTANCE, true)

    res = spvc.compiler_install_compiler_options(glsl_compiler, options)
    assert(res == .SUCCESS, "Error setting compiler options")

    glsl_shader: cstring
    res = spvc.compiler_compile(glsl_compiler, &glsl_shader)
    assert(res == .SUCCESS, "Error generating GLSL code")

    return transmute([]byte)string(glsl_shader)
}

make_directory_recursive :: proc(path: string) {
    path, _ := strings.clone(path, context.temp_allocator)

    temp: string
    for dir in strings.split_iterator(&path, "/") {
        temp = strings.join({temp, dir, "/"}, "", context.temp_allocator)
        log.debugf("Make dir '%v'", temp)
        os.make_directory(temp)
    }
}

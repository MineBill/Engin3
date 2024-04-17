package engine
import "core:c"
import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:path/slashpath"
import "core:runtime"
import "core:strings"
import "shaderc"
import fs "filesystem"
import gl "vendor:OpenGL"
import spvc "spirv-cross"
import "core:time"

ShaderKind :: enum {
    Vertex,
    Fragment,
}

@(asset)
Shader :: struct {
    using base: Asset,

    program: RenderHandle,
    vertex, fragment: string,
}

@(private="file")
check_shader_cache :: proc(path: string) -> (bytecode: []byte, ok: bool) {
    source_info, _ := os.stat(path)

    base := filepath.base(path)
    cached_path := filepath.join({"cache/shaders", base}, context.temp_allocator)
    full_path := strings.join({cached_path, "cache"}, ".", context.temp_allocator)

    cache_info, _ := os.stat(full_path)
    if time.diff(source_info.modification_time, cache_info.modification_time) < 0 {
        return {}, false
    }
    // if source_info.modification_time
    return os.read_entire_file(full_path)
}

load_shader_stage :: proc(path: string, shader_kind: ShaderKind, force_compile := false) -> (handle: RenderHandle, ok: bool) {
    cache, found := check_shader_cache(path)
    defer delete(cache)
    if !found || force_compile {
        cache, ok = compile_shader(path, shader_kind)
        // Save to disk
        fs.make_directory_recursive("cache/shaders")
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

shader_load_from_file :: proc(vertex_path, fragment_path: string, force_compile := false) -> (shader: Shader, ok: bool) {
    vertex := load_shader_stage(vertex_path, .Vertex, force_compile) or_return
    fragment := load_shader_stage(fragment_path, .Fragment, force_compile) or_return

    shader.program = gl.CreateProgram()
    gl.AttachShader(shader.program, vertex)
    gl.AttachShader(shader.program, fragment)
    gl.LinkProgram(shader.program)

    shader.vertex   = strings.clone(vertex_path)
    shader.fragment = strings.clone(fragment_path)

    success: i32
    gl.GetProgramiv(shader.program, gl.LINK_STATUS, &success)
    if b32(success) != gl.TRUE {
        log_buffer: [512]byte
        length: i32
        gl.GetProgramInfoLog(shader.program, len(log_buffer), &length, raw_data(log_buffer[:]))
        log.errorf("Error linking shader program: \n%v", string(log_buffer[:length]))
        return {}, false
    }

    return shader, true
}

shader_reload :: proc(shader: ^Shader) {
    new_shader, ok := shader_load_from_file(shader.vertex, shader.fragment, force_compile = true)
    if ok {
        shader^ = new_shader
    }
}

// Editor-Only
compile_shader :: proc(file: string, shader_kind: ShaderKind) -> (bytecode: []byte, ok: bool) {
    data := os.read_entire_file(file) or_return

    vulkan_spirv := compile_to_spirv_vulkan(data, shader_kind, file) or_return
    // If we were targeting Vulkan, we would stop here.
    glsl_source := compile_to_glsl(vulkan_spirv) or_return

    // If we were targeting Vulkan, we would stop here.
    return compile_to_spirv_opengl(glsl_source, shader_kind, file)
}

compile_to_spirv_vulkan :: proc(source: []byte, shader_kind: ShaderKind, name: string) -> (bytecode: []byte, ok: bool) {
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
    shaderc.compile_options_set_vulkan_rules_relaxed(options, true)
    shaderc.compile_options_set_generate_debug_info(options)

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
    ok = true
    return
}

compile_to_spirv_opengl :: proc(source: []byte, shader_kind: ShaderKind, name: string) -> (bytecode: []byte, ok: bool) {
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
    shaderc.compile_options_set_generate_debug_info(options)
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
    ok = true
    return
}

compile_to_glsl :: proc(spirv_bytecode: []byte) -> (glsl_source: []byte, ok: bool) {
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
    spvc.compiler_options_set_bool(options, .GLSL_ES, false)
    spvc.compiler_options_set_bool(options, .GLSL_ENABLE_ROW_MAJOR_LOAD_WORKAROUND, true)
    spvc.compiler_options_set_bool(options, .ENABLE_STORAGE_IMAGE_QUALIFIER_DEDUCTION, true)
    spvc.compiler_options_set_bool(options, .GLSL_SUPPORT_NONZERO_BASE_INSTANCE, true)

    spvc.compiler_options_set_bool(options, .GLSL_VULKAN_SEMANTICS, false)
    spvc.compiler_options_set_bool(options, .GLSL_SEPARATE_SHADER_OBJECTS, false)
    spvc.compiler_options_set_bool(options, .FLATTEN_MULTIDIMENSIONAL_ARRAYS, false)
    spvc.compiler_options_set_bool(options, .GLSL_ENABLE_420PACK_EXTENSION, true)
    spvc.compiler_options_set_bool(options, .GLSL_EMIT_PUSH_CONSTANT_AS_UNIFORM_BUFFER, false)
    spvc.compiler_options_set_bool(options, .GLSL_EMIT_UNIFORM_BUFFER_AS_PLAIN_UNIFORMS, false)

    res = spvc.compiler_install_compiler_options(glsl_compiler, options)
    if res != .SUCCESS {
        log.error("Error setting compiler options: %v", res)
        return 
    }

    glsl_shader: cstring
    res = spvc.compiler_compile(glsl_compiler, &glsl_shader)
    if res != .SUCCESS {
        log.error("Error generating GLSL code: %v", res)
        return 
    }

    return transmute([]byte)string(glsl_shader), true
}

@(private = "file")
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

@(private = "file")
include_result_release :: proc "c" (user_data: rawptr, include_result: ^shaderc.IncludeResult) {}

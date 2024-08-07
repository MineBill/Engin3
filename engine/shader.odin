package engine
import "core:c"
import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:path/slashpath"
import "base:runtime"
import "core:strings"
import "shaderc"
import fs "filesystem"
import gl "vendor:OpenGL"
import spvc "spirv-cross"
import "core:time"
import "gpu"

ShaderKind :: enum {
    Vertex,
    Fragment,
}

@(asset)
Shader :: struct {
    using base: Asset,

    shader: gpu.Shader,
    pipeline: gpu.Pipeline,

    pipeline_spec: gpu.PipelineSpecification,
    vertex, fragment: string,
}

@(private="file")
_check_shader_cache :: proc(path: string) -> (bytecode: []byte, ok: bool) {
    when ODIN_OS == .Windows {
        // @note This is stupid, raise an issue about this on Odin discord/repo?
        cwd := os.get_current_directory(context.temp_allocator)
    } else {
        cwd := os.get_current_directory()
    }

    cache_path := concat(make_tpath(project_get_cache_folder(EditorInstance.active_project), path), ".bin", allocator = context.temp_allocator)
    source_path := make_tpath(cwd, path)
    source_info, _ := os.stat(source_path)

    cache_info, _ := os.stat(cache_path)
    if time.diff(source_info.modification_time, cache_info.modification_time) < 0 {
        return {}, false
    }
    // if source_info.modification_time
    return os.read_entire_file(cache_path)
}

@(private = "file")
read_shader_cache :: proc(path: string) -> (vertex, fragment: []byte, ok: bool) {
    when ODIN_OS == .Windows {
        // @note This is stupid, raise an issue about this on Odin discord/repo?
        cwd := os.get_current_directory(context.temp_allocator)
    } else {
        cwd := os.get_current_directory()
    }

    vertex_cache_path := concat(make_tpath(project_get_cache_folder(EditorInstance.active_project), path), ".vbin", allocator = context.temp_allocator)
    fragment_cache_path := concat(make_tpath(project_get_cache_folder(EditorInstance.active_project), path), ".fbin", allocator = context.temp_allocator)

    source_path := make_tpath(cwd, path)
    source_info, _ := os.stat(source_path)

    cache_info, _ := os.stat(vertex_cache_path)
    if time.diff(source_info.modification_time, cache_info.modification_time) < 0 {
        return
    }

    vertex = os.read_entire_file(vertex_cache_path) or_return
    fragment = os.read_entire_file(fragment_cache_path) or_return
    log_debug(LC.Engine, "%v %v ", len(vertex), len(fragment))
    ok = true
    return
}

@(private = "file")
write_shader_cache :: proc(vertex, fragment: []byte, path: string) {
    vertex_cache_path := concat(make_tpath(project_get_cache_folder(EditorInstance.active_project), path), ".vbin", allocator = context.temp_allocator)
    fs.make_directory_recursive(filepath.dir(vertex_cache_path, context.temp_allocator))
    fragment_cache_path := concat(make_tpath(project_get_cache_folder(EditorInstance.active_project), path), ".fbin", allocator = context.temp_allocator)
    fs.make_directory_recursive(filepath.dir(fragment_cache_path, context.temp_allocator))

    log_debug(LC.Engine, "Writing shader caches to %v and %v", vertex_cache_path, fragment_cache_path)
    os.write_entire_file(vertex_cache_path, vertex)
    os.write_entire_file(fragment_cache_path, fragment)
}

load_shader_stage :: proc(path: string, source: string, shader_kind: ShaderKind, force_compile := false) -> (bytecode: []byte, ok: bool) {
    // cache, found := check_shader_cache(path)
    // if found && !force_compile {
    //     log_debug(LC.Engine, "CACHE FOUND")
    //     bytecode, ok = cache, true
    // } else {
    //     log_debug(LC.Engine, "CACHE NOT FOUND - COMPILING")
    //     cache_path := concat(make_tpath(project_get_cache_folder(EditorInstance.active_project), path), ".bin", allocator = context.temp_allocator)
    //     if !os.write_entire_file(cache_path, bytecode) {
    //         log_error(LC.Engine, "Could not write shader cache for '%v' of type '%v'", path, shader_kind)
    //     }
    // }

    bytecode, ok = compile_shader_source(path, source, shader_kind)
    return
}

shader_load_from_file :: proc(path: string, pipeline_spec: Maybe(gpu.PipelineSpecification) = {}, force_compile := false) -> (shader: Shader, ok: bool) {
    vertex, fragment, found := read_shader_cache(path)

    if !found || force_compile {
        log_debug(LC.Engine, "CACHE NOT FOUND - COMPILING")
        shader_source := os.read_entire_file(path) or_return
        vertex_src, fragment_src := split_shader(string(shader_source))

        vertex   = load_shader_stage(path, vertex_src, .Vertex, force_compile) or_return
        fragment = load_shader_stage(path, fragment_src, .Fragment, force_compile) or_return
        log_debug(LC.Engine, "%v %v ", len(vertex), len(fragment))

        write_shader_cache(vertex, fragment, path)
    }

    shader_spec := gpu.ShaderSpecification {
        vertex_spirv = vertex,
        fragment_spirv = fragment,
    }
    shader.shader = gpu.create_shader(&Renderer3DInstance.device, shader_spec)

    if spec, ok := pipeline_spec.?; ok {
        spec.shader = shader.shader
        shader.pipeline_spec = spec

        pipeline_error: gpu.PipelineCreationError
        shader.pipeline, pipeline_error = gpu.create_pipeline(&Renderer3DInstance.device, spec)
        fmt.assertf(pipeline_error == nil, "Failed to create pipeline: %v", pipeline_error)
    }

    return shader, true
}

new_shader :: proc(path: string, pipeline_spec: Maybe(gpu.PipelineSpecification) = {}, force_compile := false) -> (shader: ^Shader, ok: bool) {
    shader = new(Shader)
    shader^, ok = shader_load_from_file(path, pipeline_spec, force_compile)
    return
}

shader_reload :: proc(shader: ^Shader, path: string) {
    log_debug(LC.AssetSystem, "Shader reload requested")
    new_shader, ok := shader_load_from_file(path, shader.pipeline_spec, true)
    if ok {
        shader^ = new_shader
    }
}

// Editor-Only
compile_shader_source :: proc(file: string, source: string, shader_kind: ShaderKind) -> (bytecode: []byte, ok: bool) {
    bytecode = compile_to_spirv_vulkan(transmute([]byte) source, shader_kind, file) or_return

    log_info(LC.Engine, "Shader Reflection for %v:", file)
    if !reflect_shader(bytecode, file, shader_kind) {
        log_error(LC.Engine, "Shader reflection failed")
    }

    return bytecode, true
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

    if shader_kind == .Vertex {
        name :: "Vertex"
        value :: "main"
        shaderc.compile_options_add_macro_definition(options, name, len(name), value, len(value))
    } else {
        name :: "Fragment"
        value :: "main"
        shaderc.compile_options_add_macro_definition(options, name, len(name), value, len(value))
    }

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
        editor_push_notification(EditorInstance, "Shader compilation failed. Check the console for more info.", .Error)
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
    shaderc.compile_options_set_auto_map_locations(options, true)
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

reflect_shader :: proc(spirv_bytecode: []byte, name: string, stage: ShaderKind) -> (ok: bool) {
    glsl_ctx: spvc.Context
    res := spvc.context_create(&glsl_ctx)
    assert(res == .SUCCESS, "Failed to create spvc context.")

    parsed_ir: spvc.ParsedIR
    res = spvc.context_parse_spirv(glsl_ctx, transmute(^u32)&spirv_bytecode[0], len(spirv_bytecode) / 4, &parsed_ir)
    if res != .SUCCESS {
        log.errorf("Failed to parse SPIR-V IR: %v", res)
        return
    }

    compiler: spvc.Compiler
    res = spvc.context_create_compiler(glsl_ctx, .NONE, parsed_ir, .COPY, &compiler)
    assert(res == .SUCCESS, "Error creating NONE compiler")

    // options: spvc.CompilerOptions
    // spvc.compiler_create_compiler_options(compiler, &options)
    // spvc.compiler_options_set_uint(options, .GLSL_VERSION, 450)
    // spvc.compiler_options_set_bool(options, .GLSL_ES, false)
    // spvc.compiler_options_set_bool(options, .GLSL_ENABLE_ROW_MAJOR_LOAD_WORKAROUND, true)
    // spvc.compiler_options_set_bool(options, .ENABLE_STORAGE_IMAGE_QUALIFIER_DEDUCTION, true)
    // spvc.compiler_options_set_bool(options, .GLSL_SUPPORT_NONZERO_BASE_INSTANCE, true)

    // spvc.compiler_options_set_bool(options, .GLSL_VULKAN_SEMANTICS, false)
    // spvc.compiler_options_set_bool(options, .GLSL_SEPARATE_SHADER_OBJECTS, false)
    // spvc.compiler_options_set_bool(options, .FLATTEN_MULTIDIMENSIONAL_ARRAYS, false)
    // spvc.compiler_options_set_bool(options, .GLSL_ENABLE_420PACK_EXTENSION, true)
    // spvc.compiler_options_set_bool(options, .GLSL_EMIT_PUSH_CONSTANT_AS_UNIFORM_BUFFER, false)
    // spvc.compiler_options_set_bool(options, .GLSL_EMIT_UNIFORM_BUFFER_AS_PLAIN_UNIFORMS, false)

    // res = spvc.compiler_install_compiler_options(compiler, options)
    // if res != .SUCCESS {
    //     log.error("Error setting compiler options: %v", res)
    //     return 
    // }

    resources: spvc.Resources
    spvc.compiler_create_shader_resources(compiler, &resources)

    uniform_buffers, _ := spvc.resources_get_resource_list_for_type(resources, .UNIFORM_BUFFER)

    log_info(LC.Engine, "\t%v Stage:", stage)
    log_info(LC.Engine, "\t\tUniform Buffers(%v):", stage)
    for resource in uniform_buffers {
        log_info(LC.Engine, "\t\t\tID: %v", resource.id)
        log_info(LC.Engine, "\t\t\tBaseTypeID: %v", resource.base_type_id)
        log_info(LC.Engine, "\t\t\tTypeID: %v", resource.type_id)
        log_info(LC.Engine, "\t\t\tName: %v", resource.name)

        log_info(LC.Engine, "\t\t\tSet: %v, Binding: %v",
            spvc.compiler_get_decoration(compiler, resource.id, .DescriptorSet),
            spvc.compiler_get_decoration(compiler, resource.id, .Binding))
        log_info(LC.Engine, "\t\t\tName: %v", spvc.compiler_get_name(compiler, resource.id))


        log_info(LC.Engine, "")
    }

    stage_inputs, _ := spvc.resources_get_resource_list_for_type(resources, .STAGE_INPUT)

    log_info(LC.Engine, "\t\tStage Inputs(%v):", stage)
    for resource in stage_inputs {
        log_info(LC.Engine, "\t\t\tID: %v", resource.id)
        log_info(LC.Engine, "\t\t\tBaseTypeID: %v", resource.base_type_id)
        log_info(LC.Engine, "\t\t\tTypeID: %v", resource.type_id)
        log_info(LC.Engine, "\t\t\tName: %v", resource.name)

        // log_info(LC.Engine, "\tSet: %v, Binding: %v",
        //     spvc.compiler_get_decoration(compiler, resource.id, .DescriptorSet),
        //     spvc.compiler_get_decoration(compiler, resource.id, .Binding))
        // log_info(LC.Engine, "\tName: %v", spvc.compiler_get_name(compiler, resource.id))


        log_info(LC.Engine, "")
    }

    return true
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

// Splits a *.shader file into GLSL vertex and GLSL fragment source.
@(private = "file")
split_shader :: proc(source: string, allocator := context.allocator) -> (vertex: string, fragment: string) {
    common_sb, vertex_sb, fragment_sb: strings.Builder
    strings.builder_init(&common_sb, allocator = context.temp_allocator)
    strings.builder_init(&vertex_sb, allocator = context.temp_allocator)
    strings.builder_init(&fragment_sb, allocator = context.temp_allocator)

    sb: ^strings.Builder = &common_sb

    source := source
    for line in strings.split_lines_iterator(&source) {
        if strings.contains(line, "#pragma") {
            res := strings.split_n(line, " ", 2, context.temp_allocator)
            assert(len(res) == 2)

            res = strings.split(res[1], ":", context.temp_allocator)
            assert(len(res) == 2)

            keyword, type := strings.trim_space(res[0]), strings.trim_space(res[1])
            if keyword == "type" {
                if type == "vertex" {
                    sb = &vertex_sb
                } else if type == "fragment" {
                    sb = &fragment_sb
                }
            } else {
                strings.write_string(sb, line)
                strings.write_rune(sb, '\n')
            }
        } else {
            strings.write_string(sb, line)
            strings.write_rune(sb, '\n')
        }
    }

    common_source := strings.to_string(common_sb)
    vertex_source := strings.to_string(vertex_sb)
    fragment_source := strings.to_string(fragment_sb)

    vertex = strings.concatenate({common_source, vertex_source})
    fragment = strings.concatenate({common_source, fragment_source})
    return
}

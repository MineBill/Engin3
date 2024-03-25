package shaderc
import c "core:c"

H_ :: 1
ENV_H_ :: 1
STATUS_H_ :: 1

IncludeResolveFn :: #type proc(
	user_data: rawptr,
	requested_source: cstring,
	type: c.int,
	requesting_source: cstring,
	include_depth: c.size_t,
) -> ^IncludeResult
IncludeResultReleaseFn :: #type proc(user_data: rawptr, include_result: ^IncludeResult)

SourceLanguage :: enum i32 {
	glsl,
	hlsl,
}

ShaderKind :: enum i32 {
	vertex_shader,
	fragment_shader,
	compute_shader,
	geometry_shader,
	tess_control_shader,
	tess_evaluation_shader,
	glsl_vertex_shader = vertex_shader,
	glsl_fragment_shader = fragment_shader,
	glsl_compute_shader = compute_shader,
	glsl_geometry_shader = geometry_shader,
	glsl_tess_control_shader = tess_control_shader,
	glsl_tess_evaluation_shader = tess_evaluation_shader,

	// Deduce the shader kind from #pragma annotation in the source code. Compiler
	// will emit error if #pragma annotation is not found.
	glsl_infer_from_source,
	// Default shader kinds. Compiler will fall back to compile the source code as
	// the specified kind of shader when #pragma annotation is not found in the
	// source code.
	glsl_default_vertex_shader,
	glsl_default_fragment_shader,
	glsl_default_compute_shader,
	glsl_default_geometry_shader,
	glsl_default_tess_control_shader,
	glsl_default_tess_evaluation_shader,
	spirv_assembly,
	raygen_shader,
	anyhit_shader,
	closesthit_shader,
	miss_shader,
	intersection_shader,
	callable_shader,
	glsl_raygen_shader = raygen_shader,
	glsl_anyhit_shader = anyhit_shader,
	glsl_closesthit_shader = closesthit_shader,
	glsl_miss_shader = miss_shader,
	glsl_intersection_shader = intersection_shader,
	glsl_callable_shader = callable_shader,
	glsl_default_raygen_shader,
	glsl_default_anyhit_shader,
	glsl_default_closesthit_shader,
	glsl_default_miss_shader,
	glsl_default_intersection_shader,
	glsl_default_callable_shader,
	task_shader,
	mesh_shader,
	glsl_task_shader = task_shader,
	glsl_mesh_shader = mesh_shader,
	glsl_default_task_shader,
	glsl_default_mesh_shader,
}

Profile :: enum i32 {
	none, // Used if and only if GLSL version did not specify
	// profiles.
	core,
	compatibility, // Disabled. This generates an error
	es,
}

OptimizationLevel :: enum i32 {
	zero,
	size,
	performance,
}

Limit :: enum i32 {
	max_lights,
	max_clip_planes,
	max_texture_units,
	max_texture_coords,
	max_vertex_attribs,
	max_vertex_uniform_components,
	max_varying_floats,
	max_vertex_texture_image_units,
	max_combined_texture_image_units,
	max_texture_image_units,
	max_fragment_uniform_components,
	max_draw_buffers,
	max_vertex_uniform_vectors,
	max_varying_vectors,
	max_fragment_uniform_vectors,
	max_vertex_output_vectors,
	max_fragment_input_vectors,
	min_program_texel_offset,
	max_program_texel_offset,
	max_clip_distances,
	max_compute_work_group_count_x,
	max_compute_work_group_count_y,
	max_compute_work_group_count_z,
	max_compute_work_group_size_x,
	max_compute_work_group_size_y,
	max_compute_work_group_size_z,
	max_compute_uniform_components,
	max_compute_texture_image_units,
	max_compute_image_uniforms,
	max_compute_atomic_counters,
	max_compute_atomic_counter_buffers,
	max_varying_components,
	max_vertex_output_components,
	max_geometry_input_components,
	max_geometry_output_components,
	max_fragment_input_components,
	max_image_units,
	max_combined_image_units_and_fragment_outputs,
	max_combined_shader_output_resources,
	max_image_samples,
	max_vertex_image_uniforms,
	max_tess_control_image_uniforms,
	max_tess_evaluation_image_uniforms,
	max_geometry_image_uniforms,
	max_fragment_image_uniforms,
	max_combined_image_uniforms,
	max_geometry_texture_image_units,
	max_geometry_output_vertices,
	max_geometry_total_output_components,
	max_geometry_uniform_components,
	max_geometry_varying_components,
	max_tess_control_input_components,
	max_tess_control_output_components,
	max_tess_control_texture_image_units,
	max_tess_control_uniform_components,
	max_tess_control_total_output_components,
	max_tess_evaluation_input_components,
	max_tess_evaluation_output_components,
	max_tess_evaluation_texture_image_units,
	max_tess_evaluation_uniform_components,
	max_tess_patch_components,
	max_patch_vertices,
	max_tess_gen_level,
	max_viewports,
	max_vertex_atomic_counters,
	max_tess_control_atomic_counters,
	max_tess_evaluation_atomic_counters,
	max_geometry_atomic_counters,
	max_fragment_atomic_counters,
	max_combined_atomic_counters,
	max_atomic_counter_bindings,
	max_vertex_atomic_counter_buffers,
	max_tess_control_atomic_counter_buffers,
	max_tess_evaluation_atomic_counter_buffers,
	max_geometry_atomic_counter_buffers,
	max_fragment_atomic_counter_buffers,
	max_combined_atomic_counter_buffers,
	max_atomic_counter_buffer_size,
	max_transform_feedback_buffers,
	max_transform_feedback_interleaved_components,
	max_cull_distances,
	max_combined_clip_and_cull_distances,
	max_samples,
	max_mesh_output_vertices_nv,
	max_mesh_output_primitives_nv,
	max_mesh_work_group_size_x_nv,
	max_mesh_work_group_size_y_nv,
	max_mesh_work_group_size_z_nv,
	max_task_work_group_size_x_nv,
	max_task_work_group_size_y_nv,
	max_task_work_group_size_z_nv,
	max_mesh_view_count_nv,
	max_mesh_output_vertices_ext,
	max_mesh_output_primitives_ext,
	max_mesh_work_group_size_x_ext,
	max_mesh_work_group_size_y_ext,
	max_mesh_work_group_size_z_ext,
	max_task_work_group_size_x_ext,
	max_task_work_group_size_y_ext,
	max_task_work_group_size_z_ext,
	max_mesh_view_count_ext,
	max_dual_source_draw_buffers_ext,
}

// Uniform resource kinds.
// In Vulkan, uniform resources are bound to the pipeline via descriptors
// with numbered bindings and sets.
UniformKind :: enum i32 {
	// Image and image buffer.
	image,
	// Pure sampler.
	sampler,
	// Sampled texture in GLSL, and Shader Resource View in HLSL.
	texture,
	// Uniform Buffer Object (UBO) in GLSL.  Cbuffer in HLSL.
	buffer,
	// Shader Storage Buffer Object (SSBO) in GLSL.
	storage_buffer,
	// Unordered Access View, in HLSL.  (Writable storage image or storage
	// buffer.)
	unordered_access_view,
}

// The kinds of include requests.
IncludeType :: enum i32 {
	relative, // E.g. #include "source"
	standard, // E.g. #include <source>
}

TargetEnv :: enum i32 {
	vulkan, // SPIR-V under Vulkan semantics
	opengl, // SPIR-V under OpenGL semantics
	// NOTE: SPIR-V code generation is not supported for shaders under OpenGL
	// compatibility profile.
	opengl_compat, // SPIR-V under OpenGL semantics,
	// including compatibility profile
	// functions
	webgpu, // Deprecated, SPIR-V under WebGPU
	// semantics
	default = vulkan,
}

EnvVersion :: enum i32 {
	// For Vulkan, use Vulkan's mapping of version numbers to integers.
	// See vulkan.h
	vulkan_1_0 = ((1 << 22)),
	vulkan_1_1 = ((1 << 22) | (1 << 12)),
	vulkan_1_2 = ((1 << 22) | (2 << 12)),
	vulkan_1_3 = ((1 << 22) | (3 << 12)),
	// For OpenGL, use the number from #version in shaders.
	// TODO(dneto): Currently no difference between OpenGL 4.5 and 4.6.
	// See glslang/Standalone/Standalone.cpp
	// TODO(dneto): Glslang doesn't accept a OpenGL client version of 460.
	opengl_4_5 = 450,
	webgpu, // Deprecated, WebGPU env never defined versions
}

SpirvVersion :: enum i32 {
	// Use the values used for word 1 of a SPIR-V binary:
	// - bits 24 to 31: zero
	// - bits 16 to 23: major version number
	// - bits 8 to 15: minor version number
	// - bits 0 to 7: zero
	version_1_0 = 0x010000,
	version_1_1 = 0x010100,
	version_1_2 = 0x010200,
	version_1_3 = 0x010300,
	version_1_4 = 0x010400,
	version_1_5 = 0x010500,
	version_1_6 = 0x010600,
}

// Indicate the status of a compilation.
CompilationStatus :: enum i32 {
	success              = 0,
	invalid_stage        = 1, // error stage deduction
	compilation_error    = 2,
	internal_error       = 3, // unexpected failure
	null_result_object   = 4,
	invalid_assembly     = 5,
	validation_error     = 6,
	transformation_error = 7,
	configuration_error  = 8,
}

IncludeResult :: struct {
	// The name of the source file.  The name should be fully resolved
	// in the sense that it should be a unique name in the context of the
	// includer.  For example, if the includer maps source names to files in
	// a filesystem, then this name should be the absolute path of the file.
	// For a failed inclusion, this string is empty.
	source:    string,
	// source_name : cstring,
	// source_name_length : c.size_t,

	// The text contents of the source file in the normal case.
	// For a failed inclusion, this contains the error message.
	contnet:   string,
	// content : cstring,
	// content_length : c.size_t,

	// User data to be passed along with this request.
	user_data: rawptr,
}

Compiler :: struct {}
CompileOptions :: struct {}
CompilationResult :: struct {}

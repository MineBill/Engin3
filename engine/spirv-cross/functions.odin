package spirv_cross
import c "core:c"

when ODIN_OS == .Windows {
    @(extra_linker_flags="/NODEFAULTLIB:libcmt")
    foreign import lib {
        "bin/spirv-cross-c.lib",
        "bin/spirv-cross-core.lib",
        "bin/spirv-cross-cpp.lib",
        "bin/spirv-cross-glsl.lib",
        "bin/spirv-cross-msl.lib",
        "bin/spirv-cross-hlsl.lib",
        "bin/spirv-cross-reflect.lib",
    }
}

@(link_prefix="spvc_")
foreign lib {

/*
 * Context is the highest-level API construct.
 * The context owns all memory allocations made by its child object hierarchy, including various non-opaque structs and strings.
 * This means that the API user only has to care about one "destroy" call ever when using the C API.
 * All pointers handed out by the APIs are only valid as long as the context
 * is alive and context_release_allocations has not been called.
 */
context_create :: proc(ctx: ^Context) -> Result ---

/* Frees all memory allocations and objects associated with the context and its child objects. */
context_destroy :: proc(ctx: Context) ---

/* Frees all memory allocations and objects associated with the context and its child objects, but keeps the context alive. */
context_release_allocations :: proc(ctx: Context) ---

/* Get the string for the last error which was logged. */
context_get_last_error_string :: proc(ctx: Context) -> cstring ---

/* Get notified in a callback when an error triggers. Useful for debugging. */
context_set_error_callback :: proc(ctx: Context, cb: ErrorCallbackFn, userdata: rawptr) ---

/* SPIR-V parsing interface. Maps to Parser which then creates a ParsedIR, and that IR is extracted into the handle. */
context_parse_spirv :: proc(ctx: Context, spirv: ^SpvId, word_count: c.size_t,
                                                     parsed_ir: ^ParsedIR) -> Result ---

/*
 * Create a compiler backend. Capture mode controls if we construct by copy or move semantics.
 * It is always recommended to use SPVC_CAPTURE_MODE_TAKE_OWNERSHIP if you only intend to cross-compile the IR once.
 */
context_create_compiler :: proc(ctx: Context, backend: Backend,
                                                         parsed_ir: ParsedIR, mode: CaptureMode,
                                                         compiler: ^Compiler) -> Result ---

/* Maps directly to C++ API. */
compiler_get_current_id_bound :: proc(compiler: Compiler) -> c.uint ---

/* Create compiler options, which will initialize defaults. */
compiler_create_compiler_options :: proc(compiler: Compiler, options: ^CompilerOptions) -> Result ---
/* Override options. Will return error if e.g. MSL options are used for the HLSL backend, etc. */
compiler_options_set_bool :: proc(options: CompilerOptions, option: CompilerOption, value: bool) -> Result ---
compiler_options_set_uint :: proc(options: CompilerOptions, option: CompilerOption, value: c.uint) -> Result ---
/* Set compiler options. */
compiler_install_compiler_options :: proc(compiler: Compiler, options: CompilerOptions) -> Result ---

/* Compile IR into a string. *source is owned by the context, and caller must not free it themselves. */
compiler_compile :: proc(compiler: Compiler, source: ^cstring) -> Result ---

/* Maps to C++ API. */
compiler_add_header_line             :: proc(compiler: Compiler, line: cstring) -> Result ---
compiler_require_extension           :: proc(compiler: Compiler, ext: cstring) -> Result ---
compiler_get_num_required_extensions :: proc(compiler: Compiler) -> c.size_t ---
compiler_get_required_extension :: proc(compiler: Compiler, index: c.size_t) -> cstring ---
compiler_flatten_buffer_block        :: proc(compiler: Compiler, id: VariableId) -> Result ---

compiler_variable_is_depth_or_compare :: proc(compiler: Compiler, id: VariableId) -> bool ---

compiler_mask_stage_output_by_location :: proc(compiler: Compiler, location, component: c.uint) -> Result ---
compiler_mask_stage_output_by_builtin  :: proc(compiler: Compiler, builtin: BuiltIn) -> Result ---

/*
 * HLSL specifics.
 * Maps to C++ API.
 */
// compiler_hlsl_set_root_constants_layout :: proc(compiler: Compiler, #by_ptr constant_info: hlsl_root_constants, count: c.size_t) -> Result ---
// compiler_hlsl_add_vertex_attribute_remap :: proc(compiler: Compiler, #by_ptr remap: hlsl_vertex_attribute_remap, remaps: c.size_t) -> Result ---
// compiler_hlsl_remap_num_workgroups_builtin :: proc(compiler: Compiler) -> VariableId ---

// compiler_hlsl_set_resource_binding_flags :: proc(compiler: Compiler, flags: hlsl_binding_flags) -> Result ---

// compiler_hlsl_add_resource_binding :: proc(compiler: Compiler, #by_ptr binding: hlsl_resource_binding) -> Result ---
// compiler_hlsl_is_resource_used :: proc(compiler: Compiler, model: ExecutionModel, set, binding: c.uint) -> bool ---

/*
 * MSL specifics.
 * Maps to C++ API.
 */
// bool compiler_msl_is_rasterization_disabled(compiler: Compiler);

// /* Obsolete. Renamed to needs_swizzle_buffer. */
// bool compiler_msl_needs_aux_buffer(compiler: Compiler);
// bool compiler_msl_needs_swizzle_buffer(compiler: Compiler);
// bool compiler_msl_needs_buffer_size_buffer(compiler: Compiler);

// bool compiler_msl_needs_output_buffer(compiler: Compiler);
// bool compiler_msl_needs_patch_output_buffer(compiler: Compiler);
// bool compiler_msl_needs_input_threadgroup_mem(compiler: Compiler);
// result compiler_msl_add_vertex_attribute(compiler: Compiler,
//                                                                    const msl_vertex_attribute *attrs);
// result compiler_msl_add_resource_binding(compiler: Compiler,
//                                                                    const msl_resource_binding *binding);
// /* Deprecated; use compiler_msl_add_shader_input_2(). */
// result compiler_msl_add_shader_input(compiler: Compiler,
//                                                                const msl_shader_interface_var *input);
// result compiler_msl_add_shader_input_2(compiler: Compiler,
//                                                                  const msl_shader_interface_var_2 *input);
// /* Deprecated; use compiler_msl_add_shader_output_2(). */
// result compiler_msl_add_shader_output(compiler: Compiler,
//                                                                 const msl_shader_interface_var *output);
// result compiler_msl_add_shader_output_2(compiler: Compiler,
//                                                                   const msl_shader_interface_var_2 *output);
// result compiler_msl_add_discrete_descriptor_set(compiler: Compiler, unsigned desc_set);
// result compiler_msl_set_argument_buffer_device_address_space(compiler: Compiler, unsigned desc_set, bool device_address);

// /* Obsolete, use is_shader_input_used. */
// bool compiler_msl_is_vertex_attribute_used(compiler: Compiler, unsigned location);
// bool compiler_msl_is_shader_input_used(compiler: Compiler, unsigned location);
// bool compiler_msl_is_shader_output_used(compiler: Compiler, unsigned location);

// bool compiler_msl_is_resource_used(compiler: Compiler,
//                                                              SpvExecutionModel model,
//                                                              unsigned set,
//                                                              unsigned binding);
// result compiler_msl_remap_constexpr_sampler(compiler: Compiler, variable_id id, const msl_constexpr_sampler *sampler);
// result compiler_msl_remap_constexpr_sampler_by_binding(compiler: Compiler, unsigned desc_set, unsigned binding, const msl_constexpr_sampler *sampler);
// result compiler_msl_remap_constexpr_sampler_ycbcr(compiler: Compiler, variable_id id, const msl_constexpr_sampler *sampler, const msl_sampler_ycbcr_conversion *conv);
// result compiler_msl_remap_constexpr_sampler_by_binding_ycbcr(compiler: Compiler, unsigned desc_set, unsigned binding, const msl_constexpr_sampler *sampler, const msl_sampler_ycbcr_conversion *conv);
// result compiler_msl_set_fragment_output_components(compiler: Compiler, unsigned location, unsigned components);

// unsigned compiler_msl_get_automatic_resource_binding(compiler: Compiler, variable_id id);
// unsigned compiler_msl_get_automatic_resource_binding_secondary(compiler: Compiler, variable_id id);

// result compiler_msl_add_dynamic_buffer(compiler: Compiler, unsigned desc_set, unsigned binding, unsigned index);

// result compiler_msl_add_inline_uniform_block(compiler: Compiler, unsigned desc_set, unsigned binding);

// result compiler_msl_set_combined_sampler_suffix(compiler: Compiler, const char *suffix);
// const char *compiler_msl_get_combined_sampler_suffix(compiler: Compiler);

/*
 * Reflect resources.
 * Maps almost 1:1 to C++ API.
 */
compiler_get_active_interface_variables               :: proc(compiler: Compiler, set: ^Set) -> Result ---
compiler_set_enabled_interface_variables              :: proc(compiler: Compiler, set: Set) -> Result ---
compiler_create_shader_resources                      :: proc(compiler: Compiler, resources: ^Resources) -> Result ---
compiler_create_shader_resources_for_active_variables :: proc(compiler: Compiler, resources: ^Resources, active: Set) -> Result ---
resources_get_resource_list_for_type :: proc(resources: Resources, type: resource_type, resource_list: ^^reflected_resource, resource_size: ^c.size_t) -> Result ---

resources_get_builtin_resource_list_for_type :: proc(
		resources: Resources, type: builtin_resource_type,
		resource_list: ^^reflected_builtin_resource,
		resource_size: ^c.size_t) -> Result ---

/*
 * Decorations.
 * Maps to C++ API.
 */
compiler_set_decoration               :: proc(compiler: Compiler, id: SpvId, decoration: Decoration, argument: c.uint) ---
compiler_set_decoration_string        :: proc(compiler: Compiler, id: SpvId, decoration: Decoration, argument: cstring) ---
compiler_set_name                     :: proc(compiler: Compiler, id: SpvId, argument: cstring) ---
compiler_set_member_decoration        :: proc(compiler: Compiler, id: TypeId, member_index: c.uint, decoration: Decoration, argument: c.uint) ---
compiler_set_member_decoration_string :: proc(compiler: Compiler, id: TypeId, member_index: c.uint, decoration: Decoration, argument: cstring) ---
compiler_set_member_name              :: proc(compiler: Compiler, id: TypeId, member_index: c.uint, argument: cstring) ---
compiler_unset_decoration             :: proc(compiler: Compiler, id: SpvId, decoration: Decoration) ---
compiler_unset_member_decoration      :: proc(compiler: Compiler, id: TypeId, member_index: c.uint, decoration: Decoration) ---

compiler_has_decoration :: proc(compiler: Compiler, id: SpvId, decoration: Decoration) -> bool ---
compiler_has_member_decoration :: proc(compiler: Compiler, id: TypeId, member_index: c.uint, decoration: Decoration) -> bool ---
compiler_get_name                    :: proc(compiler: Compiler, id: SpvId) -> cstring ---
compiler_get_decoration                 :: proc(compiler: Compiler, id: SpvId, decoration: Decoration) -> c.uint ---
compiler_get_decoration_string       :: proc(compiler: Compiler, id: SpvId, decoration: Decoration) -> cstring ---
compiler_get_member_decoration          :: proc(compiler: Compiler, id: TypeId, member_index: c.uint, decoration: Decoration) -> c.uint ---
compiler_get_member_decoration_string:: proc(compiler: Compiler, id: TypeId, member_index: c.uint, decoration: Decoration) -> cstring ---
compiler_get_member_name             :: proc(compiler: Compiler, id: TypeId, member_index: c.uint) -> cstring ---

/*
 * Entry points.
 * Maps to C++ API.
 */
// result compiler_get_entry_points(compiler: Compiler,
//                                                            const entry_point **entry_points,
//                                                            size_t *num_entry_points);
// result compiler_set_entry_point(compiler: Compiler, const char *name,
//                                                           SpvExecutionModel model);
// result compiler_rename_entry_point(compiler: Compiler, const char *old_name,
//                                                              const char *new_name, SpvExecutionModel model);
// const char *compiler_get_cleansed_entry_point_name(compiler: Compiler, const char *name,
//                                                                         SpvExecutionModel model);
// void compiler_set_execution_mode(compiler: Compiler, SpvExecutionMode mode);
// void compiler_unset_execution_mode(compiler: Compiler, SpvExecutionMode mode);
// void compiler_set_execution_mode_with_arguments(compiler: Compiler, SpvExecutionMode mode,
//                                                                      unsigned arg0, unsigned arg1, unsigned arg2);
// result compiler_get_execution_modes(compiler: Compiler, const SpvExecutionMode **modes,
//                                                               size_t *num_modes);
// unsigned compiler_get_execution_mode_argument(compiler: Compiler, SpvExecutionMode mode);
// unsigned compiler_get_execution_mode_argument_by_index(compiler: Compiler,
//                                                                             SpvExecutionMode mode, unsigned index);
// SpvExecutionModel compiler_get_execution_model(compiler: Compiler);
// void compiler_update_active_builtins(compiler: Compiler);
// bool compiler_has_active_builtin(compiler: Compiler, SpvBuiltIn builtin, SpvStorageClass storage);

/*
 * Type query interface.
 * Maps to C++ API, except it's read-only.
 */
// type compiler_get_type_handle(compiler: Compiler, type_id id);

/* Pulls out SPIRType::self. This effectively gives the type ID without array or pointer qualifiers.
 * This is necessary when reflecting decoration/name information on members of a struct,
 * which are placed in the base type, not the qualified type.
 * This is similar to reflected_resource::base_type_id. */
// type_id type_get_base_type_id(type type);

// basetype type_get_basetype(type type);
// unsigned type_get_bit_width(type type);
// unsigned type_get_vector_size(type type);
// unsigned type_get_columns(type type);
// unsigned type_get_num_array_dimensions(type type);
// bool type_array_dimension_is_literal(type type, unsigned dimension);
// SpvId type_get_array_dimension(type type, unsigned dimension);
// unsigned type_get_num_member_types(type type);
// type_id type_get_member_type(type type, unsigned index);
// SpvStorageClass type_get_storage_class(type type);

// /* Image type query. */
// type_id type_get_image_sampled_type(type type);
// SpvDim type_get_image_dimension(type type);
// bool type_get_image_is_depth(type type);
// bool type_get_image_arrayed(type type);
// bool type_get_image_multisampled(type type);
// bool type_get_image_is_storage(type type);
// SpvImageFormat type_get_image_storage_format(type type);
// SpvAccessQualifier type_get_image_access_qualifier(type type);

/*
 * Buffer layout query.
 * Maps to C++ API.
 */
// result compiler_get_declared_struct_size(compiler: Compiler, type struct_type, size_t *size);
// result compiler_get_declared_struct_size_runtime_array(compiler: Compiler,
//                                                                                  type struct_type, size_t array_size, size_t *size);
// result compiler_get_declared_struct_member_size(compiler: Compiler, type type, unsigned index, size_t *size);

// result compiler_type_struct_member_offset(compiler: Compiler,
//                                                                     type type, unsigned index, unsigned *offset);
// result compiler_type_struct_member_array_stride(compiler: Compiler,
//                                                                           type type, unsigned index, unsigned *stride);
// result compiler_type_struct_member_matrix_stride(compiler: Compiler,
//                                                                            type type, unsigned index, unsigned *stride);

/*
 * Workaround helper functions.
 * Maps to C++ API.
 */
// result compiler_build_dummy_sampler_for_combined_images(compiler: Compiler, variable_id *id);
// result compiler_build_combined_image_samplers(compiler: Compiler);
// result compiler_get_combined_image_samplers(compiler: Compiler,
//                                                                       const combined_image_sampler **samplers,
//                                                                       size_t *num_samplers);

/*
 * Constants
 * Maps to C++ API.
 */
// result compiler_get_specialization_constants(compiler: Compiler,
//                                                                        const specialization_constant **constants,
//                                                                        size_t *num_constants);
// constant compiler_get_constant_handle(compiler: Compiler,
//                                                                 constant_id id);

// constant_id compiler_get_work_group_size_specialization_constants(compiler: Compiler,
//                                                                                             specialization_constant *x,
//                                                                                             specialization_constant *y,
//                                                                                             specialization_constant *z);

/*
 * Buffer ranges
 * Maps to C++ API.
 */
// result compiler_get_active_buffer_ranges(compiler: Compiler,
//                                                                    variable_id id,
//                                                                    const buffer_range **ranges,
//                                                                    size_t *num_ranges);

/*
 * No stdint.h until C99, sigh :(
 * For smaller types, the result is sign or zero-extended as appropriate.
 * Maps to C++ API.
 * TODO: The SPIRConstant query interface and modification interface is not quite complete.
 */
// float constant_get_scalar_fp16(constant constant, unsigned column, unsigned row);
// float constant_get_scalar_fp32(constant constant, unsigned column, unsigned row);
// double constant_get_scalar_fp64(constant constant, unsigned column, unsigned row);
// unsigned constant_get_scalar_u32(constant constant, unsigned column, unsigned row);
// int constant_get_scalar_i32(constant constant, unsigned column, unsigned row);
// unsigned constant_get_scalar_u16(constant constant, unsigned column, unsigned row);
// int constant_get_scalar_i16(constant constant, unsigned column, unsigned row);
// unsigned constant_get_scalar_u8(constant constant, unsigned column, unsigned row);
// int constant_get_scalar_i8(constant constant, unsigned column, unsigned row);
// void constant_get_subconstants(constant constant, const constant_id **constituents, size_t *count);
// unsigned long long constant_get_scalar_u64(constant constant, unsigned column, unsigned row);
// long long constant_get_scalar_i64(constant constant, unsigned column, unsigned row);
// type_id constant_get_type(constant constant);

/*
 * C implementation of the C++ api.
 */
// void constant_set_scalar_fp16(constant constant, unsigned column, unsigned row, unsigned short value);
// void constant_set_scalar_fp32(constant constant, unsigned column, unsigned row, float value);
// void constant_set_scalar_fp64(constant constant, unsigned column, unsigned row, double value);
// void constant_set_scalar_u32(constant constant, unsigned column, unsigned row, unsigned value);
// void constant_set_scalar_i32(constant constant, unsigned column, unsigned row, int value);
// void constant_set_scalar_u64(constant constant, unsigned column, unsigned row, unsigned long long value);
// void constant_set_scalar_i64(constant constant, unsigned column, unsigned row, long long value);
// void constant_set_scalar_u16(constant constant, unsigned column, unsigned row, unsigned short value);
// void constant_set_scalar_i16(constant constant, unsigned column, unsigned row, signed short value);
// void constant_set_scalar_u8(constant constant, unsigned column, unsigned row, unsigned char value);
// void constant_set_scalar_i8(constant constant, unsigned column, unsigned row, signed char value);

/*
 * Misc reflection
 * Maps to C++ API.
 */
// bool compiler_get_binary_offset_for_decoration(compiler: Compiler,
//                                                                          variable_id id,
//                                                                          SpvDecoration decoration,
//                                                                          unsigned *word_offset);

// bool compiler_buffer_is_hlsl_counter_buffer(compiler: Compiler, variable_id id);
// bool compiler_buffer_get_hlsl_counter_buffer(compiler: Compiler, variable_id id,
//                                                                        variable_id *counter_id);

// result compiler_get_declared_capabilities(compiler: Compiler,
//                                                                     const SpvCapability **capabilities,
//                                                                     size_t *num_capabilities);
// result compiler_get_declared_extensions(compiler: Compiler, const char ***extensions,
//                                                                   size_t *num_extensions);

// const char *compiler_get_remapped_declared_block_name(compiler: Compiler, variable_id id);
// result compiler_get_buffer_block_decorations(compiler: Compiler, variable_id id,
//                                                                        const SpvDecoration **decorations,
//                                                                        size_t *num_decorations);

}

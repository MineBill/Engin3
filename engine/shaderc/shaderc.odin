// Copyright 2015 The Shaderc Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License")
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package shaderc

import c "core:c"

when ODIN_OS == .Windows {
	@(extra_linker_flags = "/IGNORE:4099")
	foreign import libshaderc "bin/shaderc_combined.lib"
} else when ODIN_OS == .Linux {
	// foreign import libshaderc {
	// }
}

@(default_calling_convention = "c")
@(link_prefix = "shaderc_")
foreign libshaderc {
	// Returns a shaderc_compiler_t that can be used to compile modules.
	// A return of NULL indicates that there was an error initializing the compiler.
	// Any function operating on shaderc_compiler_t must offer the basic
	// thread-safety guarantee.
	// [http://herbsutter.com/2014/01/13/gotw-95-solution-thread-safety-and-synchronization/]
	// That is: concurrent invocation of these functions on DIFFERENT objects needs
	// no synchronization; concurrent invocation of these functions on the SAME
	// object requires synchronization IF AND ONLY IF some of them take a non-const
	// argument.
	compiler_initialize :: proc() -> ^Compiler ---

	// Releases the resources held by the shaderc_compiler_t.
	// After this call it is invalid to make any future calls to functions
	// involving this shaderc_compiler_t.
	compiler_release :: proc(unamed0: ^Compiler) ---

	// Returns a default-initialized shaderc_compile_options_t that can be used
	// to modify the functionality of a compiled module.
	// A return of NULL indicates that there was an error initializing the options.
	// Any function operating on shaderc_compile_options_t must offer the
	// basic thread-safety guarantee.
	compile_options_initialize :: proc() -> ^CompileOptions ---

	// Returns a copy of the given shaderc_compile_options_t.
	// If NULL is passed as the parameter the call is the same as
	// shaderc_compile_options_init.
	compile_options_clone :: proc(options: ^CompileOptions) -> ^CompileOptions ---

	// Releases the compilation options. It is invalid to use the given
	// shaderc_compile_options_t object in any future calls. It is safe to pass
	// NULL to this function, and doing such will have no effect.
	compile_options_release :: proc(options: ^CompileOptions) ---

	// Adds a predefined macro to the compilation options. This has the same
	// effect as passing -Dname=value to the command-line compiler.  If value
	// is NULL, it has the same effect as passing -Dname to the command-line
	// compiler. If a macro definition with the same name has previously been
	// added, the value is replaced with the new value. The macro name and
	// value are passed in with char pointers, which point to their data, and
	// the lengths of their data. The strings that the name and value pointers
	// point to must remain valid for the duration of the call, but can be
	// modified or deleted after this function has returned. In case of adding
	// a valueless macro, the value argument should be a null pointer or the
	// value_length should be 0u.
	compile_options_add_macro_definition :: proc(options: ^CompileOptions, name: cstring, nameLength: c.size_t, value: cstring, valueLength: c.size_t) ---

	// Sets the source language.  The default is GLSL.
	compile_options_set_source_language :: proc(options: ^CompileOptions, lang: SourceLanguage) ---

	// Sets the compiler mode to generate debug information in the output.
	compile_options_set_generate_debug_info :: proc(options: ^CompileOptions) ---

	// Sets the compiler optimization level to the given level. Only the last one
	// takes effect if multiple calls of this function exist.
	compile_options_set_optimization_level :: proc(options: ^CompileOptions, level: OptimizationLevel) ---

	// Forces the GLSL language version and profile to a given pair. The version
	// number is the same as would appear in the #version annotation in the source.
	// Version and profile specified here overrides the #version annotation in the
	// source. Use profile: 'shaderc_profile_none' for GLSL versions that do not
	// define profiles, e.g. versions below 150.
	compile_options_set_forced_version_profile :: proc(options: ^CompileOptions, version: c.int, profile: Profile) ---

	// Sets includer callback functions.
	compile_options_set_include_callbacks :: proc(options: ^CompileOptions, resolver: IncludeResolveFn, resultReleaser: IncludeResultReleaseFn, userData: rawptr) ---

	// Sets the compiler mode to suppress warnings, overriding warnings-as-errors
	// mode. When both suppress-warnings and warnings-as-errors modes are
	// turned on, warning messages will be inhibited, and will not be emitted
	// as error messages.
	compile_options_set_suppress_warnings :: proc(options: ^CompileOptions) ---

	// Sets the target shader environment, affecting which warnings or errors will
	// be issued.  The version will be for distinguishing between different versions
	// of the target environment.  The version value should be either 0 or
	// a value listed in shaderc_env_version.  The 0 value maps to Vulkan 1.0 if
	// |target| is Vulkan, and it maps to OpenGL 4.5 if |target| is OpenGL.
	compile_options_set_target_env :: proc(options: ^CompileOptions, target: TargetEnv, version: EnvVersion) ---

	// Sets the target SPIR-V version. The generated module will use this version
	// of SPIR-V.  Each target environment determines what versions of SPIR-V
	// it can consume.  Defaults to the highest version of SPIR-V 1.0 which is
	// required to be supported by the target environment.  E.g. Default to SPIR-V
	// 1.0 for Vulkan 1.0 and SPIR-V 1.3 for Vulkan 1.1.
	compile_options_set_target_spirv :: proc(options: ^CompileOptions, version: SpirvVersion) ---

	// Sets the compiler mode to treat all warnings as errors. Note the
	// suppress-warnings mode overrides this option, i.e. if both
	// warning-as-errors and suppress-warnings modes are set, warnings will not
	// be emitted as error messages.
	compile_options_set_warnings_as_errors :: proc(options: ^CompileOptions) ---

	// Sets a resource limit.
	compile_options_set_limit :: proc(options: ^CompileOptions, limit: Limit, value: c.int) ---

	// Sets whether the compiler should automatically assign bindings to uniforms
	// that aren't already explicitly bound in the shader source.
	compile_options_set_auto_bind_uniforms :: proc(options: ^CompileOptions, autoBind: bool) ---

	// Sets whether the compiler should automatically remove sampler variables
	// and convert image variables to combined image-sampler variables.
	compile_options_set_auto_combined_image_sampler :: proc(options: ^CompileOptions, upgrade: bool) ---

	// Sets whether the compiler should use HLSL IO mapping rules for bindings.
	// Defaults to false.
	compile_options_set_hlsl_io_mapping :: proc(options: ^CompileOptions, hlslIomap: bool) ---

	// Sets whether the compiler should determine block member offsets using HLSL
	// packing rules instead of standard GLSL rules.  Defaults to false.  Only
	// affects GLSL compilation.  HLSL rules are always used when compiling HLSL.
	compile_options_set_hlsl_offsets :: proc(options: ^CompileOptions, hlslOffsets: bool) ---

	// Sets the base binding number used for for a uniform resource type when
	// automatically assigning bindings.  For GLSL compilation, sets the lowest
	// automatically assigned number.  For HLSL compilation, the regsiter number
	// assigned to the resource is added to this specified base.
	compile_options_set_binding_base :: proc(options: ^CompileOptions, kind: UniformKind, base: u32) ---

	// Like shaderc_compile_options_set_binding_base, but only takes effect when
	// compiling a given shader stage.  The stage is assumed to be one of vertex,
	// fragment, tessellation evaluation, tesselation control, geometry, or compute.
	compile_options_set_binding_base_for_stage :: proc(options: ^CompileOptions, shaderKind: ShaderKind, kind: UniformKind, base: u32) ---

	// Sets whether the compiler should preserve all bindings, even when those
	// bindings are not used.
	compile_options_set_preserve_bindings :: proc(options: ^CompileOptions, preserveBindings: bool) ---

	// Sets whether the compiler should automatically assign locations to
	// uniform variables that don't have explicit locations in the shader source.
	compile_options_set_auto_map_locations :: proc(options: ^CompileOptions, autoMap: bool) ---

	// Sets a descriptor set and binding for an HLSL register in the given stage.
	// This method keeps a copy of the string data.
	compile_options_set_hlsl_register_set_and_binding_for_stage :: proc(options: ^CompileOptions, shaderKind: ShaderKind, reg: cstring, set: cstring, binding: cstring) ---

	// Like shaderc_compile_options_set_hlsl_register_set_and_binding_for_stage,
	// but affects all shader stages.
	compile_options_set_hlsl_register_set_and_binding :: proc(options: ^CompileOptions, reg: cstring, set: cstring, binding: cstring) ---

	// Sets whether the compiler should enable extension
	// SPV_GOOGLE_hlsl_functionality1.
	compile_options_set_hlsl_functionality1 :: proc(options: ^CompileOptions, enable: bool) ---

	// Sets whether 16-bit types are supported in HLSL or not.
	compile_options_set_hlsl_16bit_types :: proc(options: ^CompileOptions, enable: bool) ---

	// Enables or disables relaxed Vulkan rules.
	// This allows most OpenGL shaders to compile under Vulkan semantics.
	compile_options_set_vulkan_rules_relaxed :: proc(options: ^CompileOptions, enable: bool) ---

	// Sets whether the compiler should invert position.Y output in vertex shader.
	compile_options_set_invert_y :: proc(options: ^CompileOptions, enable: bool) ---
	// Sets whether the compiler generates code for max and min builtins which,
	// if given a NaN operand, will return the other operand. Similarly, the clamp
	// builtin will favour the non-NaN operands, as if clamp were implemented
	// as a composition of max and min.
	compile_options_set_nan_clamp :: proc(options: ^CompileOptions, enable: bool) ---

	// Takes a GLSL source string and the associated shader kind, input file
	// name, compiles it according to the given additional_options. If the shader
	// kind is not set to a specified kind, but shaderc_glslc_infer_from_source,
	// the compiler will try to deduce the shader kind from the source
	// string and a failure in deducing will generate an error. Currently only
	// #pragma annotation is supported. If the shader kind is set to one of the
	// default shader kinds, the compiler will fall back to the default shader
	// kind in case it failed to deduce the shader kind from source string.
	// The input_file_name is a null-termintated string. It is used as a tag to
	// identify the source string in cases like emitting error messages. It
	// doesn't have to be a 'file name'.
	// The source string will be compiled into SPIR-V binary and a
	// shaderc_compilation_result will be returned to hold the results.
	// The entry_point_name null-terminated string defines the name of the entry
	// point to associate with this GLSL source. If the additional_options
	// parameter is not null, then the compilation is modified by any options
	// present.  May be safely called from multiple threads without explicit
	// synchronization. If there was failure in allocating the compiler object,
	// null will be returned.
	compile_into_spv :: proc(compiler: ^Compiler, sourceText: cstring, sourceTextSize: c.size_t, shaderKind: ShaderKind, inputFileName: cstring, entryPointName: cstring, additionalOptions: ^CompileOptions = nil) -> ^CompilationResult ---

	// Like shaderc_compile_into_spv, but the result contains SPIR-V assembly text
	// instead of a SPIR-V binary module.  The SPIR-V assembly syntax is as defined
	// by the SPIRV-Tools open source project.
	compile_into_spv_assembly :: proc(compiler: ^Compiler, sourceText: cstring, sourceTextSize: c.size_t, shaderKind: ShaderKind, inputFileName: cstring, entryPointName: cstring, additionalOptions: ^CompileOptions) -> ^CompilationResult ---

	// Like shaderc_compile_into_spv, but the result contains preprocessed source
	// code instead of a SPIR-V binary module
	compile_into_preprocessed_text :: proc(compiler: ^Compiler, sourceText: cstring, sourceTextSize: c.size_t, shaderKind: ShaderKind, inputFileName: cstring, entryPointName: cstring, additionalOptions: ^CompileOptions) -> ^CompilationResult ---

	// Takes an assembly string of the format defined in the SPIRV-Tools project
	// (https://github.com/KhronosGroup/SPIRV-Tools/blob/master/syntax.md),
	// assembles it into SPIR-V binary and a shaderc_compilation_result will be
	// returned to hold the results.
	// The assembling will pick options suitable for assembling specified in the
	// additional_options parameter.
	// May be safely called from multiple threads without explicit synchronization.
	// If there was failure in allocating the compiler object, null will be
	// returned.
	assemble_into_spv :: proc(compiler: ^Compiler, sourceAssembly: cstring, sourceAssemblySize: c.size_t, additionalOptions: ^CompileOptions) -> ^CompilationResult ---

	// The following functions, operating on shaderc_compilation_result_t objects,
	// offer only the basic thread-safety guarantee.

	// Releases the resources held by the result object. It is invalid to use the
	// result object for any further operations.
	result_release :: proc(result: ^CompilationResult) ---
	// Returns the number of bytes of the compilation output data in a result
	// object.
	result_get_length :: proc(result: ^CompilationResult) -> c.size_t ---
	// Returns the number of warnings generated during the compilation.
	result_get_num_warnings :: proc(result: ^CompilationResult) -> c.size_t ---
	// Returns the number of errors generated during the compilation.
	result_get_num_errors :: proc(result: ^CompilationResult) -> c.size_t ---
	// Returns the compilation status, indicating whether the compilation succeeded,
	// or failed due to some reasons, like invalid shader stage or compilation
	// errors.
	result_get_compilation_status :: proc(unamed0: ^CompilationResult) -> CompilationStatus ---
	// Returns a pointer to the start of the compilation output data bytes, either
	// SPIR-V binary or char string. When the source string is compiled into SPIR-V
	// binary, this is guaranteed to be castable to a uint32_t*. If the result
	// contains assembly text or preprocessed source text, the pointer will point to
	// the resulting array of characters.
	result_get_bytes :: proc(result: ^CompilationResult) -> [^]u8 ---
	// Returns a null-terminated string that contains any error messages generated
	// during the compilation.
	result_get_error_message :: proc(result: ^CompilationResult) -> cstring ---

	// Provides the version & revision of the SPIR-V which will be produced
	get_spv_version :: proc(version: ^c.uint, revision: ^c.uint) ---

	// Parses the version and profile from a given null-terminated string
	// containing both version and profile, like: '450core'. Returns false if
	// the string can not be parsed. Returns true when the parsing succeeds. The
	// parsed version and profile are returned through arguments.
	parse_version_profile :: proc(str: cstring, version: ^c.int, profile: ^Profile) -> bool ---
}

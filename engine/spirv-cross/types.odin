package spirv_cross

import "core:c"

ErrorCallbackFn :: #type proc(userdata: rawptr, error: cstring)

Context_          :: struct {}
ParsedIR_         :: struct {}
Compiler_         :: struct {}
CompilerOptions_  :: struct {}
Resources_        :: struct {}
Type_             :: struct {}
Constant_         :: struct {}
Set_              :: struct {}

Context          :: ^Context_
ParsedIR         :: ^ParsedIR_
Compiler         :: ^Compiler_
CompilerOptions  :: ^CompilerOptions_
Resources        :: ^Resources_
Type             :: ^Type_
Constant         :: ^Constant_
Set              :: ^Set_

/*
 * Shallow typedefs. All SPIR-V IDs are plain 32-bit numbers, but this helps communicate which data is used.
 * Maps to a SPIRType.
 */
TypeId :: SpvId;
/* Maps to a SPIRVariable. */
VariableId :: SpvId;
/* Maps to a SPIRConstant. */
ConstantId :: SpvId;

/* See C++ API. */
reflected_resource :: struct {
    id: TypeId,
    base_type_id: TypeId,
    type_id: TypeId,
    name: cstring,
}

reflected_builtin_resource :: struct {
    builtin: BuiltIn,
    value_type_id: TypeId,
    resource: reflected_resource,
}

/* See C++ API. */
entry_point :: struct {
    execution_model: ExecutionModel,
    name: cstring,
}

/* See C++ API. */
combined_image_sampler :: struct {
    combined_id: TypeId,
    image_id: TypeId,
    sampler_id: TypeId,
}

/* See C++ API. */
specialization_constant :: struct {
    id: ConstantId,
    constant_id: c.uint,
}

/* See C++ API. */
buffer_range :: struct {
    index: c.uint,
    offset: c.size_t,
    range: c.size_t,
}

/* See C++ API. */
hlsl_root_constants :: struct {
    start: c.uint,
    end: c.uint,
    binding: c.uint,
    space: c.uint,
}

/* See C++ API. */
hlsl_vertex_attribute_remap :: struct {
    location: c.uint,
    semantic: cstring,
}

/*
 * Be compatible with non-C99 compilers, which do not have stdbool.
 * Only recent MSVC compilers supports this for example, and ideally SPIRV-Cross should be linkable
 * from a wide range of compilers in its C wrapper.
 */
Result :: enum {
    /* Success. */
    SUCCESS = 0,

    /* The SPIR-V is invalid. Should have been caught by validation ideally. */
    ERROR_INVALID_SPIRV = -1,

    /* The SPIR-V might be valid or invalid, but SPIRV-Cross currently cannot correctly translate this to your target language. */
    ERROR_UNSUPPORTED_SPIRV = -2,

    /* If for some reason we hit this, new or malloc failed. */
    ERROR_OUT_OF_MEMORY = -3,

    /* Invalid API argument. */
    ERROR_INVALID_ARGUMENT = -4,

    ERROR_INT_MAX = 0x7fffffff
}

CaptureMode :: enum {
    /* The Parsed IR payload will be copied, and the handle can be reused to create other compiler instances. */
    COPY = 0,

    /*
     * The payload will now be owned by the compiler.
     * parsed_ir should now be considered a dead blob and must not be used further.
     * This is optimal for performance and should be the go-to option.
     */
    TAKE_OWNERSHIP = 1,

    INT_MAX = 0x7fffffff
}

Backend :: enum {
    /* This backend can only perform reflection, no compiler options are supported. Maps to spirv_cross::Compiler. */
    NONE = 0,
    GLSL = 1, /* spirv_cross::CompilerGLSL */
    HLSL = 2, /* CompilerHLSL */
    MSL = 3, /* CompilerMSL */
    CPP = 4, /* CompilerCPP */
    JSON = 5, /* CompilerReflection w/ JSON backend */
    INT_MAX = 0x7fffffff
}

/* Maps to C++ API. */
resource_type :: enum {
    UNKNOWN = 0,
    UNIFORM_BUFFER = 1,
    STORAGE_BUFFER = 2,
    STAGE_INPUT = 3,
    STAGE_OUTPUT = 4,
    SUBPASS_INPUT = 5,
    STORAGE_IMAGE = 6,
    SAMPLED_IMAGE = 7,
    ATOMIC_COUNTER = 8,
    PUSH_CONSTANT = 9,
    SEPARATE_IMAGE = 10,
    SEPARATE_SAMPLERS = 11,
    ACCELERATION_STRUCTURE = 12,
    RAY_QUERY = 13,
    SHADER_RECORD_BUFFER = 14,
    INT_MAX = 0x7fffffff
}

builtin_resource_type :: enum {
    UNKNOWN = 0,
    STAGE_INPUT = 1,
    STAGE_OUTPUT = 2,
    INT_MAX = 0x7fffffff
}

/* Maps to spirv_cross::SPIRType::BaseType. */
basetype :: enum {
    UNKNOWN = 0,
    VOID = 1,
    BOOLEAN = 2,
    INT8 = 3,
    UINT8 = 4,
    INT16 = 5,
    UINT16 = 6,
    INT32 = 7,
    UINT32 = 8,
    INT64 = 9,
    UINT64 = 10,
    ATOMIC_COUNTER = 11,
    FP16 = 12,
    FP32 = 13,
    FP64 = 14,
    STRUCT = 15,
    IMAGE = 16,
    SAMPLED_IMAGE = 17,
    SAMPLER = 18,
    ACCELERATION_STRUCTURE = 19,

    INT_MAX = 0x7fffffff
}

COMMON_BIT :: 0x1000000
GLSL_BIT   :: 0x2000000
HLSL_BIT   :: 0x4000000
MSL_BIT    :: 0x8000000
LANG_BITS  :: 0x0f000000
ENUM_BITS  :: 0xffffff

// #define SPVC_MAKE_MSL_VERSION(major, minor, patch) ((major) * 10000 + (minor) * 100 + (patch))

MAKE_MSL_VERSION :: #force_inline proc(major, minor, patch: int) -> int {
    return ((major) * 10000 + (minor) * 100 + (patch))
}

/* Maps to C++ API. */
msl_platform :: enum {
    IOS = 0,
    MACOS = 1,
    MAX_INT = 0x7fffffff
}

/* Maps to C++ API. */
msl_index_type :: enum {
    NONE = 0,
    UINT16 = 1,
    UINT32 = 2,
    MAX_INT = 0x7fffffff
}

/* Maps to C++ API. */
msl_shader_variable_format :: enum {
    OTHER = 0,
    UINT8 = 1,
    UINT16 = 2,
    ANY16 = 3,
    ANY32 = 4,

    /* Deprecated names. */
    SPVC_MSL_VERTEX_FORMAT_OTHER        = OTHER,
    SPVC_MSL_VERTEX_FORMAT_UINT8        = UINT8,
    SPVC_MSL_VERTEX_FORMAT_UINT16       = UINT16,
    SPVC_MSL_SHADER_INPUT_FORMAT_OTHER  = OTHER,
    SPVC_MSL_SHADER_INPUT_FORMAT_UINT8  = UINT8,
    SPVC_MSL_SHADER_INPUT_FORMAT_UINT16 = UINT16,
    SPVC_MSL_SHADER_INPUT_FORMAT_ANY16  = ANY16,
    SPVC_MSL_SHADER_INPUT_FORMAT_ANY32  = ANY32,

    SPVC_MSL_SHADER_INPUT_FORMAT_INT_MAX = 0x7fffffff
}

msl_shader_input_format :: msl_shader_variable_format
msl_vertex_format :: msl_shader_variable_format

/* Maps to C++ API. Deprecated; use msl_shader_interface_var. */
msl_vertex_attribute :: struct {
    location: c.uint,

    /* Obsolete, do not use. Only lingers on for ABI compatibility. */
    msl_bufferf: c.uint,
    /* Obsolete, do not use. Only lingers on for ABI compatibility. */
    msl_offset: c.uint,
    /* Obsolete, do not use. Only lingers on for ABI compatibility. */
    msl_stride: c.uint,
    /* Obsolete, do not use. Only lingers on for ABI compatibility. */
    per_instance: bool,

    format: msl_vertex_format,
    builtin: BuiltIn,
}

/*
 * Initializes the vertex attribute struct.
 */
// foreign lib {
//     msl_vertex_attribute_init :: proc(attr: ^spv_msl_vertext_attribute) ---
// }


/* Maps to C++ API. Deprecated; use msl_shader_interface_var_2. */
msl_shader_interface_var :: struct {
    location: c.uint,
    format: msl_vertex_format,
    builtin: BuiltIn,
    vecsize: c.uint,
}

msl_shader_input :: msl_shader_interface_var

/*
 * Initializes the shader input struct.
 * Deprecated. Use msl_shader_interface_var_init_2().
 */
// SPVC_PUBLIC_API void msl_shader_interface_var_init(msl_shader_interface_var *var);
/*
 * Deprecated. Use msl_shader_interface_var_init_2().
 */
// SPVC_PUBLIC_API void spvc_msl_shader_input_init(msl_shader_input *input);

/* Maps to C++ API. */
msl_shader_variable_rate :: enum {
    PER_VERTEX = 0,
    PER_PRIMITIVE = 1,
    PER_PATCH = 2,

    INT_MAX = 0x7fffffff,
}

/* Maps to C++ API. */
msl_shader_interface_var_2 :: struct {
    location: c.uint,
    format: msl_shader_variable_format,
    builtin: BuiltIn,
    vecsize: c.uint,
    rate: msl_shader_variable_rate,
}

/*
 * Initializes the shader interface variable struct.
 */
// SPVC_PUBLIC_API void spvc_msl_shader_interface_var_init_2(msl_shader_interface_var_2 *var);

/* Maps to C++ API. */
msl_resource_binding :: struct {
    stage: ExecutionModel,
    desc_set   : c.uint,
    binding    : c.uint,
    msl_buffer : c.uint,
    msl_texture: c.uint,
    msl_sampler: c.uint,
}

/*
 * Initializes the resource binding struct.
 * The defaults are non-zero.
 */
// SPVC_PUBLIC_API void spvc_msl_resource_binding_init(msl_resource_binding *binding);

// MSL_PUSH_CONSTANT_DESC_SET     :: ~(0)
// MSL_PUSH_CONSTANT_BINDING      :: 0
// MSL_SWIZZLE_BUFFER_BINDING     :: ~(1)
// MSL_BUFFER_SIZE_BUFFER_BINDING :: ~(2)
// MSL_ARGUMENT_BUFFER_BINDING    :: ~(3)

/* Obsolete. Sticks around for backwards compatibility. */
SPVC_MSL_AUX_BUFFER_STRUCT_VERSION :: 1

/* Runtime check for incompatibility. Obsolete. */
// SPVC_PUBLIC_API unsigned spvc_msl_get_aux_buffer_struct_version(void);

/* Maps to C++ API. */
msl_sampler_coord :: enum {
    COORD_NORMALIZED = 0,
    COORD_PIXEL = 1,
    INT_MAX = 0x7fffffff
}

/* Maps to C++ API. */
msl_sampler_filter :: enum {
    NEAREST = 0,
    LINEAR = 1,
    INT_MAX = 0x7fffffff
}

/* Maps to C++ API. */
msl_sampler_mip_filter :: enum {
    NONE = 0,
    NEAREST = 1,
    LINEAR = 2,
    INT_MAX = 0x7fffffff
}

/* Maps to C++ API. */
msl_sampler_address :: enum {
    CLAMP_TO_ZERO = 0,
    CLAMP_TO_EDGE = 1,
    CLAMP_TO_BORDER = 2,
    REPEAT = 3,
    MIRRORED_REPEAT = 4,
    INT_MAX = 0x7fffffff
}

/* Maps to C++ API. */
msl_sampler_compare_func :: enum {
    NEVER = 0,
    LESS = 1,
    LESS_EQUAL = 2,
    GREATER = 3,
    GREATER_EQUAL = 4,
    EQUAL = 5,
    NOT_EQUAL = 6,
    ALWAYS = 7,
    INT_MAX = 0x7fffffff
}

/* Maps to C++ API. */
msl_sampler_border_color :: enum {
    TRANSPARENT_BLACK = 0,
    OPAQUE_BLACK = 1,
    OPAQUE_WHITE = 2,
    INT_MAX = 0x7fffffff
}

/* Maps to C++ API. */
msl_format_resolution :: enum {
    _444 = 0,
    _422,
    _420,
    _INT_MAX = 0x7fffffff
}

/* Maps to C++ API. */
msl_chroma_location :: enum {
    COSITED_EVEN = 0,
    MIDPOINT,
    INT_MAX = 0x7fffffff
}

/* Maps to C++ API. */
msl_component_swizzle :: enum {
    IDENTITY = 0,
    ZERO,
    ONE,
    R,
    G,
    B,
    A,
    INT_MAX = 0x7fffffff
}

/* Maps to C++ API. */
msl_sampler_ycbcr_model_conversion :: enum {
    RGB_IDENTITY = 0,
    YCBCR_IDENTITY,
    YCBCR_BT_709,
    YCBCR_BT_601,
    YCBCR_BT_2020,
    INT_MAX = 0x7fffffff
}

/* Maps to C+ API. */
msl_sampler_ycbcr_range :: enum {
    ITU_FULL = 0,
    ITU_NARROW,
    INT_MAX = 0x7fffffff
}

/* Maps to C++ API. */
msl_constexpr_sampler :: struct {
    coord: msl_sampler_coord,
    min_filter: msl_sampler_filter,
    mag_filter: msl_sampler_filter,
    mip_filter: msl_sampler_mip_filter,
    s_address: msl_sampler_address,
    t_address: msl_sampler_address,
    r_address: msl_sampler_address,
    compare_func: msl_sampler_compare_func,
    border_color: msl_sampler_border_color,
    lod_clamp_min: f32,
    lod_clamp_max: f32,
    max_anisotropy: c.int,

    compare_enable: bool,
    lod_clamp_enable: bool,
    anisotropy_enable: bool,
}

/*
 * Initializes the constexpr sampler struct.
 * The defaults are non-zero.
 */
// SPVC_PUBLIC_API void spvc_msl_constexpr_sampler_init(msl_constexpr_sampler *sampler);

/* Maps to the sampler Y'CbCr conversion-related portions of MSLConstexprSampler. See C++ API for defaults and details. */
msl_sampler_ycbcr_conversion :: struct {
    planes: c.uint,
    resolution: msl_format_resolution,
    chroma_filter: msl_sampler_filter,
    x_chroma_offset: msl_chroma_location,
    y_chroma_offset: msl_chroma_location,
    swizzle: [4]msl_component_swizzle,
    ycbcr_model: msl_sampler_ycbcr_model_conversion,
    ycbcr_range: msl_sampler_ycbcr_range,
    bpc: c.uint,
}

/*
 * Initializes the constexpr sampler struct.
 * The defaults are non-zero.
 */
// SPVC_PUBLIC_API void spvc_msl_sampler_ycbcr_conversion_init(msl_sampler_ycbcr_conversion *conv);

/* Maps to C++ API. */
hlsl_binding_flag_bits :: enum {
    AUTO_NONE_BIT = 0,
    AUTO_PUSH_CONSTANT_BIT = 1 << 0,
    AUTO_CBV_BIT = 1 << 1,
    AUTO_SRV_BIT = 1 << 2,
    AUTO_UAV_BIT = 1 << 3,
    AUTO_SAMPLER_BIT = 1 << 4,
    AUTO_ALL = 0x7fffffff
}


// SPVC_HLSL_PUSH_CONSTANT_DESC_SET :: (~(0))
// SPVC_HLSL_PUSH_CONSTANT_BINDING  :: (0)

/* Maps to C++ API. */
hlsl_resource_binding_mapping :: struct {
    register_space: c.uint,
    register_binding: c.uint,
}

hlsl_resource_binding :: struct {
    stage: ExecutionModel,
    desc_set: c.uint,
    binding: c.uint,

    cbv, uav, srv, sampler: hlsl_resource_binding_mapping,
}

/*
 * Initializes the resource binding struct.
 * The defaults are non-zero.
 */
// SPVC_PUBLIC_API void spvc_hlsl_resource_binding_init(hlsl_resource_binding *binding);

/* Maps to the various spirv_cross::Compiler*::Option structures. See C++ API for defaults and details. */
CompilerOption :: enum {
    UNKNOWN = 0,

    FORCE_TEMPORARY = 1 | COMMON_BIT,
    FLATTEN_MULTIDIMENSIONAL_ARRAYS = 2 | COMMON_BIT,
    FIXUP_DEPTH_CONVENTION = 3 | COMMON_BIT,
    FLIP_VERTEX_Y = 4 | COMMON_BIT,

    GLSL_SUPPORT_NONZERO_BASE_INSTANCE = 5 | GLSL_BIT,
    GLSL_SEPARATE_SHADER_OBJECTS = 6 | GLSL_BIT,
    GLSL_ENABLE_420PACK_EXTENSION = 7 | GLSL_BIT,
    GLSL_VERSION = 8 | GLSL_BIT,
    GLSL_ES = 9 | GLSL_BIT,
    GLSL_VULKAN_SEMANTICS = 10 | GLSL_BIT,
    GLSL_ES_DEFAULT_FLOAT_PRECISION_HIGHP = 11 | GLSL_BIT,
    GLSL_ES_DEFAULT_INT_PRECISION_HIGHP = 12 | GLSL_BIT,

    HLSL_SHADER_MODEL = 13 | HLSL_BIT,
    HLSL_POINT_SIZE_COMPAT = 14 | HLSL_BIT,
    HLSL_POINT_COORD_COMPAT = 15 | HLSL_BIT,
    HLSL_SUPPORT_NONZERO_BASE_VERTEX_BASE_INSTANCE = 16 | HLSL_BIT,

    MSL_VERSION = 17 | MSL_BIT,
    MSL_TEXEL_BUFFER_TEXTURE_WIDTH = 18 | MSL_BIT,

    /* Obsolete, use SWIZZLE_BUFFER_INDEX instead. */
    MSL_AUX_BUFFER_INDEX = 19 | MSL_BIT,
    MSL_SWIZZLE_BUFFER_INDEX = 19 | MSL_BIT,

    MSL_INDIRECT_PARAMS_BUFFER_INDEX = 20 | MSL_BIT,
    MSL_SHADER_OUTPUT_BUFFER_INDEX = 21 | MSL_BIT,
    MSL_SHADER_PATCH_OUTPUT_BUFFER_INDEX = 22 | MSL_BIT,
    MSL_SHADER_TESS_FACTOR_OUTPUT_BUFFER_INDEX = 23 | MSL_BIT,
    MSL_SHADER_INPUT_WORKGROUP_INDEX = 24 | MSL_BIT,
    MSL_ENABLE_POINT_SIZE_BUILTIN = 25 | MSL_BIT,
    MSL_DISABLE_RASTERIZATION = 26 | MSL_BIT,
    MSL_CAPTURE_OUTPUT_TO_BUFFER = 27 | MSL_BIT,
    MSL_SWIZZLE_TEXTURE_SAMPLES = 28 | MSL_BIT,
    MSL_PAD_FRAGMENT_OUTPUT_COMPONENTS = 29 | MSL_BIT,
    MSL_TESS_DOMAIN_ORIGIN_LOWER_LEFT = 30 | MSL_BIT,
    MSL_PLATFORM = 31 | MSL_BIT,
    MSL_ARGUMENT_BUFFERS = 32 | MSL_BIT,

    GLSL_EMIT_PUSH_CONSTANT_AS_UNIFORM_BUFFER = 33 | GLSL_BIT,

    MSL_TEXTURE_BUFFER_NATIVE = 34 | MSL_BIT,

    GLSL_EMIT_UNIFORM_BUFFER_AS_PLAIN_UNIFORMS = 35 | GLSL_BIT,

    MSL_BUFFER_SIZE_BUFFER_INDEX = 36 | MSL_BIT,

    EMIT_LINE_DIRECTIVES = 37 | COMMON_BIT,

    MSL_MULTIVIEW = 38 | MSL_BIT,
    MSL_VIEW_MASK_BUFFER_INDEX = 39 | MSL_BIT,
    MSL_DEVICE_INDEX = 40 | MSL_BIT,
    MSL_VIEW_INDEX_FROM_DEVICE_INDEX = 41 | MSL_BIT,
    MSL_DISPATCH_BASE = 42 | MSL_BIT,
    MSL_DYNAMIC_OFFSETS_BUFFER_INDEX = 43 | MSL_BIT,
    MSL_TEXTURE_1D_AS_2D = 44 | MSL_BIT,
    MSL_ENABLE_BASE_INDEX_ZERO = 45 | MSL_BIT,

    /* Obsolete. Use MSL_FRAMEBUFFER_FETCH_SUBPASS instead. */
    MSL_IOS_FRAMEBUFFER_FETCH_SUBPASS = 46 | MSL_BIT,
    MSL_FRAMEBUFFER_FETCH_SUBPASS = 46 | MSL_BIT,

    MSL_INVARIANT_FP_MATH = 47 | MSL_BIT,
    MSL_EMULATE_CUBEMAP_ARRAY = 48 | MSL_BIT,
    MSL_ENABLE_DECORATION_BINDING = 49 | MSL_BIT,
    MSL_FORCE_ACTIVE_ARGUMENT_BUFFER_RESOURCES = 50 | MSL_BIT,
    MSL_FORCE_NATIVE_ARRAYS = 51 | MSL_BIT,

    ENABLE_STORAGE_IMAGE_QUALIFIER_DEDUCTION = 52 | COMMON_BIT,

    HLSL_FORCE_STORAGE_BUFFER_AS_UAV = 53 | HLSL_BIT,

    FORCE_ZERO_INITIALIZED_VARIABLES = 54 | COMMON_BIT,

    HLSL_NONWRITABLE_UAV_TEXTURE_AS_SRV = 55 | HLSL_BIT,

    MSL_ENABLE_FRAG_OUTPUT_MASK = 56 | MSL_BIT,
    MSL_ENABLE_FRAG_DEPTH_BUILTIN = 57 | MSL_BIT,
    MSL_ENABLE_FRAG_STENCIL_REF_BUILTIN = 58 | MSL_BIT,
    MSL_ENABLE_CLIP_DISTANCE_USER_VARYING = 59 | MSL_BIT,

    HLSL_ENABLE_16BIT_TYPES = 60 | HLSL_BIT,

    MSL_MULTI_PATCH_WORKGROUP = 61 | MSL_BIT,
    MSL_SHADER_INPUT_BUFFER_INDEX = 62 | MSL_BIT,
    MSL_SHADER_INDEX_BUFFER_INDEX = 63 | MSL_BIT,
    MSL_VERTEX_FOR_TESSELLATION = 64 | MSL_BIT,
    MSL_VERTEX_INDEX_TYPE = 65 | MSL_BIT,

    GLSL_FORCE_FLATTENED_IO_BLOCKS = 66 | GLSL_BIT,

    MSL_MULTIVIEW_LAYERED_RENDERING = 67 | MSL_BIT,
    MSL_ARRAYED_SUBPASS_INPUT = 68 | MSL_BIT,
    MSL_R32UI_LINEAR_TEXTURE_ALIGNMENT = 69 | MSL_BIT,
    MSL_R32UI_ALIGNMENT_CONSTANT_ID = 70 | MSL_BIT,

    HLSL_FLATTEN_MATRIX_VERTEX_INPUT_SEMANTICS = 71 | HLSL_BIT,

    MSL_IOS_USE_SIMDGROUP_FUNCTIONS = 72 | MSL_BIT,
    MSL_EMULATE_SUBGROUPS = 73 | MSL_BIT,
    MSL_FIXED_SUBGROUP_SIZE = 74 | MSL_BIT,
    MSL_FORCE_SAMPLE_RATE_SHADING = 75 | MSL_BIT,
    MSL_IOS_SUPPORT_BASE_VERTEX_INSTANCE = 76 | MSL_BIT,

    GLSL_OVR_MULTIVIEW_VIEW_COUNT = 77 | GLSL_BIT,

    RELAX_NAN_CHECKS = 78 | COMMON_BIT,

    MSL_RAW_BUFFER_TESE_INPUT = 79 | MSL_BIT,
    MSL_SHADER_PATCH_INPUT_BUFFER_INDEX = 80 | MSL_BIT,
    MSL_MANUAL_HELPER_INVOCATION_UPDATES = 81 | MSL_BIT,
    MSL_CHECK_DISCARDED_FRAG_STORES = 82 | MSL_BIT,

    GLSL_ENABLE_ROW_MAJOR_LOAD_WORKAROUND = 83 | GLSL_BIT,

    MSL_ARGUMENT_BUFFERS_TIER = 84 | MSL_BIT,
    MSL_SAMPLE_DREF_LOD_ARRAY_AS_GRAD = 85 | MSL_BIT,
    MSL_READWRITE_TEXTURE_FENCES = 86 | MSL_BIT,
    MSL_REPLACE_RECURSIVE_INPUTS = 87 | MSL_BIT,
    MSL_AGX_MANUAL_CUBE_GRAD_FIXUP = 88 | MSL_BIT,

    INT_MAX = 0x7fffffff
}

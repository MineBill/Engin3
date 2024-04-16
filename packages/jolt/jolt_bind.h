#include <stddef.h>
#if defined(JPH_DOUBLE_PRECISION)
    #define JOLT_DOUBLE_PRECISION 1
#else
    #define JOLT_DOUBLE_PRECISION 0
#endif

#if JOLT_DOUBLE_PRECISION == 1
typedef double JOLT_Real;
#define JOLT_RVEC_ALIGN alignas(32)
#else
typedef float JOLT_Real;
#define JOLT_RVEC_ALIGN alignas(16)
#endif

typedef struct JOLT_TempAllocator     JOLT_TempAllocator;
typedef struct JOLT_JobSystem         JOLT_JobSystem;
typedef struct JOLT_BodyInterface     JOLT_BodyInterface;
typedef struct JOLT_BodyLockInterface JOLT_BodyLockInterface;
typedef struct JOLT_NarrowPhaseQuery  JOLT_NarrowPhaseQuery;

typedef struct JOLT_ShapeSettings               JOLT_ShapeSettings;
typedef struct JOLT_ConvexShapeSettings         JOLT_ConvexShapeSettings;
typedef struct JOLT_BoxShapeSettings            JOLT_BoxShapeSettings;
typedef struct JOLT_SphereShapeSettings         JOLT_SphereShapeSettings;
typedef struct JOLT_TriangleShapeSettings       JOLT_TriangleShapeSettings;
typedef struct JOLT_CapsuleShapeSettings        JOLT_CapsuleShapeSettings;
typedef struct JOLT_TaperedCapsuleShapeSettings JOLT_TaperedCapsuleShapeSettings;
typedef struct JOLT_CylinderShapeSettings       JOLT_CylinderShapeSettings;
typedef struct JOLT_ConvexHullShapeSettings     JOLT_ConvexHullShapeSettings;
typedef struct JOLT_HeightFieldShapeSettings    JOLT_HeightFieldShapeSettings;
typedef struct JOLT_MeshShapeSettings           JOLT_MeshShapeSettings;
typedef struct JOLT_DecoratedShapeSettings      JOLT_DecoratedShapeSettings;
typedef struct JOLT_CompoundShapeSettings       JOLT_CompoundShapeSettings;
typedef struct JOLT_CharacterContactSettings    JOLT_CharacterContactSettings;

typedef struct JOLT_ConstraintSettings        JOLT_ConstraintSettings;
typedef struct JOLT_TwoBodyConstraintSettings JOLT_TwoBodyConstraintSettings;
typedef struct JOLT_FixedConstraintSettings   JOLT_FixedConstraintSettings;

typedef struct JOLT_PhysicsSystem JOLT_PhysicsSystem;
typedef struct JOLT_SharedMutex   JOLT_SharedMutex;

typedef struct JOLT_Shape            JOLT_Shape;
typedef struct JOLT_Constraint       JOLT_Constraint;
typedef struct JOLT_PhysicsMaterial  JOLT_PhysicsMaterial;
typedef struct JOLT_GroupFilter      JOLT_GroupFilter;
typedef struct JOLT_Character        JOLT_Character;
typedef struct JOLT_CharacterVirtual JOLT_CharacterVirtual;
//--------------------------------------------------------------------------------------------------
//
// Types
//
//--------------------------------------------------------------------------------------------------
typedef uint16_t JOLT_ObjectLayer;
typedef uint8_t  JOLT_BroadPhaseLayer;

//--------------------------------------------------------------------------------------------------
//
// JOLT_ShapeSettings
//
//--------------------------------------------------------------------------------------------------
void JOLT_ShapeSettings_AddRef(JOLT_ShapeSettings *in_settings);

void JOLT_ShapeSettings_Release(JOLT_ShapeSettings *in_settings);

uint32_t JOLT_ShapeSettings_GetRefCount(const JOLT_ShapeSettings *in_settings);

/// First call creates the shape, subsequent calls return the same pointer and increments reference count.
/// Call `JOLT_Shape_Release()` when you don't need returned pointer anymore.
JOLT_Shape * JOLT_ShapeSettings_CreateShape(const JOLT_ShapeSettings *in_settings);

uint64_t JOLT_ShapeSettings_GetUserData(const JOLT_ShapeSettings *in_settings);

void JOLT_ShapeSettings_SetUserData(JOLT_ShapeSettings *in_settings, uint64_t in_user_data);
//--------------------------------------------------------------------------------------------------
//
// JOLT_ConvexShapeSettings (-> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 const JOLT_PhysicsMaterial *
JOLT_ConvexShapeSettings_GetMaterial(const JOLT_ConvexShapeSettings *in_settings);

 void
JOLT_ConvexShapeSettings_SetMaterial(JOLT_ConvexShapeSettings *in_settings,
                                    const JOLT_PhysicsMaterial *in_material);

 float
JOLT_ConvexShapeSettings_GetDensity(const JOLT_ConvexShapeSettings *in_settings);

 void
JOLT_ConvexShapeSettings_SetDensity(JOLT_ConvexShapeSettings *in_settings, float in_density);
//--------------------------------------------------------------------------------------------------
//
// JOLT_BoxShapeSettings (-> JOLT_ConvexShapeSettings -> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
JOLT_BoxShapeSettings * JOLT_BoxShapeSettings_Create(const float in_half_extent[3]);
void JOLT_BoxShapeSettings_GetHalfExtent(const JOLT_BoxShapeSettings *in_settings, float out_half_extent[3]);
void JOLT_BoxShapeSettings_SetHalfExtent(JOLT_BoxShapeSettings *in_settings, const float in_half_extent[3]);
float JOLT_BoxShapeSettings_GetConvexRadius(const JOLT_BoxShapeSettings *in_settings);
void JOLT_BoxShapeSettings_SetConvexRadius(JOLT_BoxShapeSettings *in_settings, float in_convex_radius);
//--------------------------------------------------------------------------------------------------
//
// JOLT_SphereShapeSettings (-> JOLT_ConvexShapeSettings -> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_SphereShapeSettings *
JOLT_SphereShapeSettings_Create(float in_radius);

 float
JOLT_SphereShapeSettings_GetRadius(const JOLT_SphereShapeSettings *in_settings);

 void
JOLT_SphereShapeSettings_SetRadius(JOLT_SphereShapeSettings *in_settings, float in_radius);
//--------------------------------------------------------------------------------------------------
//
// JOLT_TriangleShapeSettings (-> JOLT_ConvexShapeSettings -> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_TriangleShapeSettings *
JOLT_TriangleShapeSettings_Create(const float in_v1[3], const float in_v2[3], const float in_v3[3]);

 void
JOLT_TriangleShapeSettings_SetVertices(JOLT_TriangleShapeSettings *in_settings,
                                      const float in_v1[3],
                                      const float in_v2[3],
                                      const float in_v3[3]);
 void
JOLT_TriangleShapeSettings_GetVertices(const JOLT_TriangleShapeSettings *in_settings,
                                      float out_v1[3],
                                      float out_v2[3],
                                      float out_v3[3]);
 float
JOLT_TriangleShapeSettings_GetConvexRadius(const JOLT_TriangleShapeSettings *in_settings);

 void
JOLT_TriangleShapeSettings_SetConvexRadius(JOLT_TriangleShapeSettings *in_settings,
                                          float in_convex_radius);
//--------------------------------------------------------------------------------------------------
//
// JOLT_CapsuleShapeSettings (-> JOLT_ConvexShapeSettings -> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_CapsuleShapeSettings *
JOLT_CapsuleShapeSettings_Create(float in_half_height_of_cylinder, float in_radius);

 float
JOLT_CapsuleShapeSettings_GetHalfHeight(const JOLT_CapsuleShapeSettings *in_settings);

 void
JOLT_CapsuleShapeSettings_SetHalfHeight(JOLT_CapsuleShapeSettings *in_settings,
                                       float in_half_height_of_cylinder);
 float
JOLT_CapsuleShapeSettings_GetRadius(const JOLT_CapsuleShapeSettings *in_settings);

 void
JOLT_CapsuleShapeSettings_SetRadius(JOLT_CapsuleShapeSettings *in_settings, float in_radius);
//--------------------------------------------------------------------------------------------------
//
// JOLT_TaperedCapsuleShapeSettings (-> JOLT_ConvexShapeSettings -> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_TaperedCapsuleShapeSettings *
JOLT_TaperedCapsuleShapeSettings_Create(float in_half_height, float in_top_radius, float in_bottom_radius);

 float
JOLT_TaperedCapsuleShapeSettings_GetHalfHeight(const JOLT_TaperedCapsuleShapeSettings *in_settings);

 void
JOLT_TaperedCapsuleShapeSettings_SetHalfHeight(JOLT_TaperedCapsuleShapeSettings *in_settings,
                                              float in_half_height);
 float
JOLT_TaperedCapsuleShapeSettings_GetTopRadius(const JOLT_TaperedCapsuleShapeSettings *in_settings);

 void
JOLT_TaperedCapsuleShapeSettings_SetTopRadius(JOLT_TaperedCapsuleShapeSettings *in_settings, float in_top_radius);

 float
JOLT_TaperedCapsuleShapeSettings_GetBottomRadius(const JOLT_TaperedCapsuleShapeSettings *in_settings);

 void
JOLT_TaperedCapsuleShapeSettings_SetBottomRadius(JOLT_TaperedCapsuleShapeSettings *in_settings,
                                                float in_bottom_radius);
//--------------------------------------------------------------------------------------------------
//
// JOLT_CylinderShapeSettings (-> JOLT_ConvexShapeSettings -> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_CylinderShapeSettings *
JOLT_CylinderShapeSettings_Create(float in_half_height, float in_radius);

 float
JOLT_CylinderShapeSettings_GetConvexRadius(const JOLT_CylinderShapeSettings *in_settings);

 void
JOLT_CylinderShapeSettings_SetConvexRadius(JOLT_CylinderShapeSettings *in_settings, float in_convex_radius);

 float
JOLT_CylinderShapeSettings_GetHalfHeight(const JOLT_CylinderShapeSettings *in_settings);

 void
JOLT_CylinderShapeSettings_SetHalfHeight(JOLT_CylinderShapeSettings *in_settings, float in_half_height);

 float
JOLT_CylinderShapeSettings_GetRadius(const JOLT_CylinderShapeSettings *in_settings);

 void
JOLT_CylinderShapeSettings_SetRadius(JOLT_CylinderShapeSettings *in_settings, float in_radius);
//--------------------------------------------------------------------------------------------------
//
// JOLT_ConvexHullShapeSettings (-> JOLT_ConvexShapeSettings -> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_ConvexHullShapeSettings *
JOLT_ConvexHullShapeSettings_Create(const void *in_vertices, uint32_t in_num_vertices, uint32_t in_vertex_size);

 float
JOLT_ConvexHullShapeSettings_GetMaxConvexRadius(const JOLT_ConvexHullShapeSettings *in_settings);

 void
JOLT_ConvexHullShapeSettings_SetMaxConvexRadius(JOLT_ConvexHullShapeSettings *in_settings,
                                               float in_max_convex_radius);
 float
JOLT_ConvexHullShapeSettings_GetMaxErrorConvexRadius(const JOLT_ConvexHullShapeSettings *in_settings);

 void
JOLT_ConvexHullShapeSettings_SetMaxErrorConvexRadius(JOLT_ConvexHullShapeSettings *in_settings,
                                                    float in_max_err_convex_radius);
 float
JOLT_ConvexHullShapeSettings_GetHullTolerance(const JOLT_ConvexHullShapeSettings *in_settings);

 void
JOLT_ConvexHullShapeSettings_SetHullTolerance(JOLT_ConvexHullShapeSettings *in_settings,
                                             float in_hull_tolerance);
//--------------------------------------------------------------------------------------------------
//
// JOLT_HeightFieldShapeSettings (-> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_HeightFieldShapeSettings *
JOLT_HeightFieldShapeSettings_Create(const float *in_samples, uint32_t in_height_field_size);

 void
JOLT_HeightFieldShapeSettings_GetOffset(const JOLT_HeightFieldShapeSettings *in_settings, float out_offset[3]);

 void
JOLT_HeightFieldShapeSettings_SetOffset(JOLT_HeightFieldShapeSettings *in_settings, const float in_offset[3]);

 void
JOLT_HeightFieldShapeSettings_GetScale(const JOLT_HeightFieldShapeSettings *in_settings, float out_scale[3]);

 void
JOLT_HeightFieldShapeSettings_SetScale(JOLT_HeightFieldShapeSettings *in_settings, const float in_scale[3]);

 uint32_t
JOLT_HeightFieldShapeSettings_GetBlockSize(const JOLT_HeightFieldShapeSettings *in_settings);

 void
JOLT_HeightFieldShapeSettings_SetBlockSize(JOLT_HeightFieldShapeSettings *in_settings, uint32_t in_block_size);

 uint32_t
JOLT_HeightFieldShapeSettings_GetBitsPerSample(const JOLT_HeightFieldShapeSettings *in_settings);

 void
JOLT_HeightFieldShapeSettings_SetBitsPerSample(JOLT_HeightFieldShapeSettings *in_settings, uint32_t in_num_bits);
//--------------------------------------------------------------------------------------------------
//
// JOLT_MeshShapeSettings (-> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_MeshShapeSettings *
JOLT_MeshShapeSettings_Create(const void *in_vertices,
                             uint32_t in_num_vertices,
                             uint32_t in_vertex_size,
                             const uint32_t *in_indices,
                             uint32_t in_num_indices);
 uint32_t
JOLT_MeshShapeSettings_GetMaxTrianglesPerLeaf(const JOLT_MeshShapeSettings *in_settings);

 void
JOLT_MeshShapeSettings_SetMaxTrianglesPerLeaf(JOLT_MeshShapeSettings *in_settings, uint32_t in_max_triangles);

 void
JOLT_MeshShapeSettings_Sanitize(JOLT_MeshShapeSettings *in_settings);
//--------------------------------------------------------------------------------------------------
//
// JOLT_DecoratedShapeSettings (-> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_DecoratedShapeSettings *
JOLT_RotatedTranslatedShapeSettings_Create(const JOLT_ShapeSettings *in_inner_shape_settings,
                                          const JOLT_Real in_rotated[4],
                                          const JOLT_Real in_translated[3]);

 JOLT_DecoratedShapeSettings *
JOLT_ScaledShapeSettings_Create(const JOLT_ShapeSettings *in_inner_shape_settings,
                               const JOLT_Real in_scale[3]);

 JOLT_DecoratedShapeSettings *
JOLT_OffsetCenterOfMassShapeSettings_Create(const JOLT_ShapeSettings *in_inner_shape_settings,
                                           const JOLT_Real in_center_of_mass[3]);
//--------------------------------------------------------------------------------------------------
//
// JOLT_CompoundShapeSettings (-> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_CompoundShapeSettings *
JOLT_StaticCompoundShapeSettings_Create();

 JOLT_CompoundShapeSettings *
JOLT_MutableCompoundShapeSettings_Create();

 void
JOLT_CompoundShapeSettings_AddShape(JOLT_CompoundShapeSettings *in_settings,
                                   const JOLT_Real in_position[3],
                                   const JOLT_Real in_rotation[4],
                                   const JOLT_ShapeSettings *in_shape,
                                   const uint32_t in_user_data);

JOLT_BodyInterface* JOLT_GetBodyInterface(JOLT_PhysicsSystem* ps);
// TODO: Consider using structures for IDs
typedef uint32_t JOLT_BodyID;
typedef uint32_t JOLT_SubShapeID;
typedef uint32_t JOLT_CollisionGroupID;
typedef uint32_t JOLT_CollisionSubGroupID;


// Must be 16 byte aligned
typedef void *(*JOLT_AllocateFunction)(size_t in_size);
typedef void (*JOLT_FreeFunction)(void *in_block);

typedef void *(*JOLT_AlignedAllocateFunction)(size_t in_size, size_t in_alignment);
typedef void (*JOLT_AlignedFreeFunction)(void *in_block);

typedef enum JOLT_BodyType {
    JPH_BodyType_Rigid = 0,
    JPH_BodyType_Soft = 1,

    JPH_BodyType_Count,
    JPH_BodyType_Force32 = 0x7fffffff
} JPH_BodyType;

typedef uint8_t JOLT_ShapeType;
enum
{
    JOLT_SHAPE_TYPE_CONVEX       = 0,
    JOLT_SHAPE_TYPE_COMPOUND     = 1,
    JOLT_SHAPE_TYPE_DECORATED    = 2,
    JOLT_SHAPE_TYPE_MESH         = 3,
    JOLT_SHAPE_TYPE_HEIGHT_FIELD = 4,
    JOLT_SHAPE_TYPE_USER1        = 5,
    JOLT_SHAPE_TYPE_USER2        = 6,
    JOLT_SHAPE_TYPE_USER3        = 7,
    JOLT_SHAPE_TYPE_USER4        = 8
};

typedef uint8_t JOLT_ShapeSubType;
enum
{
    JOLT_SHAPE_SUB_TYPE_SPHERE                = 0,
    JOLT_SHAPE_SUB_TYPE_BOX                   = 1,
    JOLT_SHAPE_SUB_TYPE_TRIANGLE              = 2,
    JOLT_SHAPE_SUB_TYPE_CAPSULE               = 3,
    JOLT_SHAPE_SUB_TYPE_TAPERED_CAPSULE       = 4,
    JOLT_SHAPE_SUB_TYPE_CYLINDER              = 5,
    JOLT_SHAPE_SUB_TYPE_CONVEX_HULL           = 6,
    JOLT_SHAPE_SUB_TYPE_STATIC_COMPOUND       = 7,
    JOLT_SHAPE_SUB_TYPE_MUTABLE_COMPOUND      = 8,
    JOLT_SHAPE_SUB_TYPE_ROTATED_TRANSLATED    = 9,
    JOLT_SHAPE_SUB_TYPE_SCALED                = 10,
    JOLT_SHAPE_SUB_TYPE_OFFSET_CENTER_OF_MASS = 11,
    JOLT_SHAPE_SUB_TYPE_MESH                  = 12,
    JOLT_SHAPE_SUB_TYPE_HEIGHT_FIELD          = 13,
    JOLT_SHAPE_SUB_TYPE_USER1                 = 14,
    JOLT_SHAPE_SUB_TYPE_USER2                 = 15,
    JOLT_SHAPE_SUB_TYPE_USER3                 = 16,
    JOLT_SHAPE_SUB_TYPE_USER4                 = 17,
    JOLT_SHAPE_SUB_TYPE_USER5                 = 18,
    JOLT_SHAPE_SUB_TYPE_USER6                 = 19,
    JOLT_SHAPE_SUB_TYPE_USER7                 = 20,
    JOLT_SHAPE_SUB_TYPE_USER8                 = 21,
    JOLT_SHAPE_SUB_TYPE_USER_CONVEX1          = 22,
    JOLT_SHAPE_SUB_TYPE_USER_CONVEX2          = 23,
    JOLT_SHAPE_SUB_TYPE_USER_CONVEX3          = 24,
    JOLT_SHAPE_SUB_TYPE_USER_CONVEX4          = 25,
    JOLT_SHAPE_SUB_TYPE_USER_CONVEX5          = 26,
    JOLT_SHAPE_SUB_TYPE_USER_CONVEX6          = 27,
    JOLT_SHAPE_SUB_TYPE_USER_CONVEX7          = 28,
    JOLT_SHAPE_SUB_TYPE_USER_CONVEX8          = 29,
};

typedef enum JOLT_ConstraintType
{
    JOLT_CONSTRAINT_TYPE_CONSTRAINT          = 0,
    JOLT_CONSTRAINT_TYPE_TWO_BODY_CONSTRAINT = 1,
    JOLT_CONSTRAINT_TYPE_FORCEU32           = 0x7fffffff
} JOLT_ConstraintType;

typedef uint8_t JOLT_AllowedDOFs;
enum{
    JOLT_AllowedDOFs_All = 0b111111,									
    JOLT_AllowedDOFs_TranslationX = 0b000001,								
    JOLT_AllowedDOFs_TranslationY = 0b000010,								
    JOLT_AllowedDOFs_TranslationZ = 0b000100,								
    JOLT_AllowedDOFs_RotationX = 0b001000,									
    JOLT_AllowedDOFs_RotationY = 0b010000,									
    JOLT_AllowedDOFs_RotationZ = 0b100000,			
    //plane 2d is JOLT_AllowedDOFs_TranslationX | JOLT_AllowedDOFs_TranslationY | JOLT_AllowedDOFs_RotationZ,						
    JOLT_AllowedDOFs_Plane2D = 0b100011,

    JOLT_AllowedDOFs_Count,
    //supposed to be forcing 32 bit not for sure why so for now we are making this just uint8
    JOLT_AllowedDOFs_Force32 = 0x7F
};

typedef enum JOLT_ConstraintSubType
{
    JOLT_CONSTRAINT_SUB_TYPE_FIXED           = 0,
    JOLT_CONSTRAINT_SUB_TYPE_POINT           = 1,
    JOLT_CONSTRAINT_SUB_TYPE_HINGE           = 2,
    JOLT_CONSTRAINT_SUB_TYPE_SLIDER          = 3,
    JOLT_CONSTRAINT_SUB_TYPE_DISTANCE        = 4,
    JOLT_CONSTRAINT_SUB_TYPE_CONE            = 5,
    JOLT_CONSTRAINT_SUB_TYPE_SWING_TWIST     = 6,
    JOLT_CONSTRAINT_SUB_TYPE_SIX_DOF         = 7,
    JOLT_CONSTRAINT_SUB_TYPE_PATH            = 8,
    JOLT_CONSTRAINT_SUB_TYPE_VEHICLE         = 9,
    JOLT_CONSTRAINT_SUB_TYPE_RACK_AND_PINION = 10,
    JOLT_CONSTRAINT_SUB_TYPE_GEAR            = 11,
    JOLT_CONSTRAINT_SUB_TYPE_PULLEY          = 12,
    JOLT_CONSTRAINT_SUB_TYPE_USER1           = 13,
    JOLT_CONSTRAINT_SUB_TYPE_USER2           = 14,
    JOLT_CONSTRAINT_SUB_TYPE_USER3           = 15,
    JOLT_CONSTRAINT_SUB_TYPE_USER4           = 16,
    JOLT_CONSTRAINT_SUB_TYPE_FORCEU32       = 0x7fffffff
} JOLT_ConstraintSubType;

typedef enum JOLT_ConstraintSpace
{
    JOLT_CONSTRAINT_SPACE_LOCAL_TO_BODY_COM = 0,
    JOLT_CONSTRAINT_SPACE_WORLD_SPACE       = 1,
    JOLT_CONSTRAINT_SPACE_FORCEU32         = 0x7fffffff
} JOLT_ConstraintSpace;

typedef uint8_t JOLT_MotionQuality;
enum
{
    JOLT_MOTION_QUALITY_DISCRETE    = 0,
    JOLT_MOTION_QUALITY_LINEAR_CAST = 1
};
typedef uint8_t JOLT_MotionType;
enum
{
    JOLT_MOTION_TYPE_STATIC    = 0,
    JOLT_MOTION_TYPE_KINEMATIC = 1,
    JOLT_MOTION_TYPE_DYNAMIC   = 2
};
typedef enum JOLT_Activation
{
    JOLT_ACTIVATION_ACTIVATE      = 0,
    JOLT_ACTIVATION_DONT_ACTIVATE = 1,
    JOLT_ACTIVATION_FORCEU32     = 0x7fffffff
} JOLT_Activation;
typedef uint8_t JOLT_PhysicsUpdateError;
enum
{
    JOLT_PHYSICS_UPDATE_ERROR_NO_ERROR                 = 0,
    JOLT_PHYSICS_UPDATE_ERROR_MANIFOLD_CACHE_FULL      = 1 << 0,
    JOLT_PHYSICS_UPDATE_ERROR_BODY_PAIR_CACHE_FULL     = 1 << 1,
    JOLT_PHYSICS_UPDATE_ERROR_CONTACT_CONSTRAINTS_FULL = 1 << 2,
};

typedef uint8_t JOLT_OverrideMassProperties;
enum
{
    JOLT_OVERRIDE_MASS_PROPERTIES_CALC_MASS_INERTIA     = 0,
    JOLT_OVERRIDE_MASS_PROPERTIES_CALC_INERTIA          = 1,
    JOLT_OVERRIDE_MASS_PROPERTIES_MASS_INERTIA_PROVIDED = 2
};

typedef enum JOLT_CharacterGroundState
{
    JOLT_CHARACTER_GROUND_STATE_ON_GROUND       = 0,
    JOLT_CHARACTER_GROUND_STATE_ON_STEEP_GROUND = 1,
    JOLT_CHARACTER_GROUND_STATE_NOT_SUPPORTED   = 2,
    JOLT_CHARACTER_GROUND_STATE_IN_AIR          = 3,
    JOLT_CHARACTER_GROUND_FORCEU32             = 0x7fffffff
} JOLT_CharacterGroundState;

typedef enum JOLT_ValidateResult
{
    JOLT_VALIDATE_RESULT_ACCEPT_ALL_CONTACTS = 0,
    JOLT_VALIDATE_RESULT_ACCEPT_CONTACT      = 1,
    JOLT_VALIDATE_RESULT_REJECT_CONTACT      = 2,
    JOLT_VALIDATE_RESULT_REJECT_ALL_CONTACTS = 3,
    JOLT_VALIDATE_RESULT_FORCEU32           = 0x7fffffff
} JOLT_ValidateResult;

typedef uint8_t JOLT_BackFaceMode;
enum
{
    JOLT_BACK_FACE_MODE_IGNORE  = 0,
    JOLT_BACK_FACE_MODE_COLLIDE = 1
};

// NOTE: Needs to be kept in sync with JPH::MotionProperties
typedef struct JOLT_MotionProperties
{
    alignas(16) float  linear_velocity[4]; // 4th element is ignored
    alignas(16) float  angular_velocity[4]; // 4th element is ignored
    alignas(16) float  inv_inertia_diagonal[4]; // 4th element is ignored
    alignas(16) float  inertia_rotation[4];

    float              force[3];
    float              torque[3];
    float              inv_mass;
    float              linear_damping;
    float              angular_damping;
    float              max_linear_velocity;
    float              max_angular_velocity;
    float              gravity_factor;
    uint32_t           index_in_active_bodies;
    uint32_t           island_index;

    JOLT_MotionQuality  motion_quality;
    bool               allow_sleeping;

#if JOLT_DOUBLE_PRECISION == 1
    alignas(8) uint8_t reserved[76];
#else
    alignas(4) uint8_t reserved[52];
#endif

#if JOLT_ENABLE_ASSERTS == 1
    JOLT_MotionType     cached_motion_type;
#endif
} JOLT_MotionProperties;
// NOTE: Needs to be kept in sync with JPH::CollisionGroup
typedef struct JOLT_CollisionGroup
{
    const JOLT_GroupFilter * filter;
    JOLT_CollisionGroupID    group_id;
    JOLT_CollisionSubGroupID sub_group_id;
} JOLT_CollisionGroup;
// NOTE: Needs to be kept in sync with JPH::Body
typedef struct JOLT_Body
{
    JOLT_RVEC_ALIGN JOLT_Real position[4]; // 4th element is ignored
    alignas(16) float       rotation[4];
    alignas(16) float       bounds_min[4]; // 4th element is ignored
    alignas(16) float       bounds_max[4]; // 4th element is ignored

    const JOLT_Shape *       shape;
    JOLT_MotionProperties *  motion_properties; // will be NULL for static bodies
    uint64_t                user_data;
    JOLT_CollisionGroup      collision_group;

    float                   friction;
    float                   restitution;
    JOLT_BodyID              id;

    JOLT_ObjectLayer         object_layer;

    JOLT_BroadPhaseLayer     broad_phase_layer;
    JOLT_MotionType          motion_type;
    uint8_t                 flags;
} JOLT_Body;

//
//--------------------------------------------------------------------------------------------------
//
// Structures
//
//--------------------------------------------------------------------------------------------------
// NOTE: Needs to be kept in sync with JPH::MassProperties
typedef struct JOLT_MassProperties
{
    float             mass;
    alignas(16) float inertia[16];
} JOLT_MassProperties;

// NOTE: Needs to be kept in sync with JPH::BodyCreationSettings
typedef struct JOLT_BodyCreationSettings
{
    JOLT_RVEC_ALIGN JOLT_Real    position[4]; // 4th element is ignored
    alignas(16) float          rotation[4];
    alignas(16) float          linear_velocity[4]; // 4th element is ignored
    alignas(16) float          angular_velocity[4]; // 4th element is ignored
    uint64_t                   user_data;
    JOLT_ObjectLayer            object_layer;
    JOLT_CollisionGroup         collision_group;
    JOLT_MotionType             motion_type;
    JOLT_AllowedDOFs            allowed_dofs;
    bool                       allow_dynamic_or_kinematic;
    bool                       is_sensor;
    bool					mCollideKinematicVsNonDynamic;
    bool                       use_manifold_reduction;
    bool					apply_gyroscopic_force;
    JOLT_MotionQuality          motion_quality;
    bool                       allow_sleeping;
    float                      friction;
    float                      restitution;
    float                      linear_damping;
    float                      angular_damping;
    float                      max_linear_velocity;
    float                      max_angular_velocity;
    float                      gravity_factor;
    uint32_t					    mNumVelocityStepsOverride;									///< Used only when this body is dynamic and colliding. Override for the number of solver velocity iterations to run, 0 means use the default in PhysicsSettings::mNumVelocitySteps. The number of iterations to use is the max of all contacts and constraints in the island.
    uint32_t					    mNumPositionStepsOverride;
    JOLT_OverrideMassProperties override_mass_properties;
    float                      inertia_multiplier;
    JOLT_MassProperties         mass_properties_override;
    //private
    const JOLT_ShapeSettings*   shape;
    const JOLT_Shape *          shapePtr;
} JOLT_BodyCreationSettings;

// NOTE: Needs to be kept in sync
typedef struct JOLT_CharacterBaseSettings
{
#   if defined(_MSC_VER)
        const void* __vtable_header[1];
#   else
        const void* __vtable_header[2];
#   endif
    alignas(16) float   up[4]; // 4th element is ignored
    alignas(16) float   supporting_volume[4];
    float               max_slope_angle;
    const JOLT_Shape *   shape;
} JOLT_CharacterBaseSettings;

// NOTE: Needs to be kept in sync
typedef struct JOLT_CharacterSettings
{
    JOLT_CharacterBaseSettings base;
    JOLT_ObjectLayer layer;
    float mass;
    float friction;
    float gravity_factor;
} JOLT_CharacterSettings;

// NOTE: Needs to be kept in sync
typedef struct JOLT_CharacterVirtualSettings
{
    JOLT_CharacterBaseSettings base;
    float               mass;
    float               max_strength;
    alignas(16) float   shape_offset[4];
    JOLT_BackFaceMode    back_face_mode;
    float               predictive_contact_distance;
    uint32_t            max_collision_iterations;
    uint32_t            max_constraint_iterations;
    float               min_time_remaining;
    float               collision_tolerance;
    float               character_padding;
    uint32_t            max_num_hits;
    float               hit_reduction_cos_max_angle;
    float               penetration_recovery_speed;
} JOLT_CharacterVirtualSettings;

// NOTE: Needs to be kept in sync with JPH::SubShapeIDCreator
typedef struct JOLT_SubShapeIDCreator
{
    JOLT_SubShapeID id;
    uint32_t       current_bit;
} JOLT_SubShapeIDCreator;

// NOTE: Needs to be kept in sync with JPH::SubShapeIDPair
typedef struct JOLT_SubShapeIDPair
{
    struct {
        JOLT_BodyID     body_id;
        JOLT_SubShapeID sub_shape_id;
    }                  first;
    struct {
        JOLT_BodyID     body_id;
        JOLT_SubShapeID sub_shape_id;
    }                  second;
} JOLT_SubShapeIDPair;

// NOTE: Needs to be kept in sync with JPH::ContactManifold
typedef struct JOLT_ContactManifold
{
    JOLT_RVEC_ALIGN JOLT_Real  base_offset[4]; // 4th element is ignored
    alignas(16) float        normal[4]; // 4th element is ignored; world space
    float                    penetration_depth;
    JOLT_SubShapeID           shape1_sub_shape_id;
    JOLT_SubShapeID           shape2_sub_shape_id;
    struct {
        alignas(16) uint32_t num_points;
        alignas(16) float    points[64][4]; // 4th element is ignored; world space
    }                        shape1_relative_contact;
    struct {
        alignas(16) uint32_t num_points;
        alignas(16) float    points[64][4]; // 4th element is ignored; world space
    }                        shape2_relative_contact;
} JOLT_ContactManifold;

// NOTE: Needs to be kept in sync with JPH::ContactSettings
typedef struct JOLT_ContactSettings
{
    float combined_friction;
    float combined_restitution;
    bool  is_sensor;
} JOLT_ContactSettings;

// NOTE: Needs to be kept in sync with JPH::CollideShapeResult
typedef struct JOLT_CollideShapeResult
{
    alignas(16) float        shape1_contact_point[4]; // 4th element is ignored; world space
    alignas(16) float        shape2_contact_point[4]; // 4th element is ignored; world space
    alignas(16) float        penetration_axis[4]; // 4th element is ignored; world space
    float                    penetration_depth;
    JOLT_SubShapeID           shape1_sub_shape_id;
    JOLT_SubShapeID           shape2_sub_shape_id;
    JOLT_BodyID               body2_id;
    struct {
        alignas(16) uint32_t num_points;
        alignas(16) float    points[32][4]; // 4th element is ignored; world space
    }                        shape1_face;
    struct {
        alignas(16) uint32_t num_points;
        alignas(16) float    points[32][4]; // 4th element is ignored; world space
    }                        shape2_face;
} JOLT_CollideShapeResult;

// NOTE: Needs to be kept in sync with JPH::TransformedShape
typedef struct JOLT_TransformedShape
{
    JOLT_RVEC_ALIGN JOLT_Real shape_position_com[4]; // 4th element is ignored
    alignas(16) float       shape_rotation[4];
    const JOLT_Shape *       shape;
    float                   shape_scale[3];
    JOLT_BodyID              body_id;
    JOLT_SubShapeIDCreator   sub_shape_id_creator;
} JOLT_TransformedShape;

// NOTE: Needs to be kept in sync with JPH::BodyLockRead
typedef struct JOLT_BodyLockRead
{
    const JOLT_BodyLockInterface *lock_interface;
    JOLT_SharedMutex *            mutex;
    const JOLT_Body *             body;
} JOLT_BodyLockRead;

// NOTE: Needs to be kept in sync with JPH::BodyLockWrite
typedef struct JOLT_BodyLockWrite
{
    const JOLT_BodyLockInterface *lock_interface;
    JOLT_SharedMutex *            mutex;
    JOLT_Body *                   body;
} JOLT_BodyLockWrite;

// NOTE: Needs to be kept in sync with JPH::RRayCast
typedef struct JOLT_RRayCast
{
    JOLT_RVEC_ALIGN JOLT_Real origin[4]; // 4th element is ignored
    alignas(16) float       direction[4]; // length of the vector is important; 4th element is ignored
} JOLT_RRayCast;

// NOTE: Needs to be kept in sync with JPH::RayCastResult
typedef struct JOLT_RayCastResult
{
    JOLT_BodyID     body_id; // JOLT_BODY_ID_INVALID
    float          fraction; // 1.0 + JOLT_FLT_EPSILON
    JOLT_SubShapeID sub_shape_id;
} JOLT_RayCastResult;

// NOTE: Needs to be kept in sync with JPH::RayCastSettings
typedef struct JOLT_RayCastSettings
{
    JOLT_BackFaceMode back_face_mode;
    bool             treat_convex_as_solid;
} JOLT_RayCastSettings;

//--------------------------------------------------------------------------------------------------
//
// Misc functions
//
//--------------------------------------------------------------------------------------------------
 void
JOLT_RegisterDefaultAllocator(void);

 void
JOLT_RegisterCustomAllocator(JOLT_AllocateFunction in_alloc,
                            JOLT_FreeFunction in_free,
                            JOLT_AlignedAllocateFunction in_aligned_alloc,
                            JOLT_AlignedFreeFunction in_aligned_free);
 void
JOLT_CreateFactory(void);

 void
JOLT_DestroyFactory(void);

 void
JOLT_RegisterTypes(void);

 void
JOLT_BodyCreationSettings_SetDefault(JOLT_BodyCreationSettings *out_settings);

 void
JOLT_BodyCreationSettings_Set(JOLT_BodyCreationSettings *out_settings,
                             const JOLT_Shape *in_shape,
                             const JOLT_Real in_position[3],
                             const float in_rotation[4],
                             JOLT_MotionType in_motion_type,
                             JOLT_ObjectLayer in_layer);

//
//--------------------------------------------------------------------------------------------------
//
// JOLT_TempAllocator
//
//--------------------------------------------------------------------------------------------------
JOLT_TempAllocator *JOLT_TempAllocator_Create(uint32_t in_size);
void JOLT_TempAllocator_Destroy(JOLT_TempAllocator *in_allocator);

JOLT_JobSystem * JOLT_JobSystem_Create(uint32_t in_max_jobs, uint32_t in_max_barriers, int in_num_threads);
void JOLT_JobSystem_Destroy(JOLT_JobSystem *in_job_system);


//
//--------------------------------------------------------------------------------------------------
//
// JOLT_BodyInterface
//
//--------------------------------------------------------------------------------------------------
/*
JOLT_Body* JOLT_BodyInterface_CreateBody(JOLT_BodyInterface *in_iface,JOLT_BodyCreationSettings *in_setting);

JOLT_Body* JOLT_BodyInterface_CreateBodyWithID(JOLT_BodyInterface *in_iface,
                                   JOLT_BodyID in_body_id,
                                   const JOLT_BodyCreationSettings *in_settings);

void JOLT_BodyInterface_DestroyBody(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id);
void JOLT_BodyInterface_AddBody(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id, JOLT_Activation in_mode);
void JOLT_BodyInterface_RemoveBody(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id);
JOLT_BodyID JOLT_BodyInterface_CreateAndAddBody(JOLT_BodyInterface *in_iface,const JOLT_BodyCreationSettings *in_settings,JOLT_Activation in_mode);
 void JOLT_BodyInterface_SetLinearVelocity(JOLT_BodyInterface *in_iface,JOLT_BodyID in_body_id,float in_velocity[3]);
 bool JOLT_BodyInterface_IsActive(const JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id);
 void JOLT_BodyInterface_GetCenterOfMassPosition(const JOLT_BodyInterface *in_iface,JOLT_BodyID in_body_id,JOLT_Real out_position[3]);
 void JOLT_BodyInterface_GetLinearVelocity(const JOLT_BodyInterface *in_iface,JOLT_BodyID in_body_id,float out_velocity[3]);
								   */

//--------------------------------------------------------------------------------------------------
//
// JOLT_MotionProperties
//
//--------------------------------------------------------------------------------------------------
 JOLT_MotionQuality
JOLT_MotionProperties_GetMotionQuality(const JOLT_MotionProperties *in_properties);

 void
JOLT_MotionProperties_GetLinearVelocity(const JOLT_MotionProperties *in_properties,
                                       float out_linear_velocity[3]);
 void
JOLT_MotionProperties_SetLinearVelocity(JOLT_MotionProperties *in_properties,
                                       const float in_linear_velocity[3]);
 void
JOLT_MotionProperties_SetLinearVelocityClamped(JOLT_MotionProperties *in_properties,
                                              const float in_linear_velocity[3]);
 void
JOLT_MotionProperties_GetAngularVelocity(const JOLT_MotionProperties *in_properties,
                                        float out_angular_velocity[3]);
 void
JOLT_MotionProperties_SetAngularVelocity(JOLT_MotionProperties *in_properties,
                                        const float in_angular_velocity[3]);
 void
JOLT_MotionProperties_SetAngularVelocityClamped(JOLT_MotionProperties *in_properties,
                                               const float in_angular_velocity[3]);
 void
JOLT_MotionProperties_MoveKinematic(JOLT_MotionProperties *in_properties,
                                   const float in_delta_position[3],
                                   const float in_delta_rotation[4],
                                   float in_delta_time);
 void
JOLT_MotionProperties_ClampLinearVelocity(JOLT_MotionProperties *in_properties);

 void
JOLT_MotionProperties_ClampAngularVelocity(JOLT_MotionProperties *in_properties);

 float
JOLT_MotionProperties_GetLinearDamping(const JOLT_MotionProperties *in_properties);

 void
JOLT_MotionProperties_SetLinearDamping(JOLT_MotionProperties *in_properties,
                                      float in_linear_damping);
 float
JOLT_MotionProperties_GetAngularDamping(const JOLT_MotionProperties *in_properties);

 void
JOLT_MotionProperties_SetAngularDamping(JOLT_MotionProperties *in_properties,
                                       float in_angular_damping);
 float
JOLT_MotionProperties_GetGravityFactor(const JOLT_MotionProperties *in_properties);

 void
JOLT_MotionProperties_SetGravityFactor(JOLT_MotionProperties *in_properties,
                                      float in_gravity_factor);
 void
JOLT_MotionProperties_SetMassProperties(JOLT_MotionProperties *in_properties,
                                       const JOLT_MassProperties *in_mass_properties);
 float
JOLT_MotionProperties_GetInverseMass(const JOLT_MotionProperties *in_properties);

 void
JOLT_MotionProperties_SetInverseMass(JOLT_MotionProperties *in_properties, float in_inv_mass);

 void
JOLT_MotionProperties_GetInverseInertiaDiagonal(const JOLT_MotionProperties *in_properties,
                                               float out_inverse_inertia_diagonal[3]);
 void
JOLT_MotionProperties_GetInertiaRotation(const JOLT_MotionProperties *in_properties,
                                        float out_inertia_rotation[4]);
 void
JOLT_MotionProperties_SetInverseInertia(JOLT_MotionProperties *in_properties,
                                       const float in_diagonal[3],
                                       const float in_rotation[4]);
 void
JOLT_MotionProperties_GetLocalSpaceInverseInertia(const JOLT_MotionProperties *in_properties,
                                                 float out_matrix[16]);
 void
JOLT_MotionProperties_GetInverseInertiaForRotation(const JOLT_MotionProperties *in_properties,
                                                  const float in_rotation_matrix[16],
                                                  float out_matrix[16]);
 void
JOLT_MotionProperties_MultiplyWorldSpaceInverseInertiaByVector(const JOLT_MotionProperties *in_properties,
                                                              const float in_body_rotation[4],
                                                              const float in_vector[3],
                                                              float out_vector[3]);
 void
JOLT_MotionProperties_GetPointVelocityCOM(const JOLT_MotionProperties *in_properties,
                                         const float in_point_relative_to_com[3],
                                         float out_point[3]);
 float
JOLT_MotionProperties_GetMaxLinearVelocity(const JOLT_MotionProperties *in_properties);

 void
JOLT_MotionProperties_SetMaxLinearVelocity(JOLT_MotionProperties *in_properties,
                                          float in_max_linear_velocity);
 float
JOLT_MotionProperties_GetMaxAngularVelocity(const JOLT_MotionProperties *in_properties);

 void
JOLT_MotionProperties_SetMaxAngularVelocity(JOLT_MotionProperties *in_properties,
                                           float in_max_angular_velocity);


//--------------------------------------------------------------------------------------------------
//
// Interfaces (virtual tables)
//
//--------------------------------------------------------------------------------------------------
#if defined(_MSC_VER)
#define _JOLT_VTABLE_HEADER const void* __vtable_header[1]
#else
#define _JOLT_VTABLE_HEADER const void* __vtable_header[2]
#endif

typedef struct JOLT_BroadPhaseLayerInterfaceVTable
{
    // Required, *cannot* be NULL.
    uint32_t(*GetNumBroadPhaseLayers)();

#ifdef _MSC_VER
    // Required, *cannot* be NULL.
    //JOLT_BroadPhaseLayer * (*GetBroadPhaseLayer)(JOLT_BroadPhaseLayer *out_layer, JOLT_ObjectLayer in_layer);
    JOLT_BroadPhaseLayer(*GetBroadPhaseLayer)(JOLT_ObjectLayer in_layer);
#else
    // Required, *cannot* be NULL.
    JOLT_BroadPhaseLayer(*GetBroadPhaseLayer)(JOLT_ObjectLayer in_layer);
#endif
} JOLT_BroadPhaseLayerInterfaceVTable;

typedef struct JOLT_ObjectLayerPairFilterVTable
{
    // Required, *cannot* be NULL.
    bool(*ShouldCollide)(JOLT_ObjectLayer in_layer1, JOLT_ObjectLayer in_layer2);
} JOLT_ObjectLayerPairFilterVTable;

typedef struct JOLT_ContactListenerVTable
{
    // Optional, can be NULL.
    JOLT_ValidateResult
    (*OnContactValidate)(const JOLT_Body *in_body1,
                         const JOLT_Body *in_body2,
                         const JOLT_Real in_base_offset[3],
                         const JOLT_CollideShapeResult *in_collision_result);

    // Optional, can be NULL.
    void
    (*OnContactAdded)(const JOLT_Body *in_body1,
                      const JOLT_Body *in_body2,
                      const JOLT_ContactManifold *in_manifold,
                      JOLT_ContactSettings *io_settings);

    // Optional, can be NULL.
    void
    (*OnContactPersisted)(
                          const JOLT_Body *in_body1,
                          const JOLT_Body *in_body2,
                          const JOLT_ContactManifold *in_manifold,
                          JOLT_ContactSettings *io_settings);

    // Optional, can be NULL.
    void
    (*OnContactRemoved)(const JOLT_SubShapeIDPair *in_sub_shape_pair);
} JOLT_ContactListenerVTable;

typedef struct JOLT_ObjectVsBroadPhaseLayerFilterVTable
{
    // Required, *cannot* be NULL.
    bool (*ShouldCollide)(JOLT_ObjectLayer in_layer1,JOLT_BroadPhaseLayer in_layer2);
} JOLT_ObjectVsBroadPhaseLayerFilterVTable;

// Made all callbacks required for this one for simplicity's sake, but can be modified to imitate ContactListener later.
typedef struct JOLT_CharacterContactListenerVTable
{
    _JOLT_VTABLE_HEADER;

    // Required, *cannot* be NULL.
    void
    (*OnAdjustBodyVelocity)(void *in_self,
                            const JOLT_CharacterVirtual *in_character,
                            const JOLT_Body *in_body2,
                            const float io_linear_velocity[3],
                            const float io_angular_velocity[3]);

    // Required, *cannot* be NULL.
    bool
    (*OnContactValidate)(void *in_self,
                         const JOLT_CharacterVirtual *in_character,
                         const JOLT_Body *in_body2,
                         const JOLT_SubShapeID *sub_shape_id);

    // Required, *cannot* be NULL.
    void
    (*OnContactAdded)(void *in_self,
                      const JOLT_CharacterVirtual *in_character,
                      const JOLT_Body *in_body2,
                      const JOLT_SubShapeID *sub_shape_id,
                      const JOLT_Real contact_position[3],
                      const float contact_normal[3],
                      JOLT_CharacterContactSettings *io_settings);

    // Required, *cannot* be NULL.
    void
    (*OnContactSolve)(void *in_self,
                      const JOLT_CharacterVirtual *in_character,
                      const JOLT_Body *in_body2,
                      const JOLT_SubShapeID *sub_shape_id,
                      const JOLT_Real contact_position[3],
                      const float contact_normal[3],
                      const float contact_velocity[3],
                      const JOLT_PhysicsMaterial *contact_material,
                      const float character_velocity_in[3],
                      float character_velocity_out[3]);
} JOLT_CharacterContactListenerVTable;

typedef struct JOLT_ObjectLayerFilterVTable
{
    _JOLT_VTABLE_HEADER;

    // Required, *cannot* be NULL.
    bool
    (*ShouldCollide)(const void *in_self, JOLT_ObjectLayer in_layer);
} JOLT_ObjectLayerFilterVTable;

typedef struct JOLT_BodyActivationListenerVTable
{
    _JOLT_VTABLE_HEADER;

    // Required, *cannot* be NULL.
    void
    (*OnBodyActivated)(void *in_self, const JOLT_BodyID *in_body_id, uint64_t in_user_data);

    // Required, *cannot* be NULL.
    void
    (*OnBodyDeactivated)(void *in_self, const JOLT_BodyID *in_body_id, uint64_t in_user_data);
} JOLT_BodyActivationListenerVTable;

typedef struct JOLT_BodyFilterVTable
{
    _JOLT_VTABLE_HEADER;

    // Required, *cannot* be NULL.
    bool
    (*ShouldCollide)(const void *in_self, const JOLT_BodyID *in_body_id);

    // Required, *cannot* be NULL.
    bool
    (*ShouldCollideLocked)(const void *in_self, const JOLT_Body *in_body);
} JOLT_BodyFilterVTable;

typedef struct JOLT_ShapeFilterVTable
{
    _JOLT_VTABLE_HEADER;

    // Required, *cannot* be NULL.
    bool
    (*ShouldCollide)(const void *in_self, const JOLT_Shape *in_shape, const JOLT_SubShapeID *in_sub_shape_id);

    // Required, *cannot* be NULL.
    bool
    (*PairShouldCollide)(const void *in_self,
                         const JOLT_Shape *in_shape1,
                         const JOLT_SubShapeID *in_sub_shape_id1,
                         const JOLT_Shape *in_shape2,
                         const JOLT_SubShapeID *in_sub_shape_id2);

    // Set by the collision detection functions to the body ID of the "receiving" body before ShouldCollide is called.
    uint32_t bodyId2;
} JOLT_ShapeFilterVTable;

typedef struct JOLT_PhysicsStepListenerVTable
{
    _JOLT_VTABLE_HEADER;

    // Required, *cannot* be NULL.
    void
    (*OnStep)(float in_delta_time, JOLT_PhysicsSystem *in_physics_system);
} JOLT_PhysicsStepListener;

JOLT_PhysicsSystem * JOLT_PhysicsSystem_Create(uint32_t in_max_bodies,
                         uint32_t in_num_body_mutexes,
                         uint32_t in_max_body_pairs,
                         uint32_t in_max_contact_constraints,
                         JOLT_BroadPhaseLayerInterfaceVTable in_broad_phase_layer_interface,
                         JOLT_ObjectVsBroadPhaseLayerFilterVTable in_object_vs_broad_phase_layer_filter,
						 JOLT_ObjectLayerPairFilterVTable in_object_layer_pair_filter);


void JOLT_SetContactListener(JOLT_PhysicsSystem *in_physics_system,JOLT_ContactListenerVTable*in_listener);

 void
JOLT_PhysicsSystem_SetBodyActivationListener(JOLT_PhysicsSystem *in_physics_system, void *in_listener);

 void *
JOLT_PhysicsSystem_GetBodyActivationListener(const JOLT_PhysicsSystem *in_physics_system);

 void
JOLT_PhysicsSystem_SetContactListener(JOLT_PhysicsSystem *in_physics_system, void *in_listener);

 void *
JOLT_PhysicsSystem_GetContactListener(const JOLT_PhysicsSystem *in_physics_system);

 uint32_t
JOLT_PhysicsSystem_GetNumBodies(const JOLT_PhysicsSystem *in_physics_system);

 uint32_t
JOLT_PhysicsSystem_GetNumActiveBodies(const JOLT_PhysicsSystem *in_physics_system,JOLT_BodyType type);

 uint32_t
JOLT_PhysicsSystem_GetMaxBodies(const JOLT_PhysicsSystem *in_physics_system);

 void
JOLT_PhysicsSystem_GetGravity(const JOLT_PhysicsSystem *in_physics_system, float out_gravity[3]);

 void
JOLT_PhysicsSystem_SetGravity(JOLT_PhysicsSystem *in_physics_system, const float in_gravity[3]);

 JOLT_BodyInterface *
JOLT_PhysicsSystem_GetBodyInterface(JOLT_PhysicsSystem *in_physics_system);

 JOLT_BodyInterface *
JOLT_PhysicsSystem_GetBodyInterfaceNoLock(JOLT_PhysicsSystem *in_physics_system);

 void
JOLT_PhysicsSystem_OptimizeBroadPhase(JOLT_PhysicsSystem *in_physics_system);

 void
JOLT_PhysicsSystem_AddStepListener(JOLT_PhysicsSystem *in_physics_system, void *in_listener);

 void
JOLT_PhysicsSystem_RemoveStepListener(JOLT_PhysicsSystem *in_physics_system, void *in_listener);

 void
JOLT_PhysicsSystem_AddConstraint(JOLT_PhysicsSystem *in_physics_system, void *in_two_body_constraint);

 void
JOLT_PhysicsSystem_RemoveConstraint(JOLT_PhysicsSystem *in_physics_system, void *in_two_body_constraint);

 JOLT_PhysicsUpdateError
JOLT_PhysicsSystem_Update(JOLT_PhysicsSystem *in_physics_system,
                         float in_delta_time,
                         int in_collision_steps,
                         int in_integration_sub_steps,
                         JOLT_TempAllocator *in_temp_allocator,
                         JOLT_JobSystem *in_job_system);

 const JOLT_BodyLockInterface *
JOLT_PhysicsSystem_GetBodyLockInterface(const JOLT_PhysicsSystem *in_physics_system);

 const JOLT_BodyLockInterface *
JOLT_PhysicsSystem_GetBodyLockInterfaceNoLock(const JOLT_PhysicsSystem *in_physics_system);

 const JOLT_NarrowPhaseQuery *
JOLT_PhysicsSystem_GetNarrowPhaseQuery(const JOLT_PhysicsSystem *in_physics_system);

 const JOLT_NarrowPhaseQuery *
JOLT_PhysicsSystem_GetNarrowPhaseQueryNoLock(const JOLT_PhysicsSystem *in_physics_system);

/// Get copy of the list of all bodies under protection of a lock.
 void
JOLT_PhysicsSystem_GetBodyIDs(const JOLT_PhysicsSystem *in_physics_system,
                             uint32_t in_max_body_ids,
                             uint32_t *out_num_body_ids,
                             JOLT_BodyID *out_body_ids);

/// Get copy of the list of active bodies under protection of a lock.
 void
JOLT_PhysicsSystem_GetActiveBodyIDs(const JOLT_PhysicsSystem *in_physics_system,
                                   uint32_t in_max_body_ids,
                                   uint32_t *out_num_body_ids,
                                   JOLT_BodyID *out_body_ids);
///
/// Low-level access for advanced usage and zero CPU overhead (access *not* protected by a lock)
///
/// Check if this is a valid body pointer.
/// When a body is freed the memory that the pointer occupies is reused to store a freelist.
#define _JOLT_IS_FREED_BODY_BIT 0x1

#define JOLT_IS_VALID_BODY_POINTER(body_ptr) (((uintptr_t)(body_ptr) & _JOLT_IS_FREED_BODY_BIT) == 0)

/// Access a body, will return NULL if the body ID is no longer valid.
/// Use `JOLT_PhysicsSystem_GetBodiesUnsafe()` to get an array of all body pointers.
#define JOLT_TRY_GET_BODY(all_body_ptrs, body_id) \
    JOLT_IS_VALID_BODY_POINTER(all_body_ptrs[body_id & JOLT_BODY_ID_INDEX_BITS]) && \
    all_body_ptrs[body_id & JOLT_BODY_ID_INDEX_BITS]->id == body_id ? \
    all_body_ptrs[body_id & JOLT_BODY_ID_INDEX_BITS] : NULL

/// Get direct access to all bodies. Not protected by a lock. Use with great care!
 JOLT_Body **
JOLT_PhysicsSystem_GetBodiesUnsafe(JOLT_PhysicsSystem *in_physics_system);

//--------------------------------------------------------------------------------------------------
//
// JOLT_BodyLockInterface
//
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyLockInterface_LockRead(const JOLT_BodyLockInterface *in_lock_interface,
                               JOLT_BodyID in_body_id,
                               JOLT_BodyLockRead *out_lock);
 void
JOLT_BodyLockInterface_UnlockRead(const JOLT_BodyLockInterface *in_lock_interface,
                                 JOLT_BodyLockRead *io_lock);
 void
JOLT_BodyLockInterface_LockWrite(const JOLT_BodyLockInterface *in_lock_interface,
                                JOLT_BodyID in_body_id,
                                JOLT_BodyLockWrite *out_lock);
 void
JOLT_BodyLockInterface_UnlockWrite(const JOLT_BodyLockInterface *in_lock_interface,
                                  JOLT_BodyLockWrite *io_lock);

//--------------------------------------------------------------------------------------------------
//
// JOLT_NarrowPhaseQuery
//
//--------------------------------------------------------------------------------------------------
 bool
JOLT_NarrowPhaseQuery_CastRay(const JOLT_NarrowPhaseQuery *in_query,
                             const JOLT_RRayCast *in_ray,
                             JOLT_RayCastResult *io_hit, // *Must* be default initialized (see JOLT_RayCastResult)
                             const void *in_broad_phase_layer_filter, // Can be NULL (no filter)
                             const void *in_object_layer_filter, // Can be NULL (no filter)
                             const void *in_body_filter); // Can be NULL (no filter)

//--------------------------------------------------------------------------------------------------
//
// JOLT_Shape
//
//--------------------------------------------------------------------------------------------------
 void
JOLT_Shape_AddRef(JOLT_Shape *in_shape);

 void
JOLT_Shape_Release(JOLT_Shape *in_shape);

 uint32_t
JOLT_Shape_GetRefCount(const JOLT_Shape *in_shape);

 JOLT_ShapeType
JOLT_Shape_GetType(const JOLT_Shape *in_shape);

 JOLT_ShapeSubType
JOLT_Shape_GetSubType(const JOLT_Shape *in_shape);

 uint64_t
JOLT_Shape_GetUserData(const JOLT_Shape *in_shape);

 void
JOLT_Shape_SetUserData(JOLT_Shape *in_shape, uint64_t in_user_data);

 void
JOLT_Shape_GetCenterOfMass(const JOLT_Shape *in_shape, JOLT_Real out_position[3]);
//--------------------------------------------------------------------------------------------------
//
// JOLT_ConstraintSettings
//
//--------------------------------------------------------------------------------------------------
 void
JOLT_ConstraintSettings_AddRef(JOLT_ConstraintSettings *in_settings);

 void
JOLT_ConstraintSettings_Release(JOLT_ConstraintSettings *in_settings);

 uint32_t
JOLT_ConstraintSettings_GetRefCount(const JOLT_ConstraintSettings *in_settings);

 uint64_t
JOLT_ConstraintSettings_GetUserData(const JOLT_ConstraintSettings *in_settings);

 void
JOLT_ConstraintSettings_SetUserData(JOLT_ConstraintSettings *in_settings, uint64_t in_user_data);
//--------------------------------------------------------------------------------------------------
//
// JOLT_TwoBodyConstraintSettings (-> JOLT_ConstraintSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_Constraint *
JOLT_TwoBodyConstraintSettings_CreateConstraint(const JOLT_TwoBodyConstraintSettings *in_settings,
                                               JOLT_Body *in_body1,
                                               JOLT_Body *in_body2);
//--------------------------------------------------------------------------------------------------
//
// JOLT_FixedConstraintSettings (-> JOLT_TwoBodyConstraintSettings -> JOLT_ConstraintSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_FixedConstraintSettings *
JOLT_FixedConstraintSettings_Create();

 void
JOLT_FixedConstraintSettings_SetSpace(JOLT_FixedConstraintSettings *in_settings, JOLT_ConstraintSpace in_space);

 void
JOLT_FixedConstraintSettings_SetAutoDetectPoint(JOLT_FixedConstraintSettings *in_settings, bool in_enabled);
//--------------------------------------------------------------------------------------------------
//
// JOLT_Constraint
//
//--------------------------------------------------------------------------------------------------
 void
JOLT_Constraint_AddRef(JOLT_Constraint *in_shape);

 void
JOLT_Constraint_Release(JOLT_Constraint *in_shape);

 uint32_t
JOLT_Constraint_GetRefCount(const JOLT_Constraint *in_shape);

 JOLT_ConstraintType
JOLT_Constraint_GetType(const JOLT_Constraint *in_shape);

 JOLT_ConstraintSubType
JOLT_Constraint_GetSubType(const JOLT_Constraint *in_shape);

 uint64_t
JOLT_Constraint_GetUserData(const JOLT_Constraint *in_shape);

 void
JOLT_Constraint_SetUserData(JOLT_Constraint *in_shape, uint64_t in_user_data);
//--------------------------------------------------------------------------------------------------
//
// JOLT_BodyInterface
//
//--------------------------------------------------------------------------------------------------
 JOLT_Body *
JOLT_BodyInterface_CreateBody(JOLT_BodyInterface *in_iface,JOLT_BodyCreationSettings *in_setting);

 JOLT_Body *
JOLT_BodyInterface_CreateBodyWithID(JOLT_BodyInterface *in_iface,
                                   JOLT_BodyID in_body_id,
                                   const JOLT_BodyCreationSettings *in_settings);

 void
JOLT_BodyInterface_DestroyBody(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id);

 void
JOLT_BodyInterface_AddBody(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id, JOLT_Activation in_mode);

 void
JOLT_BodyInterface_RemoveBody(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id);

 JOLT_BodyID
JOLT_BodyInterface_CreateAndAddBody(JOLT_BodyInterface *in_iface,
                                   const JOLT_BodyCreationSettings *in_settings,
                                   JOLT_Activation in_mode);
 bool
JOLT_BodyInterface_IsAdded(const JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id);

 void
JOLT_BodyInterface_SetLinearAndAngularVelocity(JOLT_BodyInterface *in_iface,
                                              JOLT_BodyID in_body_id,
                                              const float in_linear_velocity[3],
                                              const float in_angular_velocity[3]);
 void
JOLT_BodyInterface_GetLinearAndAngularVelocity(const JOLT_BodyInterface *in_iface,
                                              JOLT_BodyID in_body_id,
                                              float out_linear_velocity[3],
                                              float out_angular_velocity[3]);
 void
JOLT_BodyInterface_SetLinearVelocity(JOLT_BodyInterface *in_iface,
                                    JOLT_BodyID in_body_id,
                                    const float in_velocity[3]);
 void
JOLT_BodyInterface_GetLinearVelocity(const JOLT_BodyInterface *in_iface,
                                    JOLT_BodyID in_body_id,
                                    float out_velocity[3]);
 void
JOLT_BodyInterface_AddLinearVelocity(JOLT_BodyInterface *in_iface,
                                    JOLT_BodyID in_body_id,
                                    const float in_velocity[3]);
 void
JOLT_BodyInterface_AddLinearAndAngularVelocity(JOLT_BodyInterface *in_iface,
                                              JOLT_BodyID in_body_id,
                                              const float in_linear_velocity[3],
                                              const float in_angular_velocity[3]);
 void
JOLT_BodyInterface_SetAngularVelocity(JOLT_BodyInterface *in_iface,
                                     JOLT_BodyID in_body_id,
                                     const float in_velocity[3]);
 void
JOLT_BodyInterface_GetAngularVelocity(const JOLT_BodyInterface *in_iface,
                                     JOLT_BodyID in_body_id,
                                     float out_velocity[3]);
 void
JOLT_BodyInterface_GetPointVelocity(const JOLT_BodyInterface *in_iface,
                                   JOLT_BodyID in_body_id,
                                   const JOLT_Real in_point[3],
                                   float out_velocity[3]);
 void
JOLT_BodyInterface_GetPosition(const JOLT_BodyInterface *in_iface,
                              JOLT_BodyID in_body_id,
                              JOLT_Real out_position[3]);
 void
JOLT_BodyInterface_SetPosition(JOLT_BodyInterface *in_iface,
                              JOLT_BodyID in_body_id,
                              const JOLT_Real in_position[3],
                              JOLT_Activation in_activation);
 void
JOLT_BodyInterface_GetCenterOfMassPosition(const JOLT_BodyInterface *in_iface,
                                          JOLT_BodyID in_body_id,
                                          JOLT_Real out_position[3]);
 void
JOLT_BodyInterface_GetRotation(const JOLT_BodyInterface *in_iface,
                              JOLT_BodyID in_body_id,
                              float out_rotation[4]);
 void
JOLT_BodyInterface_SetRotation(JOLT_BodyInterface *in_iface,
                              JOLT_BodyID in_body_id,
                              const JOLT_Real in_rotation[4],
                              JOLT_Activation in_activation);
 void
JOLT_BodyInterface_ActivateBody(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id);

 void
JOLT_BodyInterface_DeactivateBody(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id);

 bool
JOLT_BodyInterface_IsActive(const JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id);

 void
JOLT_BodyInterface_SetPositionRotationAndVelocity(JOLT_BodyInterface *in_iface,
                                                 JOLT_BodyID in_body_id,
                                                 const JOLT_Real in_position[3],
                                                 const float in_rotation[4],
                                                 const float in_linear_velocity[3],
                                                 const float in_angular_velocity[3]);
 void
JOLT_BodyInterface_AddForce(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id, const float in_force[3]);

 void
JOLT_BodyInterface_AddForceAtPosition(JOLT_BodyInterface *in_iface,
                                     JOLT_BodyID in_body_id,
                                     const float in_force[3],
                                     const JOLT_Real in_position[3]);
 void
JOLT_BodyInterface_AddTorque(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id, const float in_torque[3]);

 void
JOLT_BodyInterface_AddForceAndTorque(JOLT_BodyInterface *in_iface,
                                    JOLT_BodyID in_body_id,
                                    const float in_force[3],
                                    const float in_torque[3]);
 void
JOLT_BodyInterface_AddImpulse(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id, const float in_impulse[3]);

 void
JOLT_BodyInterface_AddImpulseAtPosition(JOLT_BodyInterface *in_iface,
                                       JOLT_BodyID in_body_id,
                                       const float in_impulse[3],
                                       const JOLT_Real in_position[3]);
 void
JOLT_BodyInterface_AddAngularImpulse(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id, const float in_impulse[3]);

 JOLT_MotionType 
JOLT_BodyInterface_GetMotionType(const JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id);

 void
JOLT_BodyInterface_SetMotionType(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id, JOLT_MotionType motion_type, JOLT_Activation activation);

 JOLT_ObjectLayer
JOLT_BodyInterface_GetObjectLayer(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id);

 void
JOLT_BodyInterface_SetObjectLayer(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id, JOLT_ObjectLayer in_layer);
//--------------------------------------------------------------------------------------------------
//
// JOLT_Body
//
//--------------------------------------------------------------------------------------------------
 JOLT_BodyID
JOLT_Body_GetID(const JOLT_Body *in_body);

 bool
JOLT_Body_IsActive(const JOLT_Body *in_body);

 bool
JOLT_Body_IsStatic(const JOLT_Body *in_body);

 bool
JOLT_Body_IsKinematic(const JOLT_Body *in_body);

 bool
JOLT_Body_IsDynamic(const JOLT_Body *in_body);

 bool
JOLT_Body_CanBeKinematicOrDynamic(const JOLT_Body *in_body);

 void
JOLT_Body_SetIsSensor(JOLT_Body *in_body, bool in_is_sensor);

 bool
JOLT_Body_IsSensor(const JOLT_Body *in_body);

 JOLT_MotionType
JOLT_Body_GetMotionType(const JOLT_Body *in_body);

 void
JOLT_Body_SetMotionType(JOLT_Body *in_body, JOLT_MotionType in_motion_type);

 JOLT_BroadPhaseLayer
JOLT_Body_GetBroadPhaseLayer(const JOLT_Body *in_body);

 JOLT_ObjectLayer
JOLT_Body_GetObjectLayer(const JOLT_Body *in_body);

 JOLT_CollisionGroup *
JOLT_Body_GetCollisionGroup(JOLT_Body *in_body);

 void
JOLT_Body_SetCollisionGroup(JOLT_Body *in_body, const JOLT_CollisionGroup *in_group);

 bool
JOLT_Body_GetAllowSleeping(const JOLT_Body *in_body);

 void
JOLT_Body_SetAllowSleeping(JOLT_Body *in_body, bool in_allow_sleeping);

 float
JOLT_Body_GetFriction(const JOLT_Body *in_body);

 void
JOLT_Body_SetFriction(JOLT_Body *in_body, float in_friction);

 float
JOLT_Body_GetRestitution(const JOLT_Body *in_body);

 void
JOLT_Body_SetRestitution(JOLT_Body *in_body, float in_restitution);

 void
JOLT_Body_GetLinearVelocity(const JOLT_Body *in_body, float out_linear_velocity[3]);

 void
JOLT_Body_SetLinearVelocity(JOLT_Body *in_body, const float in_linear_velocity[3]);

 void
JOLT_Body_SetLinearVelocityClamped(JOLT_Body *in_body, const float in_linear_velocity[3]);

 void
JOLT_Body_GetAngularVelocity(const JOLT_Body *in_body, float out_angular_velocity[3]);

 void
JOLT_Body_SetAngularVelocity(JOLT_Body *in_body, const float in_angular_velocity[3]);

 void
JOLT_Body_SetAngularVelocityClamped(JOLT_Body *in_body, const float in_angular_velocity[3]);

 void
JOLT_Body_GetPointVelocityCOM(const JOLT_Body *in_body,
                             const float in_point_relative_to_com[3],
                             float out_velocity[3]);
 void
JOLT_Body_GetPointVelocity(const JOLT_Body *in_body, const JOLT_Real in_point[3], float out_velocity[3]);

 void
JOLT_Body_AddForce(JOLT_Body *in_body, const float in_force[3]);

 void
JOLT_Body_AddForceAtPosition(JOLT_Body *in_body, const float in_force[3], const JOLT_Real in_position[3]);

 void
JOLT_Body_AddTorque(JOLT_Body *in_body, const float in_torque[3]);

 void
JOLT_Body_GetInverseInertia(const JOLT_Body *in_body, float out_inverse_inertia[16]);

 void
JOLT_Body_AddImpulse(JOLT_Body *in_body, const float in_impulse[3]);

 void
JOLT_Body_AddImpulseAtPosition(JOLT_Body *in_body, const float in_impulse[3], const JOLT_Real in_position[3]);

 void
JOLT_Body_AddAngularImpulse(JOLT_Body *in_body, const float in_angular_impulse[3]);

 void
JOLT_Body_MoveKinematic(JOLT_Body *in_body,
                       const JOLT_Real in_target_position[3],
                       const float in_target_rotation[4],
                       float in_delta_time);
 void
JOLT_Body_ApplyBuoyancyImpulse(JOLT_Body *in_body,
                              const JOLT_Real in_surface_position[3],
                              const float in_surface_normal[3],
                              float in_buoyancy,
                              float in_linear_drag,
                              float in_angular_drag,
                              const float in_fluid_velocity[3],
                              const float in_gravity[3],
                              float in_delta_time);
 bool
JOLT_Body_IsInBroadPhase(const JOLT_Body *in_body);

 bool
JOLT_Body_IsCollisionCacheInvalid(const JOLT_Body *in_body);

 const JOLT_Shape *
JOLT_Body_GetShape(const JOLT_Body *in_body);

 void
JOLT_Body_GetPosition(const JOLT_Body *in_body, JOLT_Real out_position[3]);

 void
JOLT_Body_GetRotation(const JOLT_Body *in_body, float out_rotation[4]);

 void
JOLT_Body_GetWorldTransform(const JOLT_Body *in_body, float out_rotation[9], JOLT_Real out_translation[3]);

 void
JOLT_Body_GetCenterOfMassPosition(const JOLT_Body *in_body, JOLT_Real out_position[3]);

 void
JOLT_Body_GetCenterOfMassTransform(const JOLT_Body *in_body,
                                  float out_rotation[9],
                                  JOLT_Real out_translation[3]);
 void
JOLT_Body_GetInverseCenterOfMassTransform(const JOLT_Body *in_body,
                                         float out_rotation[9],
                                         JOLT_Real out_translation[3]);
 void
JOLT_Body_GetWorldSpaceBounds(const JOLT_Body *in_body, float out_min[3], float out_max[3]);

 JOLT_MotionProperties *
JOLT_Body_GetMotionProperties(JOLT_Body *in_body);

 uint64_t
JOLT_Body_GetUserData(const JOLT_Body *in_body);

 void
JOLT_Body_SetUserData(JOLT_Body *in_body, uint64_t in_user_data);

 void
JOLT_Body_GetWorldSpaceSurfaceNormal(const JOLT_Body *in_body,
                                    JOLT_SubShapeID in_sub_shape_id,
                                    const JOLT_Real in_position[3], // world space
                                    float out_normal_vector[3]);
//--------------------------------------------------------------------------------------------------
//
// JOLT_BodyID
//
//--------------------------------------------------------------------------------------------------
 uint32_t
JOLT_BodyID_GetIndex(JOLT_BodyID in_body_id);

 uint8_t
JOLT_BodyID_GetSequenceNumber(JOLT_BodyID in_body_id);

 bool
JOLT_BodyID_IsInvalid(JOLT_BodyID in_body_id);
//--------------------------------------------------------------------------------------------------
//
// JOLT_CharacterSettings
//
//--------------------------------------------------------------------------------------------------
 JOLT_CharacterSettings *
JOLT_CharacterSettings_Create();

 void
JOLT_CharacterSettings_Release(JOLT_CharacterSettings *in_settings);

 void
JOLT_CharacterSettings_AddRef(JOLT_CharacterSettings *in_settings);
//--------------------------------------------------------------------------------------------------
//
// JOLT_Character
//
//--------------------------------------------------------------------------------------------------
 JOLT_Character *
JOLT_Character_Create(const JOLT_CharacterSettings *in_settings,
                     const JOLT_Real in_position[3],
                     const float in_rotation[4],
                     uint64_t in_user_data,
                     JOLT_PhysicsSystem *in_physics_system);

 void
JOLT_Character_Destroy(JOLT_Character *in_character);

 void
JOLT_Character_AddToPhysicsSystem(JOLT_Character *in_character, JOLT_Activation in_activation, bool in_lock_bodies);

 void
JOLT_Character_RemoveFromPhysicsSystem(JOLT_Character *in_character, bool in_lock_bodies);

 void
JOLT_Character_GetPosition(const JOLT_Character *in_character, JOLT_Real out_position[3]);

 void
JOLT_Character_SetPosition(JOLT_Character *in_character, const JOLT_Real in_position[3]);

 void
JOLT_Character_GetLinearVelocity(const JOLT_Character *in_character, float out_linear_velocity[3]);

 void
JOLT_Character_SetLinearVelocity(JOLT_Character *in_character, const float in_linear_velocity[3]);
//--------------------------------------------------------------------------------------------------
//
// JOLT_CharacterVirtualSettings
//
//--------------------------------------------------------------------------------------------------
 JOLT_CharacterVirtualSettings *
JOLT_CharacterVirtualSettings_Create();

 void
JOLT_CharacterVirtualSettings_Release(JOLT_CharacterVirtualSettings *in_settings);
//--------------------------------------------------------------------------------------------------
//
// JOLT_CharacterVirtual
//
//--------------------------------------------------------------------------------------------------
 JOLT_CharacterVirtual *
JOLT_CharacterVirtual_Create(const JOLT_CharacterVirtualSettings *in_settings,
                            const JOLT_Real in_position[3],
                            const float in_rotation[4],
                            JOLT_PhysicsSystem *in_physics_system);

 void
JOLT_CharacterVirtual_Destroy(JOLT_CharacterVirtual *in_character);

 void
JOLT_CharacterVirtual_Update(JOLT_CharacterVirtual *in_character,
                            float in_delta_time,
                            const float in_gravity[3],
                            const void *in_broad_phase_layer_filter,
                            const void *in_object_layer_filter,
                            const void *in_body_filter,
                            const void *in_shape_filter,
                            JOLT_TempAllocator *in_temp_allocator);

 void
JOLT_CharacterVirtual_SetListener(JOLT_CharacterVirtual *in_character, void *in_listener);

 void
JOLT_CharacterVirtual_UpdateGroundVelocity(JOLT_CharacterVirtual *in_character);

 void
JOLT_CharacterVirtual_GetGroundVelocity(const JOLT_CharacterVirtual *in_character, float out_ground_velocity[3]);

 JOLT_CharacterGroundState
JOLT_CharacterVirtual_GetGroundState(JOLT_CharacterVirtual *in_character);

 void
JOLT_CharacterVirtual_GetPosition(const JOLT_CharacterVirtual *in_character, JOLT_Real out_position[3]);

 void
JOLT_CharacterVirtual_SetPosition(JOLT_CharacterVirtual *in_character, const JOLT_Real in_position[3]);

 void
JOLT_CharacterVirtual_GetRotation(const JOLT_CharacterVirtual *in_character, float out_rotation[4]);

 void
JOLT_CharacterVirtual_SetRotation(JOLT_CharacterVirtual *in_character, const float in_rotation[4]);

 void
JOLT_CharacterVirtual_GetLinearVelocity(const JOLT_CharacterVirtual *in_character, float out_linear_velocity[3]);

 void
JOLT_CharacterVirtual_SetLinearVelocity(JOLT_CharacterVirtual *in_character, const float in_linear_velocity[3]);


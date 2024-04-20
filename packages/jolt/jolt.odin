package jolt
import "core:c"

when ODIN_OS == .Windows {
	foreign import Jolt {
		"system:Kernel32.lib",
		"system:Gdi32.lib",
		"build/jolt_bind.lib",
	}
} else when ODIN_OS == .Linux {
	@(extra_linker_flags="-lstdc++")
	foreign import Jolt {
		"build/jolt_bind.a",
	}
}else when ODIN_OS == .Darwin{
	@(extra_linker_flags="-lstdc++")
	foreign import Jolt {
		"build/jolt_bind.a",
	}
}

BodyType :: enum {
	JPH_BodyType_Rigid = 0,
	JPH_BodyType_Soft = 1,
	JPH_BodyType_Count,
	JPH_BodyType_Force32 = 0x7fffffff,
}

ConstraintType :: enum {
	CONSTRAINT_TYPE_CONSTRAINT = 0,
	CONSTRAINT_TYPE_TWO_BODY_CONSTRAINT = 1,
	CONSTRAINT_TYPE_FORCEU32 = 0x7fffffff,
}

ConstraintSubType :: enum {
	CONSTRAINT_SUB_TYPE_FIXED = 0,
	CONSTRAINT_SUB_TYPE_POINT = 1,
	CONSTRAINT_SUB_TYPE_HINGE = 2,
	CONSTRAINT_SUB_TYPE_SLIDER = 3,
	CONSTRAINT_SUB_TYPE_DISTANCE = 4,
	CONSTRAINT_SUB_TYPE_CONE = 5,
	CONSTRAINT_SUB_TYPE_SWING_TWIST = 6,
	CONSTRAINT_SUB_TYPE_SIX_DOF = 7,
	CONSTRAINT_SUB_TYPE_PATH = 8,
	CONSTRAINT_SUB_TYPE_VEHICLE = 9,
	CONSTRAINT_SUB_TYPE_RACK_AND_PINION = 10,
	CONSTRAINT_SUB_TYPE_GEAR = 11,
	CONSTRAINT_SUB_TYPE_PULLEY = 12,
	CONSTRAINT_SUB_TYPE_USER1 = 13,
	CONSTRAINT_SUB_TYPE_USER2 = 14,
	CONSTRAINT_SUB_TYPE_USER3 = 15,
	CONSTRAINT_SUB_TYPE_USER4 = 16,
	CONSTRAINT_SUB_TYPE_FORCEU32 = 0x7fffffff,
}

ConstraintSpace :: enum {
	CONSTRAINT_SPACE_LOCAL_TO_BODY_COM = 0,
	CONSTRAINT_SPACE_WORLD_SPACE = 1,
	CONSTRAINT_SPACE_FORCEU32 = 0x7fffffff,
}

Activation :: enum {
	ACTIVATION_ACTIVATE = 0,
	ACTIVATION_DONT_ACTIVATE = 1,
	ACTIVATION_FORCEU32 = 0x7fffffff,
}

CharacterGroundState :: enum {
	CHARACTER_GROUND_STATE_ON_GROUND = 0,
	CHARACTER_GROUND_STATE_ON_STEEP_GROUND = 1,
	CHARACTER_GROUND_STATE_NOT_SUPPORTED = 2,
	CHARACTER_GROUND_STATE_IN_AIR = 3,
	CHARACTER_GROUND_FORCEU32 = 0x7fffffff,
}

ValidateResult :: enum {
	VALIDATE_RESULT_ACCEPT_ALL_CONTACTS = 0,
	VALIDATE_RESULT_ACCEPT_CONTACT = 1,
	VALIDATE_RESULT_REJECT_CONTACT = 2,
	VALIDATE_RESULT_REJECT_ALL_CONTACTS = 3,
	VALIDATE_RESULT_FORCEU32 = 0x7fffffff,
}

ShapeType :: enum c.uint8_t {
	SHAPE_TYPE_CONVEX = 0,
	SHAPE_TYPE_COMPOUND = 1,
	SHAPE_TYPE_DECORATED = 2,
	SHAPE_TYPE_MESH = 3,
	SHAPE_TYPE_HEIGHT_FIELD = 4,
	SHAPE_TYPE_USER1 = 5,
	SHAPE_TYPE_USER2 = 6,
	SHAPE_TYPE_USER3 = 7,
	SHAPE_TYPE_USER4 = 8,
}
ShapeSubType :: enum c.uint8_t {
	SHAPE_SUB_TYPE_SPHERE = 0,
	SHAPE_SUB_TYPE_BOX = 1,
	SHAPE_SUB_TYPE_TRIANGLE = 2,
	SHAPE_SUB_TYPE_CAPSULE = 3,
	SHAPE_SUB_TYPE_TAPERED_CAPSULE = 4,
	SHAPE_SUB_TYPE_CYLINDER = 5,
	SHAPE_SUB_TYPE_CONVEX_HULL = 6,
	SHAPE_SUB_TYPE_STATIC_COMPOUND = 7,
	SHAPE_SUB_TYPE_MUTABLE_COMPOUND = 8,
	SHAPE_SUB_TYPE_ROTATED_TRANSLATED = 9,
	SHAPE_SUB_TYPE_SCALED = 10,
	SHAPE_SUB_TYPE_OFFSET_CENTER_OF_MASS = 11,
	SHAPE_SUB_TYPE_MESH = 12,
	SHAPE_SUB_TYPE_HEIGHT_FIELD = 13,
	SHAPE_SUB_TYPE_USER1 = 14,
	SHAPE_SUB_TYPE_USER2 = 15,
	SHAPE_SUB_TYPE_USER3 = 16,
	SHAPE_SUB_TYPE_USER4 = 17,
	SHAPE_SUB_TYPE_USER5 = 18,
	SHAPE_SUB_TYPE_USER6 = 19,
	SHAPE_SUB_TYPE_USER7 = 20,
	SHAPE_SUB_TYPE_USER8 = 21,
	SHAPE_SUB_TYPE_USER_CONVEX1 = 22,
	SHAPE_SUB_TYPE_USER_CONVEX2 = 23,
	SHAPE_SUB_TYPE_USER_CONVEX3 = 24,
	SHAPE_SUB_TYPE_USER_CONVEX4 = 25,
	SHAPE_SUB_TYPE_USER_CONVEX5 = 26,
	SHAPE_SUB_TYPE_USER_CONVEX6 = 27,
	SHAPE_SUB_TYPE_USER_CONVEX7 = 28,
	SHAPE_SUB_TYPE_USER_CONVEX8 = 29,
}
AllowedDOFs :: enum c.uint8_t {
	AllowedDOFs_All = 0b111111,
	AllowedDOFs_TranslationX = 0b000001,
	AllowedDOFs_TranslationY = 0b000010,
	AllowedDOFs_TranslationZ = 0b000100,
	AllowedDOFs_RotationX = 0b001000,
	AllowedDOFs_RotationY = 0b010000,
	AllowedDOFs_RotationZ = 0b100000,
	AllowedDOFs_Plane2D = 0b100011,
	AllowedDOFs_Count,
	AllowedDOFs_Force32 = 0x7F,
}
MotionQuality :: enum c.uint8_t {
	MOTION_QUALITY_DISCRETE = 0,
	MOTION_QUALITY_LINEAR_CAST = 1,
}
MotionType :: enum c.uint8_t {
	MOTION_TYPE_STATIC = 0,
	MOTION_TYPE_KINEMATIC = 1,
	MOTION_TYPE_DYNAMIC = 2,
}
PhysicsUpdateError :: enum c.uint8_t {
	PHYSICS_UPDATE_ERROR_NO_ERROR = 0,
	PHYSICS_UPDATE_ERROR_MANIFOLD_CACHE_FULL = 1,
	PHYSICS_UPDATE_ERROR_BODY_PAIR_CACHE_FULL = 1,
	PHYSICS_UPDATE_ERROR_CONTACT_CONSTRAINTS_FULL = 1,
}
OverrideMassProperties :: enum c.uint8_t {
	OVERRIDE_MASS_PROPERTIES_CALC_MASS_INERTIA = 0,
	OVERRIDE_MASS_PROPERTIES_CALC_INERTIA = 1,
	OVERRIDE_MASS_PROPERTIES_MASS_INERTIA_PROVIDED = 2,
}
BackFaceMode :: enum c.uint8_t {
	BACK_FACE_MODE_IGNORE = 0,
	BACK_FACE_MODE_COLLIDE = 1,
}
MotionProperties :: struct {
	linear_velocity: [4]c.float,
	angular_velocity: [4]c.float,
	inv_inertia_diagonal: [4]c.float,
	inertia_rotation: [4]c.float,
	force: [3]c.float,
	torque: [3]c.float,
	inv_mass: c.float,
	linear_damping: c.float,
	angular_damping: c.float,
	max_linear_velocity: c.float,
	max_angular_velocity: c.float,
	gravity_factor: c.float,
	index_in_active_bodies: c.uint32_t,
	island_index: c.uint32_t,
	motion_quality: MotionQuality,
	allow_sleeping: bool,
	reserved: [52]c.uint8_t,
}

CollisionGroup :: struct {
	filter: ^GroupFilter,

	group_id: CollisionGroupID,
	sub_group_id: CollisionSubGroupID,
}

Body :: struct {
	position: [4]c.float,
	rotation: [4]c.float,
	bounds_min: [4]c.float,
	bounds_max: [4]c.float,
	shape: ^Shape,

	motion_properties: ^MotionProperties,

	user_data: c.uint64_t,
	collision_group: CollisionGroup,
	friction: c.float,
	restitution: c.float,
	id: BodyID,
	object_layer: ObjectLayer,
	broad_phase_layer: BroadPhaseLayer,
	motion_type: MotionType,
	flags: c.uint8_t,
}

MassProperties :: struct {
	mass: c.float,
	inertia: [16]c.float,
}

BodyCreationSettings :: struct {
	position: [4]c.float,
	rotation: [4]c.float,
	linear_velocity: [4]c.float,
	angular_velocity: [4]c.float,
	user_data: c.uint64_t,
	object_layer: ObjectLayer,
	collision_group: CollisionGroup,
	motion_type: MotionType,
	allowed_dofs: AllowedDOFs,
	allow_dynamic_or_kinematic: bool,
	is_sensor: bool,
	mCollideKinematicVsNonDynamic: bool,
	use_manifold_reduction: bool,
	apply_gyroscopic_force: bool,
	motion_quality: MotionQuality,
	allow_sleeping: bool,
	friction: c.float,
	restitution: c.float,
	linear_damping: c.float,
	angular_damping: c.float,
	max_linear_velocity: c.float,
	max_angular_velocity: c.float,
	gravity_factor: c.float,
	mNumVelocityStepsOverride: c.uint32_t,
	mNumPositionStepsOverride: c.uint32_t,
	override_mass_properties: OverrideMassProperties,
	inertia_multiplier: c.float,
	mass_properties_override: MassProperties,
	shape: ^ShapeSettings,

	shapePtr: ^Shape,

}

CharacterBaseSettings :: struct {
	__vtable_header: [2]rawptr,
	up: [4]c.float,
	supporting_volume: [4]c.float,
	max_slope_angle: c.float,
	shape: ^Shape,

}

CharacterSettings :: struct {
	base: CharacterBaseSettings,
	layer: ObjectLayer,
	mass: c.float,
	friction: c.float,
	gravity_factor: c.float,
}

CharacterVirtualSettings :: struct {
	base: CharacterBaseSettings,
	mass: c.float,
	max_strength: c.float,
	shape_offset: [4]c.float,
	back_face_mode: BackFaceMode,
	predictive_contact_distance: c.float,
	max_collision_iterations: c.uint32_t,
	max_constraint_iterations: c.uint32_t,
	min_time_remaining: c.float,
	collision_tolerance: c.float,
	character_padding: c.float,
	max_num_hits: c.uint32_t,
	hit_reduction_cos_max_angle: c.float,
	penetration_recovery_speed: c.float,
}

SubShapeIDCreator :: struct {
	id: SubShapeID,
	current_bit: c.uint32_t,
}

SubShapeIDPair :: struct {

	first: struct {
		body_id: BodyID,
		sub_shape_id: SubShapeID,
	},

	second: struct {
		body_id: BodyID,
		sub_shape_id: SubShapeID,
	},
}

ContactManifold :: struct {
	base_offset: [4]c.float,
	normal: [4]c.float,
	penetration_depth: c.float,
	shape1_sub_shape_id: SubShapeID,
	shape2_sub_shape_id: SubShapeID,

	shape1_relative_contact: struct {
		num_points: c.uint32_t,
		points: [64][4]c.float,

	},

	shape2_relative_contact: struct {
		num_points: c.uint32_t,
		points: [64][4]c.float,

	},
}

ContactSettings :: struct {
	combined_friction: c.float,
	combined_restitution: c.float,
	is_sensor: bool,
}

CollideShapeResult :: struct {
	shape1_contact_point: [4]c.float,
	shape2_contact_point: [4]c.float,
	penetration_axis: [4]c.float,
	penetration_depth: c.float,
	shape1_sub_shape_id: SubShapeID,
	shape2_sub_shape_id: SubShapeID,
	body2_id: BodyID,

	shape1_face: struct {
		num_points: c.uint32_t,
		points: [32][4]c.float,

	},

	shape2_face: struct {
		num_points: c.uint32_t,
		points: [32][4]c.float,

	},
}

TransformedShape :: struct {
	shape_position_com: [4]c.float,
	shape_rotation: [4]c.float,
	shape: ^Shape,

	shape_scale: [3]c.float,
	body_id: BodyID,
	sub_shape_id_creator: SubShapeIDCreator,
}

BodyLockRead :: struct {
	lock_interface: ^BodyLockInterface,

	mutex: ^SharedMutex,

	body: ^Body,

}

BodyLockWrite :: struct {
	lock_interface: ^BodyLockInterface,

	mutex: ^SharedMutex,

	body: ^Body,

}

RRayCast :: struct {
	origin: [4]c.float,
	direction: [4]c.float,
}

RayCastResult :: struct {
	body_id: BodyID,
	fraction: c.float,
	sub_shape_id: SubShapeID,
}

RayCastSettings :: struct {
	back_face_mode: BackFaceMode,
	treat_convex_as_solid: bool,
}

BroadPhaseLayerInterfaceVTable :: struct {
	GetNumBroadPhaseLayers: proc "c" () -> c.uint32_t,
	GetBroadPhaseLayer: proc "c" (in_layer:ObjectLayer) -> BroadPhaseLayer,
}

ObjectLayerPairFilterVTable :: struct {
	ShouldCollide: proc "c" (in_layer1:ObjectLayer, in_layer2:ObjectLayer) -> bool,
}

ContactListenerVTable :: struct {
	OnContactValidate: proc "c" (#by_ptr in_body1: Body, #by_ptr in_body2: Body, in_base_offset:[3]c.float, #by_ptr in_collision_result: CollideShapeResult) -> ValidateResult,
	OnContactAdded: proc "c" (#by_ptr in_body1: Body, #by_ptr in_body2: Body, #by_ptr in_manifold: ContactManifold, io_settings: ^ContactSettings),
	OnContactPersisted: proc "c" (#by_ptr in_body1: Body, #by_ptr in_body2: Body, #by_ptr in_manifold: ContactManifold, io_settings: ^ContactSettings),
	OnContactRemoved: proc "c" (#by_ptr in_sub_shape_pair: SubShapeIDPair),
}

ObjectVsBroadPhaseLayerFilterVTable :: struct {
	ShouldCollide: proc "c" (in_layer1:ObjectLayer, in_layer2:BroadPhaseLayer) -> bool,
}

CharacterContactListenerVTable :: struct {
	__vtable_header: [2]rawptr,
	OnAdjustBodyVelocity: proc "c" (in_self:rawptr, #by_ptr in_character: CharacterVirtual, #by_ptr in_body2: Body, io_linear_velocity:[3]c.float, io_angular_velocity:[3]c.float),
	OnContactValidate: proc "c" (in_self:rawptr, #by_ptr in_character: CharacterVirtual, #by_ptr in_body2: Body, #by_ptr sub_shape_id: SubShapeID) -> bool,
	OnContactAdded: proc "c" (in_self:rawptr, #by_ptr in_character: CharacterVirtual, #by_ptr in_body2: Body, #by_ptr sub_shape_id: SubShapeID, contact_position:[3]c.float, contact_normal:[3]c.float, io_settings: ^CharacterContactSettings),
	OnContactSolve: proc "c" (in_self:rawptr, #by_ptr in_character: CharacterVirtual, #by_ptr in_body2: Body, #by_ptr sub_shape_id: SubShapeID, contact_position:[3]c.float, contact_normal:[3]c.float, contact_velocity:[3]c.float, #by_ptr contact_material: PhysicsMaterial, character_velocity_in:[3]c.float, character_velocity_out:[3]c.float),
}

ObjectLayerFilterVTable :: struct {
	__vtable_header: [2]rawptr,
	ShouldCollide: proc "c" (in_self:rawptr, in_layer:ObjectLayer) -> bool,
}

BodyActivationListenerVTable :: struct {
	__vtable_header: [2]rawptr,
	OnBodyActivated: proc "c" (in_self:rawptr, #by_ptr in_body_id: BodyID, in_user_data:c.uint64_t),
	OnBodyDeactivated: proc "c" (in_self:rawptr, #by_ptr in_body_id: BodyID, in_user_data:c.uint64_t),
}

BodyFilterVTable :: struct {
	__vtable_header: [2]rawptr,
	ShouldCollide: proc "c" (in_self:rawptr, #by_ptr in_body_id: BodyID) -> bool,
	ShouldCollideLocked: proc "c" (in_self:rawptr, #by_ptr in_body: Body) -> bool,
}

ShapeFilterVTable :: struct {
	__vtable_header: [2]rawptr,
	ShouldCollide: proc "c" (in_self:rawptr, #by_ptr in_shape: Shape, #by_ptr in_sub_shape_id: SubShapeID) -> bool,
	PairShouldCollide: proc "c" (in_self:rawptr, #by_ptr in_shape1: Shape, #by_ptr in_sub_shape_id1: SubShapeID, #by_ptr in_shape2: Shape, #by_ptr in_sub_shape_id2: SubShapeID) -> bool,
	bodyId2: c.uint32_t,
}

PhysicsStepListenerVTable :: struct {
	__vtable_header: [2]rawptr,
	OnStep: proc "c" (in_delta_time:c.float, in_physics_system: ^PhysicsSystem),
}

TempAllocator :: struct{}
JobSystem :: struct{}
BodyInterface :: struct{}
BodyLockInterface :: struct{}
NarrowPhaseQuery :: struct{}
ShapeSettings :: struct{}
ConvexShapeSettings :: struct{}
BoxShapeSettings :: struct{}
SphereShapeSettings :: struct{}
TriangleShapeSettings :: struct{}
CapsuleShapeSettings :: struct{}
TaperedCapsuleShapeSettings :: struct{}
CylinderShapeSettings :: struct{}
ConvexHullShapeSettings :: struct{}
HeightFieldShapeSettings :: struct{}
MeshShapeSettings :: struct{}
DecoratedShapeSettings :: struct{}
CompoundShapeSettings :: struct{}
CharacterContactSettings :: struct{}
ConstraintSettings :: struct{}
TwoBodyConstraintSettings :: struct{}
FixedConstraintSettings :: struct{}
PhysicsSystem :: struct{}
SharedMutex :: struct{}
Shape :: struct{}
Constraint :: struct{}
PhysicsMaterial :: struct{}
GroupFilter :: struct{}
Character :: struct{}
CharacterVirtual :: struct{}
ObjectLayer :: distinct c.uint16_t 
BroadPhaseLayer :: distinct c.uint8_t 
BodyID :: distinct c.uint32_t 
SubShapeID :: distinct c.uint32_t 
CollisionGroupID :: distinct c.uint32_t 
CollisionSubGroupID :: distinct c.uint32_t 
AllocateFunction :: proc "c" (in_size:c.size_t) -> rawptr
FreeFunction :: proc "c" (in_block:rawptr)
AlignedAllocateFunction :: proc "c" (in_size:c.size_t, in_alignment:c.size_t) -> rawptr
AlignedFreeFunction :: proc "c" (in_block:rawptr)
// Maximum amount of jobs to allow
cMaxPhysicsJobs : u32 = 2048
// Maximum amount of barriers to allow
cMaxPhysicsBarriers : u32 = 8
@(default_calling_convention="c")
@(link_prefix="JOLT_")
foreign Jolt {
	ShapeSettings_AddRef :: proc(in_settings: ^ShapeSettings)---
	ShapeSettings_Release :: proc(in_settings: ^ShapeSettings)---
	ShapeSettings_GetRefCount :: proc(in_settings: ^ShapeSettings) -> c.uint32_t---
	ShapeSettings_CreateShape :: proc(in_settings: ^ShapeSettings) -> ^Shape---
	ShapeSettings_GetUserData :: proc(in_settings: ^ShapeSettings) -> c.uint64_t---
	ShapeSettings_SetUserData :: proc(in_settings: ^ShapeSettings,in_user_data:c.uint64_t)---
	ConvexShapeSettings_GetMaterial :: proc(in_settings: ^ConvexShapeSettings) -> ^PhysicsMaterial---
	ConvexShapeSettings_SetMaterial :: proc(in_settings: ^ConvexShapeSettings,in_material: ^PhysicsMaterial)---
	ConvexShapeSettings_GetDensity :: proc(in_settings: ^ConvexShapeSettings) -> c.float---
	ConvexShapeSettings_SetDensity :: proc(in_settings: ^ConvexShapeSettings,in_density:c.float)---
	BoxShapeSettings_Create :: proc(in_half_extent:^[3]c.float) -> ^BoxShapeSettings---
	BoxShapeSettings_GetHalfExtent :: proc(in_settings: ^BoxShapeSettings,out_half_extent:^[3]c.float)---
	BoxShapeSettings_SetHalfExtent :: proc(in_settings: ^BoxShapeSettings,in_half_extent:^[3]c.float)---
	BoxShapeSettings_GetConvexRadius :: proc(in_settings: ^BoxShapeSettings) -> c.float---
	BoxShapeSettings_SetConvexRadius :: proc(in_settings: ^BoxShapeSettings,in_convex_radius:c.float)---
	SphereShapeSettings_Create :: proc(in_radius:c.float) -> ^SphereShapeSettings---
	SphereShapeSettings_GetRadius :: proc(in_settings: ^SphereShapeSettings) -> c.float---
	SphereShapeSettings_SetRadius :: proc(in_settings: ^SphereShapeSettings,in_radius:c.float)---
	TriangleShapeSettings_Create :: proc(in_v1:^[3]c.float,in_v2:^[3]c.float,in_v3:^[3]c.float) -> ^TriangleShapeSettings---
	TriangleShapeSettings_SetVertices :: proc(in_settings: ^TriangleShapeSettings,in_v1:^[3]c.float,in_v2:^[3]c.float,in_v3:^[3]c.float)---
	TriangleShapeSettings_GetVertices :: proc(in_settings: ^TriangleShapeSettings,out_v1:^[3]c.float,out_v2:^[3]c.float,out_v3:^[3]c.float)---
	TriangleShapeSettings_GetConvexRadius :: proc(in_settings: ^TriangleShapeSettings) -> c.float---
	TriangleShapeSettings_SetConvexRadius :: proc(in_settings: ^TriangleShapeSettings,in_convex_radius:c.float)---
	CapsuleShapeSettings_Create :: proc(in_half_height_of_cylinder:c.float,in_radius:c.float) -> ^CapsuleShapeSettings---
	CapsuleShapeSettings_GetHalfHeight :: proc(in_settings: ^CapsuleShapeSettings) -> c.float---
	CapsuleShapeSettings_SetHalfHeight :: proc(in_settings: ^CapsuleShapeSettings,in_half_height_of_cylinder:c.float)---
	CapsuleShapeSettings_GetRadius :: proc(in_settings: ^CapsuleShapeSettings) -> c.float---
	CapsuleShapeSettings_SetRadius :: proc(in_settings: ^CapsuleShapeSettings,in_radius:c.float)---
	TaperedCapsuleShapeSettings_Create :: proc(in_half_height:c.float,in_top_radius:c.float,in_bottom_radius:c.float) -> ^TaperedCapsuleShapeSettings---
	TaperedCapsuleShapeSettings_GetHalfHeight :: proc(in_settings: ^TaperedCapsuleShapeSettings) -> c.float---
	TaperedCapsuleShapeSettings_SetHalfHeight :: proc(in_settings: ^TaperedCapsuleShapeSettings,in_half_height:c.float)---
	TaperedCapsuleShapeSettings_GetTopRadius :: proc(in_settings: ^TaperedCapsuleShapeSettings) -> c.float---
	TaperedCapsuleShapeSettings_SetTopRadius :: proc(in_settings: ^TaperedCapsuleShapeSettings,in_top_radius:c.float)---
	TaperedCapsuleShapeSettings_GetBottomRadius :: proc(in_settings: ^TaperedCapsuleShapeSettings) -> c.float---
	TaperedCapsuleShapeSettings_SetBottomRadius :: proc(in_settings: ^TaperedCapsuleShapeSettings,in_bottom_radius:c.float)---
	CylinderShapeSettings_Create :: proc(in_half_height:c.float,in_radius:c.float) -> ^CylinderShapeSettings---
	CylinderShapeSettings_GetConvexRadius :: proc(in_settings: ^CylinderShapeSettings) -> c.float---
	CylinderShapeSettings_SetConvexRadius :: proc(in_settings: ^CylinderShapeSettings,in_convex_radius:c.float)---
	CylinderShapeSettings_GetHalfHeight :: proc(in_settings: ^CylinderShapeSettings) -> c.float---
	CylinderShapeSettings_SetHalfHeight :: proc(in_settings: ^CylinderShapeSettings,in_half_height:c.float)---
	CylinderShapeSettings_GetRadius :: proc(in_settings: ^CylinderShapeSettings) -> c.float---
	CylinderShapeSettings_SetRadius :: proc(in_settings: ^CylinderShapeSettings,in_radius:c.float)---
	ConvexHullShapeSettings_Create :: proc(in_vertices:rawptr,in_num_vertices:c.uint32_t,in_vertex_size:c.uint32_t) -> ^ConvexHullShapeSettings---
	ConvexHullShapeSettings_GetMaxConvexRadius :: proc(in_settings: ^ConvexHullShapeSettings) -> c.float---
	ConvexHullShapeSettings_SetMaxConvexRadius :: proc(in_settings: ^ConvexHullShapeSettings,in_max_convex_radius:c.float)---
	ConvexHullShapeSettings_GetMaxErrorConvexRadius :: proc(in_settings: ^ConvexHullShapeSettings) -> c.float---
	ConvexHullShapeSettings_SetMaxErrorConvexRadius :: proc(in_settings: ^ConvexHullShapeSettings,in_max_err_convex_radius:c.float)---
	ConvexHullShapeSettings_GetHullTolerance :: proc(in_settings: ^ConvexHullShapeSettings) -> c.float---
	ConvexHullShapeSettings_SetHullTolerance :: proc(in_settings: ^ConvexHullShapeSettings,in_hull_tolerance:c.float)---
	HeightFieldShapeSettings_Create :: proc(in_samples: ^c.float,in_height_field_size:c.uint32_t) -> ^HeightFieldShapeSettings---
	HeightFieldShapeSettings_GetOffset :: proc(in_settings: ^HeightFieldShapeSettings,out_offset:^[3]c.float)---
	HeightFieldShapeSettings_SetOffset :: proc(in_settings: ^HeightFieldShapeSettings,in_offset:^[3]c.float)---
	HeightFieldShapeSettings_GetScale :: proc(in_settings: ^HeightFieldShapeSettings,out_scale:^[3]c.float)---
	HeightFieldShapeSettings_SetScale :: proc(in_settings: ^HeightFieldShapeSettings,in_scale:^[3]c.float)---
	HeightFieldShapeSettings_GetBlockSize :: proc(in_settings: ^HeightFieldShapeSettings) -> c.uint32_t---
	HeightFieldShapeSettings_SetBlockSize :: proc(in_settings: ^HeightFieldShapeSettings,in_block_size:c.uint32_t)---
	HeightFieldShapeSettings_GetBitsPerSample :: proc(in_settings: ^HeightFieldShapeSettings) -> c.uint32_t---
	HeightFieldShapeSettings_SetBitsPerSample :: proc(in_settings: ^HeightFieldShapeSettings,in_num_bits:c.uint32_t)---
	MeshShapeSettings_Create :: proc(in_vertices:rawptr,in_num_vertices:c.uint32_t,in_vertex_size:c.uint32_t,in_indices: ^c.uint32_t,in_num_indices:c.uint32_t) -> ^MeshShapeSettings---
	MeshShapeSettings_GetMaxTrianglesPerLeaf :: proc(in_settings: ^MeshShapeSettings) -> c.uint32_t---
	MeshShapeSettings_SetMaxTrianglesPerLeaf :: proc(in_settings: ^MeshShapeSettings,in_max_triangles:c.uint32_t)---
	MeshShapeSettings_Sanitize :: proc(in_settings: ^MeshShapeSettings)---
	RotatedTranslatedShapeSettings_Create :: proc(in_inner_shape_settings: ^ShapeSettings,in_rotated:^[4]c.float,in_translated:^[3]c.float) -> ^DecoratedShapeSettings---
	ScaledShapeSettings_Create :: proc(in_inner_shape_settings: ^ShapeSettings,in_scale:^[3]c.float) -> ^DecoratedShapeSettings---
	OffsetCenterOfMassShapeSettings_Create :: proc(in_inner_shape_settings: ^ShapeSettings,in_center_of_mass:^[3]c.float) -> ^DecoratedShapeSettings---
	StaticCompoundShapeSettings_Create :: proc() -> ^CompoundShapeSettings---
	MutableCompoundShapeSettings_Create :: proc() -> ^CompoundShapeSettings---
	CompoundShapeSettings_AddShape :: proc(in_settings: ^CompoundShapeSettings,in_position:^[3]c.float,in_rotation:^[4]c.float,in_shape: ^ShapeSettings,in_user_data:c.uint32_t)---
	GetBodyInterface :: proc(ps: ^PhysicsSystem) -> ^BodyInterface---
	RegisterDefaultAllocator :: proc()---
	RegisterCustomAllocator :: proc(in_alloc:AllocateFunction,in_free:FreeFunction,in_aligned_alloc:AlignedAllocateFunction,in_aligned_free:AlignedFreeFunction)---
	CreateFactory :: proc()---
	DestroyFactory :: proc()---
	RegisterTypes :: proc()---
	BodyCreationSettings_SetDefault :: proc(out_settings: ^BodyCreationSettings)---
	BodyCreationSettings_Set :: proc(out_settings: ^BodyCreationSettings,in_shape: ^Shape,in_position:^[3]c.float,in_rotation:^[4]c.float,in_motion_type:MotionType,in_layer:ObjectLayer)---
	TempAllocator_Create :: proc(in_size:c.uint32_t) -> ^TempAllocator---
	TempAllocator_Destroy :: proc(in_allocator: ^TempAllocator)---
	JobSystem_Create :: proc(in_max_jobs:c.uint32_t,in_max_barriers:c.uint32_t,in_num_threads:int) -> ^JobSystem---
	JobSystem_Destroy :: proc(in_job_system: ^JobSystem)---
	MotionProperties_GetMotionQuality :: proc(#by_ptr in_properties: MotionProperties) -> MotionQuality---
	MotionProperties_GetLinearVelocity :: proc(#by_ptr in_properties: MotionProperties,out_linear_velocity:^[3]c.float)---
	MotionProperties_SetLinearVelocity :: proc(in_properties: ^MotionProperties,in_linear_velocity:^[3]c.float)---
	MotionProperties_SetLinearVelocityClamped :: proc(in_properties: ^MotionProperties,in_linear_velocity:^[3]c.float)---
	MotionProperties_GetAngularVelocity :: proc(#by_ptr in_properties: MotionProperties,out_angular_velocity:^[3]c.float)---
	MotionProperties_SetAngularVelocity :: proc(in_properties: ^MotionProperties,in_angular_velocity:^[3]c.float)---
	MotionProperties_SetAngularVelocityClamped :: proc(in_properties: ^MotionProperties,in_angular_velocity:^[3]c.float)---
	MotionProperties_MoveKinematic :: proc(in_properties: ^MotionProperties,in_delta_position:^[3]c.float,in_delta_rotation:^[4]c.float,in_delta_time:c.float)---
	MotionProperties_ClampLinearVelocity :: proc(in_properties: ^MotionProperties)---
	MotionProperties_ClampAngularVelocity :: proc(in_properties: ^MotionProperties)---
	MotionProperties_GetLinearDamping :: proc(#by_ptr in_properties: MotionProperties) -> c.float---
	MotionProperties_SetLinearDamping :: proc(in_properties: ^MotionProperties,in_linear_damping:c.float)---
	MotionProperties_GetAngularDamping :: proc(#by_ptr in_properties: MotionProperties) -> c.float---
	MotionProperties_SetAngularDamping :: proc(in_properties: ^MotionProperties,in_angular_damping:c.float)---
	MotionProperties_GetGravityFactor :: proc(#by_ptr in_properties: MotionProperties) -> c.float---
	MotionProperties_SetGravityFactor :: proc(in_properties: ^MotionProperties,in_gravity_factor:c.float)---
	MotionProperties_SetMassProperties :: proc(in_properties: ^MotionProperties,#by_ptr in_mass_properties: MassProperties)---
	MotionProperties_GetInverseMass :: proc(#by_ptr in_properties: MotionProperties) -> c.float---
	MotionProperties_SetInverseMass :: proc(in_properties: ^MotionProperties,in_inv_mass:c.float)---
	MotionProperties_GetInverseInertiaDiagonal :: proc(#by_ptr in_properties: MotionProperties,out_inverse_inertia_diagonal:^[3]c.float)---
	MotionProperties_GetInertiaRotation :: proc(#by_ptr in_properties: MotionProperties,out_inertia_rotation:^[4]c.float)---
	MotionProperties_SetInverseInertia :: proc(in_properties: ^MotionProperties,in_diagonal:^[3]c.float,in_rotation:^[4]c.float)---
	MotionProperties_GetLocalSpaceInverseInertia :: proc(#by_ptr in_properties: MotionProperties,out_matrix:^[16]c.float)---
	MotionProperties_GetInverseInertiaForRotation :: proc(#by_ptr in_properties: MotionProperties,in_rotation_matrix:^[16]c.float,out_matrix:^[16]c.float)---
	MotionProperties_MultiplyWorldSpaceInverseInertiaByVector :: proc(#by_ptr in_properties: MotionProperties,in_body_rotation:^[4]c.float,in_vector:^[3]c.float,out_vector:^[3]c.float)---
	MotionProperties_GetPointVelocityCOM :: proc(#by_ptr in_properties: MotionProperties,in_point_relative_to_com:^[3]c.float,out_point:^[3]c.float)---
	MotionProperties_GetMaxLinearVelocity :: proc(#by_ptr in_properties: MotionProperties) -> c.float---
	MotionProperties_SetMaxLinearVelocity :: proc(in_properties: ^MotionProperties,in_max_linear_velocity:c.float)---
	MotionProperties_GetMaxAngularVelocity :: proc(#by_ptr in_properties: MotionProperties) -> c.float---
	MotionProperties_SetMaxAngularVelocity :: proc(in_properties: ^MotionProperties,in_max_angular_velocity:c.float)---
	PhysicsSystem_Create :: proc(in_max_bodies:c.uint32_t,in_num_body_mutexes:c.uint32_t,in_max_body_pairs:c.uint32_t,in_max_contact_constraints:c.uint32_t,in_broad_phase_layer_interface:BroadPhaseLayerInterfaceVTable,in_object_vs_broad_phase_layer_filter:ObjectVsBroadPhaseLayerFilterVTable,in_object_layer_pair_filter:ObjectLayerPairFilterVTable) -> ^PhysicsSystem---
	SetContactListener :: proc(in_physics_system: ^PhysicsSystem,in_listener: ^ContactListenerVTable)---
	PhysicsSystem_SetBodyActivationListener :: proc(in_physics_system: ^PhysicsSystem,in_listener:rawptr)---
	PhysicsSystem_GetBodyActivationListener :: proc(in_physics_system: ^PhysicsSystem) -> rawptr---
	PhysicsSystem_SetContactListener :: proc(in_physics_system: ^PhysicsSystem,in_listener:rawptr)---
	PhysicsSystem_GetContactListener :: proc(in_physics_system: ^PhysicsSystem) -> rawptr---
	PhysicsSystem_GetNumBodies :: proc(in_physics_system: ^PhysicsSystem) -> c.uint32_t---
	PhysicsSystem_GetNumActiveBodies :: proc(in_physics_system: ^PhysicsSystem,type:BodyType) -> c.uint32_t---
	PhysicsSystem_GetMaxBodies :: proc(in_physics_system: ^PhysicsSystem) -> c.uint32_t---
	PhysicsSystem_GetGravity :: proc(in_physics_system: ^PhysicsSystem,out_gravity:^[3]c.float)---
	PhysicsSystem_SetGravity :: proc(in_physics_system: ^PhysicsSystem,in_gravity:^[3]c.float)---
	PhysicsSystem_GetBodyInterface :: proc(in_physics_system: ^PhysicsSystem) -> ^BodyInterface---
	PhysicsSystem_GetBodyInterfaceNoLock :: proc(in_physics_system: ^PhysicsSystem) -> ^BodyInterface---
	PhysicsSystem_OptimizeBroadPhase :: proc(in_physics_system: ^PhysicsSystem)---
	PhysicsSystem_AddStepListener :: proc(in_physics_system: ^PhysicsSystem,in_listener:rawptr)---
	PhysicsSystem_RemoveStepListener :: proc(in_physics_system: ^PhysicsSystem,in_listener:rawptr)---
	PhysicsSystem_AddConstraint :: proc(in_physics_system: ^PhysicsSystem,in_two_body_constraint:rawptr)---
	PhysicsSystem_RemoveConstraint :: proc(in_physics_system: ^PhysicsSystem,in_two_body_constraint:rawptr)---
	PhysicsSystem_Update :: proc(in_physics_system: ^PhysicsSystem,in_delta_time:c.float,in_collision_steps:int,in_integration_sub_steps:int,in_temp_allocator: ^TempAllocator,in_job_system: ^JobSystem) -> PhysicsUpdateError---
	PhysicsSystem_GetBodyLockInterface :: proc(in_physics_system: ^PhysicsSystem) -> ^BodyLockInterface---
	PhysicsSystem_GetBodyLockInterfaceNoLock :: proc(in_physics_system: ^PhysicsSystem) -> ^BodyLockInterface---
	PhysicsSystem_GetNarrowPhaseQuery :: proc(in_physics_system: ^PhysicsSystem) -> ^NarrowPhaseQuery---
	PhysicsSystem_GetNarrowPhaseQueryNoLock :: proc(in_physics_system: ^PhysicsSystem) -> ^NarrowPhaseQuery---
	PhysicsSystem_GetBodyIDs :: proc(in_physics_system: ^PhysicsSystem,in_max_body_ids:c.uint32_t,out_num_body_ids: ^c.uint32_t,out_body_ids: ^BodyID)---
	PhysicsSystem_GetActiveBodyIDs :: proc(in_physics_system: ^PhysicsSystem,in_max_body_ids:c.uint32_t,out_num_body_ids: ^c.uint32_t,out_body_ids: ^BodyID)---
	PhysicsSystem_GetBodiesUnsafe :: proc(in_physics_system: ^PhysicsSystem) -> [^]Body---
	BodyLockInterface_LockRead :: proc(in_lock_interface: ^BodyLockInterface,in_body_id:BodyID,out_lock: ^BodyLockRead)---
	BodyLockInterface_UnlockRead :: proc(in_lock_interface: ^BodyLockInterface,io_lock: ^BodyLockRead)---
	BodyLockInterface_LockWrite :: proc(in_lock_interface: ^BodyLockInterface,in_body_id:BodyID,out_lock: ^BodyLockWrite)---
	BodyLockInterface_UnlockWrite :: proc(in_lock_interface: ^BodyLockInterface,io_lock: ^BodyLockWrite)---
	BodyLockInterface_TryGetBody :: proc(in_lock_interface: ^BodyLockInterface,in_id: ^BodyID) -> ^Body---
	NarrowPhaseQuery_CastRay :: proc(in_query: ^NarrowPhaseQuery,#by_ptr in_ray: RRayCast,io_hit: ^RayCastResult,in_broad_phase_layer_filter:rawptr,in_object_layer_filter:rawptr,in_body_filter:rawptr) -> bool---
	Shape_AddRef :: proc(in_shape: ^Shape)---
	Shape_Release :: proc(in_shape: ^Shape)---
	Shape_GetRefCount :: proc(in_shape: ^Shape) -> c.uint32_t---
	Shape_GetType :: proc(in_shape: ^Shape) -> ShapeType---
	Shape_GetSubType :: proc(in_shape: ^Shape) -> ShapeSubType---
	Shape_GetUserData :: proc(in_shape: ^Shape) -> c.uint64_t---
	Shape_SetUserData :: proc(in_shape: ^Shape,in_user_data:c.uint64_t)---
	Shape_GetCenterOfMass :: proc(in_shape: ^Shape,out_position:^[3]c.float)---
	ConstraintSettings_AddRef :: proc(in_settings: ^ConstraintSettings)---
	ConstraintSettings_Release :: proc(in_settings: ^ConstraintSettings)---
	ConstraintSettings_GetRefCount :: proc(in_settings: ^ConstraintSettings) -> c.uint32_t---
	ConstraintSettings_GetUserData :: proc(in_settings: ^ConstraintSettings) -> c.uint64_t---
	ConstraintSettings_SetUserData :: proc(in_settings: ^ConstraintSettings,in_user_data:c.uint64_t)---
	TwoBodyConstraintSettings_CreateConstraint :: proc(in_settings: ^TwoBodyConstraintSettings,in_body1: ^Body,in_body2: ^Body) -> ^Constraint---
	FixedConstraintSettings_Create :: proc() -> ^FixedConstraintSettings---
	FixedConstraintSettings_SetSpace :: proc(in_settings: ^FixedConstraintSettings,in_space:ConstraintSpace)---
	FixedConstraintSettings_SetAutoDetectPoint :: proc(in_settings: ^FixedConstraintSettings,in_enabled:bool)---
	Constraint_AddRef :: proc(in_shape: ^Constraint)---
	Constraint_Release :: proc(in_shape: ^Constraint)---
	Constraint_GetRefCount :: proc(in_shape: ^Constraint) -> c.uint32_t---
	Constraint_GetType :: proc(in_shape: ^Constraint) -> ConstraintType---
	Constraint_GetSubType :: proc(in_shape: ^Constraint) -> ConstraintSubType---
	Constraint_GetUserData :: proc(in_shape: ^Constraint) -> c.uint64_t---
	Constraint_SetUserData :: proc(in_shape: ^Constraint,in_user_data:c.uint64_t)---
	BodyInterface_CreateBody :: proc(in_iface: ^BodyInterface,in_setting: ^BodyCreationSettings) -> ^Body---
	BodyInterface_CreateBodyWithID :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,#by_ptr in_settings: BodyCreationSettings) -> ^Body---
	BodyInterface_DestroyBody :: proc(in_iface: ^BodyInterface,in_body_id:BodyID)---
	BodyInterface_AddBody :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,in_mode:Activation)---
	BodyInterface_RemoveBody :: proc(in_iface: ^BodyInterface,in_body_id:BodyID)---
	BodyInterface_CreateAndAddBody :: proc(in_iface: ^BodyInterface,#by_ptr in_settings: BodyCreationSettings,in_mode:Activation) -> BodyID---
	BodyInterface_IsAdded :: proc(in_iface: ^BodyInterface,in_body_id:BodyID) -> bool---
	BodyInterface_SetLinearAndAngularVelocity :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,in_linear_velocity:^[3]c.float,in_angular_velocity:^[3]c.float)---
	BodyInterface_GetLinearAndAngularVelocity :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,out_linear_velocity:^[3]c.float,out_angular_velocity:^[3]c.float)---
	BodyInterface_SetLinearVelocity :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,in_velocity:^[3]c.float)---
	BodyInterface_GetLinearVelocity :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,out_velocity:^[3]c.float)---
	BodyInterface_AddLinearVelocity :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,in_velocity:^[3]c.float)---
	BodyInterface_AddLinearAndAngularVelocity :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,in_linear_velocity:^[3]c.float,in_angular_velocity:^[3]c.float)---
	BodyInterface_SetAngularVelocity :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,in_velocity:^[3]c.float)---
	BodyInterface_GetAngularVelocity :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,out_velocity:^[3]c.float)---
	BodyInterface_GetPointVelocity :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,in_point:^[3]c.float,out_velocity:^[3]c.float)---
	BodyInterface_GetPosition :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,out_position:^[3]c.float)---
	BodyInterface_SetPosition :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,in_position:^[3]c.float,in_activation:Activation)---
	BodyInterface_GetCenterOfMassPosition :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,out_position:^[3]c.float)---
	BodyInterface_GetRotation :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,out_rotation:^[4]c.float)---
	BodyInterface_SetRotation :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,in_rotation:^[4]c.float,in_activation:Activation)---
	BodyInterface_ActivateBody :: proc(in_iface: ^BodyInterface,in_body_id:BodyID)---
	BodyInterface_DeactivateBody :: proc(in_iface: ^BodyInterface,in_body_id:BodyID)---
	BodyInterface_IsActive :: proc(in_iface: ^BodyInterface,in_body_id:BodyID) -> bool---
	BodyInterface_SetPositionRotationAndVelocity :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,in_position:^[3]c.float,in_rotation:^[4]c.float,in_linear_velocity:^[3]c.float,in_angular_velocity:^[3]c.float)---
	BodyInterface_AddForce :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,in_force:^[3]c.float)---
	BodyInterface_AddForceAtPosition :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,in_force:^[3]c.float,in_position:^[3]c.float)---
	BodyInterface_AddTorque :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,in_torque:^[3]c.float)---
	BodyInterface_AddForceAndTorque :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,in_force:^[3]c.float,in_torque:^[3]c.float)---
	BodyInterface_AddImpulse :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,in_impulse:^[3]c.float)---
	BodyInterface_AddImpulseAtPosition :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,in_impulse:^[3]c.float,in_position:^[3]c.float)---
	BodyInterface_AddAngularImpulse :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,in_impulse:^[3]c.float)---
	BodyInterface_GetMotionType :: proc(in_iface: ^BodyInterface,in_body_id:BodyID) -> MotionType---
	BodyInterface_SetMotionType :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,motion_type:MotionType,activation:Activation)---
	BodyInterface_GetObjectLayer :: proc(in_iface: ^BodyInterface,in_body_id:BodyID) -> ObjectLayer---
	BodyInterface_SetObjectLayer :: proc(in_iface: ^BodyInterface,in_body_id:BodyID,in_layer:ObjectLayer)---
	Body_GetID :: proc(#by_ptr in_body: Body) -> BodyID---
	Body_IsActive :: proc(#by_ptr in_body: Body) -> bool---
	Body_IsStatic :: proc(#by_ptr in_body: Body) -> bool---
	Body_IsKinematic :: proc(#by_ptr in_body: Body) -> bool---
	Body_IsDynamic :: proc(#by_ptr in_body: Body) -> bool---
	Body_CanBeKinematicOrDynamic :: proc(#by_ptr in_body: Body) -> bool---
	Body_SetIsSensor :: proc(in_body: ^Body,in_is_sensor:bool)---
	Body_IsSensor :: proc(#by_ptr in_body: Body) -> bool---
	Body_GetMotionType :: proc(#by_ptr in_body: Body) -> MotionType---
	Body_SetMotionType :: proc(in_body: ^Body,in_motion_type:MotionType)---
	Body_GetBroadPhaseLayer :: proc(#by_ptr in_body: Body) -> BroadPhaseLayer---
	Body_GetObjectLayer :: proc(#by_ptr in_body: Body) -> ObjectLayer---
	Body_GetCollisionGroup :: proc(in_body: ^Body) -> ^CollisionGroup---
	Body_SetCollisionGroup :: proc(in_body: ^Body,#by_ptr in_group: CollisionGroup)---
	Body_GetAllowSleeping :: proc(#by_ptr in_body: Body) -> bool---
	Body_SetAllowSleeping :: proc(in_body: ^Body,in_allow_sleeping:bool)---
	Body_GetFriction :: proc(#by_ptr in_body: Body) -> c.float---
	Body_SetFriction :: proc(in_body: ^Body,in_friction:c.float)---
	Body_GetRestitution :: proc(#by_ptr in_body: Body) -> c.float---
	Body_SetRestitution :: proc(in_body: ^Body,in_restitution:c.float)---
	Body_GetLinearVelocity :: proc(#by_ptr in_body: Body,out_linear_velocity:^[3]c.float)---
	Body_SetLinearVelocity :: proc(in_body: ^Body,in_linear_velocity:^[3]c.float)---
	Body_SetLinearVelocityClamped :: proc(in_body: ^Body,in_linear_velocity:^[3]c.float)---
	Body_GetAngularVelocity :: proc(#by_ptr in_body: Body,out_angular_velocity:^[3]c.float)---
	Body_SetAngularVelocity :: proc(in_body: ^Body,in_angular_velocity:^[3]c.float)---
	Body_SetAngularVelocityClamped :: proc(in_body: ^Body,in_angular_velocity:^[3]c.float)---
	Body_GetPointVelocityCOM :: proc(#by_ptr in_body: Body,in_point_relative_to_com:^[3]c.float,out_velocity:^[3]c.float)---
	Body_GetPointVelocity :: proc(#by_ptr in_body: Body,in_point:^[3]c.float,out_velocity:^[3]c.float)---
	Body_AddForce :: proc(in_body: ^Body,in_force:^[3]c.float)---
	Body_AddForceAtPosition :: proc(in_body: ^Body,in_force:^[3]c.float,in_position:^[3]c.float)---
	Body_AddTorque :: proc(in_body: ^Body,in_torque:^[3]c.float)---
	Body_GetInverseInertia :: proc(#by_ptr in_body: Body,out_inverse_inertia:^[16]c.float)---
	Body_AddImpulse :: proc(in_body: ^Body,in_impulse:^[3]c.float)---
	Body_AddImpulseAtPosition :: proc(in_body: ^Body,in_impulse:^[3]c.float,in_position:^[3]c.float)---
	Body_AddAngularImpulse :: proc(in_body: ^Body,in_angular_impulse:^[3]c.float)---
	Body_MoveKinematic :: proc(in_body: ^Body,in_target_position:^[3]c.float,in_target_rotation:^[4]c.float,in_delta_time:c.float)---
	Body_ApplyBuoyancyImpulse :: proc(in_body: ^Body,in_surface_position:^[3]c.float,in_surface_normal:^[3]c.float,in_buoyancy:c.float,in_linear_drag:c.float,in_angular_drag:c.float,in_fluid_velocity:^[3]c.float,in_gravity:^[3]c.float,in_delta_time:c.float)---
	Body_IsInBroadPhase :: proc(#by_ptr in_body: Body) -> bool---
	Body_IsCollisionCacheInvalid :: proc(#by_ptr in_body: Body) -> bool---
	Body_GetShape :: proc(#by_ptr in_body: Body) -> ^Shape---
	Body_GetPosition :: proc(#by_ptr in_body: Body,out_position:^[3]c.float)---
	Body_GetRotation :: proc(#by_ptr in_body: Body,out_rotation:^[4]c.float)---
	Body_GetWorldTransform :: proc(#by_ptr in_body: Body,out_rotation:^[9]c.float,out_translation:^[3]c.float)---
	Body_GetCenterOfMassPosition :: proc(#by_ptr in_body: Body,out_position:^[3]c.float)---
	Body_GetCenterOfMassTransform :: proc(#by_ptr in_body: Body,out_rotation:^[9]c.float,out_translation:^[3]c.float)---
	Body_GetInverseCenterOfMassTransform :: proc(#by_ptr in_body: Body,out_rotation:^[9]c.float,out_translation:^[3]c.float)---
	Body_GetWorldSpaceBounds :: proc(#by_ptr in_body: Body,out_min:^[3]c.float,out_max:^[3]c.float)---
	Body_GetMotionProperties :: proc(in_body: ^Body) -> ^MotionProperties---
	Body_GetUserData :: proc(#by_ptr in_body: Body) -> c.uint64_t---
	Body_SetUserData :: proc(in_body: ^Body,in_user_data:c.uint64_t)---
	Body_GetWorldSpaceSurfaceNormal :: proc(#by_ptr in_body: Body,in_sub_shape_id:SubShapeID,in_position:^[3]c.float,out_normal_vector:^[3]c.float)---
	BodyID_GetIndex :: proc(in_body_id:BodyID) -> c.uint32_t---
	BodyID_GetSequenceNumber :: proc(in_body_id:BodyID) -> c.uint8_t---
	BodyID_IsInvalid :: proc(in_body_id:BodyID) -> bool---
	CharacterSettings_Create :: proc() -> ^CharacterSettings---
	CharacterSettings_Release :: proc(in_settings: ^CharacterSettings)---
	CharacterSettings_AddRef :: proc(in_settings: ^CharacterSettings)---
	Character_Create :: proc(#by_ptr in_settings: CharacterSettings,in_position:^[3]c.float,in_rotation:^[4]c.float,in_user_data:c.uint64_t,in_physics_system: ^PhysicsSystem) -> ^Character---
	Character_Destroy :: proc(in_character: ^Character)---
	Character_AddToPhysicsSystem :: proc(in_character: ^Character,in_activation:Activation,in_lock_bodies:bool)---
	Character_RemoveFromPhysicsSystem :: proc(in_character: ^Character,in_lock_bodies:bool)---
	Character_GetPosition :: proc(in_character: ^Character,out_position:^[3]c.float)---
	Character_SetPosition :: proc(in_character: ^Character,in_position:^[3]c.float)---
	Character_GetLinearVelocity :: proc(in_character: ^Character,out_linear_velocity:^[3]c.float)---
	Character_SetLinearVelocity :: proc(in_character: ^Character,in_linear_velocity:^[3]c.float)---
	CharacterVirtualSettings_Create :: proc() -> ^CharacterVirtualSettings---
	CharacterVirtualSettings_Release :: proc(in_settings: ^CharacterVirtualSettings)---
	CharacterVirtual_Create :: proc(#by_ptr in_settings: CharacterVirtualSettings,in_position:^[3]c.float,in_rotation:^[4]c.float,in_physics_system: ^PhysicsSystem) -> ^CharacterVirtual---
	CharacterVirtual_Destroy :: proc(in_character: ^CharacterVirtual)---
	CharacterVirtual_Update :: proc(in_character: ^CharacterVirtual,in_delta_time:c.float,in_gravity:^[3]c.float,in_broad_phase_layer_filter:rawptr,in_object_layer_filter:rawptr,in_body_filter:rawptr,in_shape_filter:rawptr,in_temp_allocator: ^TempAllocator)---
	CharacterVirtual_SetListener :: proc(in_character: ^CharacterVirtual,in_listener:rawptr)---
	CharacterVirtual_UpdateGroundVelocity :: proc(in_character: ^CharacterVirtual)---
	CharacterVirtual_GetGroundVelocity :: proc(in_character: ^CharacterVirtual,out_ground_velocity:^[3]c.float)---
	CharacterVirtual_GetGroundState :: proc(in_character: ^CharacterVirtual) -> CharacterGroundState---
	CharacterVirtual_GetPosition :: proc(in_character: ^CharacterVirtual,out_position:^[3]c.float)---
	CharacterVirtual_SetPosition :: proc(in_character: ^CharacterVirtual,in_position:^[3]c.float)---
	CharacterVirtual_GetRotation :: proc(in_character: ^CharacterVirtual,out_rotation:^[4]c.float)---
	CharacterVirtual_SetRotation :: proc(in_character: ^CharacterVirtual,in_rotation:^[4]c.float)---
	CharacterVirtual_GetLinearVelocity :: proc(in_character: ^CharacterVirtual,out_linear_velocity:^[3]c.float)---
	CharacterVirtual_SetLinearVelocity :: proc(in_character: ^CharacterVirtual,in_linear_velocity:^[3]c.float)---
	ContactManifold_GetWorldSpaceContactPointOn1 :: proc(#by_ptr in_manifold: ContactManifold,in_index:c.uint32_t,out_position:^[3]c.float)---
	ContactManifold_GetWorldSpaceContactPointOn2 :: proc(#by_ptr in_manifold: ContactManifold,in_index:c.uint32_t,out_position:^[3]c.float)---
}
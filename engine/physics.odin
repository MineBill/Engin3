package engine
import "packages:jolt"
import "core:log"

PhysicsInstance: ^Physics

ObjectLayers :: enum jolt.ObjectLayer {
    NonMoving = 0,
    Moving = 1,
}

BroadPhaseLayers :: enum jolt.BroadPhaseLayer {
    NonMoving = 0,
    Moving = 1,
}

Physics :: struct {
    broad_phase_layer_interface: jolt.BroadPhaseLayerInterfaceVTable,
    object_vs_broadphase_layer_filter: jolt.ObjectVsBroadPhaseLayerFilterVTable,
    object_layer_pair_filter: jolt.ObjectLayerPairFilterVTable,

    object_to_broad_phase: map[ObjectLayers]BroadPhaseLayers,

    job_system: ^jolt.JobSystem,
    physics_system: ^jolt.PhysicsSystem,
    temp_allocator: ^jolt.TempAllocator,

    contact_listener: jolt.ContactListenerVTable,

    body_interface: ^jolt.BodyInterface,
}

physics_init :: proc(physics: ^Physics) {
    PhysicsInstance = physics

    physics.object_to_broad_phase[.Moving] = .Moving
    physics.object_to_broad_phase[.NonMoving] = .NonMoving

    physics.broad_phase_layer_interface.GetBroadPhaseLayer = proc "c" (layer: jolt.ObjectLayer) -> jolt.BroadPhaseLayer {
        context = EngineInstance.ctx
        return cast(jolt.BroadPhaseLayer) PhysicsInstance.object_to_broad_phase[ObjectLayers(layer)]
    }

    physics.broad_phase_layer_interface.GetNumBroadPhaseLayers = proc "c" () -> u32 {
        context = EngineInstance.ctx
        return len(BroadPhaseLayers)
    }

    physics.object_vs_broadphase_layer_filter.ShouldCollide = proc "c" (a: jolt.ObjectLayer, b: jolt.BroadPhaseLayer) -> bool {
        context = EngineInstance.ctx
        switch ObjectLayers(a) {
        case .Moving:
            return true
        case .NonMoving:
            return BroadPhaseLayers(b) == .Moving
        }
        return false
    }

    physics.object_layer_pair_filter.ShouldCollide = proc "c" (a, b: jolt.ObjectLayer) -> bool {
        context = EngineInstance.ctx
        a, b := ObjectLayers(a), ObjectLayers(b)
        switch a {
        case .NonMoving:
            return b == .Moving
        case .Moving:
            return true
        }
        return false
    }
    jolt.RegisterDefaultAllocator()
    jolt.RegisterTypes()

    physics.temp_allocator = jolt.TempAllocator_Create(1024 * 1024 * 10)

    physics.job_system = jolt.JobSystem_Create(jolt.cMaxPhysicsJobs, jolt.cMaxPhysicsBarriers, 4)

    max_bodies       : u32 = 1024
    num_body_mutexes : u32 = 0
    max_body_pairs   : u32 = 1024
    max_constraints  : u32 = 1024

    physics.physics_system = jolt.PhysicsSystem_Create(
        max_bodies,
        num_body_mutexes,
        max_body_pairs,
        max_constraints,
        physics.broad_phase_layer_interface,
        physics.object_vs_broadphase_layer_filter,
        physics.object_layer_pair_filter)

    physics.contact_listener.OnContactAdded = proc "c" (body1, body2: jolt.Body, manifold: jolt.ContactManifold, settings: ^jolt.ContactSettings) {
        context = EngineInstance.ctx

        log.infof("COLLISION DETECTED %v - %v", body1.id, body2.id)
    }

    physics.contact_listener.OnContactRemoved = proc "c" (sub_shape_pair: jolt.SubShapeIDPair) {
        context = EngineInstance.ctx

        first := sub_shape_pair.first.body_id
        second := sub_shape_pair.second.body_id
        log.infof("COLLISION FINISHED %v - %v", first, second)
    }

    physics.contact_listener.OnContactValidate = proc "c" (in_body1,in_body2: jolt.Body,in_base_offset:vec3,in_collision_result: jolt.CollideShapeResult) -> jolt.ValidateResult {
        return .VALIDATE_RESULT_ACCEPT_ALL_CONTACTS
    }

    jolt.SetContactListener(physics.physics_system, &physics.contact_listener)

    // TODO: Remove this, only for testing if jolt bindings work.

    body_interface := jolt.GetBodyInterface(physics.physics_system)
    physics.body_interface = body_interface

    floor_size := vec3{100, 1, 100}
    floor_shape_settings := jolt.BoxShapeSettings_Create(&floor_size)

    floor_shape := jolt.ShapeSettings_CreateShape(cast(^jolt.ShapeSettings) floor_shape_settings)

    position := vec3{0, -1, 0}
    rotation := vec4{0, 0, 0, 1}
    body_settings: jolt.BodyCreationSettings
    jolt.BodyCreationSettings_Set(&body_settings, floor_shape, &position, &rotation, .MOTION_TYPE_STATIC, jolt.ObjectLayer(ObjectLayers.NonMoving))

    floor := jolt.BodyInterface_CreateBody(body_interface, &body_settings)
    jolt.BodyInterface_AddBody(body_interface, floor.id, .ACTIVATION_DONT_ACTIVATE)

    jolt.PhysicsSystem_OptimizeBroadPhase(physics.physics_system)
}

physics_update :: proc(physics: ^Physics, delta: f64) {
    COLLSION_STEPS :: 1
    INTEGRATION_SUB_STEPS :: 0

    jolt.PhysicsSystem_Update(physics.physics_system, f32(1.0 / 60.0), COLLSION_STEPS, INTEGRATION_SUB_STEPS, physics.temp_allocator, physics.job_system)
}

physics_set_instance :: proc(physics: ^Physics) {
    PhysicsInstance = physics
}

physics_deinit :: proc(physics: ^Physics) {

}

ShapeType :: enum {
    Box,
    Sphere,
}

SphereShape :: struct {
    radius: f32,
}

BoxShape :: struct {
    size: vec3,
}

Shape :: union {
    SphereShape,
    BoxShape,
}

package test
import "core:c"
import jolt "../"
import "core:runtime"
import "core:fmt"
import m "core:math/linalg/hlsl"

main :: proc(){
    init()
    update()
}

//Just some code you can copy paste and try to run to check if things are running properly this is not the full hello
init :: proc(){
    in_broad_phase_layer_interface.GetNumBroadPhaseLayers = get_num_broad_pl
    in_broad_phase_layer_interface.GetBroadPhaseLayer = get_broad_phase_layer

    in_object_vs_broad_phase_layer_filter.ShouldCollide = should_collide
    in_object_layer_pair_filter.ShouldCollide = should_collide_object_layer

    // Register allocation hook
    jolt.RegisterDefaultAllocator()
    // Create a factory
    // Register all Jolt physics types
    jolt.RegisterTypes()
    // We need a temp allocator for temporary allocations during the physics update. We're
    // pre-allocating 10 MB to avoid having to do allocations during the physics update.
    // B.t.w. 10 MB is way too much for this example but it is a typical value you can use.
    // If you don't want to pre-allocate you can also use TempAllocatorMalloc to fall back to
    jta = jolt.TempAllocator_Create(1024 * 1024*10)
    // We need a job system that will execute physics jobs on multiple threads. Typically
    // you would implement the JobSystem interface yourself and let Jolt Physics run on top
    // of your own job scheduler. JobSystemThreadPool is an example implementation.
    js = jolt.JobSystem_Create(jolt.cMaxPhysicsJobs,jolt.cMaxPhysicsBarriers,4)

    in_max_bodies : u32 = 1024
    in_num_body_mutexes : u32 = 0
    in_max_body_pairs : u32 = 1024
    in_max_constraints : u32 = 1024

    // Create class that filters object vs broadphase layers
    // Note: As this is an interface, PhysicsSystem will take a reference to this so this instance needs to stay alive!
    //TODO

    // Create class that filters object vs object layers
    // Note: As this is an interface, PhysicsSystem will take a reference to this so this instance needs to stay alive!
    //TODO

    // Now we can create the actual physics system.
    physics_system = jolt.PhysicsSystem_Create(in_max_bodies,in_num_body_mutexes,in_max_body_pairs,in_max_constraints,
        in_broad_phase_layer_interface,
        in_object_vs_broad_phase_layer_filter,
        in_object_layer_pair_filter)
    //physics_system := jolt.PhysicsSystem_Create(in_max_bodies,in_num_body_mutexes,in_max_body_pairs,in_max_constraints,&in_broad_phase_layer_interface,&in_object_vs_broad_phase_layer_filter,&in_object_layer_pair_filter)
    // A contact listener gets notified when bodies (are about to) collide, and when they separate again.
    // Note that this is called from a job so whatever you do here needs to be thread safe.
    // Registering one is entirely optional.
    contact_listener : jolt.ContactListenerVTable
    contact_listener.OnContactAdded = contact_added_test
    jolt.SetContactListener(physics_system,&contact_listener)

    // The main way to interact with the bodies in the physics system is through the body interface. There is a locking and a non-locking
    // variant of this. We're going to use the locking version (even though we're not planning to access bodies from multiple threads)
    body_interface = jolt.GetBodyInterface(physics_system)
    fmt.println("body interface get")

    // Next we can create a rigid body to serve as the floor, we make a large box
    // Create the settings for the collision volume (the shape).
    // Note that for simple shapes (like boxes) you can also directly construct a BoxShape.
    // Create the shape
    // Add it to the world
    a := m.float3{100,1,100}
    floor_shape_settings := jolt.BoxShapeSettings_Create(&a)
    fmt.println("box shape settings create")
    floor_shape := jolt.ShapeSettings_CreateShape((^jolt.ShapeSettings)(floor_shape_settings))
    fmt.println("floor shape create")
    bcs : jolt.BodyCreationSettings

    in_p := m.float3{0,-1,0}
    in_r := m.float4{0,0,0,1}
    jolt.BodyCreationSettings_Set(&bcs,floor_shape,&in_p,&in_r,.MOTION_TYPE_STATIC,BroadPhaseLayers_Moving)
    floor := jolt.BodyInterface_CreateBody(body_interface,&bcs)
    fmt.println("create body floor")
    jolt.BodyInterface_AddBody(body_interface,jolt.Body_GetID(floor),.ACTIVATION_DONT_ACTIVATE)
    fmt.println("add body floor")
    
    // Now create a dynamic body to bounce on the floor
    // Note that this uses the shorthand version of creating and adding a body to the world
    sphere_shape_settings := jolt.SphereShapeSettings_Create(0.5)
    sss : jolt.BodyCreationSettings
    in_p = m.float3{0,2,0}
    in_r = m.float4{0,0,0,1}
    jolt.BodyCreationSettings_Set(&sss,jolt.ShapeSettings_CreateShape((^jolt.ShapeSettings)(sphere_shape_settings)),&in_p,&in_r,.MOTION_TYPE_DYNAMIC,BroadPhaseLayers_Moving)
    sphere_id = jolt.BodyInterface_CreateAndAddBody(body_interface,&sss,.ACTIVATION_ACTIVATE)
    fmt.println(sss)
    // Now you can interact with the dynamic body, in this case we're going to give it a velocity.
    // (note that if we had used CreateBody then we could have set the velocity straight on the body before adding it to the physics system)
    in_p = m.float3{0,-5,0}
    jolt.BodyInterface_SetLinearVelocity(body_interface,sphere_id,&in_p)
    linvel : m.float3
    jolt.BodyInterface_GetLinearVelocity(body_interface,sphere_id,&linvel)
    fmt.println(linvel)

    // We simulate the physics world in discrete time steps. 60 Hz is a good rate to update the physics system.
    //const float cDeltaTime = 1.0f / 60.0f;
    cDeltaTime : f32 = 1.0 / 60.0

    // Optional step: Before starting the physics simulation you can optimize the broad phase. This improves collision detection performance (it's pointless here because we only have 2 bodies).
    // You should definitely not call this every frame or when e.g. streaming in a new level section as it is an expensive operation.
    // Instead insert all new objects in batches instead of 1 at a time to keep the broad phase efficient.
    jolt.PhysicsSystem_OptimizeBroadPhase(physics_system)
    fmt.printf("end init")
}

update :: proc(){
    fmt.printf("Update")
    step := 0
    for jolt.BodyInterface_IsActive(body_interface,sphere_id){
        pos : m.float3
        jolt.BodyInterface_GetCenterOfMassPosition(body_interface,sphere_id,&pos)
        linvel : m.float3
        jolt.BodyInterface_GetLinearVelocity(body_interface,sphere_id,&linvel)
        fmt.printf("step %v : position : %v : linear velocity %v \n",step,pos,linvel)

        collision_steps := 1
        dt :f32 = 1.0 / 60.0
        jolt.PhysicsSystem_Update(physics_system,dt,collision_steps,0,jta,js)
    }
}

//interface and callback stuff
get_num_broad_pl :: proc "c" ()-> c.uint32_t{
    context = runtime.default_context()
    fmt.println("Called genum broad pl")
    return (c.uint32_t)(BroadPhaseLayers.NumLayers)
}

get_broad_phase_layer :: proc"c"(in_layer : jolt.ObjectLayer)->jolt.BroadPhaseLayer{
    return (jolt.BroadPhaseLayer)(broad_phase_layer_map[in_layer])
}

contact_added_test :: proc "c"(b : ^jolt.Body,b2 : ^jolt.Body,in_manifold : ^jolt.ContactManifold,io_settings : ^jolt.ContactSettings){
    context = runtime.default_context()
    fmt.printf("%v %v %v %v/n",b,b2,in_manifold,io_settings)
}

should_collide :: proc "c"(in_layer : jolt.ObjectLayer,in_layer2 : jolt.BroadPhaseLayer)->bool{
    context = runtime.default_context()
    fmt.println("Called should collide")
    switch int(in_layer){
        case (int)(BroadPhaseLayers_NonMoving):
            return (int(in_layer2) == int(BroadPhaseLayers_Moving))
        case int(BroadPhaseLayers_Moving):
            return true;
        case:
            //JPH_ASSERT(false);
            return false;
    }
    return false
}

should_collide_object_layer :: proc "c"(in_layer : jolt.ObjectLayer,in_layer2 : jolt.ObjectLayer)->bool{
    context = runtime.default_context()
    fmt.println("Called should collide")
        switch int(in_layer){
        case int(BroadPhaseLayers_NonMoving):
            return (int(in_layer2) == int(BroadPhaseLayers_Moving)) // Non moving only collides with moving
        case int(BroadPhaseLayers_Moving):
            return true; // Moving collides with everything
        case:
            //JPH_ASSERT(false);
            return false;
        }
    return false
}

// Each broadphase layer results in a separate bounding volume tree in the broad phase. You at least want to have
// a layer for non-moving and moving objects to avoid having to update a tree full of static objects every frame.
// You can have a 1-on-1 mapping between object layers and broadphase layers (like in this case) but if you have
// many object layers you'll be creating many broad phase trees, which is not efficient. If you want to fine tune
// your broadphase layers define JPH_TRACK_BROADPHASE_STATS and look at the stats reported on the TTY.
/*
namespace BroadPhaseLayers
{
    static constexpr BroadPhaseLayer NON_MOVING(0);
    static constexpr BroadPhaseLayer MOVING(1);
    static constexpr uint NUM_LAYERS(2);
};
*/

physics_system: ^jolt.PhysicsSystem
jta:            ^jolt.TempAllocator
js:             ^jolt.JobSystem
body_interface: ^jolt.BodyInterface

sphere_id : jolt.BodyID

BroadPhaseLayers :: enum c.uint8_t{
    NonMoving = 0,
    Moving = 1,
    NumLayers = 2,
}

BroadPhaseLayers_NonMoving: jolt.ObjectLayer : 0
BroadPhaseLayers_Moving:    jolt.ObjectLayer : 1
BroadPhaseLayers_NumLayers: jolt.ObjectLayer : 2

broad_phase_layer_map : map[jolt.ObjectLayer]BroadPhaseLayers

in_broad_phase_layer_interface:        jolt.BroadPhaseLayerInterfaceVTable
in_object_vs_broad_phase_layer_filter: jolt.ObjectVsBroadPhaseLayerFilterVTable
in_object_layer_pair_filter:           jolt.ObjectLayerPairFilterVTable

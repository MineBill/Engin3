package engine
import gl "vendor:OpenGL"
import "core:mem"
import "core:fmt"
import "core:log"
import tracy "packages:odin-tracy"
import "core:encoding/json"
import "core:os"

MAX_ENTITIES :: 1_000

EntityFlag :: enum {
    Static,
    Outlined,
}

EntityFlags :: bit_set[EntityFlag]

// The vtable for components.
ComponentVTable :: struct {
    init: #type proc(this: rawptr),

    // Called every frame
    update: #type proc(this: rawptr, delta: f64),

    // Called when the component is destroyed. Can happen if it is manually destroyed
    // or as a result of destroying the owning gameobject.
    destroy: #type proc(this: rawptr),

    // Called when a component property changes.
    prop_changed: #type proc(this: rawptr, prop: any),

    editor_ui: #type proc(this: rawptr),
}

component_default_init :: proc(this: rawptr) {}
component_default_update :: proc(this: rawptr, delta: f64) {}
component_default_destroy :: proc(this: rawptr) {}
component_default_prop_changed :: proc(this: rawptr, prop: any) {}
component_default_editor_ui :: proc(this: rawptr) {}

default_component_constructor :: proc() -> Component {
    tracy.Zone()
    return {
        enabled = true,
        init = component_default_init,
        update = component_default_update,
        destroy = component_default_destroy,
        prop_changed = component_default_prop_changed,
        editor_ui = component_default_editor_ui,
    }
}

Component :: struct {
    using vtable: ComponentVTable,

    enabled: bool,
    world: ^World,
    owner: Handle,
}

ComponentConstructor :: #type proc() -> rawptr

GameObject :: struct {
    components: map[typeid]^Component `json:"ignore"`,
    world: ^World `json:"ignore"`,
    handle: Handle,

    enabled: bool,
    name: DynamicString,
    flags: EntityFlags,

    transform: TransformComponent,
    parent: Handle,
    children: [dynamic]Handle,
}

Handle :: distinct uint

@(private = "file")
NOT_REGISTERED_MESSAGE :: "Component %v is not registered. Register the component with @(component) and define a construct proc with @(ctor_for=<C>)"

add_component_typeid :: proc(w: ^World, handle: Handle, id: typeid) {
    tracy.Zone()
    assert(id in COMPONENT_INDICES, fmt.tprintf(NOT_REGISTERED_MESSAGE, id))

    go := get_object(w, handle)

    go.components[id] = cast(^Component)get_component_constructor(id)()
    go.components[id].owner = handle
    go.components[id].world = w

    go.components[id]->init()
}

add_component_type :: proc(w: ^World, handle: Handle, $C: typeid) {
    tracy.Zone()
    assert(C in COMPONENT_INDICES, fmt.tprintf(NOT_REGISTERED_MESSAGE, typeid_of(C)))

    go := get_object(w, handle)

    go.components[C] = cast(^Component)get_component_constructor(C)()
    go.components[C].owner = handle
    go.components[C].world = w

    go.components[C]->init()
}

add_component :: proc {
    add_component_type,
    add_component_typeid,
}

get_component_type :: proc(w: ^World, handle: Handle, $C: typeid) -> ^C {
    tracy.Zone()
    if !has_component(w, handle, C) do return nil
    go := get_object(w, handle)
    return cast(^C)go.components[C]
}

get_component :: proc {
    get_component_type,
    // get_component_typeid,
}

get_or_add_component_type :: proc(w: ^World, handle: Handle, $C: typeid) -> ^C {
    tracy.Zone()
    if !has_component(w, handle, C) {
        add_component(w, handle, C)
    }
    return get_component(w, handle, C)
}

get_or_add_component :: proc {
    get_or_add_component_type,
}

remove_component_type :: proc(w: ^World, handle: Handle, $C: typeid) {
    remove_component_typeid(w, handle, C)
}

remove_component_typeid :: proc(w: ^World, handle: Handle, id: typeid) {
    tracy.Zone()
    assert(id in COMPONENT_INDICES, NOT_REGISTERED_MESSAGE)

    go := get_object(w, handle)

    component :=  go.components[id]
    if component.destroy != nil {
        component->destroy()
    }

    delete_key(&go.components, id)
    free(component)
}

remove_component :: proc {
    remove_component_type,
    remove_component_typeid,
}

has_component_type :: proc(w: ^World, handle: Handle, $C: typeid) -> bool {
    tracy.Zone()
    go := get_object(w, handle)
    return C in go.components
}

has_component_typeid :: proc(w: ^World, handle: Handle, id: typeid) -> bool {
    tracy.Zone()
    go := get_object(w, handle)
    return id in go.components
}

has_component :: proc {
    has_component_type,
    has_component_typeid,
}

World :: struct {
    objects: map[Handle]GameObject,
    // _objects: [dynamic]GameObject,
    // _map: map[Handle]int,
    root: Handle,

    next_handle: Handle,
}

create_world :: proc() -> (world: World) {
    tracy.Zone()
    world.root = world.next_handle
    world.objects[world.root] = GameObject{name = make_ds("Root"), transform = {
        local_scale = vec3{1, 1, 1},
    }}

    world.next_handle += 1
    return
}

destroy_world :: proc(world: ^World) {
}

world_update :: proc(world: ^World, delta: f64) {
    tracy.Zone()
    update_object :: proc(go: ^GameObject, handle: Handle, delta: f64) {
        tracy.Zone()
        update_transform(go, &go.transform, delta)
        for child_handle in go.children {
            child := get_object(go.world, child_handle)
            update_object(child, child_handle, delta)
        }

        for id, component in go.components {
            component->update(delta)
        }
    }

    root := &world.objects[world.root]
    update_object(root, world.root, delta)
}

get_object :: proc(world: ^World, handle: Handle) -> ^GameObject {
    if handle in world.objects {
        return &world.objects[handle]
    }
    return nil
}

add_child :: proc(world: ^World, parent: Handle, child: Handle) {
    parent_go := &world.objects[parent]
    append(&parent_go.children, child)

    child_go := &world.objects[child]
    child_go.parent = parent
}

new_object :: proc(world: ^World, name: string = "New GameObject", parent: Maybe(Handle) = nil) -> Handle {
    tracy.Zone()
    handle := world.next_handle
    world.objects[handle] = GameObject{name = make_ds(name)}
    world.next_handle += 1

    go := &world.objects[handle]
    if parent == nil {
        // go.parent = world.root
        add_child(world, world.root, handle)
    } else {
        // go.parent = parent.(Handle)
        add_child(world, parent.(Handle), handle)
    }

    go.world = world
    go.handle = handle
    go.enabled = true
    go.transform.local_scale = vec3{1, 1, 1}

    return handle
}

delete_object :: proc(world: ^World, handle: Handle) {
    tracy.Zone()
    go := get_object(world, handle)

    for child in go.children {
        delete_object(world, child)
    }
    if handle in world.objects {

        obj := world.objects[handle]
        log.debugf("Destroying '%v'", ds_to_string(obj.name))

        for id, comp in obj.components {
            if comp.destroy != nil {
                comp->destroy()
            }
        }
        
        delete_key(&world.objects, handle)
    }
}

// Scans the entire world and returns the first componment of type C it finds.
// If no such component exists, a nil pointer is returned.
find_first_component :: proc(world: ^World, $C: typeid) -> ^C {
    tracy.Zone()
    for obj_handle, &obj in world.objects {
        if has_component(world, obj_handle, C) {
            return get_component(world, obj_handle, C)
        }
    }

    return nil
}

serialize_world :: proc(world: World, file: string) {
    data, err := json.marshal(world, {
        spec = .JSON5,
    })
    if err != nil {
        log.error(err)
        return
    }

    os.write_entire_file(file, data)
}

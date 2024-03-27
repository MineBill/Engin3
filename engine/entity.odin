package engine
import gl "vendor:OpenGL"
import "core:mem"
import "core:fmt"
import "core:log"
import tracy "packages:odin-tracy"
import "core:encoding/json"
import "core:os"
import "core:runtime"
import "core:reflect"

MAX_ENTITIES :: 1_000

EntityFlag :: enum {
    Static,
    Outlined,
}

EntityFlags :: bit_set[EntityFlag; u64]

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

Entity :: struct {
    components: map[typeid]^Component,
    world: ^World,
    handle: Handle,
    id: UUID,

    enabled: bool,
    name: DynamicString,
    flags: EntityFlags,

    transform: TransformComponent,
    parent: Handle,
    children: [dynamic]Handle,
}

Handle :: UUID

@(private = "file")
NOT_REGISTERED_MESSAGE :: "Component %v is not registered. Register the component with @(component) and define a constructor proc with @(constructor=<C>)"

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

get_component_typeid :: proc(w: ^World, handle: Handle, id: typeid) -> ^Component {
    tracy.Zone()
    if !has_component(w, handle, id) do return nil
    go := get_object(w, handle)
    return go.components[id]
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
    // The name of this world/level.
    name: string,

    objects: map[Handle]Entity,
    root: Handle,
}

create_world :: proc(world: ^World, name: string = "World") {
    tracy.Zone()
    // world.root = generate_uuid()
    world^ = World{}
    world.name = name
    world.objects[world.root] = Entity{
        name = make_ds("Root"),
        transform = default_transform(),
        world = world,
    }

    return
}

destroy_world :: proc(world: ^World) {
}

world_update :: proc(world: ^World, delta: f64) {
    tracy.Zone()
    update_object :: proc(go: ^Entity, handle: Handle, delta: f64) {
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

get_object :: proc(world: ^World, handle: Handle) -> ^Entity {
    if handle in world.objects {
        return &world.objects[handle]
    }
    return nil
}

add_child :: proc(world: ^World, parent: Handle, child: Handle) {
    child_go := &world.objects[child]
    remove_child(world, child_go.parent, child)

    parent_go := &world.objects[parent]
    append(&parent_go.children, child)

    child_go.parent = parent
}

remove_child :: proc(world: ^World, parent: Handle, child: Handle) {
    entity := &world.objects[parent]
    for c, i in entity.children {
        if c == child {
            ordered_remove(&entity.children, i)
            return
        }
    }
}

new_object :: proc(world: ^World, name: string = "New Entity", parent: Maybe(Handle) = nil) -> Handle {
    tracy.Zone()
    // handle := world.next_handle
    id := generate_uuid()
    world.objects[id] = Entity{name = make_ds(name)}
    // world.next_handle += 1

    go := &world.objects[id]
    if parent == nil {
        // go.parent = world.root
        add_child(world, world.root, id)
    } else {
        // go.parent = parent.(Handle)
        add_child(world, parent.(Handle), id)
    }

    go.world = world
    go.handle = id
    go.id = id
    go.enabled = true
    go.transform.local_scale = vec3{1, 1, 1}

    return id
}

new_object_with_uuid :: proc(world: ^World, name: string = "New Entity", uuid: UUID, parent: Maybe(Handle) = nil) -> Handle {
    tracy.Zone()
    // handle := world.next_handle
    world.objects[uuid] = Entity{name = make_ds(name)}
    // world.next_handle += 1

    go := &world.objects[uuid]
    if parent == nil {
        // go.parent = world.root
        add_child(world, world.root, uuid)
    } else {
        // go.parent = parent.(Handle)
        add_child(world, parent.(Handle), uuid)
    }

    go.world = world
    go.handle = uuid
    go.id = uuid
    go.enabled = true
    go.transform.local_scale = vec3{1, 1, 1}

    return uuid
}

delete_object :: proc(world: ^World, handle: Handle) {
    tracy.Zone()
    go := get_object(world, handle)

    remove_child(world, go.parent, handle)

    for child in go.children {
        delete_object(world, child)
    }
    if handle in world.objects {

        obj := world.objects[handle]

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

import "core:strings"
import "core:io"

serialize_world :: proc(world: World, file: string) {
    log.debugf("Serializing world to file: %v", file)
    sb: strings.Builder
    strings.builder_init(&sb)

    w := strings.to_writer(&sb)

    opt: json.Marshal_Options
    opt.pretty = true
    opt.spec = .MJSON

    json.opt_write_key(w, &opt, "Name")
    json.marshal_to_writer(w, world.name, &opt)

    json.opt_write_iteration(w, &opt, 1)

    json.opt_write_key(w, &opt, "Entities")
    json.opt_write_start(w, &opt, '[')

    i := 0
    for id, go in world.objects {
        if id == 0 do continue
        json.opt_write_iteration(w, &opt, i)
        serialize_gameobject(w, go, &opt)
        i += 1
    }

    json.opt_write_end(w, &opt, ']')

    os.write_entire_file(file, transmute([]u8)strings.to_string(sb))
}

deserialize_world :: proc(world: ^World, file: string) -> (ok: bool) {
    log.debugf("Deserializing world from file: %v", file)

    destroy_world(world)
    create_world(world)

    scene_data := os.read_entire_file(file) or_return
    defer delete(scene_data)

    value, err := json.parse(scene_data, .MJSON, parse_integers = true)
    if err != nil do return false
    
    ResolvePair :: struct {entity, parent: UUID}
    parents_to_resolve := make([dynamic]ResolvePair)
    defer delete(parents_to_resolve)

    if root, ok := value.(json.Object); ok {
        world.name = root["Name"].(json.String)
        entities := root["Entities"].(json.Array)
        for entity in entities {
            en := entity.(json.Object)

            uuid := UUID(en["UUID"].(json.Integer))
            name := en["Name"].(json.String)
            flags := transmute(EntityFlags)(en["Flags"].(json.Integer))
            enabled := en["Enabled"].(json.Boolean)
            parent := UUID(en["Parent"].(json.Integer))

            id: UUID
            if parent in world.objects {
                id = new_object_with_uuid(world, name, uuid, parent)
            } else {
                id = new_object_with_uuid(world, name, uuid)
                append(&parents_to_resolve, ResolvePair{entity = id, parent = parent})
            }

            entity := get_object(world, id)
            entity.enabled = enabled
            entity.flags = flags

            transform := en["Transform"].(json.Object)

            get_vec3 :: proc(obj: json.Array) -> vec3 {
                x := f32(obj[0].(json.Float))
                y := f32(obj[1].(json.Float))
                z := f32(obj[2].(json.Float))
                return vec3{x, y, z}
            }

            // entity.transform.local_position = get_vec3(transform["Position"].(json.Array))
            // entity.transform.local_rotation = get_vec3(transform["Rotation"].(json.Array))
            // entity.transform.local_scale    = get_vec3(transform["Scale"].(json.Array))
            s := Serializer {
                object = transform,
            }
            serialize_transform(&entity.transform, false, &s)

            for component_name, data in en["Components"].(json.Object) {
                deserialize_component(world, entity, component_name, data.(json.Object))
            }
        }
    }

    for pair in parents_to_resolve {
        if pair.parent in world.objects {
            add_child(world, pair.parent, pair.entity)
        }
    }

    return true
}

serialize_gameobject :: proc(w: io.Writer, go: Entity, opt: ^json.Marshal_Options) {
    json.opt_write_start(w, opt, '{')

    json.opt_write_indentation(w, opt)
    json.opt_write_key(w, opt, "UUID")
    io.write_u64(w, u64(go.id))

    json.opt_write_iteration(w, opt, 1)

    json.opt_write_key(w, opt, "Name")
    io.write_quoted_string(w, ds_to_string(go.name), '"', nil, true)

    json.opt_write_iteration(w, opt, 2)

    json.opt_write_key(w, opt, "Flags")
    json.marshal_to_writer(w, go.flags, opt)

    json.opt_write_iteration(w, opt, 3)

    json.opt_write_key(w, opt, "Enabled")
    json.marshal_to_writer(w, go.enabled, opt)

    json.opt_write_iteration(w, opt, 4)

    json.opt_write_key(w, opt, "Parent")
    json.marshal_to_writer(w, go.parent, opt)

    json.opt_write_iteration(w, opt, 5)

    json.opt_write_key(w, opt, "Transform")
    s := Serializer {
        writer = w,
        opt = opt,
    }
    transform := go.transform
    serialize_transform(&transform, true, &s)

    json.opt_write_iteration(w, opt, 6)

    json.opt_write_key(w, opt, "Components")
    json.opt_write_start(w, opt, '{')
    i := 0
    for id, comp in go.components {
        json.opt_write_iteration(w, opt, i)
        serialize_component(w, opt, id, comp)
        i += 1
    }
    json.opt_write_end(w, opt, '}')

    json.opt_write_end(w, opt, '}')
}

serialize_component :: proc(w: io.Writer, opt: ^json.Marshal_Options, type: typeid, comp: ^Component) {
    ti := type_info_of(type)
    named, ok := ti.variant.(runtime.Type_Info_Named)
    assert(ok)

    base_info := runtime.type_info_base(ti)
    s, ok2 := base_info.variant.(runtime.Type_Info_Struct)
    assert(ok2)

    a := any{comp, ti.id}

    json.opt_write_key(w, opt, named.name)
    json.opt_write_start(w, opt, '{')

    json.opt_write_iteration(w, opt, 0)
    json.opt_write_key(w, opt, "Enabled")
    json.marshal_to_writer(w, comp.enabled, opt)

    if type in COMPONENT_SERIALIZERS {
        serializer := COMPONENT_SERIALIZERS[type]

        s := Serializer {
            writer = w,
            opt = opt,
        }

        serializer(comp, true, &s)
    }

    json.opt_write_end(w, opt, '}')
}

deserialize_component :: proc(world: ^World, go: ^Entity, component_name: string, component: json.Object) {
    enabled := component["Enabled"].(json.Boolean)

    if id, ok := get_component_typeid_from_name(component_name); ok {
        add_component(world, go.id, id)
        comp := get_component_typeid(world, go.id, id)

        if id in COMPONENT_SERIALIZERS {
            // Component has a serializer
            serializer := COMPONENT_SERIALIZERS[id]

            s := Serializer{object = component}
            serializer(comp, false, &s)
        }
    }
}

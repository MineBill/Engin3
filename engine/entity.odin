package engine
import gl "vendor:OpenGL"
import "core:mem"
import "core:fmt"
import tracy "packages:odin-tracy"
import "core:encoding/json"
import "core:os"
import "base:runtime"
import "core:reflect"
import "core:strings"
import "core:io"
import "core:slice"

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

    // Used by components to draw themselves in the editor.
    debug_draw: #type proc(this: rawptr, ctx: ^DebugDrawContext),

    // @Editor: Editor only field, allows a component to have custom imgui.
    editor_ui: #type proc(this: rawptr, editor: ^Editor, s: any) -> bool,

    // Copies the component and returns a new instance.
    copy: #type proc(this: rawptr) -> rawptr,
}

component_default_init :: proc(this: rawptr) {}
component_default_update :: proc(this: rawptr, delta: f64) {}
component_default_destroy :: proc(this: rawptr) {
    free(this)
}

component_default_prop_changed :: proc(this: rawptr, prop: any) {
    this := cast(^Component)this
    this.world.modified = true
}

component_default_editor_ui :: proc(this: rawptr, editor: ^Editor, s: any) -> bool {
    return imgui_draw_struct(editor, s)
}

component_default_debug_draw :: proc(this: rawptr, ctx: ^DebugDrawContext) {}

component_default_copy :: proc(this: rawptr) -> rawptr {
    assert(false, "Copy needs to be implemented")
    return nil
}

default_component_constructor :: proc() -> Component {
    tracy.Zone()
    return {
        enabled      = true,
        init         = component_default_init,
        update       = component_default_update,
        destroy      = component_default_destroy,
        prop_changed = component_default_prop_changed,
        editor_ui    = component_default_editor_ui,
        copy         = component_default_copy,
        debug_draw   = component_default_debug_draw,
    }
}

Component :: struct {
    using vtable: ComponentVTable,

    enabled: bool,
    world: ^World,
    owner: EntityHandle,
}

ComponentConstructor :: #type proc() -> rawptr

ComponentMap :: map[typeid]^Component
Children :: [dynamic]EntityHandle

@(LuaExport = {
    Type = {Light},
    Fields = {
        transform = "transform",
    },
})
Entity :: struct {
    components: ComponentMap `fmt:"-"`,
    world: ^World `fmt:"-"`,
    handle: EntityHandle,
    local_id: int,

    enabled: bool,
    name: DynamicString `fmt:"s"`,
    flags: EntityFlags,

    transform: TransformComponent `fmt:"-"`,
    parent: EntityHandle,
    children: Children,
}

EntityHandle :: distinct UUID

duplicate_entity :: proc(world: ^World, entity: EntityHandle) -> EntityHandle {
    en := get_object(world, entity)
    new := new_object(world, ds_to_string(en.name))
    new_en := get_object(world, new)

    new_en.transform = en.transform
    new_en.flags = en.flags
    new_en.enabled = en.enabled

    for id, component in en.components {
        copy_component(world, new, entity, id)
    }
    return new
}

@(private = "file")
NOT_REGISTERED_MESSAGE :: "Component %v is not registered. Register the component with @(component) and define a constructor proc with @(constructor=<C>)"

copy_component :: proc(w: ^World, handle, target: EntityHandle, id: typeid) {
    tracy.Zone()
    assert(id in COMPONENT_INDICES, fmt.tprintf(NOT_REGISTERED_MESSAGE, id))

    go := get_object(w, handle)

    target_component := get_component_typeid(w, target, id)
    if target_component == nil {
        log_error(LC.EntitySystem, "Cannot copy component %v from entity %v because it doesn't exist.", id, target)
        return
    }

    // go.components[id] = cast(^Component)get_component_constructor(id)()
    go.components[id] = cast(^Component)target_component->copy()
    go.components[id].owner = handle
    go.components[id].world = w

    // go.components[id]->init()
}

add_component_typeid :: proc(w: ^World, handle: EntityHandle, id: typeid) {
    tracy.Zone()
    assert(id in COMPONENT_INDICES, fmt.tprintf(NOT_REGISTERED_MESSAGE, id))

    go := get_object(w, handle)

    go.components[id] = cast(^Component)get_component_constructor(id)()
    go.components[id].owner = handle
    go.components[id].world = w

    // go.components[id]->init()
}

add_component_type :: proc(w: ^World, handle: EntityHandle, $C: typeid) {
    tracy.Zone()
    assert(C in COMPONENT_INDICES, fmt.tprintf(NOT_REGISTERED_MESSAGE, typeid_of(C)))

    go := get_object(w, handle)

    go.components[C] = cast(^Component)get_component_constructor(C)()
    go.components[C].owner = handle
    go.components[C].world = w

    // go.components[C]->init()
}

add_component :: proc {
    add_component_type,
    add_component_typeid,
}

get_component_type :: proc(w: ^World, handle: EntityHandle, $C: typeid) -> ^C {
    tracy.Zone()
    if !has_component(w, handle, C) do return nil
    go := get_object(w, handle)
    return cast(^C)go.components[C]
}

get_component_typeid :: proc(w: ^World, handle: EntityHandle, id: typeid) -> ^Component {
    tracy.Zone()
    if !has_component(w, handle, id) do return nil
    go := get_object(w, handle)
    return go.components[id]
}

get_component :: proc {
    get_component_type,
    // get_component_typeid,
}

get_or_add_component_type :: proc(w: ^World, handle: EntityHandle, $C: typeid) -> ^C {
    tracy.Zone()
    if !has_component(w, handle, C) {
        add_component(w, handle, C)
    }
    return get_component(w, handle, C)
}

get_or_add_component :: proc {
    get_or_add_component_type,
}

remove_component_type :: proc(w: ^World, handle: EntityHandle, $C: typeid) {
    remove_component_typeid(w, handle, C)
}

remove_component_typeid :: proc(w: ^World, handle: EntityHandle, id: typeid) {
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

has_component_type :: proc(w: ^World, handle: EntityHandle, $C: typeid) -> bool {
    tracy.Zone()
    go := get_object(w, handle)
    return C in go.components
}

has_component_typeid :: proc(w: ^World, handle: EntityHandle, id: typeid) -> bool {
    tracy.Zone()
    go := get_object(w, handle)
    return id in go.components
}

has_component :: proc {
    has_component_type,
    has_component_typeid,
}

when USE_EDITOR {
    WorldEditorData :: struct {
        modified: bool,
        file_path: string,
    }
} else {
    WorldEditorData :: struct {}
}

@(asset = {
    ImportFormats = ".scene",
})
World :: struct {
    using base: Asset,

    // The name of this world/level.
    name: string,

    objects: map[EntityHandle]Entity,
    local_id_to_uuid: map[int]EntityHandle,
    next_local_id: int,
    root: EntityHandle,

    ambient_color: Color,

    ssao_data: struct {
        radius: f32,
        bias: f32,
    },

    using editor_data: WorldEditorData,
}

// @(constructor=World)
// new_world :: proc() -> ^Asset {
//     // world: 
// }

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
    world.next_local_id = 1

    return
}

destroy_world :: proc(world: ^World) {
    delete(world.name)
    delete_object(world, world.root)
    delete(world.objects)
    delete(world.file_path)
}

copy_world :: proc(source: ^World) -> (new: World) {
    new.name = strings.clone(source.name)
    new.root = source.root

    new.file_path = source.file_path
    new.next_local_id = source.next_local_id

    return
}

world_update :: proc(world: ^World, delta: f64, update_components := true) {
    tracy.Zone()
    update_object :: proc(go: ^Entity, handle: EntityHandle, delta: f64, update_components: bool) {
        tracy.Zone()
        update_transform(go, &go.transform, delta)
        for child_handle in go.children {
            child := get_object(go.world, child_handle)
            update_object(child, child_handle, delta, update_components)
        }

        if update_components {
            for id, component in go.components {
                component->update(delta)
            }
        }
    }
    if world.objects == nil || len(world.objects) == 0 {
        return
    }

    root := &world.objects[world.root]
    update_object(root, world.root, delta, update_components)
}

world_init_components :: proc(world: ^World) {
    tracy.Zone()
    update_object :: proc(go: ^Entity, handle: EntityHandle) {
        tracy.Zone()
        for child_handle in go.children {
            child := get_object(go.world, child_handle)
            update_object(child, child_handle)
        }

        for id, component in go.components {
            component->init()
        }
    }

    root := &world.objects[world.root]
    update_object(root, world.root)
}

get_object :: proc(world: ^World, handle: EntityHandle) -> ^Entity {
    if handle in world.objects {
        return &world.objects[handle]
    }
    return nil
}

get_entity :: get_object

add_child :: proc(world: ^World, parent: EntityHandle, child: EntityHandle) {
    tracy.Zone()
    child_go := &world.objects[child]
    remove_child(world, child_go.parent, child)

    parent_go := &world.objects[parent]
    append(&parent_go.children, child)

    child_go.parent = parent
}

remove_child :: proc(world: ^World, parent: EntityHandle, child: EntityHandle) {
    tracy.Zone()
    entity := &world.objects[parent]
    for c, i in entity.children {
        if c == child {
            ordered_remove(&entity.children, i)
            return
        }
    }
}

reparent_entity :: proc(world: ^World, entity_h, new_parent_h: EntityHandle) {
    entity := get_object(world, entity_h)

    remove_child(world, entity.parent, entity_h)
    add_child(world, new_parent_h, entity_h)
}

new_object :: proc(world: ^World, name: string = "New Entity", parent: Maybe(EntityHandle) = nil) -> EntityHandle {
    tracy.Zone()
    id := EntityHandle(generate_uuid())
    world.objects[id] = Entity{name = make_ds(name)}

    go := &world.objects[id]

    if p, ok := parent.(EntityHandle); ok {
        add_child(world, p, id)
    } else {
        add_child(world, world.root, id)
    }

    go.world = world
    go.handle = id
    go.local_id = world.next_local_id
    go.enabled = true
    go.transform.local_scale = vec3{1, 1, 1}

    world.next_local_id += 1
    world.local_id_to_uuid[go.local_id] = go.handle

    return id
}

new_object_with_uuid :: proc(world: ^World, name: string = "New Entity", handle: EntityHandle, parent: Maybe(EntityHandle) = nil) -> EntityHandle {
    tracy.Zone()
    // handle := world.next_handle
    world.objects[handle] = Entity{name = make_ds(name)}
    // world.next_handle += 1

    go := &world.objects[handle]
    if parent == nil {
        // go.parent = world.root
        add_child(world, world.root, handle)
    } else {
        // go.parent = parent.(EntityHandle)
        add_child(world, parent.(EntityHandle), handle)
    }

    go.world = world
    go.handle = handle
    go.enabled = true
    go.transform.local_scale = vec3{1, 1, 1}

    go.local_id = world.next_local_id
    world.next_local_id += 1
    world.local_id_to_uuid[go.local_id] = go.handle

    return handle
}

delete_object :: proc(world: ^World, handle: EntityHandle) {
    tracy.Zone()
    go := get_object(world, handle)
    if go == nil do return

    remove_child(world, go.parent, handle)

    children := make([dynamic]EntityHandle, len(go.children))
    copy(children[:], go.children[:])
    defer delete(children)

    for child in children {
        child_entity := get_object(world, child)
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

    delete_ds(go.name)
    delete(go.children)
    delete(go.components)
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
    s: SerializeContext
    serialize_init(&s)
    defer serialize_deinit(&s)

    serialize_begin_table(&s, "Scene")
    {
        serialize_do_field(&s, "Name", world.name)

        serialize_begin_table(&s, "Environment")
        {
            serialize_do_field(&s, "AmbientColor", world.ambient_color)

            serialize_begin_table(&s, "SSAO")
            serialize_do_field(&s, "Radius", world.ssao_data.radius)
            serialize_do_field(&s, "Bias", world.ssao_data.bias)
            serialize_end_table(&s)
        }
        serialize_end_table(&s)

        serialize_begin_array(&s, "Entities")
        {
            i := 0
            keys, err := slice.map_keys(world.objects, context.temp_allocator)
            assert(err == nil)
            slice.sort_by(keys, proc(i, j: EntityHandle) -> bool {
                return i < j
            })
            for id in keys {
                if id == 0 do continue
                en := &world.objects[id]
                if id == 0 do continue
                serialize_begin_table_int(&s, i)
                serialize_entity(en, &s)
                serialize_end_table_int(&s)
                i += 1
            }
        }
        serialize_end_array(&s)
    }
    serialize_end_table(&s)

    serialize_dump(&s, file)
}

deserialize_world :: proc(world: ^World, file: string) -> bool {
    destroy_world(world)
    create_world(world)
    world.file_path = strings.clone(file)

    ResolvePair :: struct {entity, parent: EntityHandle}
    parents_to_resolve := make([dynamic]ResolvePair)
    defer delete(parents_to_resolve)

    s: SerializeContext
    serialize_init_file(&s, file)
    defer serialize_deinit(&s)

    serialize_begin_table(&s, "Scene")
    {
        serialize_do_field(&s, "Name", world.name)

        if serialize_begin_table(&s, "Environment") {
            if color, ok := serialize_get_field(&s, "AmbientColor", Color); ok {
                world.ambient_color = color
            }

            if serialize_begin_table(&s, "SSAO") {
                if radius, ok := serialize_get_field(&s, "Radius", f32); ok {
                    world.ssao_data.radius = radius
                }
                if bias, ok := serialize_get_field(&s, "Bias", f32); ok {
                    world.ssao_data.bias = bias
                }
                serialize_end_table(&s)
            }
            serialize_end_table(&s)
        }

        serialize_begin_array(&s, "Entities")
        {
            len := serialize_get_array(&s)
            for i in 0..<len {
                serialize_begin_table_int(&s, i)

                uuid,  _ := serialize_get_field(&s, "UUID", u64)
                name,  _ := serialize_get_field(&s, "Name", string)
                defer delete(name)
                flags, _ := serialize_get_field(&s, "Flags", EntityFlags)
                enabled, _ := serialize_get_field(&s, "Enabled", bool)
                parent, _ := serialize_get_field(&s, "Parent", u64)

                id: EntityHandle
                if EntityHandle(parent) in world.objects {
                    id = new_object_with_uuid(world, name, EntityHandle(uuid), EntityHandle(parent))
                } else {
                    id = new_object_with_uuid(world, name, EntityHandle(uuid))
                    append(&parents_to_resolve, ResolvePair{entity = id, parent = EntityHandle(parent)})
                }

                entity := get_object(world, id)
                entity.enabled = enabled
                entity.flags = flags

                if serialize_begin_table(&s, "Transform") {
                    if position, ok := serialize_get_field(&s, "LocalPosition", vec3); ok {
                        entity.transform.local_position = position
                    }
                    if rotation, ok := serialize_get_field(&s, "LocalRotation", vec3); ok {
                        entity.transform.local_rotation = rotation
                    }
                    if scale, ok := serialize_get_field(&s, "LocalScale", vec3); ok {
                        entity.transform.local_scale = scale
                    }
                    serialize_end_table(&s)
                }

                if serialize_begin_table(&s, "Components") {
                    for key in serialize_get_keys(&s) {
                        serialize_begin_table(&s, key)
                        deserialize_component(&s, key, world, entity)
                        serialize_end_table(&s)
                    }
                    serialize_end_table(&s)
                }

                serialize_end_table_int(&s)
            }
        }
        serialize_end_array(&s)
    }
    serialize_end_table(&s)

    for pair in parents_to_resolve {
        if pair.parent in world.objects {
            add_child(world, pair.parent, pair.entity)
        }
    }
    return true
}

serialize_entity :: proc(entity: ^Entity, s: ^SerializeContext) {
    serialize_begin_table(s, "Transform")
        serialize_do_field(s, "LocalPosition", entity.transform.local_position)
        serialize_do_field(s, "LocalRotation", entity.transform.local_rotation)
        serialize_do_field(s, "LocalScale", entity.transform.local_scale)
    serialize_end_table(s)

    serialize_begin_table(s, "Components")
    {
        i := 0
        for id, component in entity.components {
            serialize_component(component, id, s)
            i += 1
        }
    }
    serialize_end_table(s)

    serialize_do_field(s, "UUID", entity.handle)
    serialize_do_field(s, "Name", ds_to_string(entity.name))

    flags := entity.flags
    flags -= {.Outlined}
    serialize_do_field(s, "Flags", flags)
    serialize_do_field(s, "Enabled", entity.enabled)
    serialize_do_field(s, "Parent", entity.parent)
}

serialize_component :: proc(component: ^Component, id: typeid, s: ^SerializeContext) {
    ti := type_info_of(id)
    named, ok := ti.variant.(runtime.Type_Info_Named)
    assert(ok)

    base_info := runtime.type_info_base(ti)
    struct_info, ok2 := base_info.variant.(runtime.Type_Info_Struct)
    assert(ok2)

    a := any{component, ti.id}

    serialize_begin_table(s, named.name)

    serialize_do_field(s, "Enabled", component.enabled)

    if id in COMPONENT_SERIALIZERS {
        serializer := COMPONENT_SERIALIZERS[id]

        serializer(component, true, s)
    }

    serialize_end_table(s)
}

deserialize_component :: proc(s: ^SerializeContext, name: string, world: ^World, entity: ^Entity) {
    tracy.Zone()
    enabled: bool
    serialize_do_field(s, "Enabled", enabled)

    if id, ok := get_component_typeid_from_name(name); ok {
        add_component(world, entity.handle, id)
        comp := get_component_typeid(world, entity.handle, id)

        if id in COMPONENT_SERIALIZERS {
            // Component has a serializer
            serializer := COMPONENT_SERIALIZERS[id]
            serializer(comp, false, s)
        }
    }
}

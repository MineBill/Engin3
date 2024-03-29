package meta
import "core:odin/ast"
import "core:odin/parser"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:fmt"
import "core:log"
import "core:slice"

Visitor :: struct {
    pkg: ^ast.Package,
    pkgs_seen: map[string]string,
    imports: [dynamic]string,
}

Struct :: struct {
    name: string,
    attrs: [dynamic]Attribute,
}

Proc :: struct {
    name: string,
    attrs: [dynamic]Attribute,
}

main :: proc() {
    context.logger = log.create_console_logger()
    package_path := os.args[1]

    pkg, ok := parser.parse_package_from_path(package_path)
    assert(ok)

    structs: [dynamic]Struct
    procs: [dynamic]Proc
    for name, &file in pkg.files {
        extract_structs_and_procs(file, &structs, &procs)
    }

    slice.sort_by_cmp(structs[:], proc(i, j: Struct) -> slice.Ordering {
        if i.name == j.name do return .Equal
        if i.name < j.name do return .Less
        if i.name > j.name do return .Greater
        unreachable()
    })

    slice.sort_by_cmp(procs[:], proc(i, j: Proc) -> slice.Ordering {
        if i.name == j.name do return .Equal
        if i.name < j.name do return .Less
        if i.name > j.name do return .Greater
        unreachable()
    })

    sb: strings.Builder
    strings.builder_init(&sb)

    strings.write_string(&sb, "package engine\n")
    strings.write_string(&sb, "// === AUTO GENERATED - DO NOT MODIFY ===\n")
    strings.write_string(&sb, "// === AUTO GENERATED - DO NOT MODIFY ===\n")
    strings.write_string(&sb, "// === AUTO GENERATED - DO NOT MODIFY ===\n")
    strings.write_string(&sb, "\n")

    strings.write_string(&sb, "COMPONENT_INDICES : map[typeid]int = {\n")

    for s, i in structs do if has_attr_name(s, "component") {
        strings.write_string(&sb, fmt.tprintf("\ttypeid_of(%v) = %v,\n", s.name, i))
    }

    strings.write_string(&sb, "}\n\n")

    strings.write_string(&sb, "COMPONENTS : []typeid = {\n")

    for s, i in structs do if has_attr_name(s, "component") {
        strings.write_string(&sb, fmt.tprintf("\t%v = typeid_of(%v),\n", i, s.name))
    }

    strings.write_string(&sb, "}\n\n")

    // Generate a map that contains "constructors" for all components. These "constructors"
    // are responsible for wiring up the init/update/destroy procs.
    strings.write_string(&sb, "// i know 💀\n")
    strings.write_string(&sb, "COMPONENT_CONSTRUCTORS : []Constructor = {\n")

    for s, i in structs do if has_attr_name(s, "component") {
        // Find the ctor for the struct
        ctor: Maybe(string)
        for p in procs {
            if has_attr_name(p, "constructor") {
                if get_attr_value_proc(p, "constructor") == s.name {
                    ctor = p.name
                }
            }
        }

        if name, ok := ctor.(string); ok {
            strings.write_string(&sb, fmt.tprintf("\t{{%v,  typeid_of(%v)}},\n", name, s.name))
        }
    }

    strings.write_string(&sb, "}\n\n")

    strings.write_string(&sb, "COMPONENT_CATEGORIES : []Category = {\n")

    structs_with_category := make([dynamic]Struct)

    for s, i in structs do if has_attr_name(s, "component") {
        value := get_attr_value(s, "component")
        if len(value) == 0 do continue
        append(&structs_with_category, s)
    }

    slice.sort_by_cmp(structs_with_category[:], proc(i, j: Struct) -> slice.Ordering {
        lhs := get_attr_value(i, "component")
        rhs := get_attr_value(j, "component")
        return slice.Ordering(strings.compare(lhs, rhs))
    })

    // NOTE(minebill): Sort this? 
    for s, i in structs_with_category {
        value := get_attr_value(s, "component")

        strings.write_string(&sb, fmt.tprintf("\t{{%v, typeid_of(%v)}},\n", value, s.name))
    }

    strings.write_string(&sb, "}\n\n")

    strings.write_string(&sb, "COMPONENT_NAMES : map[typeid]string = {\n")

    for s, i in structs do if has_attr_name(s, "component") {
        strings.write_string(&sb, fmt.tprintf("\ttypeid_of(%v) = \"%v\",\n", s.name, s.name))
    }

    strings.write_string(&sb, "}\n\n")

    strings.write_string(&sb, "COMPONENT_SERIALIZERS : map[typeid]ComponentSerializer = {\n")

    for p, i in procs do if has_attr_name(p, "serializer") {
        component := get_attr_value(p, "serializer")
        assert(len(component) != 0)

        strings.write_string(&sb, fmt.tprintf("\ttypeid_of(%v) = %v,\n", component, p.name))
    }

    strings.write_string(&sb, "}\n")

    strings.write_string(&sb, `
Category :: struct {
    name: string,
    id:   typeid,
}

Constructor :: struct {
    ctor: ComponentConstructor,
    id:   typeid,
}

@(private = "file")
get_component_constructor_type :: proc($C: typeid) -> ComponentConstructor {
    return get_component_constructor_typeid(C)
}

@(private = "file")
get_component_constructor_typeid :: proc(id: typeid) -> ComponentConstructor {
    for constructor in COMPONENT_CONSTRUCTORS {
        if constructor.id == id {
            return constructor.ctor
        }
    }
    return nil
}

get_component_constructor :: proc {
    get_component_constructor_type,
    get_component_constructor_typeid,
}

@(private = "file")
get_component_category_type :: proc($C: typeid) -> (category: string, ok: bool) {
    category, ok = get_component_category_typeid(C)
    return
}

@(private = "file")
get_component_category_typeid :: proc(id: typeid) -> (category: string, ok: bool) {
    for category in COMPONENT_CATEGORIES {
        if category.id == id {
            return category.name, true
        }
    }
    return "", false
}

// Returns a peepgas
get_component_category :: proc {
    get_component_category_type,
    get_component_category_typeid,
}

get_component_typeid_from_name :: proc(name: string) -> (id: typeid, ok: bool) {
    for c_id, c_name in COMPONENT_NAMES {
        if c_name == name {
            return c_id, true
        }
    }
    return {}, false
}
`)

    src := strings.to_string(sb)
    os.write_entire_file("engine/entity_generated.odin", transmute([]byte)src)

    // ASSET STUFF GENERATION

    strings.builder_reset(&sb)
    
    strings.write_string(&sb, "package engine\n")
    strings.write_string(&sb, "// === AUTO GENERATED - DO NOT MODIFY ===\n")
    strings.write_string(&sb, "// === AUTO GENERATED - DO NOT MODIFY ===\n")
    strings.write_string(&sb, "// === AUTO GENERATED - DO NOT MODIFY ===\n")
    strings.write_string(&sb, "\n")

    strings.write_string(&sb, "ASSET_LOADERS : map[typeid]AssetLoader = {\n")
    for p in procs do if has_attr_name(p, "loader") {
        asset := get_attr_value(p, "loader")

        strings.write_string(&sb, fmt.tprintf("\ttypeid_of(%v) = %v,\n", asset, p.name))
    }
    strings.write_string(&sb, "}\n")

    src = strings.to_string(sb)
    os.write_entire_file("engine/assets_generated.odin", transmute([]byte)src)
}

_ :: proc() {
    COMPONENT_CATEGORIES : []Category = {
        {"Core", typeid_of(struct{})},
    }

    Category :: struct {
        name: string,
        id:   typeid,
    }

    for cat in COMPONENT_CATEGORIES {
        _ = cat.name
    }
}

extract_structs_and_procs :: proc(f: ^ast.File, structs: ^[dynamic]Struct, procs: ^[dynamic]Proc) {
    for decl in f.decls {
        val, ok := decl.derived_stmt.(^ast.Value_Decl)
        if !ok do continue
        if len(val.attributes) == 0 do continue
        if len(val.values) == 0 do continue

        name := f.src[val.names[0].pos.offset:val.names[0].end.offset]
        #partial switch hmm in val.values[0].derived_expr {
        case ^ast.Struct_Type:
            attrs := get_attributes(f, val)

            append(structs, Struct {
                name = name,
                attrs = attrs,
            })
        case ^ast.Proc_Lit:
            attrs := get_attributes(f, val)

            append(procs, Proc {
                name = name,
                attrs = attrs,
            })
        }
    }
}

has_entity_attr :: proc(f: ^ast.File, v: ^ast.Value_Decl) -> (bool, string) {
    for attr in v.attributes {
        src := f.src[attr.pos.offset:attr.end.offset]

        for elem in attr.elems {
            ident, iok := elem.derived.(^ast.Ident)
            if !iok do continue
            if ident.name == "entity" || ident.name == "component" {
                return true, ident.name
            }
        }
    }
    return false, ""
}

Attribute :: struct {
    name: string,
    value: string,
}

has_attr_name_struct :: proc(s: Struct, name: string) -> bool {
    for attr in s.attrs {
        if attr.name == name {
            return true
        }
    }
    return false
}

has_attr_name_proc :: proc(s: Proc, name: string) -> bool {
    for attr in s.attrs {
        if attr.name == name {
            return true
        }
    }
    return false
}

has_attr_name :: proc {
    has_attr_name_proc,
    has_attr_name_struct,
}

get_attr_value_proc :: proc(p: Proc, key: string) -> string {
    for attr in p.attrs {
        if attr.name == key {
            return attr.value
        }
    }
    return ""
}

get_attr_value_struct :: proc(p: Struct, key: string) -> string {
    for attr in p.attrs {
        if attr.name == key {
            return attr.value
        }
    }
    return ""
}

get_attr_value :: proc {
    get_attr_value_proc,
    get_attr_value_struct,
}

get_attributes :: proc(f: ^ast.File, v: ^ast.Value_Decl) -> (attrs: [dynamic]Attribute) {
    for attr in v.attributes {
        for elem in attr.elems {
            #partial switch hmm in elem.derived {
            case ^ast.Ident:
                append(&attrs, Attribute {
                    name = hmm.name,
                })

            case ^ast.Field_Value:
                src := f.src[hmm.field.pos.offset:hmm.field.end.offset]
                value := f.src[hmm.value.pos.offset:hmm.value.end.offset]

                append(&attrs, Attribute {
                    name = src,
                    value = value,
                })
            }
        }
    }
    return
}

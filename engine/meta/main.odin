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
                if get_attr_value(p, "constructor").(string) == s.name {
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
        if value, ok := get_attr_value(s, "component").(string); ok {
            append(&structs_with_category, s)
        }
    }

    slice.sort_by_cmp(structs_with_category[:], proc(i, j: Struct) -> slice.Ordering {
        lhs := get_attr_value(i, "component").(string)
        rhs := get_attr_value(j, "component").(string)
        return slice.Ordering(strings.compare(lhs, rhs))
    })

    // NOTE(minebill): Sort this? 
    for s, i in structs_with_category {
        value := get_attr_value(s, "component").(string)

        strings.write_string(&sb, fmt.tprintf("\t{{\"%v\", typeid_of(%v)}},\n", value, s.name))
    }

    strings.write_string(&sb, "}\n\n")

    strings.write_string(&sb, "COMPONENT_NAMES : map[typeid]string = {\n")

    for s, i in structs do if has_attr_name(s, "component") {
        strings.write_string(&sb, fmt.tprintf("\ttypeid_of(%v) = \"%v\",\n", s.name, s.name))
    }

    strings.write_string(&sb, "}\n\n")

    strings.write_string(&sb, "COMPONENT_SERIALIZERS : map[typeid]ComponentSerializer = {\n")

    for p, i in procs do if has_attr_name(p, "serializer") {
        component := get_attr_value(p, "serializer").(string)
        assert(len(component) != 0)
        context.user_ptr = &component

         if slice.any_of_proc(structs[:], proc(s: Struct) -> bool {
            component := cast(^string)context.user_ptr
            if has_attr_name(s, "component") {
                if s.name == component^ {
                    return true
                }
            }
            return false
        }) {
            strings.write_string(&sb, fmt.tprintf("\ttypeid_of(%v) = %v,\n", component, p.name))
         }
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

    strings.write_string(&sb, "ASSET_CONSTRUCTORS : map[typeid]proc() -> ^Asset = {\n")

    for s, i in structs do if has_attr_name(s, "asset") {
        // Find the ctor for the struct
        ctor: Maybe(string)
        for p in procs {
            if has_attr_name(p, "constructor") {
                if get_attr_value(p, "constructor").(string) == s.name {
                    ctor = p.name
                }
            }
        }

        if name, ok := ctor.(string); ok {
            strings.write_string(&sb, fmt.tprintf("\ttypeid_of(%v) = %v,\n", s.name, name))
        }
    }

    strings.write_string(&sb, "}\n\n")

    strings.write_string(&sb, "ASSET_LOADERS : map[AssetType]AssetLoader = {\n")
    for p in procs do if has_attr_name(p, "loader") {
        asset := get_attr_value(p, "loader").(string)

        strings.write_string(&sb, fmt.tprintf("\t.%v = %v,\n", asset, p.name))
    }
    strings.write_string(&sb, "}\n")

    strings.write_string(&sb, "\n")

    strings.write_string(&sb, "ASSET_IMPORTERS : map[AssetType]AssetImporter = {\n")
    for p in procs do if has_attr_name(p, "importer") {
        asset := get_attr_value(p, "importer").(string)

        strings.write_string(&sb, fmt.tprintf("\t.%v = %v,\n", asset, p.name))
    }
    strings.write_string(&sb, "}\n")

    strings.write_string(&sb, "\n")

    fmt.sbprintf(&sb, "RAW_TYPE_TO_ASSET_TYPE := map[typeid]AssetType {{\n")
    for s in structs do if has_attr_name(s, "asset") {
        fmt.sbprintf(&sb, "\ttypeid_of(%v) = .%v,\n", s.name, s.name)
    }
    fmt.sbprintf(&sb, "}}\n")

    strings.write_string(&sb, "\n")

    fmt.sbprintf(&sb, "ASSET_TYPE_TO_TYPEID := map[AssetType]typeid {{\n")
    for s in structs do if has_attr_name(s, "asset") {
        fmt.sbprintf(&sb, "\t.%v = typeid_of(%v),\n", s.name, s.name)
    }
    fmt.sbprintf(&sb, "}}\n")

    strings.write_string(&sb, "\n")

    fmt.sbprintf(&sb, "SUPPORTED_ASSETS := map[string]AssetType {{\n")
    for s in structs do if has_attr_name(s, "asset") {
        if attributes, ok := get_attr_value(s, "asset").(map[string]AttributeValue); ok {
            if "ImportFormats" in attributes {
                formats := attributes["ImportFormats"].(string)
                for format in strings.split(formats, ",") {
                    format := strings.trim_space(format)
                    format = strings.trim(format, "\"")

                    fmt.sbprintf(&sb, "\t\"%v\" = .%v,\n", format, s.name)
                }
            }
        }
    }
    fmt.sbprintf(&sb, "}}\n")

    strings.write_string(&sb, "\n")

    strings.write_string(&sb, "ASSET_SERIALIZERS : map[typeid]AssetSerializer = {\n")

    for p, i in procs do if has_attr_name(p, "serializer") {
        component := get_attr_value(p, "serializer").(string)
        assert(len(component) != 0)
        context.user_ptr = &component

         if slice.any_of_proc(structs[:], proc(s: Struct) -> bool {
            component := cast(^string)context.user_ptr
            if has_attr_name(s, "asset") {
                if s.name == component^ {
                    return true
                }
            }
            return false
        }) {
            strings.write_string(&sb, fmt.tprintf("\ttypeid_of(%v) = %v,\n", component, p.name))
         }
    }

    strings.write_string(&sb, "}\n")

    strings.write_string(&sb, "\n")

    fmt.sbprintf(&sb, "AssetType :: enum {{\n")
        fmt.sbprintf(&sb, "\t%v,\n\n", "Invalid")
    for s in structs do if has_attr_name(s, "asset") {
        fmt.sbprintf(&sb, "\t%v,\n", s.name)
    }
    fmt.sbprintf(&sb, "}}\n")

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

AttributeValue :: union {
    string,
    [dynamic]AttributeValue,
    map[string]AttributeValue,
}

Attribute :: struct {
    name: string,
    value: AttributeValue,
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

get_attr_value_proc :: proc(p: Proc, key: string) -> AttributeValue {
    for attr in p.attrs {
        if attr.name == key {
            return attr.value
        }
    }
    return ""
}

get_attr_value_struct :: proc(p: Struct, key: string) -> AttributeValue {
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
            name := get_attr_name(f, elem)
            value := parse_attrib_val(f, elem)
            append(&attrs, Attribute {
                name = name,
                value = value,
            })
        }
    }
    return
}

parse_attrib_object :: proc(root: ^ast.File, obj: ^ast.Comp_Lit) -> (result: map[string]AttributeValue) {
    result = make(type_of(result))
    for elem, i in obj.elems {
        name := get_attr_name(root, elem)
        result[name] = parse_attrib_val(root, elem)
    }
    return
}

get_attr_name :: proc(root: ^ast.File, elem: ^ast.Expr) -> (name: string) {
    #partial switch x in elem.derived  {
        case ^ast.Field_Value: {
            attr := x.field.derived.(^ast.Ident)
            name = attr.name
        }

        case ^ast.Ident: {
            name = x.name
        }
    }
    return
}

parse_attrib_val :: proc(f: ^ast.File, obj: ^ast.Expr) -> AttributeValue {
    #partial switch hmm in obj.derived {
    case ^ast.Ident:
        return hmm.name

    case ^ast.Field_Value:
        #partial switch v in hmm.value.derived {
        case ^ast.Basic_Lit:
            return strings.trim(v.tok.text, "\"")
        case ^ast.Ident:
            return f.src[v.pos.offset:v.end.offset]
        case ^ast.Comp_Lit:
            return parse_attrib_object(f, v)
        }

        // src := f.src[hmm.field.pos.offset:hmm.field.end.offset]
        // value := f.src[hmm.value.pos.offset:hmm.value.end.offset]

        // append(&attrs, Attribute {
        //     name = src,
        //     value = value,
        // })
    }
    return nil
}

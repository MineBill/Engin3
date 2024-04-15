package mani_generator

import strings "core:strings"
import fmt "core:fmt"
import filepath "core:path/filepath"
import os "core:os"
import json "core:encoding/json"
import "core:slice"

DEFAULT_PROC_ATTRIBUTES := Attributes {}

// Note(Dragos): This should change
DEFAULT_STRUCT_ATTRIBUTES := Attributes {
    "Type" = Attributes {
        "Full" = nil, 
        "Light" = nil,
    },
}

GeneratorConfig :: struct {
    input_directory: string,
    meta_directory: string,
    show_timings: bool,
    files: map[string]PackageFile,
    lua_types: map[string]string, // Key: odin type

    odin_ext: string,
    lua_ext: string,

    declared_modules: map[string]struct{},
    methods: map[string][dynamic]ProcedureExport, // Exported struct name -> Method Proc
}

PackageFile :: struct {
    builder: strings.Builder,
    filename: string,
    imports: map[string]FileImport, // Key: import package name; Value: import text

    // Lua LSP metadata
    lua_filename: string,
    lua_builder: strings.Builder,
}

package_file_make :: proc(path: string, luaPath: string) -> PackageFile {
    return PackageFile {
        builder = strings.builder_make(), 
        filename = path,
        imports = make(map[string]FileImport),

        lua_builder = strings.builder_make(),
        lua_filename = luaPath,
    }
}

create_config_from_args :: proc() -> (result: GeneratorConfig) {
    result = GeneratorConfig{}
    for arg in os.args {
        if arg[0] == '-' {
            pair := strings.split(arg, ":", context.temp_allocator)
            switch pair[0] {
                case "-show-timings": {
                    result.show_timings = true
                }
            }
        } else {
            result.input_directory = arg
            config_from_json(&result, arg)
        }
    }
    return
}

config_from_json :: proc(config: ^GeneratorConfig, file: string) {
    data, ok := os.read_entire_file(file, context.temp_allocator)
    if !ok {
        fmt.printf("Failed to read config file\n")
        return
    }
    str := strings.clone_from_bytes(data, context.temp_allocator)
    obj, err := json.parse_string(data = str, allocator = context.temp_allocator)
    if err != .None {
        return
    }

    root := obj.(json.Object)
    config.input_directory = strings.clone(root["dir"].(json.String))
    config.meta_directory = strings.clone(root["meta_dir"].(json.String))
    config.odin_ext = strings.clone(root["odin_ext"].(json.String) or_else "manigen.odin")
    config.lua_ext = strings.clone(root["lua_ext"].(json.String) or_else "lsp.lua")
    config.lua_types = make(map[string]string)
    types := root["types"].(json.Object)
    
    for luaType, val in types {
        odinTypes := val.(json.Array)
        for type in odinTypes {
            config.lua_types[strings.clone(type.(json.String))] = strings.clone(luaType)
        }
    }
}

config_package :: proc(config: ^GeneratorConfig, pkg: string, filename: string) {
    result, ok := &config.files[pkg]
    if !ok {
        using strings

        path := filepath.dir(filename, context.temp_allocator)

        name := filepath.stem(filename)
        filename := strings.concatenate({path, "/", pkg, config.odin_ext})
        luaFilename := strings.concatenate({config.meta_directory, "/", pkg, config.lua_ext})

        config.files[pkg] = package_file_make(filename, luaFilename)
        sb := &(&config.files[pkg]).builder
        file := &config.files[pkg]

        luaSb := &(&config.files[pkg]).lua_builder

        write_string(sb, "package ")
        write_string(sb, pkg)
        write_string(sb, "\n\n")
    
        // Add required imports
   
        file.imports["c"] = FileImport {
            name = "c",
            text = `import c "core:c"`,
        }
        file.imports["fmt"] = FileImport {
            name = "fmt",
            text = `import fmt "core:fmt"`,
        }
        file.imports["runtime"] = FileImport {
            name = "runtime",
            text = `import runtime "core:runtime"`,
        }
        file.imports["lua"] = FileImport {
            name = "lua",
            text = `import lua "packages:odin-lua/lua"`,
        }
        file.imports["luaL"] = FileImport {
            name = "luaL",
            text = `import luaL "packages:odin-lua/luaL"`,
        }
        file.imports["mani"] = FileImport {
            name = "mani",
            text = `import mani "packages:mani/mani"`,
        }
        file.imports["strings"] = FileImport {
            name = "strings",
            text = `import strings "core:strings"`,
        }

        for _, imp in file.imports {
            write_string(sb, imp.text)
            write_string(sb, "\n")
        }
        write_string(sb, "\n")

        write_string(luaSb, "---@meta\n\n")
    }
}

generate_struct_lua_wrapper :: proc(config: ^GeneratorConfig, exports: FileExports, s: StructExport, filename: string, package_exports: ^PackageExports) {
    using strings 
    sb := &(&config.files[exports.symbols_package]).builder
    exportAttribs := s.attribs["LuaExport"].(Attributes)

    generate_methods_mapping(config, exports, exportAttribs, s.name, package_exports)

    write_lua_index(config, sb, exports, s , package_exports)
    write_lua_newindex(sb, exports, s , package_exports)
    write_lua_struct_init(config, sb, exports, s, package_exports)
}

generate_array_lua_wrapper :: proc(config: ^GeneratorConfig, exports: FileExports, arr: ArrayExport, filename: string, package_exports: ^PackageExports) {
    using strings 
    sb := &(&config.files[exports.symbols_package]).builder
    exportAttribs := arr.attribs["LuaExport"].(Attributes)

    generate_methods_mapping(config, exports, exportAttribs, arr.name, package_exports)

    write_lua_array_index(sb, exports, arr)
    write_lua_array_newindex(sb, exports, arr)
    write_lua_array_init(sb, exports, arr)
}

generate_methods_mapping :: proc(config: ^GeneratorConfig, exports: FileExports, attributes: Attributes, name: string, package_exports: ^PackageExports) {
    using strings, fmt
    sb := &(&config.files[exports.symbols_package]).builder

    write_string(sb, `@(private = "file")`)
    write_rune(sb, '\n')
    write_string(sb, "_mani_methods_")
    write_string(sb, name)
    write_string(sb, " := map[string]lua.CFunction {\n")

    if methods, ok := attributes["Methods"].(Attributes); ok {
        for odinName, v in methods {
            luaName := v.(String)
            sbprintf(sb, "    \"%s\" = _mani_%s,\n", luaName, odinName)
        }
    }

    if name in config.methods {
        for proc_export in config.methods[name] {
            odin_name := proc_export.name
            attribs := proc_export.attribs["LuaExport"].(Attributes) or_else DEFAULT_PROC_ATTRIBUTES

            lua_name := odin_name
            if "Name" in attribs {
                lua_name = attribs["Name"].(String) or_else odin_name
            }

            sbprintf(sb, "    \"%s\" = _mani_%s,\n", lua_name, odin_name)
        }
    }
    write_string(sb, "}\n")
}

generate_enum_wrapper :: proc(config: ^GeneratorConfig, exports: FileExports, the_enum: EnumExport, filename: string, package_exports: ^PackageExports) {
    using strings, fmt
    sb := &(&config.files[exports.symbols_package]).builder

    write_string(sb, "@(private = \"file\", init)\n")
    write_string(sb, fmt.tprintf("_generate_%v :: proc() {{\n", the_enum.name))

    name := the_enum.attribs["LuaExport"].(Attributes)["Name"].(String) or_else the_enum.name

    write_string(sb, "\texport := mani.EnumExport{}\n")
    write_string(sb, fmt.tprintf("\texport.name = \"%v\"\n\n", name))

    write_string(sb, fmt.tprintf("\tfor elem in %v {{\n", the_enum.name))

    write_string(sb, "\t\tname, _ := reflect.enum_name_from_value(elem)\n")
    write_string(sb, "\t\texport.fields[name] = int(elem)\n")

    write_string(sb, "\t}\n\n")

    write_string(sb, "\tmani.add_enum(export)\n")

    write_string(sb, "}\n")
}

add_import :: proc(file: ^PackageFile, import_statement: FileImport) {
    if import_statement.name not_in file.imports {
        using strings
        sb := &file.builder
        write_string(sb, import_statement.text)
        write_string(sb, "\n")
        file.imports[import_statement.name] = import_statement
    }
}

generate_lua_exports :: proc(config: ^GeneratorConfig, exports: FileExports, package_exports: ^PackageExports) {
    using strings
    config_package(config, exports.symbols_package, exports.relpath)
    file := &config.files[exports.symbols_package]

    for _, imp in exports.imports {
        add_import(file, imp)
    }

    keys, _ := slice.map_keys(exports.symbols)
    slice.sort(keys)

    config.methods = make(map[string][dynamic]ProcedureExport)

    for key in keys {
        exp := exports.symbols[key]

        #partial switch x in exp {
        case ProcedureExport:
            attribs := x.attribs[LUAEXPORT_STR].(Attributes) or_else DEFAULT_PROC_ATTRIBUTES
            if "MethodOf" in attribs {
                the_struct := attribs["MethodOf"]
                #partial switch s in the_struct {
                case Identifier:
                    str := string(s)
                    if str not_in config.methods {
                        config.methods[str] = make([dynamic]ProcedureExport)
                    }
                    append(&config.methods[str], x)
                }
            }
        }
    }

    for key in keys {
        exp := exports.symbols[key]

        switch x in exp {
        case ProcedureExport: {
            if "LuaExport" in x.attribs {
                generate_proc_lua_wrapper(config, exports, x, exports.relpath, package_exports)
                write_proc_meta(config, exports, x, package_exports)
            } else if "LuaImport" in x.attribs {
                generate_pcall_wrapper(config, exports, x, exports.relpath, package_exports)
            }
        }

        case StructExport: {
            generate_struct_lua_wrapper(config, exports, x, exports.relpath, package_exports)
            write_struct_meta(config, exports, x, package_exports)
        }

        case ArrayExport: {
            generate_array_lua_wrapper(config, exports, x, exports.relpath, package_exports)
            write_array_meta(config, exports, x, package_exports)
        }

        case EnumExport:
            generate_enum_wrapper(config, exports, x, exports.relpath, package_exports)
            write_enum_meta(config, exports, x, package_exports)
        }
    }
}

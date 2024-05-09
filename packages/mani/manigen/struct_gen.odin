package mani_generator

import "core:fmt"
import "core:strings"
import "core:slice"

write_lua_struct_init :: proc(config: ^GeneratorConfig, sb: ^strings.Builder, exports: FileExports, s: StructExport, package_exports: ^PackageExports) {
    using strings, fmt

    exportAttribs := s.attribs[LUAEXPORT_STR].(Attributes) or_else DEFAULT_STRUCT_ATTRIBUTES
    udataType := exportAttribs["Type"].(Attributes)  
    allowLight := "Light" in udataType
    allowFull := "Full" in udataType
    
    luaName := exportAttribs["Name"].(String) or_else s.name


    write_string(sb, "@(init)\n")
    write_string(sb, "_mani_init_")
    write_string(sb, s.name)
    write_string(sb, " :: proc() {\n    ")

    write_string(sb, "expStruct: mani.StructExport")
    write_string(sb, "\n    ")
    write_string(sb, "expStruct.pkg = ")
    write_rune(sb, '"')
    write_string(sb, exports.symbols_package)
    write_rune(sb, '"')
    write_string(sb, "\n    ")

    write_string(sb, "expStruct.odin_name = ")
    write_rune(sb, '"')
    write_string(sb, s.name)
    write_rune(sb, '"')
    write_string(sb, "\n    ")

    write_string(sb, "expStruct.lua_name = ")
    write_rune(sb, '"')
    write_string(sb, luaName)
    write_rune(sb, '"')
    write_string(sb, "\n    ")

    write_string(sb, "expStruct.type = ")
    write_string(sb, s.name)
    write_string(sb, "\n    ")

    write_string(sb, "expStruct.methods = make(map[mani.LuaName]lua.CFunction)")
    write_string(sb, "\n    ")
    if methodsAttrib, found := exportAttribs["Methods"]; found {
        methods := methodsAttrib.(Attributes) 
        for odinName, attribVal in methods {
            luaName: string
            if name, ok := attribVal.(String); ok {
                luaName = name
            } else {
                luaName = odinName
            }
            fullName := strings.concatenate({"_mani_", odinName}, context.temp_allocator)
            write_string(sb, "expStruct.methods[")
            write_rune(sb, '"')
            write_string(sb, luaName)
            write_rune(sb, '"')
            write_string(sb, "] = ")
            write_string(sb, fullName)
            write_string(sb, "\n    ")
        }
    }

    if s.name in config.methods {
        for proc_export in config.methods[s.name] {
            odin_name := proc_export.name
            attribs := proc_export.attribs["LuaExport"].(Attributes) or_else DEFAULT_PROC_ATTRIBUTES

            lua_name := odin_name
            if "Name" in attribs {
                lua_name = attribs["Name"].(String) or_else odin_name
            }

            full_name := strings.concatenate({"_mani_", odin_name}, context.temp_allocator)
            write_string(sb, "expStruct.methods[")
            write_rune(sb, '"')
            write_string(sb, lua_name)
            write_rune(sb, '"')
            write_string(sb, "] = ")
            write_string(sb, full_name)
            write_string(sb, "\n    ")
        }
    }

    if allowLight {
        write_string(sb, "\n    ")
        write_string(sb, "refMeta: mani.MetatableData\n    ")
        write_string(sb, "refMeta.name = ")
        write_rune(sb, '"')
        write_string(sb, s.name)
        write_string(sb, "_ref")
        write_rune(sb, '"')
        write_string(sb, "\n    ")


        write_string(sb, "refMeta.odin_type = ")
        write_rune(sb, '^')
        write_string(sb, s.name)
        write_string(sb, "\n    ")

        write_string(sb, "refMeta.index = ")
        write_string(sb, "_mani_index_")
        write_string(sb, s.name)
        write_string(sb, "_ref")
        write_string(sb, "\n    ")

        write_string(sb, "refMeta.newindex = ")
        write_string(sb, "_mani_newindex_")
        write_string(sb, s.name)
        write_string(sb, "_ref")
        write_string(sb, "\n    ")

        if metaAttrib, found := exportAttribs["Metamethods"]; found {
            write_string(sb, "refMeta.methods = make(map[cstring]lua.CFunction)")
            write_string(sb, "\n    ")
            methods := metaAttrib.(Attributes)

            names, _ := slice.map_keys(methods)
            slice.sort(names)
            for name in names {
                val := methods[name]
                odinProc := val.(Identifier)
                fmt.sbprintf(sb, "refMeta.methods[\"%s\"] = _mani_%s", name, cast(String)odinProc)
                write_string(sb, "\n    ")
            }
        }

        if fields, ok := exportAttribs["Fields"].(Attributes); ok {
            odin_names, _ := slice.map_keys(s.fields)
            slice.sort(odin_names)
            for odin_name in odin_names {
                field := s.fields[odin_name]
                if name, ok := fields[odin_name]; ok {
                    write_string(sb, 
                        fmt.tprintf("expStruct.fields[\"%v\"] = mani.StructFieldExport{{\"%v\", \"%v\", typeid_of(%v)}}\n", 
                            name,
                            name,
                            odin_name,
                            field.type))
                }
            }
        }

        write_string(sb, "\texpStruct.light_meta = refMeta")
        write_string(sb, "\n    ")
    }

    if allowFull {
        write_string(sb, "\n    ")
        write_string(sb, "copyMeta: mani.MetatableData\n    ")
        write_string(sb, "copyMeta.name = ")
        write_rune(sb, '"')
        write_string(sb, s.name)
        write_rune(sb, '"')
        write_string(sb, "\n    ")

        write_string(sb, "copyMeta.odin_type = ")
        write_string(sb, s.name)
        write_string(sb, "\n    ")


        write_string(sb, "copyMeta.index = ")
        write_string(sb, "_mani_index_")
        write_string(sb, s.name)
        write_string(sb, "\n    ")

        write_string(sb, "copyMeta.newindex = ")
        write_string(sb, "_mani_newindex_")
        write_string(sb, s.name)
        write_string(sb, "\n    ")

        if metaAttrib, found := exportAttribs["Metamethods"]; found {
            write_string(sb, "copyMeta.methods = make(map[cstring]lua.CFunction)")
            write_string(sb, "\n    ")
            methods := metaAttrib.(Attributes)

            names, _ := slice.map_keys(methods)
            slice.sort(names)
            for name in names {
                val := methods[name]
                odinProc := val.(Identifier)
                fmt.sbprintf(sb, "copyMeta.methods[\"%s\"] = _mani_%s", name, cast(String)odinProc)
                write_string(sb, "\n    ")
            }
        }

        write_string(sb, "expStruct.full_meta = copyMeta")
        write_string(sb, "\n    ")
        write_string(sb, "\n    ")

    }

   
    
    write_string(sb, "mani.add_struct(expStruct)")
    write_string(sb, "\n}\n\n")
}

write_lua_newstruct :: proc(sb: ^strings.Builder, exports: FileExports, s: StructExport, package_exports: ^PackageExports) {
    
}

write_lua_index :: proc(config: ^GeneratorConfig, sb: ^strings.Builder, exports: FileExports, s: StructExport, package_exports: ^PackageExports) {
    using strings
    exportAttribs := s.attribs[LUAEXPORT_STR].(Attributes) or_else DEFAULT_STRUCT_ATTRIBUTES
    luaFields := exportAttribs["Fields"].(Attributes) if "Fields" in exportAttribs else nil
    udataType := exportAttribs["Type"].(Attributes)  
    allowLight := "Light" in udataType
    allowFull := "Full" in udataType
    hasMethods := "Methods" in exportAttribs || s.name in config.methods


    if allowFull {
        if hasMethods {
            fmt.sbprintf(sb, 
                `
_mani_index_{0:s} :: proc "c" (L: ^lua.State) -> c.int {{
    context = mani.default_context()
    udata := transmute(^{1:s})luaL.checkudata(L, 1, "{0:s}")
    key := lua.tostring(L, 2)
    if method, found := _mani_methods_{0:s}[key]; found {{
        mani.push_value(L, method)
        return 1
    }}
    switch key {{
        case: {{
            lua.pushnil(L)
            return 1
        }}
                `, s.name, s.name)
        } else {
            fmt.sbprintf(sb, 
                `
_mani_index_{0:s} :: proc "c" (L: ^lua.State) -> c.int {{
    context = mani.default_context()
    udata := transmute(^{1:s})luaL.checkudata(L, 1, "{0:s}")
    key := lua.tostring(L, 2)
    switch key {{
        case: {{
            lua.pushnil(L)
            return 1
        }}
                `, s.name, s.name)
        }

        if luaFields != nil {

            keys, _ := slice.map_keys(s.fields)
            slice.sort(keys)
            for k in keys {
                field := s.fields[k]
                shouldExport := false
                name: string
                if luaField, ok := luaFields[field.name]; ok {
                    shouldExport = true
                    if luaName, ok := luaField.(String); ok {
                        name = luaName
                    } else {
                        name = field.name
                    }  
                } else {
                    shouldExport = false
                }
                
    
                if shouldExport {
                    fmt.sbprintf(sb, 
`        
        case "{0:s}": {{
            mani.push_value(L, udata.{1:s})
            return 1
        }}
`,    name, field.name)
                }
            }
        }
        
        fmt.sbprintf(sb, 
`
    }}
    return 1
}}

`       )
    }

    if allowLight {
        if hasMethods {
            fmt.sbprintf(sb, 
                `
_mani_index_{0:s}_ref :: proc "c" (L: ^lua.State) -> c.int {{
    context = mani.default_context()
    udata := transmute(^{1:s})luaL.checkudata(L, 1, "{0:s}_ref")
    key := lua.tostring(L, 2)
    if method, found := _mani_methods_{0:s}[key]; found {{
        mani.push_value(L, method)
        return 1
    }}
    switch key {{
        case: {{
            lua.pushnil(L)
            return 1
        }}
                `, s.name, s.name)
        } else {
            fmt.sbprintf(sb, 
                `
_mani_index_{0:s}_ref :: proc "c" (L: ^lua.State) -> c.int {{
    context = mani.default_context()
    udata := transmute(^{1:s})luaL.checkudata(L, 1, "{0:s}_ref")
    key := lua.tostring(L, 2)
    switch key {{
        case: {{
            lua.pushnil(L)
            return 1
        }}
                `, s.name, s.name)
        }

        if luaFields != nil {

            keys, _ := slice.map_keys(s.fields)
            slice.sort(keys)
            for k in keys {
                field := s.fields[k]
                shouldExport := false
                name: string
                if luaField, ok := luaFields[field.name]; ok {
                    shouldExport = true
                    if luaName, ok := luaField.(String); ok {
                        name = luaName
                    } else {
                        name = field.name
                    }  
                } else {
                    shouldExport = false
                }
                
    
                if shouldExport {
                    fmt.sbprintf(sb, 
`        
        case "{0:s}": {{
            mani.push_value(L, udata^.{1:s})
            return 1
        }}
`,    name, field.name)
                }
            }
        }

        fmt.sbprintf(sb, 
`
    }}
    return 1
}}

`       )
    }
    
}

write_lua_newindex :: proc(sb: ^strings.Builder, exports: FileExports, s: StructExport, package_exports: ^PackageExports) {
    using strings
    exportAttribs := s.attribs[LUAEXPORT_STR].(Attributes) or_else DEFAULT_STRUCT_ATTRIBUTES
    luaFields := exportAttribs["Fields"].(Attributes) if "Fields" in exportAttribs else nil
    udataType := exportAttribs["Type"].(Attributes)  
    allowLight := "Light" in udataType
    allowFull := "Full" in udataType


    if allowFull {
        fmt.sbprintf(sb, 
`
_mani_newindex_{0:s} :: proc "c" (L: ^lua.State) -> c.int {{
    context = mani.default_context()
    udata := transmute(^{1:s})luaL.checkudata(L, 1, "{0:s}")
    key := lua.tostring(L, 2)
    switch key {{
        case: {{
            // Throw an error here
            return 0
        }}
`       , s.name, s.name)
        if luaFields != nil {
            keys, _ := slice.map_keys(s.fields)
            slice.sort(keys)
            for k in keys {
                field := s.fields[k]
                shouldExport := false
                name: string
                if luaField, ok := luaFields[field.name]; ok {
                    shouldExport = true
                    if luaName, ok := luaField.(String); ok {
                        name = luaName
                    } else {
                        name = field.name
                    }
                } else {
                    shouldExport = false
                }

                if shouldExport {
                    fmt.sbprintf(sb,
`
        case "{0:s}": {{
            mani.to_value(L, 3, &udata.{1:s})
            return 1
        }}
`,    name, field.name)
                }
            }
        }

        fmt.sbprintf(sb,
`
    }}
    return 0
}}

`       )
    }

    if allowLight {
        fmt.sbprintf(sb, 
`
_mani_newindex_{0:s}_ref :: proc "c" (L: ^lua.State) -> c.int {{
    context = mani.default_context()
    udata := transmute(^^{1:s})luaL.checkudata(L, 1, "{0:s}_ref")
    key := lua.tostring(L, 2)
    switch key {{
        case: {{
            lua.pushnil(L)
        }}
`       , s.name, s.name)
        if luaFields != nil {
            keys, _ := slice.map_keys(s.fields)
            slice.sort(keys)
            for k in keys {
                field := s.fields[k]
                shouldExport := false
                name: string
                if luaField, ok := luaFields[field.name]; ok {
                    shouldExport = true
                    if luaName, ok := luaField.(String); ok {
                        name = luaName
                    } else {
                        name = field.name
                    }  
                } else {
                    shouldExport = false
                }
                

                if shouldExport {
                    fmt.sbprintf(sb, 
`        
        case "{0:s}": {{
            mani.to_value(L, 3, &udata^.{1:s})
            return 1
        }}
`,    name, field.name)
                }
            }
        }

        fmt.sbprintf(sb, 
`
    }}
    return 1
}}

`       )
    }
}

write_struct_meta :: proc(config: ^GeneratorConfig, exports: FileExports, s: StructExport, package_exports: ^PackageExports) {
    using strings
    sb := &(&config.files[exports.symbols_package]).lua_builder
    
    exportAttribs := s.attribs[LUAEXPORT_STR].(Attributes) or_else DEFAULT_PROC_ATTRIBUTES
    // This makes LuaExport.Name not enitrely usable, I should map struct names to lua names
    className :=  exportAttribs["Name"].(String) or_else s.name
    fmt.sbprintf(sb, "---@class %s\n", className)
    for comment in s.lua_docs {
        fmt.sbprintf(sb, "---%s\n", comment)
    }
    if fieldsAttrib, found := exportAttribs["Fields"].(Attributes); found {
        for k, field in s.fields {
            name: string
            luaType := "any" 
            fieldType := field.type[1:] if is_pointer_type(field.type) else field.type
            if luaField, ok := fieldsAttrib[field.name]; ok {
                if luaName, ok := luaField.(String); ok {
                    name = luaName
                } else {
                    name = field.name
                } 

                if type, found := config.lua_types[fieldType]; found {
                    luaType = type 
                } else {
                    #partial switch type in exports.symbols[fieldType] {
                        case ArrayExport: {
                            // Note(Dragos): Not the best. Will need some refactoring
                            luaType = type.attribs["LuaExport"].(Attributes)["Name"].(String) or_else type.name
             
                        }
        
                        case StructExport: {
                            luaType = type.attribs["LuaExport"].(Attributes)["Name"].(String) or_else type.name
                        }
                    }
                }
                fmt.sbprintf(sb, "---@field %s %s\n", name, luaType)
            } 
        }
    }
    fmt.sbprintf(sb, "%s = {{}}\n\n", className)
    
    if methodsAttrib, found := exportAttribs["Methods"]; found {
        methods := methodsAttrib.(Attributes)

        keys, _ := slice.map_keys(methods, context.temp_allocator)
        slice.sort(keys)
        for key in keys {
            val := methods[key]
            methodName: string 
            if name, found := val.(String); found {
                methodName = name 
            } else {
                methodName = key
            }

            procExport := exports.symbols[key].(ProcedureExport)
            write_proc_meta(config, exports, procExport, package_exports, fmt.tprintf("%s:%s", className, methodName), 1)
        }
    }

    if s.name in config.methods {
        methods := config.methods[s.name]

        for method in methods {
            // val := methods[key]
            // methodName: string 
            // if name, found := val.(String); found {
            //     methodName = name 
            // } else {
            //     methodName = key
            // }

            method_name := method.attribs["LuaExport"].(Attributes)["Name"].(String) or_else method.name

            // procExport := exports.symbols[key].(ProcedureExport)
            write_proc_meta(config, exports, method, package_exports, fmt.tprintf("%s:%s", className, method_name), 1)
        }
    }
}

write_enum_meta :: proc(config: ^GeneratorConfig, exports: FileExports, e: EnumExport, package_exports: ^PackageExports) {
    e := e
    sb := &(&config.files[exports.symbols_package]).lua_builder

    export_attribs := e.attribs[LUAEXPORT_STR].(Attributes)
    // This makes LuaExport.Name not enitrely usable, I should map struct names to lua names
    enum_name :=  export_attribs["Name"].(String) or_else e.name
    fmt.sbprintf(sb, "---@enum %s\n", enum_name)
    for comment in e.lua_docs {
        fmt.sbprintf(sb, "---%s\n", comment)
    }

    fmt.sbprintf(sb, "%v = {{\n", enum_name)

    fields, _ := slice.map_keys(e.fields, context.temp_allocator)
    context.user_ptr = &e.fields
    slice.sort_by(fields, proc(i, j: string) -> bool {
        fields := cast(^map[string]int)context.user_ptr
        return fields[i] < fields[j]
    })

    for field in fields {
        value := e.fields[field]
        fmt.sbprintf(sb, "    %v = %v,\n", field, value)
    }
    fmt.sbprintf(sb, "}}\n\n")
}

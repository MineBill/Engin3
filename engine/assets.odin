package engine
import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:reflect"
import "core:slice"
import "core:strings"
import fs "filesystem"
import intr "core:intrinsics"

AbsolutePath :: distinct string
RelativePath :: distinct string

AssetLoader :: #type proc(data: []byte) -> ^Asset

AssetNotFoundError :: struct {
    path: string,
}

GenericMessageError :: struct {
    message: string,
}

InvalidAssetFormatError :: struct {
    message: string,
}

AssetImportError :: union {
    AssetNotFoundError,
    GenericMessageError,
    InvalidAssetFormatError,
    ScriptCompilationError,
}

AssetImporter :: #type proc(metadata: AssetMetadata) -> (^Asset, AssetImportError)

COOKED_GAME :: !USE_EDITOR

// We make this distinct so the editor can provide proper UI.
AssetHandle :: distinct UUID

AssetManagerBase :: struct {
    assets: map[string]^Asset,
    loaded_assets: map[AssetHandle]^Asset,
}

when USE_EDITOR {
    AssetVTable :: struct {}
} else {
    AssetVTable :: struct {}
}

Asset :: struct {
    using _ : AssetVTable,

    id: UUID,
    type: AssetType,
}

when USE_EDITOR {
    AssetMetadata :: struct {
        type: AssetType,

        // Relative path to the project root.
        path: string,

        is_virtual: bool,
    }

    AssetRegistry :: map[AssetHandle]AssetMetadata

    registry_set_metadata :: proc(registry: ^AssetRegistry, handle: AssetHandle, metadata: AssetMetadata) {
        registry[handle] = metadata

        if !metadata.is_virtual {
            s: SerializeContext
            serialize_init(&s)
            serialize_asset_registry(registry, &s)
            serialize_dump_to_file(&s, project_get_asset_registry_location(EditorInstance.active_project))
        }
    }

    AssetManager :: EditorAssetManager

    EditorAssetManager :: struct {
        using base: AssetManagerBase,

        registry: AssetRegistry,
    }

    AssetSerializer :: #type proc(this: ^Asset, s: ^SerializeContext)

    asset_manager_init :: proc(manager: ^EditorAssetManager) {
        manager.registry = make(AssetRegistry)

        s: SerializeContext
        serialize_init_file(&s, project_get_asset_registry_location(EditorInstance.active_project))
        serialize_asset_registry(&manager.registry, &s)
    }

    asset_manager_deinit :: proc(manager: ^EditorAssetManager) {
        s: SerializeContext
        serialize_init(&s)
        serialize_asset_registry(&manager.registry, &s)
        serialize_dump(&s, project_get_asset_registry_location(EditorInstance.active_project))

        delete(manager.registry)
    }

    is_asset_handle_valid :: #force_inline proc(am: ^EditorAssetManager, handle: AssetHandle) -> bool {
        return handle in am.registry
    }

    is_asset_loaded :: proc(manager: ^EditorAssetManager, handle: AssetHandle) -> bool {
        return handle in manager.loaded_assets
    }

    get_asset_type :: proc(manager: ^EditorAssetManager, asset: AssetHandle) -> AssetType {
        if !is_asset_handle_valid(manager, asset) {
            return .Invalid
        }

        return manager.registry[asset].type
    }

    get_asset_metadata :: proc(manager: ^EditorAssetManager, asset: AssetHandle) -> AssetMetadata {
        if !is_asset_handle_valid(manager, asset) {
            return AssetMetadata {
                type = .Invalid,
            }
        }

        return manager.registry[asset]
    }

    get_asset_from_asset_type :: proc(manager: ^EditorAssetManager, handle: AssetHandle, type: AssetType) -> ^Asset {
        if !is_asset_handle_valid(manager, handle) {
            return nil
        }

        if is_asset_loaded(manager, handle) {
            return manager.loaded_assets[handle]
        } else {
            metadata := manager.registry[handle]

            asset, error := import_asset(handle, metadata, type)
            if error != nil {
                if error != nil {
                    switch x in error {
                    case AssetNotFoundError:
                        log.errorf("Asset at path '%v' could not be found. Make sure it exists.", x.path)
                    case InvalidAssetFormatError:
                        log.errorf("Asset importer reported that the source asset is in a wrong format: %s", x.message)
                    case ScriptCompilationError:
                        log.errorf("Script compilation error: %v", x)
                    case GenericMessageError:
                        log.errorf("Asset import error: %s", error)
                    }
                }
                log.errorf("Could not import asset handle '%v'", handle)
                return nil
            }
            manager.loaded_assets[handle] = asset
            return asset
        }

        return nil
    }

    get_asset_from_raw_type :: proc(manager: ^EditorAssetManager, handle: AssetHandle, $T: typeid) -> ^T {
        return cast(^T)get_asset_from_asset_type(manager, handle, RAW_TYPE_TO_ASSET_TYPE[T])
    }

    get_asset :: proc {
        get_asset_from_asset_type,
        get_asset_from_raw_type,
    }

    // Imports an already registered asset into memory and makes it available for retrieval using `get_asset`.
    import_asset :: proc(handle: AssetHandle, metadata: AssetMetadata, type: AssetType) -> (^Asset, AssetImportError) {
        if type in ASSET_IMPORTERS {
            importer := ASSET_IMPORTERS[type]
            return importer(metadata)
        }

        fmt.assertf(false, "Could not find importer for asset type '%v'", type)
        return nil, nil
    }

    // Registers and new asset file with the registry. It should then be available for retrieval using `get_asset`.
    register_asset :: proc(manager: ^EditorAssetManager, absolute_file_path: string) {
        // // Check it file is already registered.
        // if handle := get_asset_handle_from_path(manager, path); handle != 0 {
        //     return
        // }

        handle := AssetHandle(generate_uuid())

        file_name := filepath.base(absolute_file_path)

        new_file_path := filepath.join({EditorInstance.content_browser.current_dir, file_name}, context.temp_allocator)

        relative_path_to_project, rel_err := filepath.rel(EditorInstance.active_project.root, new_file_path)
        if rel_err != nil {
            #partial switch rel_err {
            case .Cannot_Relate:
                log.errorf("Cannot relate '%v' to '%v'", absolute_file_path, new_file_path)
            }
            return
        }
        log.debugf("Relative path to project: '%v'", relative_path_to_project)

        log.debugf("Copying file '%v' to location '%v'", absolute_file_path, new_file_path)
        fs.copy_file(absolute_file_path, new_file_path)

        ext := filepath.ext(file_name)
        log.debugf("File ext: '%v'", ext)

        type: AssetType = .Invalid
        if ext in SUPPORTED_ASSETS {
            type = SUPPORTED_ASSETS[ext]
        }

        metadata := AssetMetadata {
            type = type,
            path = relative_path_to_project,
        }

        registry_set_metadata(&manager.registry, handle, metadata)
    }

    // Writes an asset handle.
    serialize_asset_handle :: proc(am: ^EditorAssetManager, s: ^SerializeContext, key: string, asset: ^AssetHandle) {
        switch s.mode {
        case .Serialize:
            if !is_asset_handle_valid(am, asset^) {
                return
            }
            serialize_do_field(s, key, asset^)
        case .Deserialize:
            if handle, ok := serialize_get_field(s, key, AssetHandle); ok {
                asset^ = handle
            }
        }
    }

    // Writes an asset to an asset file.
    save_asset :: proc(manager: ^EditorAssetManager, asset_handle: AssetHandle) {
        metadata := get_asset_metadata(manager, asset_handle)
        odin_type := ASSET_TYPE_TO_TYPEID[metadata.type]
        if odin_type in ASSET_SERIALIZERS {
            serializer := ASSET_SERIALIZERS[odin_type]

            s: SerializeContext
            serialize_init(&s)

            asset := get_asset(manager, asset_handle, metadata.type)
            serializer(asset, &s)

            full_path := filepath.join({EditorInstance.active_project.root, metadata.path})
            serialize_dump(&s, full_path)
        } else {
            log.warnf("Attempet to serialize asset '%v' without a serializer.", metadata.type)
        }
    }

    create_new_asset :: proc(manager: ^EditorAssetManager, type: AssetType, path: RelativePath) {
        if type in ASSET_TYPE_TO_TYPEID {
            odin_type := ASSET_TYPE_TO_TYPEID[type]

            if odin_type in ASSET_CONSTRUCTORS {
                constructor := ASSET_CONSTRUCTORS[odin_type]

                asset := constructor()
                handle := AssetHandle(generate_uuid())

                metadata := AssetMetadata {
                    type = type,
                    path = strings.clone(string(path)),
                }
                registry_set_metadata(&manager.registry, handle, metadata)

                save_asset(manager, handle)
            }
        }
    }

    // Renames an asset.
    // `new_name`: The new name of asset. Should __NOT__ include the extension.
    // Returns `true` if everything went smoothly, `false` otherwise.
    rename_asset :: proc(manager: ^EditorAssetManager, asset: AssetHandle, new_name: string) -> bool {
        tmp := context.temp_allocator
        if !is_asset_handle_valid(manager, asset) {
            log.errorf("Cannot rename invalid asset '%v'", asset)
            return false
        }
        metadata := &manager.registry[asset]

        abs_asset_path := filepath.join({EditorInstance.active_project.root, metadata.path}, tmp)
        ext := filepath.ext(metadata.path)
        asset_dir := filepath.dir(metadata.path, tmp)
        new_metadata_path := filepath.join({asset_dir, strings.join({new_name,  ext}, "", tmp)})
        // log.debugf("os.rename(%v, %v)", abs_asset_path, filepath.join({EditorInstance.active_project.root, metadata.path}, tmp))

        new_abs_path := filepath.join({EditorInstance.active_project.root, new_metadata_path}, tmp)
        if os.exists(new_abs_path) {
            log.errorf("Cannot rename asset '%s' to '%s' because another file with that name exists!", abs_asset_path, new_abs_path)
            return false
        }

        metadata.path = new_metadata_path

        error := os.rename(abs_asset_path, new_abs_path)
        if error != 0 {
            log.errorf("Could not rename asset. Error: %v", error)
            return false
        }
        // dir := filepath.dir(metadata.path, context.temp_allocator)
        // new_path := filepath.join({EditorInstance.active_project.root, dir, new_name}, context.temp_allocator)
        // new_path_rel := filepath.join({dir, new_name}, context.temp_allocator)
        // log.debugf("Renaming asset: From %v to %v", old_path, new_path_rel)

        // metadata.path = strings.clone(new_path_rel)

        // error := os.rename(old_path, new_path)
        // if error != 0 {
        //     log.errorf("Error while renaming asset: %v", error)
        //     return false
        // }
        return true
    }

    // Renames a folder in the assets directory and the metadata for any asset the is affected.
    // `absolute_folder_path`:  The current absolute path to the folder you want to rename.
    // `new_name`:              The new name of the folder.
    // Returns `true` if everything went smoothly, `false` otherwise.
    rename_folder :: proc(manager: ^EditorAssetManager, absolute_folder_path: string, new_name: string) -> bool {
        relative_to_project, err := filepath.rel(EditorInstance.active_project.root, absolute_folder_path, context.temp_allocator)
        if err != nil {
            log.errorf("Cannot relate '%v' to '%v'", EditorInstance.active_project.root, absolute_folder_path)
            return false
        }
        base := filepath.dir(relative_to_project, context.temp_allocator)
        new_relative_to_project := filepath.join({base, new_name})

        new_absolute_path := filepath.join({filepath.dir(absolute_folder_path, context.temp_allocator), new_name}, context.temp_allocator)
        move_error := os.rename(absolute_folder_path, new_absolute_path)
        if move_error != 0 {
            log.errorf("Error renaming directory. Error code: %v", move_error)
            return false
        }

        affected_items := make([dynamic]AssetHandle)
        for asset, &metadata in manager.registry {
            if strings.has_prefix(metadata.path, relative_to_project) {
                metadata_base, err := filepath.rel(relative_to_project, metadata.path, context.temp_allocator)
                assert(err == nil)

                new_path := filepath.join({new_relative_to_project, metadata_base})
                delete(metadata.path)
                metadata.path = new_path
            }
        }
        return true
    }

    delete_asset :: proc(manager: ^EditorAssetManager, asset: AssetHandle) {
        if !is_asset_handle_valid(manager, asset) {
            return
        }

        if asset in manager.loaded_assets {
            asset_ptr := manager.loaded_assets[asset]

            // TODO(minebill): Have some kind of clean up procedure that can be implemented by the assets.
            //                  Possibly, similar to the component system.
            free(asset_ptr)

            delete_key(&manager.loaded_assets, asset)
        }

        delete_key(&manager.registry, asset)
    }

    create_virtual_asset :: proc(manager: ^EditorAssetManager, asset: ^$T, tag: string = "")  -> (handle: AssetHandle)
        where intr.type_is_subtype_of(T, Asset) {

        type := RAW_TYPE_TO_ASSET_TYPE[T]

        handle = AssetHandle(generate_uuid())
        metadata := AssetMetadata {
            type = type,
            is_virtual = true,
            path = strings.clone(tag),
        }
        registry_set_metadata(&manager.registry, handle, metadata)

        manager.loaded_assets[handle] = asset

        return
    }

    serialize_asset_registry :: proc(registry: ^AssetRegistry, s: ^SerializeContext) {
        serialize_begin_table(s, "AssetRegistry")

        switch s.mode {
        case .Serialize:
            serialize_begin_table(s, "Assets")
            handles, err := slice.map_keys(registry^)
            assert(err == nil)
            slice.sort(handles)
            for handle, i in handles {
                metadata := registry[handle]
                if metadata.is_virtual do continue

                serialize_begin_table_int(s, i)
                serialize_do_field(s, "Handle", handle)
                serialize_do_field(s, "Path", metadata.path)
                serialize_do_field(s, "Type", metadata.type)
                serialize_end_table_int(s)
            }
            serialize_end_table(s)
        case .Deserialize:
            if serialize_begin_table(s, "Assets") {
                item_count := serialize_get_array(s)
                for i in 0..<item_count {
                    serialize_begin_table_int(s, i)
                    if handle, ok := serialize_get_field(s, "Handle", AssetHandle); ok {
                        registry[handle] = {}
                        metadata := &registry[handle]

                        if path, ok := serialize_get_field(s, "Path", string); ok {
                            metadata.path = path
                        }

                        if type, ok := serialize_get_field(s, "Type", AssetType); ok {
                            metadata.type = type
                        }
                    }
                    serialize_end_table_int(s)
                }
                serialize_end_table(s)
            }
        }

        serialize_end_table(s)
    }

    get_asset_handle_from_path :: proc(manager: ^EditorAssetManager, path: string) -> AssetHandle {
        for k, v in manager.registry {
            if v.path == path {
                return k
            }
        }
        return 0
    }
} else when COOKED_GAME {
    AssetManager :: RuntimeAssetManager

    RuntimeAssetManager :: struct {}

    asset_manager_init :: proc(manager: ^RuntimeAssetManager) {
        unimplemented()
    }

    asset_manager_deinit :: proc(manager: ^RuntimeAssetManager) {
        unimplemented()
    }

    is_asset_handle_valid :: #force_inline proc(am: ^RuntimeAssetManager, handle: AssetHandle) -> bool {
        unimplemented()
    }

    is_asset_loaded :: proc(manager: ^RuntiemAssetManager, handle: AssetHandle) -> bool {
        unimplemented()
    }

    get_asset :: proc(manager: ^RuntimeAssetManager, handle: AssetHandle, $T: typeid) -> ^T {
        unimplemented()
    }
}

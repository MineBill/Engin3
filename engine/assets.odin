package engine
import "core:strings"
import "core:reflect"
import "core:intrinsics"
import "core:encoding/json"
import "core:os"
import "core:log"

AssetLoader :: #type proc(data: []byte) -> ^Asset

COOKED_GAME :: !USE_EDITOR

Path :: string

AssetManager :: struct {
    assets: map[Path]^Asset,
}

asset_manager_init :: proc(am: ^AssetManager) {}

Asset :: struct {
    id: UUID,
    path: string,
}

get_asset :: proc(am: ^AssetManager, asset: Path, $T: typeid, id: Maybe(UUID) = nil) -> ^T 
    where intrinsics.type_is_subtype_of(T, Asset) {
    if asset in am.assets {
        return cast(^T)am.assets[asset]
    }

    key := strings.clone(asset)
    am.assets[key] = load_asset(key, T, id)
    return cast(^T)am.assets[key]
}

// Loads an asset from path and returns it.
load_asset :: proc(path: Path, type: typeid, id: Maybe(UUID) = nil) -> ^Asset {
    if path == "" {
        return nil
    }
    // find loader for type
    when USE_EDITOR {
        data, ok := os.read_entire_file(path)
        assert(ok)
        defer delete(data)
    } else when COOKED_GAME {
        #assert( false )
        // Extract data from packed binary file
    }

    if type in ASSET_LOADERS {
        loader := ASSET_LOADERS[type]

        asset := loader(data)
        asset.path = strings.clone(path)
        if id, ok := id.?; ok {
            asset.id = id
        } else {
            asset.id = generate_uuid()
        }
        return asset
    }

    log.errorf("Did not find a loader for asset: '%v'", type)

    return nil
}

serialize_asset :: proc(am: ^AssetManager, s: ^SerializeContext, serialize: bool, key: string, asset: ^^$T)
    where intrinsics.type_is_subtype_of(T, Asset) {
    serialize_begin_table(s, key)
    if serialize {
        serialize_do_field(s, "UUID", asset^.id)
        serialize_do_field(s, "Path", asset^.path)
    } else {
        id: Maybe(UUID) = nil

        if uuid, ok := serialize_get_field(s, "UUID", type_of(asset^.id)); ok {
            id = UUID(uuid)
        }

        if path, ok := serialize_get_field(s, "Path", type_of(asset^.path)); ok {
            if ass := get_asset(am, path, T, id); ass != nil {
                asset^ = ass
            }
        }
    }
    serialize_end_table(s)
}

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

serialize_asset :: proc(am: ^AssetManager, s: ^Serializer, serialize: bool, key: string, asset: ^^$T)
    where intrinsics.type_is_subtype_of(T, Asset) {
    if serialize {
        if asset^ == nil || asset^.path == "" || asset^.id == 0 {
            return
        }
        w := s.writer
        opt := s.opt

        json.opt_write_iteration(w, opt, 1)
        json.opt_write_key(w, opt, key)
        json.opt_write_start(w, opt, '{')

        json.opt_write_iteration(w, opt, 1)
        json.opt_write_key(w, opt, "UUID")
        json.marshal_to_writer(w, asset^.id, opt)

        json.opt_write_iteration(w, opt, 1)
        json.opt_write_key(w, opt, "Path")
        json.marshal_to_writer(w, asset^.path, opt)

        json.opt_write_end(w, opt, '}')
    } else {
        if object, ok := s.object[key].(json.Object); ok {
            id: Maybe(UUID) = nil

            if uuid, ok := object["UUID"].(json.Integer); ok {
                id = UUID(uuid)
            }

            if path, ok := object["Path"].(json.String); ok {
                if ass := get_asset(am, path, T, id); ass != nil {
                    asset^ = ass
                }
            }
        }
    }
}

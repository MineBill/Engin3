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

get_asset :: proc(am: ^AssetManager, asset: Path, $T: typeid) -> ^T {
    if asset in am.assets {
        return cast(^T)am.assets[asset]
    }

    am.assets[asset] = load_asset(asset, T)
    return cast(^T)am.assets[asset]
}

load_asset :: proc(path: Path, type: typeid) -> ^Asset {
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
        asset.id = generate_uuid()
        return asset
    }

    log.errorf("Did not find a loader for asset: '%v'", type)

    return nil
}

serialize_asset :: proc(am: ^AssetManager, s: ^Serializer, serialize: bool, asset: ^$T) {
    if serialize {
        w := s.writer
        opt := s.opt
        json.opt_write_iteration(w, opt, 1)
        json.opt_write_key(w, opt, "Path")
        json.marshal_to_writer(w, asset.path, opt)
    } else {
        path := s.object["Path"].(json.String)
        if ass := get_asset(am, path, T); ass != nil {
            log.debug("Setting ass", ass^)
            asset^ = ass^
        }
    }
}

// deserialize_asset :: proc(obj: json.Object, $T: typeid) -> T where intrinsics.type_is_subtype_of(T, Asset) {
//     path := obj["Path"].(json.String)
//     return _load_asset(path, T)
// }

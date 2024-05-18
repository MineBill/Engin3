package engine
import "core:strings"
import "core:os"
import "core:path/filepath"
import "core:fmt"

Project :: struct {
    root: string,

    name: string,
    cache_folder: string,
    assets_folder: string,
    asset_registry_location: string,

    default_scene: AssetHandle,
}

free_project :: proc(project: ^Project) {
    delete(project.root)
    delete(project.name)
    delete(project.cache_folder)
    delete(project.assets_folder)
    delete(project.asset_registry_location)
}

new_project :: proc(name: string, location: string) -> (project: Project, ok: bool) {
    if !filepath.is_abs(location) {
        log_error(LC.Editor, "New project location must be an absolute path.")
        return {}, false
    }

    if os.exists(location) {
        log_error(LC.Editor, "Folder already exists at %v", location)
        return {}, false
    }
    project.name = strings.clone(name)

    err := os.make_directory(location)
    assert(err == 0)

    project.assets_folder = "Assets"
    os.make_directory(filepath.join({location, "Assets"}))

    project.cache_folder = "Cache"
    os.make_directory(filepath.join({location, "Cache"}))

    project.asset_registry_location = "AssetRegistry.r3gistry"

    s: SerializeContext
    serialize_init(&s)
    serialize_project(project, &s)
    serialize_dump_to_file(&s, filepath.join({location, "Project.engin3"}))

    return project, true
}

load_project :: proc(project_file: string) -> (project: Project, ok: bool) {
    if !os.exists(project_file) {
        return {}, false
    }

    s: SerializeContext
    serialize_init_file(&s, project_file)
    ok = deserialize_project(&project, &s)

    if ok {
        root := filepath.dir(project_file)
        project.root = root
    }

    return
}

project_get_assets_folder :: proc(project: Project, allocator := context.allocator) -> string {
    return filepath.join({project.root, project.assets_folder}, allocator)
}

project_get_cache_folder :: proc(project: Project, allocator := context.allocator) -> string {
    return filepath.join({project.root, project.cache_folder}, allocator)
}

project_get_asset_registry_location :: proc(project: Project, allocator := context.allocator) -> string {
    return filepath.join({project.root, project.asset_registry_location}, allocator)
}

project_get_abs_path :: proc(project: Project, path: string, allocator := context.allocator) -> string {
    return filepath.join({project.root, path}, allocator)
}

serialize_project :: proc(project: Project, s: ^SerializeContext) {
    serialize_begin_table(s, "Project")
    serialize_do_field(s, "Name", project.name)
    serialize_do_field(s, "CacheFolder", project.cache_folder)
    serialize_do_field(s, "AssetsFolder", project.assets_folder)
    serialize_do_field(s, "AssetRegistryLocation", project.asset_registry_location)

    if EngineInstance != nil && is_asset_handle_valid(&EngineInstance.asset_manager, project.default_scene) {
        serialize_do_field(s, "DefaultScene", project.default_scene)
    }

    serialize_end_table(s)
}

deserialize_project :: proc(project: ^Project, s: ^SerializeContext) -> bool {
    if serialize_begin_table(s, "Project") {
        if name, ok := serialize_get_field(s, "Name", string); ok {
            project.name = name
        }

        if path, ok := serialize_get_field(s, "CacheFolder", string); ok {
            project.cache_folder = path
        }

        if path, ok := serialize_get_field(s, "AssetsFolder", string); ok {
            project.assets_folder = path
        }

        if path, ok := serialize_get_field(s, "AssetRegistryLocation", string); ok {
            project.asset_registry_location = path
        }

        if scene_handle, ok := serialize_get_field(s, "DefaultScene", AssetHandle); ok {
            project.default_scene = scene_handle
        }
        serialize_end_table(s)
        return true
    }
    return false
}

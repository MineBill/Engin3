package engine
import "core:log"
import stbi "vendor:stb/image"
import "core:os"
import gltf "vendor:cgltf"
import "core:strings"
import "core:fmt"
import gl "vendor:OpenGL"
import "core:slice"
import "core:mem"
import "core:path/filepath"
import "gpu"
import tracy "packages:odin-tracy"

@(importer=Image)
import_image :: proc(metadata: AssetMetadata) -> (asset: ^Asset, error: AssetImportError) {
    if !os.exists(metadata.path) {
        return nil, AssetNotFoundError {
            path = metadata.path,
        }
    }

    image := new(Image)
    image.type = .Image

    image^, error = import_image_from_path(metadata.path)
    return image, error
}

import_image_from_path :: proc(path: string) -> (image: Image, error: AssetImportError) {
    w, h, c: i32
    raw_image := stbi.load(cstr(path), &w, &h, &c, 4)
    if raw_image == nil {
        return {}, GenericMessageError {
            message = strings.clone_from_cstring(stbi.failure_reason()),
        }
    }

    image.data = raw_image[:w * h * c]
    image.width = int(w)
    image.height = int(h)
    image.channels = int(c)
    return
}

@(importer=Texture2D)
import_texture :: proc(metadata: AssetMetadata) -> (asset: ^Asset, error: AssetImportError) {
    tracy.Zone()
    texture := new(Texture2D)
    texture.type = .Texture2D
    path := filepath.join({EditorInstance.active_project.root, metadata.path})
    defer delete(path)
    texture^, error = import_texture_from_path(path)
    return texture, error
}

import_texture_from_path :: proc(path: string) -> (Texture2D, AssetImportError) {
    tracy.Zone()
    if !os.exists(path) {
        return {}, AssetNotFoundError {
            path = path,
        }
    }

    w, h, c: i32
    raw_image := stbi.load(cstr(path), &w, &h, &c, 4)
    if raw_image == nil {
        return {}, GenericMessageError {
            message = strings.clone_from_cstring(stbi.failure_reason()),
        }
    }

    // TODO(minebill): These need to be saved per-asset.
    spec := TextureSpecification {
        width = int(w),
        height = int(h),
        format = .RGBA8,
        filter = .Linear,
        anisotropy = 4,
    }

    BYTES_PER_CHANNEL :: 1
    // TODO: What about floating point images?
    size := w * h * 4 * BYTES_PER_CHANNEL
    return create_texture2d(spec, raw_image[:size]), {}
}

@(importer=LuaScript)
import_script :: proc(metadata: AssetMetadata) -> (asset: ^Asset, error: AssetImportError) {
    tracy.Zone()
    path := filepath.join({EditorInstance.active_project.root, metadata.path}, context.temp_allocator)
    if !os.exists(path) {
        return nil, AssetNotFoundError {
            path = path,
        }
    }

    script := new(LuaScript)
    script.type = .LuaScript

    data, _ := os.read_entire_file(path)
    if s, err := compile_script(&EngineInstance.scripting_engine, data); err != nil {
        return {}, err
    } else {
        script^ = s
    }

    return script, error
}

@(importer=Mesh)
import_mesh :: proc(metadata: AssetMetadata) -> (asset: ^Asset, error: AssetImportError) {
    path := filepath.join({EditorInstance.active_project.root, metadata.path}, context.temp_allocator)
    if !os.exists(path) {
        return nil, AssetNotFoundError {
            path = path,
        }
    }

    mesh := new(Mesh)
    mesh.type = .Mesh

    ok: bool
    mesh^, ok = load_mesh_from_gltf_file(path)
    if !ok {
        error = GenericMessageError {
            message = "Failed to import mesh",
        }
        return
    }

    asset = mesh

    return
}

@(importer=PbrMaterial)
import_pbr_material :: proc(metadata: AssetMetadata) -> (asset: ^Asset, error: AssetImportError) {
    material := new_pbr_material()
    material.type = .PbrMaterial

    s: SerializeContext
    serialize_init_file(&s, filepath.join({EditorInstance.active_project.root, metadata.path}, context.temp_allocator))

    serialize_pbr_material(material, &s)

    return material, nil
}

@(importer=Shader)
import_shader :: proc(metadata: AssetMetadata) -> (asset: ^Asset, error: AssetImportError) {
    return
}

@(importer=Scene)
import_scene :: proc(metadata: AssetMetadata) -> (asset: ^Asset, error: AssetImportError) {
    world := new(Scene)
    world.type = .Scene
    deserialize_world(world, filepath.join({EditorInstance.active_project.root, metadata.path}, context.temp_allocator))

    return world, nil
}

// This is a seperate proc from `import_shader` to allow the editor to use it aswell.
import_shader_from_path :: proc(path: string) {
    
}

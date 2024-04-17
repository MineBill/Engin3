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

@(importer=Image)
import_image :: proc(metadata: AssetMetadata) -> (asset: ^Asset, error: AssetImportError) {
    if !os.exists(metadata.path) {
        return nil, AssetNotFoundError {
            path = metadata.path,
        }
    }

    image := new(Image)
    image.type = .Image

    w, h, c: i32
    raw_image := stbi.load(cstr(metadata.path), &w, &h, &c, 4)
    if raw_image == nil {
        return nil, GenericMessageError {
            message = strings.clone_from_cstring(stbi.failure_reason()),
        }
    }

    image.data = raw_image[:w * h * c]
    image.width = int(w)
    image.height = int(h)
    image.channels = int(c)

    return image, nil
}

@(importer=Texture2D)
import_texture :: proc(metadata: AssetMetadata) -> (asset: ^Asset, error: AssetImportError) {
    texture := new(Texture2D)
    texture.type = .Texture2D
    path := filepath.join({EditorInstance.active_project.root, metadata.path})
    defer delete(path)
    texture^, error = import_texture_from_path(path)
    return texture, error
}

import_texture_from_path :: proc(path: string) -> (Texture2D, AssetImportError) {
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
    size := w * h * c * BYTES_PER_CHANNEL
    return create_texture2d(spec, raw_image[:size]), {}
}

@(importer=LuaScript)
import_script :: proc(metadata: AssetMetadata) -> (asset: ^Asset, error: AssetImportError) {
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

    gltf_data, ok := os.read_entire_file(path)
    assert(ok)

    if len(gltf_data) <= 0 {
        log.errorf("Empty data provided to model loader. Cannot continue.")
        return nil, InvalidAssetFormatError {
            message = "Asset is",
        }
    }

    options := gltf.options{}

    data, res := gltf.parse(options, raw_data(gltf_data), len(gltf_data))
    if res != .success {
        log.errorf("Error while loading model: %v", res)
        return nil, GenericMessageError {
            message = fmt.aprintf("cgltf error: %v", res),
        }
    }

    res = gltf.load_buffers(options, data, cstr(path))
    if res != .success {
        log.errorf("Error while loading model: %v", res)
        return nil, GenericMessageError {
            message = "Could not load gltf buffers",
        }
    }

    assert(len(data.scenes) == 1, "Can only support one scene definition per scene file.")
    s := data.scenes[0]

    model := new(Mesh)
    model.type = .Mesh

    node := s.nodes[0]

    mesh := node.mesh

    for primitive in mesh.primitives {
        get_buffer_data :: proc(attributes: []gltf.attribute, index: u32, $T: typeid) -> []T {
            accessor := attributes[index].data
            data := cast([^]T)(uintptr(accessor.buffer_view.buffer.data) +
                uintptr(accessor.buffer_view.offset))
            count := accessor.count
            #partial switch attributes[index].type {
            case .tangent:
                count *= 4
            case .normal: fallthrough
            case .position:
                count *= 3
            case .texcoord:
                count *= 2
            }
            return data[:count]
        }

        position_data := get_buffer_data(primitive.attributes, 0, f32)

        normal_data := get_buffer_data(primitive.attributes, 1, f32)

        tex_data := get_buffer_data(primitive.attributes, 2, f32)

        tangent_data := get_buffer_data(primitive.attributes, 3, f32)

        vertices := make([]Vertex, len(position_data) / 3, context.temp_allocator)

        vi := 0
        ti := 0
        tangent_idx := 0
        for i := 0; i < len(vertices) - 0; i += 1 {
            vertices[i] = Vertex {
                position = {position_data[vi], position_data[vi + 1], position_data[vi + 2]},
                normal = {normal_data[vi], normal_data[vi + 1], normal_data[vi + 2]},
                tangent = {tangent_data[tangent_idx], tangent_data[tangent_idx + 1], tangent_data[tangent_idx + 2]},
                uv = {tex_data[ti], tex_data[ti + 1]},
                color = {1, 1, 1},
            }
            // vertices[i].pos += node.translation
            vi += 3
            ti += 2
            tangent_idx += 4
        }

        accessor := primitive.indices
        data := accessor.buffer_view.buffer.data
        offset := accessor.buffer_view.offset

        indices_raw := cast([^]u16)(uintptr(data) + uintptr(offset))
        count := accessor.count
        indices := indices_raw[:count]

        model.num_indices = i32(len(indices))
        gl.CreateBuffers(1, &model.vertex_buffer)
        gl.NamedBufferStorage(model.vertex_buffer, size_of(Vertex) * len(vertices), raw_data(vertices), gl.DYNAMIC_STORAGE_BIT)

        gl.CreateBuffers(1, &model.index_buffer)
        gl.NamedBufferStorage(model.index_buffer, size_of(u16) * len(indices), raw_data(indices), gl.DYNAMIC_STORAGE_BIT)

        gl.CreateVertexArrays(1, &model.vertex_array)

        vao := model.vertex_array
        gl.VertexArrayVertexBuffer(vao, 0, model.vertex_buffer, 0, size_of(Vertex))
        gl.VertexArrayElementBuffer(vao, model.index_buffer)

        gl.EnableVertexArrayAttrib(vao, 0)
        gl.EnableVertexArrayAttrib(vao, 1)
        gl.EnableVertexArrayAttrib(vao, 2)
        gl.EnableVertexArrayAttrib(vao, 3)
        gl.EnableVertexArrayAttrib(vao, 4)

        gl.VertexArrayAttribFormat(vao, 0, 3, gl.FLOAT, false, u32(offset_of(Vertex, position)))
        gl.VertexArrayAttribFormat(vao, 1, 3, gl.FLOAT, false, u32(offset_of(Vertex, normal)))
        gl.VertexArrayAttribFormat(vao, 2, 3, gl.FLOAT, false, u32(offset_of(Vertex, tangent)))
        gl.VertexArrayAttribFormat(vao, 3, 2, gl.FLOAT, false, u32(offset_of(Vertex, uv)))
        gl.VertexArrayAttribFormat(vao, 4, 3, gl.FLOAT, false, u32(offset_of(Vertex, color)))

        gl.VertexArrayAttribBinding(vao, 0, 0)
        gl.VertexArrayAttribBinding(vao, 1, 0)
        gl.VertexArrayAttribBinding(vao, 2, 0)
        gl.VertexArrayAttribBinding(vao, 3, 0)
        gl.VertexArrayAttribBinding(vao, 4, 0)

        // albedo_data: []byte = nil
        // normal_map_data: []byte = nil

        // material:^gltf.material = primitive.material
        // if material != nil {
        //     log.debugf("\tProcessing material %v", material.name)
        //     when true {
        //         if material.has_pbr_metallic_roughness {
        //             aa: if material.pbr_metallic_roughness.base_color_texture.texture != nil {
        //                 texture := material.pbr_metallic_roughness.base_color_texture.texture
        //                 log.debugf("\t\tLoading albedo texture '%v' from memory", texture.image_.name)
        //                 buffer := texture.image_.buffer_view
        //                 color_base_data := buffer.buffer.data
        //                 color_offset := buffer.offset

        //                 size := texture.image_.buffer_view.size

        //                 albedo_data = (cast([^]byte)(uintptr(color_base_data) + uintptr(color_offset)))[:size]

        //                 texture = material.normal_texture.texture

        //                 // NOTE(minebill): Do proper checking here
        //                 if texture == nil do break aa
        //                 log.debugf("\t\tLoading normal texture '%v' from memory", texture.image_.name)
        //                 buffer = texture.image_.buffer_view
        //                 color_base_data = buffer.buffer.data
        //                 color_offset = buffer.offset

        //                 size = texture.image_.buffer_view.size

        //                 normal_map_data = (cast([^]byte)(uintptr(color_base_data) + uintptr(color_offset)))[:size]

        //             }

        //             // material.albedo_color = Color(material.pbr_metallic_roughness.base_color_factor)
        //             // material.metallic_factor = material.pbr_metallic_roughness.metallic_factor
        //             // material.roughness_factor = material.pbr_metallic_roughness.roughness_factor
        //         }
        //     }
        // }
        // update_material(&e.material, albedo_data, normal_map_data, nil)
    }
    return model, {}
}

@(importer=PbrMaterial)
import_pbr_material :: proc(metadata: AssetMetadata) -> (asset: ^Asset, error: AssetImportError) {
    material := new_pbr_material()
    material.type = .PbrMaterial

    s: SerializeContext
    serialize_init_file(&s, filepath.join({EditorInstance.active_project.root, metadata.path}))

    serialize_pbr_material(material, &s)

    return material, nil
}

@(importer=Shader)
import_shader :: proc(metadata: AssetMetadata) ->(asset: ^Asset, error: AssetImportError) {
    return
}

// This is a seperate proc from `import_shader` to allow the editor to use it aswell.
import_shader_from_path :: proc(path: string) {
    
}

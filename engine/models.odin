package engine
import "core:log"
import "core:os"
import "core:strings"
import gltf "vendor:cgltf"
import gl "vendor:OpenGL"
import stbi "vendor:stb/image"
import "core:math/linalg"
import "gpu"

WHITE_TEXTURE :: #load("../assets/textures/white_texture.png")
BLACK_TEXTURE :: #load("../assets/textures/black_texture.png")
NORMAL_MAP :: #load("../assets/textures/default_normal_map.png")

Vertex :: struct {
    position:   vec3,
    normal:     vec3,
    tangent:    vec3,
    uv:         vec2,
    color:      vec3,
}

@(asset)
Image :: struct {
    using base: Asset,

    data: []byte,
    width, height: int,
    channels: int,
}

destroy_image :: proc(image: ^Image) {
    stbi.image_free(raw_data(image.data))
    image^ = {}
}

@(asset = {
    ImportFormats = ".glb, .gltf",
})
Mesh :: struct {
    using base: Asset,

    name:           string,
    // vertex_buffer:  u32,
    // index_buffer:   u32,
    // vertex_array:   u32,
    vertex_buffer: gpu.Buffer,
    index_buffer: gpu.Buffer,

    num_indices:    i32,
}

is_mesh_valid :: proc(mesh: Mesh) -> bool {
    return mesh.num_indices > 0
}

mesh_deinit :: proc(mesh: ^Mesh) {
    delete(mesh.name)
}

@(asset)
PbrMaterial :: struct {
    using base: Asset,

    albedo_texture: AssetHandle `asset:"Texture2D"`,
    normal_texture: AssetHandle `asset:"Texture2D"`,
    height_texture: AssetHandle `asset:"Texture2D"`,

    block: UniformBuffer(struct {
        albedo_color:     Color,
        metallic_factor:  f32 `range:"0.0, 1.0"`,
        roughness_factor: f32 `range:"0.0, 1.0"`,
    }),
}

@(constructor=PbrMaterial)
new_pbr_material :: proc() -> ^Asset {
    material := new(PbrMaterial)

    // material.block = create_uniform_buffer(type_of(material.block.data), 10)

    return material
}

@(serializer=PbrMaterial)
serialize_pbr_material :: proc(this: ^Asset, s: ^SerializeContext) {
    this := cast(^PbrMaterial)this

    switch s.mode {
    case .Serialize:
        serialize_begin_table(s, "PbrMaterial")
        // serialize_do_field(s, "AlbedoColor", this.block.albedo_color)
        // serialize_do_field(s, "MetallicFactor", this.block.metallic_factor)
        // serialize_do_field(s, "RoughnessFactor", this.block.roughness_factor)
        serialize_asset_handle(&EngineInstance.asset_manager, s, "AbledoTexture", &this.albedo_texture)
        serialize_asset_handle(&EngineInstance.asset_manager, s, "NormalTexture", &this.normal_texture)

        serialize_end_table(s)
    case .Deserialize:
        if serialize_begin_table(s, "PbrMaterial") {
            // if color, ok := serialize_get_field(s, "AlbedoColor", Color); ok {
            //     this.block.albedo_color = color
            // }
            // if metallic, ok := serialize_get_field(s, "MetallicFactor", f32); ok {
            //     this.block.metallic_factor = metallic
            // }
            // if roughness, ok := serialize_get_field(s, "RoughnessFactor", f32); ok {
            //     this.block.roughness_factor = roughness
            // }

            serialize_asset_handle(&EngineInstance.asset_manager, s, "AbledoTexture", &this.albedo_texture)
            serialize_asset_handle(&EngineInstance.asset_manager, s, "NormalTexture", &this.normal_texture)
            serialize_end_table(s)
        }
    }
}

bind_pbr_material :: proc(m: ^PbrMaterial) {
    manager := &EngineInstance.asset_manager
    /*
    albedo := get_asset(manager, m.albedo_texture, Texture2D)
    if albedo == nil {
        gl.BindTextureUnit(0, get_asset(manager, RendererInstance.white_texture, Texture2D).handle)
    } else {
        gl.BindTextureUnit(0, albedo.handle)
    }

    normal := get_asset(manager, m.normal_texture, Texture2D)
    if normal == nil {
        gl.BindTextureUnit(1, get_asset(manager, RendererInstance.normal_texture, Texture2D).handle)
    } else {
        gl.BindTextureUnit(1, normal.handle)
    }

    // gl.BindBufferBase(gl.UNIFORM_BUFFER, 10, m.block.handle)
    uniform_buffer_rebind(&m.block)
    uniform_buffer_set_data(&m.block)
    */
}

/*
// Currently, every object in a gltf file is be its own buffer.
scene_load_from_file :: proc(w: ^World, file: string) {
    model_data, ok := os.read_entire_file_from_filename(file)
    if !ok do return
    defer delete(model_data)

    options := gltf.options{}
    data, res := gltf.parse(options, raw_data(model_data), len(model_data))
    if res != .success {
        log.errorf("Error while loading model: %v", res)
    }

    res = gltf.load_buffers(options, data, strings.clone_to_cstring(file, context.temp_allocator))
    if res != .success {
        log.errorf("Error while loading model: %v", res)
    }

    assert(len(data.scenes) == 1)
    s := data.scenes[0]

    scene_root := new_object(w, string(s.name))

    for node in s.nodes {
        log.debugf("Processing scene node '%v'", node.name)
        // if node.name != "Cube.002" do continue
        mesh := node.mesh
        // model := Model {}
        // append(&scene.models, new(Model))
        // model := scene.models[len(scene.models) - 1]
        // model.name = strings.clone_from(node.name)

        // model.material = default_material()
        // init_material(&app.device, &model.material, app.material_layout)
        // eh := add_entity(string(node.name), Model_Entity)
        // e := get_entity(eh, Model_Entity)

        go := get_object(w, new_object(w, string(node.name), scene_root))
        e := get_or_add_component(go.world, go.handle, MeshRenderer)
        log.debugf("%v", ds_to_string(go.name))

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

            log.debugf("\tNormal count: %v", len(normal_data))
            log.debugf("\tTangent count: %v", len(tangent_data))
            log.debugf("\tPosiiton count: %v", len(position_data))

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
            go.transform.local_position = node.translation

            r := node.rotation
            qr := quaternion(w = r.w, x = r.x, y = r.y, z = r.z)
            x, y, z := linalg.euler_angles_xyz_from_quaternion(qr)
            go.transform.local_rotation = vec3{x, y, z}
            go.transform.local_scale = node.scale

            accessor := primitive.indices
            data := accessor.buffer_view.buffer.data
            offset := accessor.buffer_view.offset

            indices_raw := cast([^]u16)(uintptr(data) + uintptr(offset))
            count := accessor.count
            indices := indices_raw[:count]

            // model.vertex_buffer = create_vertex_buffer(&app.device, vertices)
            // model.index_buffer = create_index_buffer(&app.device, indices)
            e.model.num_indices = i32(len(indices))
            gl.CreateBuffers(1, &e.model.vertex_buffer)
            gl.NamedBufferStorage(e.model.vertex_buffer, size_of(Vertex) * len(vertices), raw_data(vertices), gl.DYNAMIC_STORAGE_BIT)

            gl.CreateBuffers(1, &e.model.index_buffer)
            gl.NamedBufferStorage(e.model.index_buffer, size_of(u16) * len(indices), raw_data(indices), gl.DYNAMIC_STORAGE_BIT)

            gl.CreateVertexArrays(1, &e.model.vertex_array)

            vao := e.model.vertex_array
            gl.VertexArrayVertexBuffer(vao, 0, e.model.vertex_buffer, 0, size_of(Vertex))
            gl.VertexArrayElementBuffer(vao, e.model.index_buffer)

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

            albedo_data: []byte = nil
            normal_map_data: []byte = nil

            material:^gltf.material = primitive.material
            if material != nil {
                log.debugf("\tProcessing material %v", material.name)
                when true {
                    if material.has_pbr_metallic_roughness {
                        aa: if material.pbr_metallic_roughness.base_color_texture.texture != nil {
                            texture := material.pbr_metallic_roughness.base_color_texture.texture
                            log.debugf("\t\tLoading albedo texture '%v' from memory", texture.image_.name)
                            buffer := texture.image_.buffer_view
                            color_base_data := buffer.buffer.data
                            color_offset := buffer.offset

                            size := texture.image_.buffer_view.size

                            albedo_data = (cast([^]byte)(uintptr(color_base_data) + uintptr(color_offset)))[:size]

                            texture = material.normal_texture.texture

                            // NOTE(minebill): Do proper checking here
                            if texture == nil do break aa
                            log.debugf("\t\tLoading normal texture '%v' from memory", texture.image_.name)
                            buffer = texture.image_.buffer_view
                            color_base_data = buffer.buffer.data
                            color_offset = buffer.offset

                            size = texture.image_.buffer_view.size

                            normal_map_data = (cast([^]byte)(uintptr(color_base_data) + uintptr(color_offset)))[:size]

                        }

                        e.material.albedo_color = Color(material.pbr_metallic_roughness.base_color_factor)
                        e.material.metallic_factor = material.pbr_metallic_roughness.metallic_factor
                        e.material.roughness_factor = material.pbr_metallic_roughness.roughness_factor
                    }
                }
            }
            update_material(&e.material, albedo_data, normal_map_data, nil)
        }
    }

    return
}
*/

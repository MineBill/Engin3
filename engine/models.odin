package engine
import "core:log"
import "core:os"
import "core:strings"
import gltf "vendor:cgltf"
import gl "vendor:OpenGL"
import stbi "vendor:stb/image"
import "core:math/linalg"

WHITE_TEXTURE :: #load("../assets/textures/white_texture.png")
BLACK_TEXTURE :: #load("../assets/textures/black_texture.png")
NORMAL_MAP :: #load("../assets/textures/default_normal_map.png")

Material :: struct {
    name: string,
    using block : struct {
        albedo_color:     Color,
        metallic_factor:  f32 `range:"0.0, 1.0"`,
        roughness_factor: f32 `range:"0.0, 1.0"`,
    },

    albedo_image: ^Image,
    normal_image: ^Image,
    height_image: ^Image,

    albedo_texture: Texture2D,
    normal_texture: Texture2D,
    height_texture: Texture2D,

    ubo: u32,
}

bind_material :: proc(m: ^Material) {
    gl.BindTextureUnit(0, m.albedo_texture.handle)
    gl.BindTextureUnit(1, m.normal_texture.handle)
    gl.BindBufferBase(gl.UNIFORM_BUFFER, 2, m.ubo)
}

default_material :: proc() -> Material {
    return {
        block = {
            albedo_color = Color{1, 1, 1, 1},
            metallic_factor = 0,
            roughness_factor = 0.5,
        },
    }
}

clone_material :: proc(m: Material) -> (clone: Material) {
    clone = m
    create_material(&clone)
    update_material_new(&clone)
    return
}

upload_material :: proc(m: Material) {
    m := m
    gl.NamedBufferSubData(m.ubo, 0, size_of(m.block), &m.block)
}

create_material :: proc(m: ^Material) {
    gl.CreateBuffers(1, &m.ubo)
    gl.NamedBufferStorage(m.ubo, size_of(m.block), &m.block, gl.DYNAMIC_STORAGE_BIT)
}

update_material_new :: proc(m: ^Material) {
    if m.albedo_image == nil {
        m.albedo_image = cast(^Image)image_loader(WHITE_TEXTURE)
    }
    if m.normal_image == nil {
        m.normal_image = cast(^Image)image_loader(NORMAL_MAP)
    }
    if m.height_image == nil {
        m.height_image = cast(^Image)image_loader(BLACK_TEXTURE)
    }

    albedo := m.albedo_image
    normal := m.normal_image
    height := m.height_image

    m.albedo_texture = create_texture(albedo.width, albedo.height, {
        samples = 1,
        format = gl.SRGB8_ALPHA8,
        min_filter = .MipMapLinear,
        mag_filter = .Linear,
        anisotropy = 4,
    })

    set_texture_data(m.albedo_texture, albedo.data)

    m.normal_texture = create_texture(normal.width, normal.height, {
        samples = 1,
        format = gl.RGBA8,
        min_filter = .MipMapLinear,
        mag_filter = .Linear,
        anisotropy = 4,
    })
    set_texture_data(m.normal_texture, normal.data)

    m.height_texture = create_texture(height.width, height.height, {
        samples = 1,
        format = gl.RGBA8,
        min_filter = .Linear,
        mag_filter = .Linear,
        anisotropy = 1,
    })
    set_texture_data(m.height_texture, height.data)
    upload_material(m^)
}

update_material :: proc(m: ^Material, albedo, normal, height: []byte) {
    i, ok := load_image_memory(albedo if albedo != nil else WHITE_TEXTURE)
    defer destroy_image(&i)

    m.albedo_texture = create_texture(i.width, i.height, {
        samples = 1,
        format = gl.SRGB8_ALPHA8,
        min_filter = .MipMapLinear,
        mag_filter = .Linear,
        anisotropy = 4,
    })

    set_texture_data(m.albedo_texture, i.data)

    i2, ok2 := load_image_memory(normal if normal != nil else NORMAL_MAP)
    defer destroy_image(&i2)

    m.normal_texture = create_texture(i2.width, i2.height, {
        samples = 1,
        format = gl.RGBA8,
        min_filter = .MipMapLinear,
        mag_filter = .Linear,
        anisotropy = 4,
    })
    set_texture_data(m.normal_texture, i2.data)

    i3, ok3 := load_image_memory(height if height != nil else BLACK_TEXTURE)
    defer destroy_image(&i3)

    m.height_texture = create_texture(i3.width, i3.height, {
        samples = 1,
        format = gl.RGBA8,
        min_filter = .Linear,
        mag_filter = .Linear,
        anisotropy = 1,
    })
    set_texture_data(m.height_texture, i3.data)

    buffer: [1024]int

    gl.CreateBuffers(1, &m.ubo)
    gl.NamedBufferStorage(m.ubo, size_of(m.block), &m.block, gl.DYNAMIC_STORAGE_BIT)
}

Image :: struct {
    using base: Asset,

    data: []byte,
    width, height: int,
    channels: int,
    file: Maybe(string),
}

load_image_memory :: proc(data: []byte) -> (image: Image, ok: bool) {
    w, h, c: i32
    raw_image := stbi.load_from_memory(raw_data(data), cast(i32)len(data), &w, &h, &c, 4)
    if raw_image == nil {
        log.warnf("Failed to read image: %v", stbi.failure_reason())
        return {}, false
    }

    image.data = raw_image[:w * h * c]
    image.width = int(w)
    image.height = int(h)
    image.channels = int(c)
    return image, true
}

load_image_from_file :: proc(file: string) -> (image: Image, ok: bool) {
    data := os.read_entire_file(file) or_return
    defer delete(data)
    w, h, c: i32
    raw_image := stbi.load_from_memory(raw_data(data), cast(i32)len(data), &w, &h, &c, 4)
    if raw_image == nil {
        log.warnf("Failed to read image: %v", stbi.failure_reason())
        return {}, false
    }

    image.data = raw_image[:w * h * c]
    image.width = int(w)
    image.height = int(h)
    image.channels = int(c)
    return image, true
}

destroy_image :: proc(image: ^Image) {
    stbi.image_free(raw_data(image.data))
    image^ = {}
}

Model :: struct {
    using base: Asset,

    name:           string,
    vertex_buffer:  u32,
    index_buffer:   u32,
    vertex_array:   u32,
    num_indices:    i32,
}

is_model_valid :: proc(model: Model) -> bool {
    return model.num_indices > 0
}

model_deinit :: proc(model: ^Model) {
    delete(model.name)
}

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

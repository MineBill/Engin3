package engine
import "gpu"
import "core:mem"
import "vendor:glfw"
import vk "vendor:vulkan"
import "core:math"
import "core:math/linalg"

import "packages:odin-imgui/imgui_impl_vulkan"
import "packages:odin-imgui/imgui_impl_glfw"
import imgui "packages:odin-imgui"
import "base:runtime"
import "core:fmt"
import tracy "packages:odin-tracy"

Renderer3DInstance: ^Renderer3D
SHADOW_CASCADES :: 4

Renderer3D :: struct {
    instance: gpu.Instance,
    device: gpu.Device,
    stats: gpu.RenderStats,
    swapchain: gpu.Swapchain,

    image_index: u32,
    command_buffers: [3]gpu.CommandBuffer,

    // grug developer logic
    global_set: GlobalSet,
    scene_set: SceneSet,
    object_set: ObjectSet,

    shadow_renderpass: gpu.RenderPass,
    world_renderpass: gpu.RenderPass,
    object_shader, depth_shader: AssetHandle,
    sky_shader: AssetHandle,
    grid_shader: AssetHandle,
    // world_pipeline: gpu.Pipeline,
    ui_renderpass:    gpu.RenderPass,
    ui_pipeline: gpu.Pipeline,

    depth_image: gpu.Image,
    shadow_framebuffers: [SHADOW_CASCADES]gpu.FrameBuffer,
    world_framebuffers: [3]gpu.FrameBuffer,

    global_pool: gpu.ResourcePool,
    pool_allocator: gpu.FrameAllocator,
    // global_uniform_resource_usage: gpu.ResourceUsage,
    // global_uniform_buffer: UniformBuffer(GlobalUniform),
    // scene_uniform_buffer: UniformBuffer(SceneData),
    // light_uniform_buffer: UniformBuffer(LightData),

    // scene_uniform_usage: gpu.ResourceUsage,

    material_pool: gpu.ResourcePool,

    // Probably shouldn't be here.
    imgui_renderpass: gpu.RenderPass,
    object_picking: ObjectPicking,

    swapchain_needs_resize: bool,
    _editor_images: map[gpu.UUID]vk.DescriptorSet,
    _shaders: map[AssetHandle]^Shader,

    visualization_options: VisualizationOptions,

    white_texture, normal_texture, black_texture: AssetHandle,
    primitive_cube: AssetHandle,
    default_material: AssetHandle,
}

tex :: proc(image: gpu.Image) -> imgui.TextureID {
    return transmute(imgui.TextureID) Renderer3DInstance._editor_images[image.id]
}

r3d_setup :: proc(r: ^Renderer3D) {
    Renderer3DInstance = r
    error: gpu.Error
    r.instance, error = gpu.create_instance(
        "Engin3",
        "Engin3",
        0, 0, EngineInstance.window,
    )
    if error != nil {
        log_error(LC.Renderer, "%v", error)
    }

    r.device = gpu.create_device(r.instance, {
        user_data = r,
        image_create = proc(user_data: rawptr, image: ^gpu.Image) {
            m := cast(^Renderer3D) user_data

            if .Sampled in image.spec.usage {
                layout: vk.ImageLayout
                #partial switch image.spec.final_layout {
                case .Undefined, .ColorAttachmentOptimal:
                    layout = .ATTACHMENT_OPTIMAL
                case .DepthStencilReadOnlyOptimal:
                    layout = .DEPTH_STENCIL_READ_ONLY_OPTIMAL
                case:
                    layout = .SHADER_READ_ONLY_OPTIMAL
                }
                m._editor_images[image.id] = imgui_impl_vulkan.AddTexture(
                    image.sampler.handle,
                    image.view.handle,
                    layout,
                )
            }
        },
        image_destroy = proc(user_data: rawptr, image: ^gpu.Image) {
            m := cast(^Renderer3D) user_data

            if image.id in m._editor_images {
                imgui_impl_vulkan.RemoveTexture(m._editor_images[image.id])
            }
        },
    })
    r.stats = gpu.create_render_stats(&r.device)
    gpu.set_global_stats(&r.stats)

    pool_spec := gpu.ResourcePoolSpecification {
        device = &r.device,
        max_sets = 3,
        resource_limits = gpu.make_list([]gpu.ResourceLimit{{
            resource = .UniformBuffer,
            limit    = 5,
        }, {
            resource = .CombinedImageSampler,
            limit    = 5,
        }}),
    }
    r.global_pool = gpu.create_resource_pool(pool_spec)

    pool_spec = gpu.ResourcePoolSpecification {
        device = &r.device,
        max_sets = 20,
        resource_limits = gpu.make_list([]gpu.ResourceLimit{{
            resource = .UniformBuffer,
            limit    = 30,
        }}),
    }
    r.material_pool = gpu.create_resource_pool(pool_spec)

    r.pool_allocator = gpu.create_frame_allocator({device = &r.device, frames = gpu.MAX_FRAMES_IN_FLIGHT})

    r.global_set = build_global_set(r)
    r.scene_set = build_scene_set(r)
    r.object_set = build_object_set(r)
}

r3d_init :: proc(r: ^Renderer3D) {
    r3d_setup_renderpasses(r)
    object_picking_init(&r.object_picking, &r.device)
    create_default_resources(r)

    swapchain_spec := gpu.SwapchainSpecification {
        device = &r.device,
        extent = {
            width = u32(EngineInstance.screen_size.x),
            height = u32(EngineInstance.screen_size.y),
        },
        format = .B8G8R8A8_UNORM,
        renderpass = r.imgui_renderpass
    }

    error: gpu.Error
    r.swapchain, error = gpu.create_swapchain(swapchain_spec)

    object_shader := get_asset(&EngineInstance.asset_manager, r.object_shader, Shader)

    // r.object_set.material = create_uniform_buffer(&r.device,
    //     r.global_pool,
    //     object_shader.pipeline_spec.layout.spec.layouts["object"],
    //     LightData,
    //     "View Data")

    cmd_spec := gpu.CommandBufferSpecification {
        tag = "Swapchain Command Buffer",
        device = r.device,
    }
    r.command_buffers = gpu.create_command_buffers(r.device, cmd_spec, 3)

    dbg_init(g_dbg_context, r.world_renderpass)
}

r3d_deinit :: proc(r: ^Renderer3D) {
    gpu.device_wait(r.device)
    object_picking_deinit(&r.object_picking)
}

RPacket :: struct {
    scene: ^World,
    camera: RenderCamera,
    size: vec2i,
}

r3d_draw_frame :: proc(r: ^Renderer3D, packet: RPacket, cmd: gpu.CommandBuffer) {
    tracy.Zone()

    packet := packet

    object_shader := get_asset(&EngineInstance.asset_manager, r.object_shader, Shader)

    r.global_set.uniform_buffer.data.projection = packet.camera.projection
    r.global_set.uniform_buffer.data.view = packet.camera.view
    r.global_set.uniform_buffer.data.screen_size = Vector2{cast(f32)packet.size.x, cast(f32)packet.size.y}
    uniform_buffer_flush(&r.global_set.uniform_buffer)

    r.global_set.debug_options.data = visualization_options_to_shader(r.visualization_options)
    uniform_buffer_flush(&r.global_set.debug_options)

    r.global_set.global_data.time += EngineInstance.delta
    uniform_buffer_flush(&r.global_set.global_data)

    gpu.bind_resource(cmd, r.global_set.resource, object_shader.pipeline)

    mesh_components := make([dynamic]^MeshRenderer, allocator = context.temp_allocator)
    {
        tracy.ZoneN("Mesh Collection")
        for handle, &go in packet.scene.objects do if go.enabled && has_component(packet.scene, handle, MeshRenderer) {
            mr := get_component(packet.scene, handle, MeshRenderer)
            if is_asset_handle_valid(&EngineInstance.asset_manager, mr.mesh) {
                append(&mesh_components, mr)
            }
        }
    }

    splits := do_depth_pass(r, &packet, cmd, mesh_components[:])
    r.scene_set.light_data.shadow_split_distances = splits

    size := EngineInstance.screen_size
    if gpu.do_render_pass(cmd, r.world_renderpass, r.world_framebuffers[0]) {
        tracy.ZoneN("World Pass")
        gpu.set_viewport(cmd, {size.x, -size.y})
        gpu.set_scissor(cmd, 0, 0, u32(size.x), u32(size.y))

        render_scene(r, &packet, cmd, mesh_components[:])

        gpu.bind_resource(cmd, r.global_set.resource, g_dbg_context.pipeline)
        // NOTE(minebill): Is this the correct place for this?
        dbg_render(g_dbg_context, cmd, EngineInstance.delta)

        {
            grid_shader := get_asset(&EngineInstance.asset_manager, r.grid_shader, Shader)
            gpu.bind_resource(cmd, r.global_set.resource, grid_shader.pipeline)
            gpu.bind_resource(cmd, r.scene_set.resource, grid_shader.pipeline, 1)
            gpu.pipeline_bind(cmd, grid_shader.pipeline)
            gpu.draw(cmd, 6, 1)
        }
    }

    object_picking_render(&r.object_picking, packet, cmd, mesh_components[:])
}

r3d_begin_frame :: proc(r: ^Renderer3D) -> (cmd: gpu.CommandBuffer, ok: bool) {
    tracy.Zone()
    error: gpu.SwapchainError
    r.image_index, error = gpu.swapchain_get_next_image(&r.swapchain)
    #partial switch error {
    case .SwapchainOutOfDate, .SwapchainSuboptimal:
        gpu.device_wait(r.device)
        width, height := glfw.GetFramebufferSize(EngineInstance.window)
        log_debug(LC.Renderer, "Got out of date/suboptimal swapchain, resizing to: (%v, %v)", width, height)
        gpu.swapchain_resize(&r.swapchain, {f32(width), f32(height)})
        return
    }

    gpu.frame_allocator_reset(&r.pool_allocator)

    cmd = r.command_buffers[r.image_index]
    gpu.reset(cmd)
    gpu.cmd_begin(cmd)
    gpu.stats_begin_frame(cmd)
    return cmd, true
}

r3d_end_frame :: proc(r: ^Renderer3D, cmd: gpu.CommandBuffer) {
    if cmd.handle != nil {
        gpu.stats_end_frame(cmd)
        gpu.cmd_end(cmd, {})
        gpu.swapchain_cmd_submit(&r.swapchain, {cmd})
    }

    gpu.swapchain_present(&r.swapchain, r.image_index)

    gpu.stats_collect()
}

r3d_on_resize :: proc(r: ^Renderer3D, size: vec2) {
    log_info(LC.Renderer, "New renderer size is: %v", size)
    gpu.device_wait(r.device)

    for i in 0..<len(r.world_framebuffers) {
        gpu.framebuffer_resize(&r.world_framebuffers[i], size)
    }

    object_picking_resize(&r.object_picking, size)
}

r3d_resize_swapchain :: proc(r: ^Renderer3D, size: vec2) {
    // r.swapchain_needs_resize = true
    // gpu.device_wait(r.device)
    // gpu.swapchain_resize(&r.swapchain, size)
}

@(private = "file")
render_scene :: proc(r: ^Renderer3D, packet: ^RPacket, cmd: gpu.CommandBuffer, mesh_components: []^MeshRenderer) {
    tracy.Zone()
    asset_manager := &EngineInstance.asset_manager

    for handle, &go in packet.scene.objects do if go.enabled && has_component(packet.scene, handle, DirectionalLight) {
        dir_light := get_component(packet.scene, handle, DirectionalLight)
        rot := go.transform.local_rotation
        dir_light_quat := linalg.quaternion_from_euler_angles(
            rot.y * math.RAD_PER_DEG,
            rot.x * math.RAD_PER_DEG,
            rot.z * math.RAD_PER_DEG,
            .YXZ)
        dir := linalg.quaternion_mul_vector3(dir_light_quat, vec3{0, 0, 1})

        light_data := &r.scene_set.light_data
        light_data.directional.direction = vec4{dir.x, dir.y, dir.z, 0}
        light_data.directional.color = dir_light.color
        // light_data.directional.light_space_matrix[split] = view_data.projection * view_data.view

        uniform_buffer_flush(light_data)
        // uniform_buffer_set_data(light_data,
        //     offset_of(light_data.data.directional),
        //     size_of(light_data.data.directional))
    }

    r.scene_set.scene_data.view_direction = linalg.quaternion_mul_vector3(
        packet.camera.rotation, vec3{0, 0, 1},
    )
    r.scene_set.scene_data.view_position = packet.camera.position
    r.scene_set.scene_data.ambient_color = packet.scene.ambient_color
    uniform_buffer_flush(&r.scene_set.scene_data)

    gpu.resource_bind_image(r.scene_set.resource, r.depth_image, .CombinedImageSampler, 2)

    {
        sky_shader := get_asset(&EngineInstance.asset_manager, r.sky_shader, Shader)
        gpu.pipeline_bind(cmd, sky_shader.pipeline)
        gpu.bind_resource(cmd, r.global_set.resource, sky_shader.pipeline, 0)
        gpu.bind_resource(cmd, r.scene_set.resource, sky_shader.pipeline, 1)

        gpu.draw(cmd, 4, 1)
    }
    object_shader := get_asset(&EngineInstance.asset_manager, r.object_shader, Shader)
    gpu.pipeline_bind(cmd, object_shader.pipeline)
    gpu.bind_resource(cmd, r.global_set.resource, object_shader.pipeline, 0)
    gpu.bind_resource(cmd, r.scene_set.resource, object_shader.pipeline, 1)

    for mr in mesh_components {
        tracy.ZoneN("Draw Mesh")
        mesh := get_asset(asset_manager, mr.mesh, Mesh)
        if mesh == nil do continue

        go := get_object(packet.scene, mr.owner)

        material := get_asset(&EngineInstance.asset_manager, mr.material, PbrMaterial)
        fmt.assertf(material != nil, "Cannot have <nil> material. A default one should have been assigned.")

        // gpu.frame_allocator_alloc(&r.pool_allocator, )
        {
            tracy.ZoneN("Object set allocation")
            manager := &EngineInstance.asset_manager

            object_set := build_object_set(r)
            albedo := get_asset(manager, material.albedo_texture, Texture2D)
            if albedo == nil {
                albedo = get_asset(manager, Renderer3DInstance.white_texture, Texture2D)
            }

            normal := get_asset(manager, material.normal_texture, Texture2D)
            if normal == nil {
                normal = get_asset(manager, Renderer3DInstance.normal_texture, Texture2D)
            }

            ao := get_asset(manager, material.ambient_occlusion_texture, Texture2D)
            if ao == nil {
                ao = get_asset(manager, Renderer3DInstance.white_texture, Texture2D)
            }

            emissive := get_asset(manager, material.emissive_texture, Texture2D)
            if emissive == nil {
                emissive = get_asset(manager, Renderer3DInstance.black_texture, Texture2D)
            }

            metallic_roughness := get_asset(manager, material.metallic_texture, Texture2D)
            if metallic_roughness == nil {
                metallic_roughness = get_asset(manager, Renderer3DInstance.white_texture, Texture2D)
            }

            object_set.material = material^
            // @note This is where we could use shader reflection i guess?
            gpu.resource_bind_buffer(object_set.resource, object_set.material.block.handle, .UniformBuffer, 0)
            gpu.resource_bind_image(object_set.resource, albedo.handle, .CombinedImageSampler, 1)
            gpu.resource_bind_image(object_set.resource, normal.handle, .CombinedImageSampler, 2)
            gpu.resource_bind_image(object_set.resource, ao.handle, .CombinedImageSampler, 3)
            gpu.resource_bind_image(object_set.resource, emissive.handle, .CombinedImageSampler, 4)
            gpu.resource_bind_image(object_set.resource, metallic_roughness.handle, .CombinedImageSampler, 5)

            uniform_buffer_flush(&object_set.material.block)
            gpu.bind_resource(cmd, object_set.resource, object_shader.pipeline, 2)
        }

        mat := go.transform.global_matrix
        push := PushConstants {
            model = mat,
            local_entity_id = go.local_id,
        }
        vk.CmdPushConstants(
            cmd.handle,
            object_shader.pipeline.spec.layout.handle,
            {.VERTEX, .FRAGMENT},
            0, size_of(PushConstants), &push)

        gpu.bind_buffers(cmd, mesh.vertex_buffer)
        gpu.bind_buffers(cmd, mesh.index_buffer)
        gpu.draw_indexed(cmd, mesh.num_indices, 1, 0)
    }
}

do_depth_pass :: proc(r: ^Renderer3D, packet: ^RPacket, cmd: gpu.CommandBuffer, mesh_components: []^MeshRenderer) -> (distances: [4]f32) {
    scene := packet.scene
    view_data := &r.global_set.uniform_buffer

    for split in 0..<SHADOW_CASCADES {
        for handle, &go in scene.objects do if go.enabled && has_component(scene, handle, DirectionalLight) {
            dir_light := get_component(scene, handle, DirectionalLight)
            z := get_split_depth(split + 1, SHADOW_CASCADES, packet.camera.near, packet.camera.far, dir_light.shadow.correction)
            distances[split] = z
        }
    }

    for split in 0..<SHADOW_CASCADES {
        if gpu.do_render_pass(cmd, r.shadow_renderpass, r.shadow_framebuffers[split]) {
            size := vec2{SHADOW_MAP_RES, SHADOW_MAP_RES}
            gpu.set_viewport(cmd, {size.x, -size.y})
            gpu.set_scissor(cmd, 0, 0, u32(size.x), u32(size.y))


            depth_shader := get_asset(&EngineInstance.asset_manager, r.depth_shader, Shader)
            assert(depth_shader != nil)

            gpu.pipeline_bind(cmd, depth_shader.pipeline)
            // gpu.bind_resource(cmd, r.scene_set.resource, object_shader.pipeline, 1)

            // Depth Pass, for lighting
            {
                for handle, &go in scene.objects do if go.enabled && has_component(scene, handle, DirectionalLight) {
                    dir_light := get_component(scene, handle, DirectionalLight)
                    rot := go.transform.local_rotation
                    dir_light_quat := linalg.quaternion_from_euler_angles(
                        rot.y * math.RAD_PER_DEG,
                        rot.x * math.RAD_PER_DEG,
                        rot.z * math.RAD_PER_DEG,
                        .YXZ)
                    dir := linalg.quaternion_mul_vector3(dir_light_quat, vec3{0, 0, 1})
                    near := packet.camera.near

                    z := distances[split]

                    proj := linalg.matrix4_perspective_f32(
                        math.to_radians(f32(50)),
                        f32(packet.size.x) / f32(packet.size.y),
                        // distances[split], packet.camera.far if split < SHADOW_CASCADES else distances[split + 1])
                        near, z * packet.camera.far)
                        // distances[split - 1] if split > 0 else near, z)

                    corners := get_frustum_corners_world_space(
                        proj,
                        packet.camera.view)

                    center := vec3{}
                    for corner in corners {
                        center += corner.xyz
                    }

                    center /= len(corners)

                    view_data.view = linalg.matrix4_look_at_f32(center + dir, center, vec3{0, 1, 0})

                    min_f :: min(f32)
                    max_f :: max(f32)

                    min, max := vec3{max_f, max_f, max_f}, vec3{min_f, min_f, min_f}

                    for corner in corners {
                        hm := (view_data.view * corner).xyz
                        if hm.x < min.x do min.x = hm.x
                        if hm.y < min.y do min.y = hm.y
                        if hm.z < min.z do min.z = hm.z
                        if hm.x > max.x do max.x = hm.x
                        if hm.y > max.y do max.y = hm.y
                        if hm.z > max.z do max.z = hm.z
                    }

                    view_data.projection = linalg.matrix_ortho3d_f32(
                        left = min.x,
                        right = max.x,
                        bottom = min.y,
                        top = max.y,
                        near = min.z * 10,
                        far = max.z / 10)

                        // dbg_draw_sphere(g_dbg_context, center, color = COLOR_PEACH)

                    if .ShadowCascadeBoxes in r.visualization_options {
                        light_corners := get_frustum_corners_world_space(view_data.projection, view_data.view)
                        center := vec3{}
                        for corner in light_corners {
                            center += corner.xyz
                        }

                        r := f32(split) / f32(dir_light.shadow.splits)
                        color := Color{r, r, r, 1.0}
                        switch split {
                        case 0:
                            color = COLOR_RED
                        case 1:
                            color = COLOR_BLUE
                        case 2:
                            color = COLOR_GREEN
                        case 3:
                            color = COLOR_YELLOW
                        }
                        dbg_draw_line(g_dbg_context, light_corners[0].xyz + center, light_corners[1].xyz + center, 2.0, color)
                        dbg_draw_line(g_dbg_context, light_corners[2].xyz + center, light_corners[3].xyz + center, 2.0, color)
                        dbg_draw_line(g_dbg_context, light_corners[4].xyz + center, light_corners[5].xyz + center, 2.0, color)
                        dbg_draw_line(g_dbg_context, light_corners[6].xyz + center, light_corners[7].xyz + center, 2.0, color)

                        dbg_draw_line(g_dbg_context, light_corners[0].xyz + center, light_corners[2].xyz + center, 2.0, color)
                        dbg_draw_line(g_dbg_context, light_corners[2].xyz + center, light_corners[6].xyz + center, 2.0, color)
                        dbg_draw_line(g_dbg_context, light_corners[6].xyz + center, light_corners[4].xyz + center, 2.0, color)
                        dbg_draw_line(g_dbg_context, light_corners[4].xyz + center, light_corners[0].xyz + center, 2.0, color)

                        dbg_draw_line(g_dbg_context, light_corners[1].xyz + center, light_corners[3].xyz + center, 2.0, color)
                        dbg_draw_line(g_dbg_context, light_corners[3].xyz + center, light_corners[7].xyz + center, 2.0, color)
                        dbg_draw_line(g_dbg_context, light_corners[7].xyz + center, light_corners[5].xyz + center, 2.0, color)
                        dbg_draw_line(g_dbg_context, light_corners[5].xyz + center, light_corners[1].xyz + center, 2.0, color)
                    }

                    light_data := &r.scene_set.light_data
                    light_space := view_data.projection * view_data.view
                    light_data.directional.light_space_matrix[split] = light_space

                    for mr in mesh_components {
                        mesh := get_asset(&EngineInstance.asset_manager, mr.mesh, Mesh)
                        if mesh == nil do continue

                        go := get_object(scene, mr.owner)

                        mat := go.transform.global_matrix
                        push := DepthPassPushConstants {
                            model = mat,
                            light_space = light_space,
                        }

                        vk.CmdPushConstants(
                            cmd.handle,
                            depth_shader.pipeline.spec.layout.handle,
                            {.VERTEX, .FRAGMENT},
                            0, size_of(DepthPassPushConstants), &push)

                        gpu.bind_buffers(cmd, mesh.vertex_buffer)
                        gpu.bind_buffers(cmd, mesh.index_buffer)
                        gpu.draw_indexed(cmd, mesh.num_indices, 1, 0)
                    }
                }
            }
        }
    }
    return
}

UniformBuffer :: struct($T: typeid) {
    using data: T,

    handle: gpu.Buffer,
    resource: gpu.Resource,
}

create_uniform_buffer :: proc(device: ^gpu.Device, $T: typeid, $name: cstring) -> (buffer: UniformBuffer(T)) {
    spec := gpu.BufferSpecification {
        name = name + " UBO",
        device = device,
        size = size_of(T),
        usage = {.Uniform},
        mapped = true,
    }

    buffer.handle = gpu.create_buffer(spec)

    // layout := gpu.create_resource_layout(device^, {
    //     type = .UniformBuffer,
    //     count = 1,
    //     stage = {.Vertex, .Fragment},
    // })

    // alloc_error: gpu.ResourceAllocationError
    // buffer.resource, alloc_error = gpu.allocate_resource(pool, layout)
    // fmt.assertf(alloc_error == nil, "Resource allocation error: %v", alloc_error)

    // gpu.resource_bind_buffer(buffer.resource, buffer.handle, .UniformBuffer)
    return
}

uniform_buffer_flush :: proc(ubo: ^UniformBuffer($T)) {
    mem.copy(ubo.handle.alloc_info.pMappedData, &ubo.data, size_of(T))
}

@(private = "file")
r3d_setup_renderpasses :: proc(r: ^Renderer3D) -> (ok: bool) {
    vertex_layout := gpu.vertex_layout({
        name = "Position",
        type = .Float3,
    }, {
        name = "Normal",
        type = .Float3,
    }, {
        name = "Tangent",
        type = .Float3,
    }, {
        name = "UV",
        type = .Float2,
    }, {
        name = "Color",
        type = .Float3,
    })

    // ==============================
    // === Dear ImGui Render Pass ===
    // ==============================

    imgui: {
        renderpass_spec := gpu.RenderPassSpecification {
            tag         = "Dear ImGui Render Pass",
            device      = &r.device,
            attachments = gpu.make_list([]gpu.RenderPassAttachment {
                {
                    tag          = "Color",
                    format       = .B8G8R8A8_UNORM,
                    load_op      = .Clear,
                    store_op     = .Store, // ?
                    final_layout = .PresentSrc,
                    clear_color  = vec4{0.15, 0.15, 0.15, 1},
                },
                {
                    tag          = "Depth",
                    format       = .D32_SFLOAT,
                    load_op      = .Clear,
                    final_layout = .DepthStencilAttachmentOptimal,
                    clear_depth  = 1.0,
                },
            }),
            subpasses = {
                {
                    color_attachments = gpu.make_list([]gpu.RenderPassAttachmentRef {{
                        attachment = 0, layout = .ColorAttachmentOptimal,
                    }}),
                    depth_stencil_attachment = gpu.RenderPassAttachmentRef {
                        attachment = 1, layout = .DepthStencilAttachmentOptimal,
                    },
                },
            },
        }

        r.imgui_renderpass = gpu.create_render_pass(renderpass_spec)
        initialize_imgui_for_vulkan(r)
    }

    // =========================
    // === Depth Render Pass ===
    // =========================

    depth: {
        renderpass_spec := gpu.RenderPassSpecification {
            tag = "ShadowPass",
            device = &r.device,
            attachments = {
                {
                    tag          = "Depth",
                    format       = .D32_SFLOAT,
                    load_op      = .Clear,
                    store_op     = .Store,
                    samples      = 1,
                    final_layout = .DepthStencilReadOnlyOptimal,
                    clear_depth  = 1.0,
                },
            },
            subpasses = {
                {
                    depth_stencil_attachment = gpu.RenderPassAttachmentRef {
                        attachment = 0, layout = .DepthStencilAttachmentOptimal,
                    },
                }
            }
        }

        r.shadow_renderpass = gpu.create_render_pass(renderpass_spec, true)

        pipeline_layout_spec := gpu.PipelineLayoutSpecification {
            tag = "Depth Pipeline Layout",
            device = &r.device,
            layouts = {
            },
            use_push = true,
        }

        depth_pipeline_layout := gpu.create_pipeline_layout(pipeline_layout_spec, size_of(DepthPassPushConstants))

        config := gpu.default_pipeline_config()
        config.multisample_info.rasterizationSamples = {._1}
        config.multisample_info.sampleShadingEnable = false
        config.rasterization_info.cullMode = {}
        config.rasterization_info.depthBiasEnable = true

        pipeline_spec := gpu.PipelineSpecification {
            tag = "Depth Pipeline",
            layout = depth_pipeline_layout,
            attribute_layout = vertex_layout,
            renderpass = r.shadow_renderpass,
            config = config,
        }

        manager := &EngineInstance.asset_manager
        id := AssetHandle(generate_uuid())
        manager.registry[id] = AssetMetadata {
            path = "assets/shaders/new/depth.shader",
            type = .Shader,
            dont_serialize = true,
        }
        manager.loaded_assets[id] = new_shader(manager.registry[id].path, pipeline_spec) or_return

        r.depth_shader = id

        // Create depth image
        depth_image_spec := gpu.ImageSpecification {
            device = &r.device,
            width = SHADOW_MAP_RES,
            height = SHADOW_MAP_RES,
            layer_count = SHADOW_CASCADES,
            format = renderpass_spec.attachments[0].format,
            usage = {.DepthStencilAttachment, .Sampled},
            sampler = {},
            layout = .Undefined,
            final_layout = .DepthStencilReadOnlyOptimal,
        }
        r.depth_image = gpu.create_image(depth_image_spec)

        for i in 0..<SHADOW_CASCADES {

            spec := gpu.FrameBufferSpecification {
                device = &r.device,
                width = SHADOW_MAP_RES,
                height = SHADOW_MAP_RES,
                renderpass = r.shadow_renderpass,
            }
            // Create view
            image_view_spec := gpu.ImageViewSpecification {
                device = &r.device,
                format = depth_image_spec.format,
                view_type = .D2_Array,
                base_layer_index = i,
                layer_count = 1,
            }
            view := gpu.create_image_view(r.depth_image, image_view_spec)

            // NOTE(minebill): The framebuffer only really cares about the view, so we
            // just create a dumb struct here with just a view.
            image := gpu.Image {
                view = view,
            }

            r.shadow_framebuffers[i] = gpu.create_framebuffer_from_images(spec, []gpu.Image {image})
        }
    }

    // =========================
    // === World Render Pass ===
    // =========================

    world: {
        renderpass_spec := gpu.RenderPassSpecification {
            tag         = "Object RenderPass",
            device      = &r.device,
            attachments = gpu.make_list([]gpu.RenderPassAttachment {
                {
                    tag          = "Color",
                    format       = .R8G8B8A8_SRGB,
                    load_op      = .Clear,
                    store_op     = .DontCare, // ?
                    final_layout = .ColorAttachmentOptimal,
                    samples      = 8,
                    clear_color  = vec4{0.15, 0.15, 0.15, 1},
                },
                {
                    tag          = "Color Resolve Target",
                    format       = .R8G8B8A8_SRGB,
                    load_op      = .DontCare,
                    store_op     = .Store, // ?
                    final_layout = .ColorAttachmentOptimal,
                    samples      = 1,
                },
                {
                    tag          = "Depth",
                    format       = .D32_SFLOAT_S8_UINT,
                    load_op      = .Clear,
                    store_op     = .Store,
                    samples      = 8,
                    final_layout = .DepthStencilAttachmentOptimal,
                    clear_depth  = 1.0,
                    stencil_load_op = .Clear,
                    stencil_store_op = .Store,
                },
            }),

            subpasses = {
                {
                    color_attachments = gpu.make_list([]gpu.RenderPassAttachmentRef {
                        {
                            attachment = 0, layout = .ColorAttachmentOptimal,
                        },
                    }),
                    depth_stencil_attachment = gpu.RenderPassAttachmentRef {
                        attachment = 2, layout = .DepthStencilAttachmentOptimal,
                    },
                    resolve_attachments = {
                        {
                            attachment = 1,
                            layout = .ColorAttachmentOptimal,
                        },
                    },
                },
            },
        }

        r.world_renderpass = gpu.create_render_pass(renderpass_spec)
        for i in 0..<len(r.world_framebuffers) {
            fb_spec := gpu.FrameBufferSpecification {
                device = &r.device,
                width = 100, height = 100,
                samples = 8,
                renderpass = r.world_renderpass,
                attachments = {
                    {
                        format = .R8G8B8A8_SRGB,
                        usage = {.Transient, .ColorAttachment},
                        samples = 8,
                    },
                    {
                        format = .R8G8B8A8_SRGB,
                        usage = {.ColorAttachment, .Sampled},
                        samples = 1,
                    },
                    {
                        format = .D32_SFLOAT_S8_UINT,
                        usage = {.Transient, .DepthStencilAttachment},
                        samples = 8,
                    }
                },
            }

            r.world_framebuffers[i] = gpu.create_framebuffer(fb_spec)
        }

        pipeline_layout_spec := gpu.PipelineLayoutSpecification {
            tag = "Object Pipeline Layout",
            device = &r.device,
            layouts = {
                r.global_set.layout,
                r.scene_set.layout,
                r.object_set.layout,
            },
            use_push = true,
        }

        world_pipeline_layout := gpu.create_pipeline_layout(pipeline_layout_spec, size_of(PushConstants))

        config := gpu.default_pipeline_config()
        config.multisample_info.rasterizationSamples = {._8}
        config.multisample_info.sampleShadingEnable = true
        config.rasterization_info.cullMode = {}

        config.depth_stencil_info.stencilTestEnable = true
        config.depth_stencil_info.back.compareOp = .ALWAYS
        config.depth_stencil_info.back.failOp = .REPLACE
        config.depth_stencil_info.back.depthFailOp = .REPLACE
        config.depth_stencil_info.back.passOp = .REPLACE
        config.depth_stencil_info.back.compareMask = 0xff
        config.depth_stencil_info.back.writeMask = 0xff
        config.depth_stencil_info.back.reference = 1

        config.depth_stencil_info.front = config.depth_stencil_info.back

        pipeline_spec := gpu.PipelineSpecification {
            tag = "Object Pipeline",
            layout = world_pipeline_layout,
            attribute_layout = vertex_layout,
            renderpass = r.world_renderpass,
            config = config,
        }

        manager := &EngineInstance.asset_manager
        id := AssetHandle(generate_uuid())
        manager.registry[id] = AssetMetadata {
            path = "assets/shaders/new/simple_3d.shader",
            type = .Shader,
            dont_serialize = true,
        }
        manager.loaded_assets[id] = new_shader("assets/shaders/new/simple_3d.shader", pipeline_spec) or_return

        r.object_shader = id

        sky_pl_layout_spec := gpu.PipelineLayoutSpecification {
            tag = "Sky PL Layout",
            device = &r.device,
            layouts = {
                r.global_set.layout,
                r.scene_set.layout,
            }
        }

        sky_pl_layout := gpu.create_pipeline_layout(sky_pl_layout_spec)

        config = gpu.default_pipeline_config()
        config.multisample_info.rasterizationSamples = {._8}
        config.multisample_info.sampleShadingEnable = true
        config.rasterization_info.cullMode = {.FRONT}
        config.depth_stencil_info.depthTestEnable = false
        config.input_assembly_info.topology = .TRIANGLE_STRIP

        sky_pl_spec := gpu.PipelineSpecification {
            tag = "Sky PL",
            renderpass = r.world_renderpass,
            layout = sky_pl_layout,
            config = config,
        }

        r.sky_shader = AssetHandle(generate_uuid())
        manager.registry[r.sky_shader] = AssetMetadata {
            path = "assets/shaders/new/simple_sky.shader",
            type = .Shader,
            dont_serialize = true,
        }
        manager.loaded_assets[r.sky_shader] = new_shader(manager.registry[r.sky_shader].path, sky_pl_spec) or_return
    }

    pipeline_layout_spec := gpu.PipelineLayoutSpecification {
        tag = "Grid Pipeline Layout",
        device = &r.device,
        layouts = {
            r.global_set.layout,
            r.scene_set.layout,
        },
        use_push = true,
    }

    pipeline_layout := gpu.create_pipeline_layout(pipeline_layout_spec, size_of(PushConstants))

    config := gpu.default_pipeline_config()
    config.multisample_info.rasterizationSamples = {._8}
    config.multisample_info.sampleShadingEnable = true
    config.rasterization_info.cullMode = {.FRONT}
    config.colorblend_attachment_info.blendEnable = true

    pipeline_spec := gpu.PipelineSpecification {
        tag = "Grid Pipeline",
        layout = pipeline_layout,
        renderpass = r.world_renderpass,
        // attribute_layout = gpu.vertex_layout(),
        config = config,
    }

    manager := &EngineInstance.asset_manager
    id := AssetHandle(generate_uuid())

    manager.registry[id] = AssetMetadata {
        path = "assets/shaders/new/grid.shader",
        type = .Shader,
        dont_serialize = true,
    }
    manager.loaded_assets[id] = new_shader(manager.registry[id].path, pipeline_spec) or_return
    r.grid_shader = id

    return true
}

@(private = "file")
create_default_resources :: proc(r: ^Renderer3D) {
    spec := TextureSpecification {
        width = 1,
        height = 1,
        samples = 1,
        anisotropy = 1,
        filter = .Nearest,
        format = .RGBA8,
    }

    white_data := []byte {255, 255, 255, 255}
    white := new_texture2d(spec, white_data, "White Texture")
    r.white_texture = create_virtual_asset(&EngineInstance.asset_manager, white, "Default White Texture")
    gpu.image_transition_layout(&white.handle, .ShaderReadOnlyOptimal)

    normal_data := []byte {128, 128, 255, 255}
    normal := new_texture2d(spec, normal_data, "Normal Texture")
    r.normal_texture = create_virtual_asset(&EngineInstance.asset_manager, normal, "Default Normal Texture")
    gpu.image_transition_layout(&normal.handle, .ShaderReadOnlyOptimal)

    black_data := []byte {0, 0, 0, 255}
    black := new_texture2d(spec, black_data, "Black Texture")
    r.black_texture = create_virtual_asset(&EngineInstance.asset_manager, black, "Default Black Texture")
    gpu.image_transition_layout(&black.handle, .ShaderReadOnlyOptimal)

    cube := new_mesh_from_file("assets/models/primitives/cube.glb")
    assert(cube != nil, "Failed to load cube primitive")
    r.primitive_cube = create_virtual_asset(&EngineInstance.asset_manager, cube, "Primitive Cube")

    material := cast(^PbrMaterial) new_pbr_material()
    material.albedo_texture = r.white_texture
    material.normal_texture = r.normal_texture
    material.block.albedo_color = Color{1, 1, 1, 1}
    material.block.metallic_factor = 0.5
    material.block.roughness_factor = 0.5

    r.default_material = create_virtual_asset(&EngineInstance.asset_manager, &material.base, "Default Material")
}

// NOTE(minebill): Remember to factor this out, somehow.
@(private = "file")
initialize_imgui_for_vulkan :: proc(r: ^Renderer3D) {
    s := r
    IMGUI_MAX :: 100
    imgui_descriptor_pool := gpu._vk_device_create_descriptor_pool(s.device, IMGUI_MAX, {
        { .COMBINED_IMAGE_SAMPLER, IMGUI_MAX},
        { .SAMPLER, IMGUI_MAX},
        { .SAMPLED_IMAGE, IMGUI_MAX },
        { .STORAGE_IMAGE, IMGUI_MAX },
        { .UNIFORM_TEXEL_BUFFER, IMGUI_MAX },
        { .STORAGE_TEXEL_BUFFER, IMGUI_MAX },
        { .UNIFORM_BUFFER, IMGUI_MAX },
        { .STORAGE_BUFFER, IMGUI_MAX },
        { .UNIFORM_BUFFER_DYNAMIC, IMGUI_MAX },
        { .STORAGE_BUFFER_DYNAMIC, IMGUI_MAX },
        { .INPUT_ATTACHMENT, IMGUI_MAX },
    }, {.FREE_DESCRIPTOR_SET})

    imgui_init := imgui_impl_vulkan.InitInfo {
        Instance = s.instance.handle,
        PhysicalDevice = s.device.physical_device,
        Device = s.device.handle,
        QueueFamily = u32(0), // TODO: This is wrong. It just happens to line up for now.
        Queue = s.device.graphics_queue,
        PipelineCache = 0, // NOTE(minebill): We don't use pipeline caches right now.
        DescriptorPool = imgui_descriptor_pool,
        Subpass = 0,
        MinImageCount = 2,
        ImageCount = 2,
        MSAASamples = {._1},

        // Dynamic Rendering (Optional)
        UseDynamicRendering = false,

        // Allocation, Debugging
        Allocator = nil,
        CheckVkResultFn = proc"c"(result: vk.Result) {
            if result != .SUCCESS {
                // context = EngineInstance.ctx
                context = runtime.default_context()
                // log_error(LC.Renderer, "Vulkan error from imgui: %v", result)
                fmt.eprintfln("Vulkan error from imgui: %v", result)
            }
        },
    }

    imgui.CHECKVERSION()
    imgui.CreateContext(nil)
    io := imgui.GetIO()
    io.ConfigFlags += {.DockingEnable, .ViewportsEnable, .IsSRGB, .NavEnableKeyboard}

    imgui_impl_glfw.InitForVulkan(EngineInstance.window, true)
    imgui_impl_vulkan.LoadFunctions(proc "c" (name: cstring, user_data: rawptr) -> vk.ProcVoidFunction {
        // NOTE(minebill): Odin recommends not to use auto_cast but eh.
        return vk.GetInstanceProcAddr(auto_cast user_data, name)
    }, s.instance.handle)

    imgui_impl_vulkan.Init(&imgui_init, s.imgui_renderpass.handle)
}

TextureSpecification :: struct {
    width, height: int,
    samples: int,
    anisotropy: int,
    filter: TextureFilter,
    format, desired_format: TextureFormat,
    type: TextureType,
    wrap: TextureWrap,
    pixel_type: TexturePixelType,
}

@(asset)
Texture :: struct {
    using base: Asset,

    handle: gpu.Image,
    spec: TextureSpecification,
}

@(asset = {
    ImportFormats = ".png,.jpg,.jpeg",
})
Texture2D :: struct {
    using texture_base: Texture,
}

create_texture2d :: proc(spec: TextureSpecification, data: []byte = {}, tag: cstring = "") -> (texture: Texture2D) {
    spec := spec
    spec.samples = 1 if spec.samples <= 0 else spec.samples
    spec.anisotropy = 1 if spec.anisotropy <= 0 else spec.anisotropy
    spec.desired_format = spec.format if spec.desired_format == nil else spec.desired_format
    spec.pixel_type = .Unsigned if spec.pixel_type == nil else spec.pixel_type
    texture.spec = spec

    image_spec := gpu.ImageSpecification {
        tag = tag,
        device = &Renderer3DInstance.device,
        width = spec.width,
        height = spec.height,
        samples = spec.samples,
        usage = {.Sampled, .TransferDst, .ColorAttachment},
        format = .R8G8B8A8_UNORM,
        final_layout = .ShaderReadOnlyOptimal,
        sampler = {
            wrap = .Repeat,
        }
    }

    texture.handle = gpu.create_image(image_spec)
    gpu.image_set_data(&texture.handle, data)
    gpu.image_transition_layout(&texture.handle, .ShaderReadOnlyOptimal)
    return
}

new_texture2d :: proc(spec: TextureSpecification, data: []byte = {}, tag: cstring = "") -> (texture: ^Texture2D) {
    texture = new(Texture2D)
    texture^ = create_texture2d(spec, data, tag)
    return
}

set_texture2d_data :: proc(texture: ^Texture2D, data: []byte, level: i32 = 0, layer := 0) {
    gpu.image_set_data(&texture.handle, data)
}

build_global_set :: proc(r: ^Renderer3D) -> (set: GlobalSet) {
    set.layout = gpu.create_resource_layout(r.device, {
        type = .UniformBuffer,
        count = 1,
        stage = {.Vertex, .Fragment},
    }, {
        type = .UniformBuffer,
        count = 1,
        stage = {.Vertex, .Fragment},
    }, {
        type = .UniformBuffer,
        count = 1,
        stage = {.Vertex, .Fragment},
    })

    alloc_error: gpu.ResourceAllocationError
    set.resource, alloc_error = gpu.allocate_resource(r.global_pool, set.layout, "Global Set")
    fmt.assertf(alloc_error == nil, "Error allocating resource for global set: %v", alloc_error)

    set.uniform_buffer = create_uniform_buffer(&r.device, GlobalUniform, "Global Uniform")
    gpu.resource_bind_buffer(set.resource, set.uniform_buffer.handle, .UniformBuffer, 0)

    set.debug_options = create_uniform_buffer(&r.device, ShaderVisualizationOptions, "Debug Options - Shader Visualizations")
    gpu.resource_bind_buffer(set.resource, set.debug_options.handle, .UniformBuffer, 1)

    set.global_data = create_uniform_buffer(&r.device, GlobalData, "Global Shader Data")
    gpu.resource_bind_buffer(set.resource, set.global_data.handle, .UniformBuffer, 2)
    return
}

build_scene_set :: proc(r: ^Renderer3D) -> (set: SceneSet) {
    set.layout = gpu.create_resource_layout(r.device, {
        type = .UniformBuffer,
        count = 1,
        stage = {.Vertex, .Fragment},
    }, {
        type = .UniformBuffer,
        count = 1,
        stage = {.Vertex, .Fragment},
    }, {
        tag = "Shadow Map",
        type = .CombinedImageSampler,
        count = 1,
        stage = {.Fragment},
    })

    alloc_error: gpu.ResourceAllocationError
    set.resource, alloc_error = gpu.allocate_resource(r.global_pool, set.layout, "Scene Set")
    fmt.assertf(alloc_error == nil, "Error allocating resource for scene set: %v", alloc_error)

    set.scene_data = create_uniform_buffer(&r.device, SceneData, "Scene Data")
    gpu.resource_bind_buffer(set.resource, set.scene_data.handle, .UniformBuffer, 0)

    set.light_data = create_uniform_buffer(&r.device, LightData, "Scene Light Data")
    gpu.resource_bind_buffer(set.resource, set.light_data.handle, .UniformBuffer, 1)
    return
}

build_object_set :: proc(r: ^Renderer3D) -> (set: ObjectSet) {
    tracy.Zone()
    set.layout = gpu.create_resource_layout(r.device, {
        tag = "Material",
        type = .UniformBuffer,
        count = 1,
        stage = {.Vertex, .Fragment},
    }, {
        tag = "Albedo Map",
        type = .CombinedImageSampler,
        count = 1,
        stage ={.Fragment},
    }, {
        tag = "Normal Map",
        type = .CombinedImageSampler,
        count = 1,
        stage ={.Fragment},
    }, {
        tag = "Ambient Occlusion Map",
        type = .CombinedImageSampler,
        count = 1,
        stage ={.Fragment},
    }, {
        tag = "Emissive Map",
        type = .CombinedImageSampler,
        count = 1,
        stage ={.Fragment},
    }, {
        tag = "Metallic Roughness Map",
        type = .CombinedImageSampler,
        count = 1,
        stage ={.Fragment},
    })

    alloc_error: gpu.ResourceAllocationError
    // set.resource, alloc_error = gpu.allocate_resource(pool, set.layout)
    // fmt.assertf(alloc_error == nil, "Error allocating resource for global set: %v", alloc_error)
    set.resource, alloc_error = gpu.frame_allocator_alloc(&r.pool_allocator, set.layout)
    fmt.assertf(alloc_error == nil, "Error allocating resource for object set: %v", alloc_error)

    // set.view_data = create_uniform_buffer(&r.device, ViewData, "Scene View Data")
    // gpu.resource_bind_buffer(set.resource, set.view_data.handle, .UniformBuffer)

    // set.light_data = create_uniform_buffer(&r.device, LightData, "Scene Light Data")
    // gpu.resource_bind_buffer(set.resource, set.light_data.handle, .UniformBuffer)
    return
}

get_frustum_corners_world_space :: proc(proj, view: mat4) -> (corners: [8]vec4) {
    inv := linalg.inverse(proj * view)

    i := 0
    for x in 0..<2 {
        for y in 0..<2 {
            for z in 0..<2 {
                pt := inv * vec4{
                    2 * f32(x) - 1,
                    2 * f32(y) - 1,
                    2 * f32(z) - 1,
                    1.0}

                corners[i] = pt / pt.w

                i += 1
            }
        }
    }
    return
}

get_split_depth :: proc(current_split, max_splits: int, near, far: f32, l := f32(1)) -> f32 {
    split_ratio := f32(current_split) / f32(max_splits)
    log := near * math.pow(far / near, split_ratio)
    uniform := near + (far - near) * split_ratio
    d := l * (log - uniform) + uniform
    return (d -  near) / (far - near)
}
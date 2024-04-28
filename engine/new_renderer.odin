package engine
import "gpu"
import "core:mem"
import "vendor:glfw"
import vk "vendor:vulkan"
import "core:math/linalg"

import "packages:odin-imgui/imgui_impl_vulkan"
import "packages:odin-imgui/imgui_impl_glfw"
import imgui "packages:odin-imgui"
import "base:runtime"
import "core:fmt"
import tracy "packages:odin-tracy"

Renderer3DInstance: ^Renderer3D

Renderer3D :: struct {
    instance: gpu.Instance,
    device: gpu.Device,
    swapchain: gpu.Swapchain,

    image_index: u32,
    command_buffers: [3]gpu.CommandBuffer,

    // grug developer logic
    world_renderpass: gpu.RenderPass,
    world_pipeline: gpu.Pipeline,
    ui_renderpass:    gpu.RenderPass,
    ui_pipeline: gpu.Pipeline,

    world_framebuffers: [3]gpu.FrameBuffer,

    global_uniform_resource_usage: gpu.ResourceUsage,
    global_pool: gpu.ResourcePool,
    global_uniform_buffer: UniformBuffer(GlobalUniform),
    scene_uniform_buffer: UniformBuffer(SceneData),

    scene_uniform_usage: gpu.ResourceUsage,

    // Probably shouldn't be here.
    imgui_renderpass: gpu.RenderPass,

    swapchain_needs_resize: bool,
    _editor_images: map[gpu.UUID]vk.DescriptorSet,
}

tex :: proc(image: gpu.Image) -> imgui.TextureID {
    return transmute(imgui.TextureID) Renderer3DInstance._editor_images[image.id]
}

r3d_init :: proc(r: ^Renderer3D) {
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
                m._editor_images[image.id] = imgui_impl_vulkan.AddTexture(
                    image.sampler.handle,
                    image.view.handle,
                    // gpu.image_layout_to_vulkan(image.spec.layout),
                    .ATTACHMENT_OPTIMAL,
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

    r3d_setup_renderpasses(r)

    swapchain_spec := gpu.SwapchainSpecification {
        device = &r.device,
        extent = {
            width = u32(EngineInstance.screen_size.x),
            height = u32(EngineInstance.screen_size.y),
        },
        format = .B8G8R8A8_UNORM,
        renderpass = r.imgui_renderpass
    }

    r.swapchain, error = gpu.create_swapchain(swapchain_spec)

    pool_spec := gpu.ResourcePoolSpecification {
        device = &r.device,
        max_sets = 2,
        resource_limits = gpu.make_list([]gpu.ResourceLimit{{
            resource = .UniformBuffer,
            limit    = 3,
        }}),
    }
    r.global_pool = gpu.create_resource_pool(pool_spec)
    r.global_uniform_buffer = create_uniform_buffer(&r.device, r.global_pool, GlobalUniform, "Global")

    r.scene_uniform_buffer = create_uniform_buffer(&r.device, r.global_pool, SceneData, "Scene Data")

    cmd_spec := gpu.CommandBufferSpecification {
        tag = "Swapchain Command Buffer",
        device = r.device,
    }
    r.command_buffers = gpu.create_command_buffers(r.device, cmd_spec, 3)

    dbg_init(g_dbg_context, r.world_renderpass)
}

r3d_deinit :: proc(r: ^Renderer3D) {}

RPacket :: struct {
    scene: ^World,
    camera: RenderCamera,
    size: vec2i,
}

r3d_draw_frame :: proc(r: ^Renderer3D, packet: RPacket, cmd: gpu.CommandBuffer) {
    packet := packet
    r.global_uniform_buffer.data.projection = packet.camera.projection
    r.global_uniform_buffer.data.view = packet.camera.view
    uniform_buffer_flush(&r.global_uniform_buffer)

    gpu.bind_resource(cmd, r.global_uniform_buffer.resource, r.world_pipeline)

    if gpu.do_render_pass(cmd, r.world_renderpass, r.world_framebuffers[0]) {
        size := EngineInstance.screen_size
        gpu.set_viewport(cmd, size)
        gpu.set_scissor(cmd, 0, 0, u32(size.x), u32(size.y))
        gpu.pipeline_bind(cmd, r.world_pipeline)

        render_scene(r, &packet, cmd)

        gpu.bind_resource(cmd, r.global_uniform_buffer.resource, g_dbg_context.pipeline)
        // NOTE(minebill): Is this the correct place for this?
        dbg_render(g_dbg_context, cmd)
    }
}

r3d_begin_frame :: proc(r: ^Renderer3D) -> (cmd: gpu.CommandBuffer, ok: bool) {
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

    cmd = r.command_buffers[r.image_index]
    gpu.reset(cmd)
    gpu.cmd_begin(cmd)
    return cmd, true
}

r3d_end_frame :: proc(r: ^Renderer3D, cmd: gpu.CommandBuffer) {
    if cmd.handle != nil {
        gpu.cmd_end(cmd, {})
        gpu.swapchain_cmd_submit(&r.swapchain, {cmd})
    }

    gpu.swapchain_present(&r.swapchain, r.image_index)
}

r3d_on_resize :: proc(r: ^Renderer3D, size: vec2) {
    log_info(LC.Renderer, "New renderer size is: %v", size)
    gpu.device_wait(r.device)

    for i in 0..<len(r.world_framebuffers) {
        gpu.framebuffer_resize(&r.world_framebuffers[i], size)
    }
}

r3d_resize_swapchain :: proc(r: ^Renderer3D, size: vec2) {
    // r.swapchain_needs_resize = true
    // gpu.device_wait(r.device)
    // gpu.swapchain_resize(&r.swapchain, size)
}

@(private = "file")
render_scene :: proc(r: ^Renderer3D, packet: ^RPacket, cmd: gpu.CommandBuffer) {
    asset_manager := &EngineInstance.asset_manager
    mesh_components := make([dynamic]^MeshRenderer, allocator = context.temp_allocator)
    {
        tracy.ZoneN("Mesh Collection")
        for handle, &go in packet.scene.objects do if go.enabled && has_component(packet.scene, handle, MeshRenderer) {
            mr := get_component(packet.scene, handle, MeshRenderer)
            if is_asset_handle_valid(asset_manager, mr.mesh) {
                append(&mesh_components, mr)
            }
        }
    }

    r.scene_uniform_buffer.data.view_direction = linalg.quaternion_mul_vector3(
        packet.camera.rotation, vec3{0, 0, -1},
    )
    r.scene_uniform_buffer.data.view_position = packet.camera.position
    r.scene_uniform_buffer.data.ambient_color = Color{0.4, 0.1, 0.1, 1.0}
    uniform_buffer_flush(&r.scene_uniform_buffer)

    // for mesh in mesh_components {
    //     // mat := mesh
    //     // vk.CmdPushConstants(cmd.handle, r.world_pipeline.spec.layout, {.VERTEX}, 0, 1)
    // }
    for mr in mesh_components {
        mesh := get_asset(asset_manager, mr.mesh, Mesh)
        if mesh == nil do continue

        go := get_object(packet.scene, mr.owner)

        mat := go.transform.global_matrix
        // draw_elements(gl.TRIANGLES, mesh.num_indices, gl.UNSIGNED_SHORT)
        vk.CmdPushConstants(cmd.handle, r.world_pipeline.spec.layout.handle, {.VERTEX}, 0, size_of(mat4), &mat)

        gpu.bind_buffers(cmd, mesh.vertex_buffer)
        gpu.bind_buffers(cmd, mesh.index_buffer)
        gpu.draw_indexed(cmd, mesh.num_indices, 1, 0)
    }
}

UniformBuffer :: struct($T: typeid) {
    data: T,

    handle: gpu.Buffer,
    resource: gpu.Resource,
}

create_uniform_buffer :: proc(device: ^gpu.Device, pool: gpu.ResourcePool, $T: typeid, $name: cstring) -> (buffer: UniformBuffer(T)) {
    spec := gpu.BufferSpecification {
        name = name + " UBO",
        device = device,
        size = size_of(T),
        usage = {.Uniform},
        mapped = true,
    }

    buffer.handle = gpu.create_buffer(spec)

    layout := gpu.create_resource_layout(device^, {
        type = .UniformBuffer,
        count = 1,
        stage = {.Vertex, .Fragment},
    })

    alloc_error: gpu.ResourceAllocationError
    buffer.resource, alloc_error = gpu.allocate_resource(pool, layout)
    fmt.assertf(alloc_error == nil, "Resource allocation error: %v", alloc_error)

    gpu.resource_bind_buffer(buffer.resource, buffer.handle, .UniformBuffer)
    return
}

uniform_buffer_flush :: proc(ubo: ^UniformBuffer($T)) {
    mem.copy(ubo.handle.alloc_info.pMappedData, &ubo.data, size_of(T))
}

@(private = "file")
r3d_setup_renderpasses :: proc(r: ^Renderer3D) {
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

    r.global_uniform_resource_usage = gpu.ResourceUsage {
        type = .UniformBuffer,
        count = 1,
        stage = {.Vertex, .Fragment},
    }

    r.scene_uniform_usage = gpu.ResourceUsage {
        type = .UniformBuffer,
        count = 1,
        stage = {.Vertex, .Fragment},
    }

    imgui: {
        renderpass_spec := gpu.RenderPassSpecification {
            tag         = "Dear ImGui RenderPass",
            device      = &r.device,
            attachments = gpu.make_list([]gpu.RenderPassAttachment {
                {
                    tag          = "Color",
                    format       = .R8G8B8A8_UNORM,
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
            subpasses = gpu.make_list([]gpu.RenderPassSubpass {
                {
                    color_attachments = gpu.make_list([]gpu.RenderPassAttachmentRef {{
                        attachment = 0, layout = .ColorAttachmentOptimal,
                    }}),
                    depth_stencil_attachment = gpu.RenderPassAttachmentRef {
                        attachment = 1, layout = .DepthStencilAttachmentOptimal,
                    },
                },
            }),
        }

        r.imgui_renderpass = gpu.create_render_pass(renderpass_spec)
        initialize_imgui_for_vulkan(r)
    }

    world: {
        renderpass_spec := gpu.RenderPassSpecification {
            tag         = "Object RenderPass",
            device      = &r.device,
            attachments = gpu.make_list([]gpu.RenderPassAttachment {
                {
                    tag          = "Color",
                    format       = .R8G8B8A8_SRGB,
                    load_op      = .Clear,
                    store_op     = .Store, // ?
                    final_layout = .ColorAttachmentOptimal,
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
            subpasses = gpu.make_list([]gpu.RenderPassSubpass {
                {
                    color_attachments = gpu.make_list([]gpu.RenderPassAttachmentRef {{
                        attachment = 0, layout = .ColorAttachmentOptimal,
                    }}),
                    depth_stencil_attachment = gpu.RenderPassAttachmentRef {
                        attachment = 1, layout = .DepthStencilAttachmentOptimal,
                    },
                },
            }),
        }

        r.world_renderpass = gpu.create_render_pass(renderpass_spec)
        for i in 0..<len(r.world_framebuffers) {
            fb_spec := gpu.FrameBufferSpecification {
                device = &r.device,
                width = 100, height = 100,
                samples = 1,
                renderpass = r.world_renderpass,
                attachments = gpu.make_list([]gpu.ImageFormat{.R8G8B8A8_SRGB, .D32_SFLOAT}),
            }

            r.world_framebuffers[i] = gpu.create_framebuffer(fb_spec)
        }

        resource_layout := gpu.create_resource_layout(
            Renderer3DInstance.device,
            r.global_uniform_resource_usage)

        scene_buffer_layout := gpu.create_resource_layout(Renderer3DInstance.device, r.scene_uniform_usage)

        pipeline_layout_spec := gpu.PipelineLayoutSpecification {
            device = &r.device,
            tag = "Object Pipeline Layout",
            layouts = gpu.make_list([]gpu.ResourceLayout {resource_layout, scene_buffer_layout}),
            use_push = true,
        }

        world_pipeline_layout := gpu.create_pipeline_layout(pipeline_layout_spec)

        object_shader, ok := shader_load_from_file("assets/shaders/new/simple_3d.shader")
        fmt.assertf(ok, "Failed to open/compile default object shader")

        pipeline_spec := gpu.PipelineSpecification {
            tag = "Object Pipeline",
            layout = world_pipeline_layout,
            shader = object_shader.shader,
            attribute_layout = vertex_layout,
            renderpass = r.world_renderpass,
        }

        world_pipeline, pipeline_error := gpu.create_pipeline(&r.device, pipeline_spec)
        fmt.assertf(pipeline_error == nil, "Failed to create pipeline: %v", pipeline_error)

        r.world_pipeline = world_pipeline
    }
}

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

    imgui_rp_spec := gpu.RenderPassSpecification {
        tag         = "Dear ImGui Renderpass",
        device      = &s.device,
        attachments = gpu.make_list([]gpu.RenderPassAttachment {
            {
                tag          = "Color",
                format       = .B8G8R8A8_UNORM,
                load_op      = .Clear,
                store_op     = .Store,
                final_layout = .PresentSrc,
                clear_color  = [4]f32{1, 0, 0, 1},
            },
            {
                tag          = "Depth",
                format       = .D32_SFLOAT,
                load_op      = .Clear,
                final_layout = .DepthStencilAttachmentOptimal,
                clear_depth  = 1.0,
            },
        }),
        subpasses = gpu.make_list([]gpu.RenderPassSubpass {
            {
                color_attachments = gpu.make_list([]gpu.RenderPassAttachmentRef {
                    { attachment = 0, layout = .ColorAttachmentOptimal, },
                }),
                depth_stencil_attachment = gpu.RenderPassAttachmentRef {
                    attachment = 1, layout = .DepthStencilAttachmentOptimal,
                },
            },
        }),
    }
    s.imgui_renderpass = gpu.create_render_pass(imgui_rp_spec)

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

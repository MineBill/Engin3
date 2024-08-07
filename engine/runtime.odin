package engine

import "core:log"
import "core:math"
import "core:math/linalg"
import tracy "packages:odin-tracy"
import "core:math/rand"
import "base:intrinsics"
import "core:mem"
import "gpu"

VISUALIZE_CASCADES :: false

RenderCamera :: struct {
    position : vec3,
    rotation: quaternion128,
    projection, view: mat4,
    near, far: f32,
}

NewUniformBuffer :: struct($T: typeid) {
    data: T,

    handle: gpu.Buffer,
    resource: gpu.Resource,
}

create_new_uniform_buffer :: proc(device: ^gpu.Device, pool: gpu.ResourcePool, $T: typeid, $name: cstring) -> (buffer: NewUniformBuffer(T)) {
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

    // buffer.resource = gpu.allocate_resource(pool, layout)
    // gpu.resource_bind_buffer(buffer.resource, buffer.handle, .UniformBuffer)
    return
}

new_unifrom_buffer_flush :: proc(ubo: ^NewUniformBuffer($T)) {
    mem.copy(ubo.handle.alloc_info.pMappedData, &ubo.data, size_of(T))
}

WorldRenderer :: struct {
    world: ^World,

    per_object_data: UniformBuffer(PerObjectData),
    // view_data:       UniformBuffer(ViewData),
    light_data:      UniformBuffer(LightData),
    scene_data:      UniformBuffer(SceneData),
    ssao_data:       UniformBuffer(SSAOData),
    ssao_noise_texture: AssetHandle,

    depth_pass_per_object_data: UniformBuffer(DepthPassPerObjectData),

    depth_frame_buffer:     FrameBuffer,
    world_frame_buffer:     FrameBuffer,
    resolved_frame_buffer:  FrameBuffer,
    final_frame_buffer:     FrameBuffer,
    g_buffer:               FrameBuffer,
    ssao_frame_buffer:      FrameBuffer,
    ssao_blur_frame_buffer: FrameBuffer,

    bloom_vertical_fb:    FrameBuffer,
    bloom_horizontal_fb:    FrameBuffer,

    shaders: map[string]Shader,

    shadow_map: Texture2DArray,


    // NEW VULKAN STUFF

    renderpasses: map[string]gpu.RenderPass,
    pipelines:    map[string]gpu.Pipeline,
    framebuffers: map[string]gpu.FrameBuffer,

    global_resource_pool: gpu.ResourcePool,
}

world_renderer_init :: proc(renderer: ^WorldRenderer) {
    // spec := FrameBufferSpecification {
    //     width = 800,
    //     height = 800,
    //     attachments = attachment_list(.RGBA16F, .RGBA16F, .RED_INTEGER, .DEPTH),
    //     samples = 1,
    // }

    // renderer.world_frame_buffer = create_framebuffer(spec)

    // spec.attachments = attachment_list(.RGBA16F, .RGBA16F, .DEPTH)
    // renderer.resolved_frame_buffer = create_framebuffer(spec)

    // spec.attachments = attachment_list(.RGBA8, .DEPTH)
    // renderer.final_frame_buffer = create_framebuffer(spec)

    // // Position, Normal
    // spec.attachments = attachment_list(.RGBA16F, .RGBA16F, .DEPTH)
    // renderer.g_buffer = create_framebuffer(spec)

    // spec.attachments = attachment_list(.RED_FLOAT)
    // renderer.ssao_frame_buffer = create_framebuffer(spec)
    // renderer.ssao_blur_frame_buffer = create_framebuffer(spec)

    // spec.attachments             = attachment_list(.RGBA16F)
    // renderer.bloom_vertical_fb   = create_framebuffer(spec)
    // renderer.bloom_horizontal_fb = create_framebuffer(spec)

    // spec.width       = SHADOW_MAP_RES
    // spec.height      = SHADOW_MAP_RES
    // spec.attachments = attachment_list(.DEPTH32F)
    // spec.samples     = 1
    // renderer.depth_frame_buffer = create_framebuffer(spec)

    // renderer.shadow_map = create_texture_array(SHADOW_MAP_RES, SHADOW_MAP_RES, gl.DEPTH_COMPONENT32F, 4)

    // renderer.per_object_data = create_uniform_buffer(PerObjectData, 0)
    // renderer.view_data       = create_uniform_buffer(ViewData, 1)
    // renderer.scene_data      = create_uniform_buffer(SceneData, 2)
    // renderer.light_data      = create_uniform_buffer(LightData, 3)
    // renderer.ssao_data       = create_uniform_buffer(SSAOData, 11)

    // renderer.depth_pass_per_object_data = create_uniform_buffer(DepthPassPerObjectData, 0)

    // // TODO(minebill): These shaders should probably be loaded from the asset system.
    // ok: bool
    // renderer.shaders["depth"], ok = shader_load_from_file(
    //     "assets/shaders/depth.vert.glsl",
    //     "assets/shaders/depth.frag.glsl",
    // )
    // assert(ok)

    // renderer.shaders["pbr"], ok = shader_load_from_file(
    //     "assets/shaders/triangle.vert.glsl",
    //     "assets/shaders/pbr.frag.glsl",
    // )
    // assert(ok)

    // renderer.shaders["screen"], ok = shader_load_from_file(
    //     "assets/shaders/screen.vert.glsl",
    //     "assets/shaders/screen.frag.glsl",
    // )
    // assert(ok)

    // renderer.shaders["bloom"], ok = shader_load_from_file(
    //     "assets/shaders/screen.vert.glsl",
    //     "assets/shaders/bloom.frag.glsl",
    // )
    // assert(ok)

    // renderer.shaders["bloom_vertical"], ok = shader_load_from_file(
    //     "assets/shaders/screen.vert.glsl",
    //     "assets/shaders/postprocess/bloom_vertical.frag.glsl",
    // )
    // assert(ok)

    // renderer.shaders["blend"], ok = shader_load_from_file(
    //     "assets/shaders/screen.vert.glsl",
    //     "assets/shaders/postprocess/blend.frag.glsl",
    // )
    // assert(ok)

    // renderer.shaders["cubemap"], ok = shader_load_from_file(
    //     "assets/shaders/cubemap.vert.glsl",
    //     "assets/shaders/cubemap.frag.glsl",
    // )
    // assert(ok)

    // renderer.shaders["geometry"], ok = shader_load_from_file(
    //     "assets/shaders/geometry_pass.vert.glsl",
    //     "assets/shaders/geometry_pass.frag.glsl",
    // )
    // assert(ok)

    // renderer.shaders["ssao"], ok = shader_load_from_file(
    //     "assets/shaders/screen.vert.glsl",
    //     "assets/shaders/postprocess/ssao.frag.glsl",
    // )
    // assert(ok)

    // renderer.shaders["ssao_blur"], ok = shader_load_from_file(
    //     "assets/shaders/screen.vert.glsl",
    //     "assets/shaders/postprocess/ssao_blur.frag.glsl",
    // )
    // assert(ok)

    // device := rand.create(u64(intrinsics.read_cycle_counter()))

    // for i in 0..<len(renderer.ssao_data.kernel) {
    //     sample := vec3{
    //         rand.float32(&device) * 2.0 - 1.0,
    //         rand.float32(&device) * 2.0 - 1.0,
    //         rand.float32(&device) * 2.0 - 1.0,
    //     }

    //     sample = linalg.normalize(sample)
    //     sample *= rand.float32(&device)

    //     scale := f32(i) / len(renderer.ssao_data.kernel)
    //     lerp :: proc(a, b, f: f32) -> f32 {
    //         return a + f * (b - a);
    //     }
    //     scale = cast(f32) lerp(f32(0.1), f32(1.0), scale * scale)
    //     sample *= scale
    //     // TODO: More options, choose samples closer to the center of the sphere.
    //     renderer.ssao_data.kernel[i] = sample
    // }
    // uniform_buffer_set_data(
    //     &renderer.ssao_data,
    //     offset_of(renderer.ssao_data.data.kernel),
    //     size_of(renderer.ssao_data.data.kernel))

    // ssao_noise: [4 * 4]vec3
    // for i in 0..<len(ssao_noise) {
    //     noise := vec3{
    //         rand.float32(&device) * 2.0 - 1.0,
    //         rand.float32(&device) * 2.0 - 1.0,
    //         0,
    //     }
    //     ssao_noise[i] = noise
    // }

    // texture_spec := TextureSpecification {
    //     width = 4,
    //     height = 4,
    //     format = .RGB8,
    //     desired_format = .RGBA16F,
    //     wrap = .Repeat,
    //     filter = .Nearest,
    //     pixel_type = .Float,
    // }

    // bytes := mem.slice_to_bytes(ssao_noise[:])
    // renderer.ssao_noise_texture = create_virtual_asset(&EngineInstance.asset_manager, new_texture2d(texture_spec, bytes), "SSAO Noise")

    // NEW VULKAN STUFF

    // [Depth Renderpass]
    //               || Output: Depth Attachment
    //               \/
    // [3D World Renderpass]
    //               || Output: Color Attachment
    //               \/
    // [Post-Proccess Renderpass]
    //               || Output: Color Attachment
    //
    // (In the Editor)
    // Display the [Post-Process Renderpass] Output in the Viewport window.

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

    // ================
    // DEPTH RENDERPASS
    // ================
    drp: {
        renderpass_spec := gpu.RenderPassSpecification {
            tag         = "Depth RenderPass",
            device      = &RendererInstance.device,
            attachments = gpu.make_list([]gpu.RenderPassAttachment {
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
                    depth_stencil_attachment = gpu.RenderPassAttachmentRef {
                        attachment = 0, layout = .DepthStencilAttachmentOptimal,
                    },
                },
            }),
        }

        // NOTE(minebill): Should this be registered with the Renderer? Or we just keep it as local thing? No idea.
        depth_renderpass := gpu.create_render_pass(renderpass_spec)
        renderer.renderpasses["depth"] = depth_renderpass

        // The depth renderpass will only use 1 uniform buffer, the ViewData.
        resource_layout := gpu.create_resource_layout(RendererInstance.device, gpu.ResourceUsage {
            type = .UniformBuffer,
            count = 1,
            stage = {.Vertex, .Fragment},
        })

        pipeline_layout_spec := gpu.PipelineLayoutSpecification {
            tag = "Depth Pipeline Layout",
            device = &RendererInstance.device,
            // layout = resource_layout,
        }

        pipeline_layout := gpu.create_pipeline_layout(pipeline_layout_spec)

        depth_shader, ok := shader_load_from_file("assets/shaders/new/depth.shader")

        // NOTE(minebill): Could this be reused with the "world" renderpass? Does it provide a measurable benefit if so?
        pipeline_spec := gpu.PipelineSpecification {
            tag = "Depth Pipeline",
            // device = &RendererInstance.device,
            shader = depth_shader.shader,
            layout = pipeline_layout,
            renderpass = depth_renderpass,
            // TODO(minebill): This is the same layout with the 3d render pass and we just ignore the rest of the attributes
            // in the depth shader. However, could we use buffer views on the vertex buffer? That way we could create a position only
            // view and use that with the depth pass.
            attribute_layout = vertex_layout,
        }

        pipeline, error := gpu.create_pipeline(&RendererInstance.device, pipeline_spec)
        renderer.pipelines["depth"] = pipeline

        fb_spec := gpu.FrameBufferSpecification {
            device = &RendererInstance.device,
            width = 100, height = 100,
            samples = 1,
            renderpass = depth_renderpass,
            // attachments = gpu.make_list([]gpu.ImageFormat{.D32_SFLOAT}),
        }
        fb := gpu.create_framebuffer(fb_spec)
        renderer.framebuffers["depth"] = fb
    }
    // ====================
    // END DEPTH RENDERPASS
    // ====================

    // ===================
    // 3D WORLD RENDERPASS
    // ===================
    wrp: {
        renderpass_spec := gpu.RenderPassSpecification {
            tag         = "World RenderPass",
            device      = &RendererInstance.device,
            attachments = gpu.make_list([]gpu.RenderPassAttachment {
                {
                    tag          = "Color",
                    format       = .R8G8B8A8_SRGB,
                    load_op      = .Clear,
                    store_op     = .Store, // ?
                    final_layout = .ColorAttachmentOptimal,
                    clear_color  = vec4{0.1, 0.1, 0.1, 1},
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

        // NOTE(minebill): Should this be registered with the Renderer? Or we just keep it as local thing? No idea.
        world_renderpass := gpu.create_render_pass(renderpass_spec)
        renderer.renderpasses["world"] = world_renderpass

        // The world renderpass will only use 1 uniform buffer, for now, the ViewData.
        resource_layout := gpu.create_resource_layout(RendererInstance.device, gpu.ResourceUsage {
            type = .UniformBuffer,
            count = 1,
            stage = {.Vertex, .Fragment},
        })

        pipeline_layout_spec := gpu.PipelineLayoutSpecification {
            tag = "World Pipeline Layout",
            device = &RendererInstance.device,
            // layout = resource_layout,
        }

        pipeline_layout := gpu.create_pipeline_layout(pipeline_layout_spec)

        simple3d_shader, ok := shader_load_from_file("assets/shaders/new/simple_3d.shader")

        // NOTE(minebill): Could this be reused with the "world" renderpass? Does it provide a measurable benefit if so?
        pipeline_spec := gpu.PipelineSpecification {
            tag = "World Pipeline",
            // device = &RendererInstance.device,
            shader = simple3d_shader.shader,
            layout = pipeline_layout,
            renderpass = world_renderpass,
            attribute_layout = vertex_layout,
        }

        pipeline, error := gpu.create_pipeline(&RendererInstance.device, pipeline_spec)
        renderer.pipelines["world"] = pipeline

        fb_spec := gpu.FrameBufferSpecification {
            device = &RendererInstance.device,
            width = 100, height = 100,
            samples = 1,
            renderpass = world_renderpass,
            // attachments = gpu.make_list([]gpu.ImageFormat{.R8G8B8A8_SRGB, .D32_SFLOAT}),
        }
        fb := gpu.create_framebuffer(fb_spec)
        renderer.framebuffers["world"] = fb
    }
    // =======================
    // END 3D WORLD RENDERPASS
    // =======================

    pool_spec := gpu.ResourcePoolSpecification {
        device = &RendererInstance.device,
        max_sets = 10,
        resource_limits = gpu.make_list([]gpu.ResourceLimit{{
            resource = .UniformBuffer,
            limit    = 10,
        }}),
    }
    renderer.global_resource_pool = gpu.create_resource_pool(pool_spec)


    // TODO(minebill): Figure out where this actually has to be initialized
    dbg_init(&EngineInstance.dbg_draw, renderer.renderpasses["world"])
}

RenderPacket :: struct {
    camera: RenderCamera,
    world: ^World,
    size: vec2i,
    clear_color: Color,
}

render_world :: proc(world_renderer: ^WorldRenderer, packet: RenderPacket) {
    /*
    world_renderer.world = packet.world
    asset_manager := &EngineInstance.asset_manager

    world := world_renderer.world
    view_data := &world_renderer.view_data
    light_data := &world_renderer.light_data

    view_data.screen_size = EngineInstance.screen_size
    uniform_buffer_set_data(
        view_data,
        offset_of(view_data.data.screen_size),
        size_of(view_data.data.screen_size))

    mesh_components := make([dynamic]^MeshRenderer, allocator = context.temp_allocator)
    {
        tracy.ZoneN("Mesh Collection")
        for handle, &go in world.objects do if go.enabled && has_component(world, handle, MeshRenderer) {
            mr := get_component(world, handle, MeshRenderer)
            if is_asset_handle_valid(asset_manager, mr.mesh) {
                append(&mesh_components, mr)
            }
        }
    }

    // TODO(minebill): Different uniform buffer for point_lights/spot_lights?
    num_point_lights := 0
    {
        tracy.ZoneN("Light Collection")

        light_data := &world_renderer.light_data
        lights: for handle, &go in world.objects do if has_component(world, handle, PointLightComponent) {
            if num_point_lights >= 10 {
                log.errorf("Cannot use more than %v point lights!", MAX_POINTLIGHTS)
                break lights
            }
            point_light := get_component(world, handle, PointLightComponent)

            light := &light_data.point_lights[num_point_lights]
            light.color = point_light.color
            light.linear = point_light.linear
            light.constant = point_light.constant
            light.quadratic = point_light.quadratic
            light.position.xyz = go.transform.position

            num_point_lights += 1
        }

        if num_point_lights > 0 {
            uniform_buffer_set_data(
                light_data,
                offset_of(light_data.data.point_lights),
                size_of(light_data.data.point_lights[0]) * num_point_lights)
        }

        // NOTE:    This will return -1 even though it is a valid location to the uniform.
        //          Is it because we use push_constants and the shader compiler does some funky stuff?
        if loc := gl.GetUniformLocation(world_renderer.shaders["pbr"].program, "push_constants"); true {
            gl.ProgramUniform1i(world_renderer.shaders["pbr"].program, loc, cast(i32) num_point_lights)
        }
    }

    light_data.shadow_split_distances = do_depth_pass(world_renderer, mesh_components[:], packet)
    uniform_buffer_rebind(light_data)
    uniform_buffer_set_data(
        light_data,
        offset_of(light_data.data.shadow_split_distances),
        size_of(light_data.data.shadow_split_distances))

    per_object := &world_renderer.per_object_data
    uniform_buffer_rebind(per_object)

    scene_data := &world_renderer.scene_data
    world_fb := &world_renderer.world_frame_buffer

    scene_data.view_position = packet.camera.position
    scene_data.view_direction = linalg.quaternion_mul_vector3(packet.camera.rotation, vec3{0, 0, -1})
    scene_data.ambient_color = world.ambient_color
    uniform_buffer_upload(scene_data)

    view_data.projection = packet.camera.projection
    uniform_buffer_set_data(
        view_data,
        offset_of(view_data.data.projection),
        size_of(view_data.data.projection))
    view_data.view = packet.camera.view
    uniform_buffer_set_data(view_data, offset_of(view_data.data.view), size_of(view_data.view))

    // Geometry pass
    {
        gl.Enable(gl.DEPTH_TEST)
        gl.BindFramebuffer(gl.FRAMEBUFFER, world_renderer.g_buffer.handle)
        gl.Viewport(0, 0, packet.size.x, packet.size.y)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        geometry_shader := &world_renderer.shaders["geometry"]

        gl.UseProgram(geometry_shader.program)

        for mr in mesh_components {
            mesh := get_asset(asset_manager, mr.mesh, Mesh)
            if mesh == nil do continue

            go := get_object(world, mr.owner)
            gl.BindVertexArray(mesh.vertex_array)

            per_object.model = go.transform.global_matrix
            uniform_buffer_set_data(
                per_object,
                offset_of(per_object.data.model),
                size_of(per_object.data.model))
            draw_elements(gl.TRIANGLES, mesh.num_indices, gl.UNSIGNED_SHORT)
        }
    }

    PLANE_VERT_COUNT :: 6

    // [SSAO]
    {
        uniform_buffer_rebind(&world_renderer.ssao_data)
        world_renderer.ssao_data.params.x = world_renderer.world.ssao_data.radius
        world_renderer.ssao_data.params.y = world_renderer.world.ssao_data.bias
        uniform_buffer_set_data(
            &world_renderer.ssao_data,
            offset_of(world_renderer.ssao_data.data.params),
            size_of(world_renderer.ssao_data.data.params),
        )

        gl.BindFramebuffer(gl.FRAMEBUFFER, world_renderer.ssao_frame_buffer.handle)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        gl.UseProgram(world_renderer.shaders["ssao"].program)
        gl.BindTextureUnit(0, get_color_attachment(world_renderer.g_buffer, 0))
        gl.BindTextureUnit(1, get_color_attachment(world_renderer.g_buffer, 1))
        noise := get_asset(&EngineInstance.asset_manager, world_renderer.ssao_noise_texture, Texture2D)
        if noise != nil do gl.BindTextureUnit(2, noise.handle)

        draw_arrays(gl.TRIANGLES, 0, PLANE_VERT_COUNT)

        gl.BindFramebuffer(gl.FRAMEBUFFER, world_renderer.ssao_blur_frame_buffer.handle)
        gl.Clear(gl.COLOR_BUFFER_BIT)
        gl.UseProgram(world_renderer.shaders["ssao_blur"].program)
        gl.BindTextureUnit(0, get_color_attachment(world_renderer.ssao_frame_buffer))

        draw_arrays(gl.TRIANGLES, 0, PLANE_VERT_COUNT)
    }

    gl.BindFramebuffer(gl.FRAMEBUFFER, world_fb.handle)
    gl.Viewport(0, 0, packet.size.x, packet.size.y)

    gl.ClearColor(expand_values(packet.clear_color))
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)

    { // Cubemap Skybox
        if cubemap := find_first_component(world, CubemapComponent); cubemap != nil {
            texture := get_asset(asset_manager, cubemap.texture, Texture2D)
            if texture != nil {
                gl.Disable(gl.DEPTH_TEST)

                view_data.view = linalg.matrix4_from_quaternion(packet.camera.rotation)
                uniform_buffer_set_data(view_data, offset_of(view_data.data.view), size_of(view_data.data.view))

                gl.UseProgram(cubemap.shader.program)
                gl.BindTextureUnit(6, texture.handle)
                gl.DrawArrays(gl.TRIANGLES, 0, 36)

                gl.Enable(gl.DEPTH_TEST)
            }
        }
    }

    view_data.view = packet.camera.view
    uniform_buffer_upload(view_data, offset_of(view_data.data.view), size_of(view_data.view))

    uniform_buffer_rebind(per_object)

    // Draw meshes
    {
        pbr_shader := &world_renderer.shaders["pbr"]

        gl.UseProgram(pbr_shader.program)
        // gl.BindTextureUnit(2, get_depth_attachment(world_renderer.depth_frame_buffer))
        gl.BindTextureUnit(2, world_renderer.shadow_map.handle)
        gl.BindTextureUnit(3, get_color_attachment(world_renderer.ssao_blur_frame_buffer, 0))

        for mr in mesh_components {
            mesh := get_asset(asset_manager, mr.mesh, Mesh)
            if mesh == nil do continue

            go := get_object(world, mr.owner)
            gl.BindVertexArray(mesh.vertex_array)

            material := get_asset(&EngineInstance.asset_manager, mr.material, PbrMaterial)
            if material != nil {
                bind_pbr_material(material)
            }

            per_object.model = go.transform.global_matrix
            uniform_buffer_set_data(
                per_object,
                offset_of(per_object.data.model),
                size_of(per_object.data.model))
            when USE_EDITOR {
                per_object.entity_id = go.local_id
                uniform_buffer_set_data(
                    per_object,
                    offset_of(per_object.data.entity_id),
                    size_of(per_object.data.entity_id))
            }
            // gl.UniformMatrix4fv(uniform(pbr_shader, "model"), 1, false, &mm[0][0])
            // gl.Uniform1i(uniform(pbr_shader, "gameobject_id"), i32(go.local_id))

            draw_elements(gl.TRIANGLES, mesh.num_indices, gl.UNSIGNED_SHORT)
        }

        gl.Enable(gl.STENCIL_TEST)
        gl.Disable(gl.DEPTH_TEST)
        gl.ColorMask(false, false, false, false)
        gl.StencilFunc(gl.ALWAYS, 1, 0xFF)
        gl.StencilMask(0xFF)

        gl.UseProgram(pbr_shader.program)
        for handle, &go in world.objects do if go.enabled && .Outlined in go.flags && has_component(world, handle, MeshRenderer) {
            mr := get_component(world, handle, MeshRenderer)

            mesh := get_asset(asset_manager, mr.mesh, Mesh)
            if mesh == nil do continue

            gl.BindVertexArray(mesh.vertex_array)

            per_object.model = go.transform.global_matrix
            uniform_buffer_set_data(
                per_object,
                offset_of(per_object.data.model),
                size_of(per_object.data.model))
            // TODO(minebill): Use a simple shader here.
            // gl.UniformMatrix4fv(uniform(pbr_shader, "model"), 1, false, &mm[0][0])

            draw_elements(gl.TRIANGLES, mesh.num_indices, gl.UNSIGNED_SHORT)
        }

        gl.Disable(gl.STENCIL_TEST)
        gl.Enable(gl.DEPTH_TEST)
        gl.ColorMask(true, true, true, true)
    }

    // Resolve the MSAA framebuffer to a single sample.
    width, height := f32(packet.size.x), f32(packet.size.y)
    blit_framebuffer(
        world_renderer.world_frame_buffer,
        world_renderer.resolved_frame_buffer,
        {{0, 0}, {width, height}},
        {{0, 0}, {width, height}},
        1 if is_key_pressed(.K) else 0, 0)

    blit_framebuffer(
        world_renderer.world_frame_buffer,
        world_renderer.resolved_frame_buffer,
        {{0, 0}, {width, height}},
        {{0, 0}, {width, height}},
        1, 1)

    // Apply gamma correction.
    // NOTE(minebill): I guess this is where a post-processing stack would go.
    {
        gl.BindFramebuffer(gl.FRAMEBUFFER, world_renderer.final_frame_buffer.handle)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        blit_framebuffer_depth(
            world_renderer.world_frame_buffer,
            world_renderer.final_frame_buffer,
            {{0, 0}, {width, height}},
            {{0, 0}, {width, height}},
        )


        gl.BindTextureUnit(0, get_color_attachment(world_renderer.resolved_frame_buffer))
        gl.BindTextureUnit(1, get_color_attachment(world_renderer.resolved_frame_buffer, 1))
        gl.BindTextureUnit(2, get_color_attachment(world_renderer.ssao_frame_buffer, 0))
        gl.UseProgram(world_renderer.shaders["screen"].program)

        gl.Disable(gl.DEPTH_TEST)
        gl.Enable(gl.BLEND)

        draw_arrays(gl.TRIANGLES, 0, PLANE_VERT_COUNT)

        // {
        //     horizontal := false
        //     first := true
        //     for i in 0..<5 {
        //         gl.BindFramebuffer(gl.FRAMEBUFFER, world_renderer.bloom_horizontal_fb.handle if horizontal else world_renderer.bloom_vertical_fb.handle)
        //         gl.UseProgram(world_renderer.shaders["bloom"].program if horizontal else world_renderer.shaders["bloom_vertical"].program)

        //         if first {
        //             gl.BindTextureUnit(1, get_color_attachment(world_renderer.resolved_frame_buffer, 1))
        //         } else {
        //             gl.BindTextureUnit(1, get_color_attachment(world_renderer.bloom_horizontal_fb if !horizontal else world_renderer.bloom_vertical_fb))
        //         }

        //         draw_arrays(gl.TRIANGLES, 0, PLANE_VERT_COUNT)
        //         horizontal = !horizontal
        //         first = false
        //     }
        // }

        // {
        //     gl.BindFramebuffer(gl.FRAMEBUFFER, world_renderer.final_frame_buffer.handle)
        //     gl.UseProgram(world_renderer.shaders["blend"].program)
        //     gl.BindTextureUnit(0, get_color_attachment(world_renderer.resolved_frame_buffer))
        //     gl.BindTextureUnit(1, get_color_attachment(world_renderer.bloom_vertical_fb))
        //     draw_arrays(gl.TRIANGLES, 0, PLANE_VERT_COUNT)
        // }
        gl.Enable(gl.DEPTH_TEST)

    }
    */
}

do_depth_pass_ :: proc(world_renderer: ^WorldRenderer, mesh_components: []^MeshRenderer, packet: RenderPacket) -> (distances: [4]f32) {
    /*
    world := world_renderer.world
    view_data := &world_renderer.view_data
    per_object := &world_renderer.depth_pass_per_object_data
    uniform_buffer_rebind(per_object)

    // Depth Pass, for lighting
    {
        depth_fb := &world_renderer.depth_frame_buffer
        gl.BindFramebuffer(gl.FRAMEBUFFER, depth_fb.handle)
        gl.Viewport(0, 0, SHADOW_MAP_RES, SHADOW_MAP_RES)


        for handle, &go in world.objects do if go.enabled && has_component(world, handle, DirectionalLight) {
            dir_light := get_component(world, handle, DirectionalLight)
            r := go.transform.local_rotation
            dir_light_quat := linalg.quaternion_from_euler_angles(
                                r.x * math.RAD_PER_DEG,
                                r.y * math.RAD_PER_DEG,
                                r.z * math.RAD_PER_DEG,
                                .XYZ)
            dir := linalg.quaternion_mul_vector3(dir_light_quat, vec3{0, 0, -1})

            for split in 0..<dir_light.shadow.splits {
                gl.NamedFramebufferTextureLayer(
                    depth_fb.handle,
                    gl.DEPTH_ATTACHMENT,
                    world_renderer.shadow_map.handle,
                    0,
                    i32(split),
                )
                gl.Clear(gl.DEPTH_BUFFER_BIT)
                near := packet.camera.near

                z := get_split_depth(split + 1, dir_light.shadow.splits, near, packet.camera.far, dir_light.shadow.correction)
                // z := dir_light.shadow.distances[split]
                distances[split] = z / packet.camera.far

                // camera_view := linalg.matrix4_from_quaternion(packet.camera.rotation) * linalg.inverse(linalg.matrix4_translate(packet.camera.position))
                proj := linalg.matrix4_perspective_f32(math.to_radians(f32(50)), f32(packet.size.x) / f32(packet.size.y), distances[split - 1] if split > 0 else near, z)
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
                    near = min.z,
                    far = max.z)

                when VISUALIZE_CASCADES {
                    light_corners := get_frustum_corners_world_space(view_data.projection, view_data.view)
                    r := f32(split) / f32(dir_light.shadow.splits)
                    color := Color{r , r, r, 1.0}
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
                    dbg_draw_line(g_dbg_context, light_corners[0].xyz, light_corners[1].xyz, 2.0, color)
                    dbg_draw_line(g_dbg_context, light_corners[2].xyz, light_corners[3].xyz, 2.0, color)
                    dbg_draw_line(g_dbg_context, light_corners[4].xyz, light_corners[5].xyz, 2.0, color)
                    dbg_draw_line(g_dbg_context, light_corners[6].xyz, light_corners[7].xyz, 2.0, color)

                    dbg_draw_line(g_dbg_context, light_corners[0].xyz, light_corners[2].xyz, 2.0, color)
                    dbg_draw_line(g_dbg_context, light_corners[2].xyz, light_corners[6].xyz, 2.0, color)
                    dbg_draw_line(g_dbg_context, light_corners[6].xyz, light_corners[4].xyz, 2.0, color)
                    dbg_draw_line(g_dbg_context, light_corners[4].xyz, light_corners[0].xyz, 2.0, color)

                    dbg_draw_line(g_dbg_context, light_corners[1].xyz, light_corners[3].xyz, 2.0, color)
                    dbg_draw_line(g_dbg_context, light_corners[3].xyz, light_corners[7].xyz, 2.0, color)
                    dbg_draw_line(g_dbg_context, light_corners[7].xyz, light_corners[5].xyz, 2.0, color)
                    dbg_draw_line(g_dbg_context, light_corners[5].xyz, light_corners[1].xyz, 2.0, color)
                }

                uniform_buffer_upload(view_data)

                light_data := &world_renderer.light_data
                light_data.directional.direction = vec4{dir.x, dir.y, dir.z, 0}
                light_data.directional.color = dir_light.color
                light_data.directional.light_space_matrix[split] = view_data.projection * view_data.view

                uniform_buffer_set_data(light_data,
                    offset_of(light_data.data.directional),
                    size_of(light_data.data.directional))

                gl.UseProgram(world_renderer.shaders["depth"].program)

                per_object.light_space = light_data.directional.light_space_matrix[split]
                uniform_buffer_set_data(per_object, offset_of(per_object.data.light_space), size_of(per_object.data.light_space))
                for mr in mesh_components {
                    mesh := get_asset(&EngineInstance.asset_manager, mr.mesh, Mesh)
                    if mesh == nil do continue

                    gl.BindVertexArray(mesh.vertex_array)

                    go := get_object(world, mr.owner)

                    per_object.model = go.transform.global_matrix
                    uniform_buffer_set_data(
                        per_object,
                        offset_of(per_object.data.model),
                        size_of(per_object.data.model))

                    draw_elements(gl.TRIANGLES, mesh.num_indices, gl.UNSIGNED_SHORT)
                }
            }
        }
    }
    */
    return
}

world_renderer_resize :: proc(world_renderer: ^WorldRenderer, width, height: int) {
    world_renderer.world_frame_buffer.spec.samples = int(g_msaa_level)

    for key, &fb in world_renderer.framebuffers {
        gpu.framebuffer_resize(&fb, {f32(width), f32(height)})
    }

    // resize_framebuffer(&world_renderer.final_frame_buffer, width, height)
    // resize_framebuffer(&world_renderer.world_frame_buffer, width, height)
    // resize_framebuffer(&world_renderer.resolved_frame_buffer, width, height)
    // resize_framebuffer(&world_renderer.g_buffer, width, height)
    // resize_framebuffer(&world_renderer.ssao_frame_buffer, width, height)
    // resize_framebuffer(&world_renderer.ssao_blur_frame_buffer, width, height)

    // resize_framebuffer(&world_renderer.bloom_vertical_fb, width, height)
    // resize_framebuffer(&world_renderer.bloom_horizontal_fb, width, height)
}



render_material_preview :: proc(packet: RenderPacket, target: ^FrameBuffer, material: ^PbrMaterial, mesh: ^Mesh, renderer: ^WorldRenderer, cubemap_texture: ^Texture2D) {
    /*
    spec := FrameBufferSpecification{
        width = int(packet.size.x),
        height = int(packet.size.y),
        attachments = attachment_list(.RGBA16F, .DEPTH),
        samples = 4,
    }
    // TODO(minebill): This just feels wrong. Is there a better way to do this instead
    //                  of creating and destroying frame buffers every frame???
    buffer := create_framebuffer(spec)
    defer destroy_framebuffer(buffer)

    spec.samples = 1
    spec.attachments = attachment_list(.RGBA8)
    resolve_target := create_framebuffer(spec)
    defer destroy_framebuffer(resolve_target)

    gl.BindFramebuffer(gl.FRAMEBUFFER, buffer.handle)
    gl.Viewport(0, 0, packet.size.x, packet.size.y)

    gl.ClearColor(expand_values(packet.clear_color))
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)

    // Render a cube
    per_object := &renderer.per_object_data
    view_data := &renderer.view_data
    light_data := &renderer.light_data
    scene_data := &renderer.scene_data

    scene_data.view_position = packet.camera.position
    dir := linalg.quaternion_mul_vector3(packet.camera.rotation, vec3{0, 0, -1})
    scene_data.view_direction = dir
    scene_data.ambient_color = Color{0.5, 0.5, 0.5, 1.0}
    uniform_buffer_rebind(scene_data)
    uniform_buffer_set_data(scene_data)

    quat := linalg.quaternion_look_at(vec3{1, 1, 1}, vec3{0, 0, 0}, vec3{0, 1, 0})
    dir = linalg.quaternion_mul_vector3(quat, vec3{0, 0, -1})
    light_data.directional.direction = vec4{dir.x, dir.y, dir.z, 0}
    light_data.directional.color = COLOR_WHITE
    light_data.directional.light_space_matrix[0] = {}
    light_data.directional.light_space_matrix[1] = {}
    light_data.directional.light_space_matrix[2] = {}
    light_data.directional.light_space_matrix[3] = {}

    uniform_buffer_rebind(light_data)
    uniform_buffer_set_data(light_data,
        offset_of(light_data.data.directional),
        size_of(light_data.data.directional))

    view_data.projection = packet.camera.projection
    uniform_buffer_set_data(
        view_data,
        offset_of(view_data.data.projection),
        size_of(view_data.data.projection))

    { // Cubemap Skybox
            if cubemap_texture != nil {
                gl.Disable(gl.DEPTH_TEST)

                view_data.view = linalg.matrix4_from_quaternion(packet.camera.rotation)
                uniform_buffer_set_data(view_data, offset_of(view_data.data.view), size_of(view_data.data.view))

                gl.UseProgram(renderer.shaders["cubemap"].program)
                gl.BindTextureUnit(6, cubemap_texture.handle)
                gl.DrawArrays(gl.TRIANGLES, 0, 36)

                gl.Enable(gl.DEPTH_TEST)
            }
    }

    view_data.view = packet.camera.view
    uniform_buffer_set_data(view_data, offset_of(view_data.data.view), size_of(view_data.view))

    white_texture := get_asset(&EngineInstance.asset_manager, RendererInstance.white_texture, Texture2D)
    gl.BindTextureUnit(3, white_texture.handle)
    {
        gl.UseProgram(renderer.shaders["pbr"].program)
        gl.BindVertexArray(mesh.vertex_array)

        bind_pbr_material(material)

        per_object.model = linalg.matrix4_translate(vec3{0.0, 0.0, 0.0})
        uniform_buffer_set_data(
            per_object,
            offset_of(per_object.data.model),
            size_of(per_object.data.model))

        draw_elements(gl.TRIANGLES, mesh.num_indices, gl.UNSIGNED_SHORT)
    }

    width, height := f32(packet.size.x), f32(packet.size.y)
    blit_framebuffer(
        buffer,
        resolve_target,
        {{0, 0}, {width, height}},
        {{0, 0}, {width, height}})

    gl.BindFramebuffer(gl.FRAMEBUFFER, target.handle)

    PLANE_VERT_COUNT :: 6

    gl.BindTextureUnit(0, get_color_attachment(resolve_target))
    gl.UseProgram(renderer.shaders["screen"].program)

    gl.Disable(gl.DEPTH_TEST)
    draw_arrays(gl.TRIANGLES, 0, PLANE_VERT_COUNT)
    gl.Enable(gl.DEPTH_TEST)
    */
}

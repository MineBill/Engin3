package engine
import "gpu"
import tracy "packages:odin-tracy"
import vk "vendor:vulkan"

ObjectPicking :: struct {
    renderpass: gpu.RenderPass,
    shader: AssetHandle,
    framebuffer: gpu.FrameBuffer,
}

ObjectPickingPushConstants :: struct {
    model: mat4,
    object_id: int,
}

object_picking_init :: proc(this: ^ObjectPicking, device: ^gpu.Device) -> bool {
    renderpass_spec := gpu.RenderPassSpecification {
        tag = "Object Picking RP",
        device = device,
        attachments = {
            {
                tag = "Object Picking ID",
                format = .RED_SIGNED,
                load_op = .Clear,
                final_layout = .ColorAttachmentOptimal,
                samples = 1,
                clear_color = Vector4{1, 1, 1, 1},
            },
            {
                tag          = "Object Picking Depth",
                format       = .D32_SFLOAT_S8_UINT,
                load_op      = .Clear,
                store_op     = .Store,
                samples      = 1,
                final_layout = .DepthStencilAttachmentOptimal,
                clear_depth  = 1.0,
            },
        },
        subpasses = {
            {
                color_attachments = {
                    {
                        attachment = 0, layout = .ColorAttachmentOptimal,
                    }
                },
                depth_stencil_attachment = gpu.RenderPassAttachmentRef {
                    attachment = 1, layout = .DepthStencilAttachmentOptimal,
                },
            }
        },
    }

    this.renderpass = gpu.create_render_pass(renderpass_spec)

    fb_spec := gpu.FrameBufferSpecification {
        device = device,
        width = 100,
        height = 100,
        samples = 1,
        renderpass = this.renderpass,
        attachments = {
            {
                format = .RED_SIGNED,
                usage = {.ColorAttachment, .Sampled, .TransferSrc},
                samples = 1,
            },
            {
                format = .D32_SFLOAT_S8_UINT,
                usage = {.Transient, .DepthStencilAttachment},
                samples = 1,
            }
        }
    }

    this.framebuffer = gpu.create_framebuffer(fb_spec)

    pipeline_layout_spec := gpu.PipelineLayoutSpecification {
        tag = "Object Picking PL",
        device = device,
        layouts = {
            Renderer3DInstance.global_set.layout,
            Renderer3DInstance.scene_set.layout,
            Renderer3DInstance.object_set.layout,
        },
        use_push = true,
    }

    pipeline_layout := gpu.create_pipeline_layout(
        pipeline_layout_spec,
        size_of(ObjectPickingPushConstants))

    // config := gpu.default_pipeline_config()
    // config.multisample_info.rasterizationSamples = {._8}
    // config.multisample_info.sampleShadingEnable = true
    // config.rasterization_info.cullMode = {.FRONT}

    // @note This should be moved out of here.
    vertex_layout := gpu.vertex_layout({
        name = "Position",
        type = .Float3,
    }, {
        name = "Normal", // not needed for this pass
        type = .Float3,
    }, {
        name = "Tangent", // not needed for this pass
        type = .Float3,
    }, {
        name = "UV", // not needed for this pass
        type = .Float2,
    }, {
        name = "Color", // not needed for this pass
        type = .Float3,
    })
    pipeline_spec := gpu.PipelineSpecification {
        tag = "Object Pipeline",
        layout = pipeline_layout,
        attribute_layout = vertex_layout,
        renderpass = this.renderpass,
    }

    manager := &EngineInstance.asset_manager
    this.shader = AssetHandle(generate_uuid())
    manager.registry[this.shader] = AssetMetadata {
        path = "assets/shaders/new/object_pick.shader",
        type = .Shader,
        dont_serialize = true,
    }

    manager.loaded_assets[this.shader] = new_shader(manager.registry[this.shader].path, pipeline_spec) or_return

    return true
}

object_picking_deinit :: proc(this: ^ObjectPicking) {
    gpu.destroy_framebuffer(&this.framebuffer)
}

object_picking_render :: proc(this: ^ObjectPicking, packet: RPacket, cmd: gpu.CommandBuffer, mesh_components: []^MeshRenderer) {
    if gpu.do_render_pass(cmd, this.renderpass, this.framebuffer) {
        tracy.ZoneN("Object Picking")

        shader := get_asset(&EngineInstance.asset_manager, this.shader, Shader)
        gpu.pipeline_bind(cmd, shader.pipeline)

        for mr in mesh_components {
            tracy.ZoneN("Draw Mesh")
            mesh := get_asset(&EngineInstance.asset_manager, mr.mesh, Mesh)
            if mesh == nil do continue

            go := get_object(packet.scene, mr.owner)

            mat := go.transform.global_matrix
            // draw_elements(gl.TRIANGLES, mesh.num_indices, gl.UNSIGNED_SHORT)
            push := ObjectPickingPushConstants {
                model = mat,
                object_id = go.local_id,
            }

            vk.CmdPushConstants(
                cmd.handle,
                shader.pipeline.spec.layout.handle,
                {.VERTEX, .FRAGMENT},
                0, size_of(PushConstants), &push)

            gpu.bind_buffers(cmd, mesh.vertex_buffer)
            gpu.bind_buffers(cmd, mesh.index_buffer)
            gpu.draw_indexed(cmd, mesh.num_indices, 1, 0)
        }
    }
}

object_picking_resize :: proc(this: ^ObjectPicking, size: Vector2) {
    gpu.framebuffer_resize(&this.framebuffer, size)
}
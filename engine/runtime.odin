package engine

import "core:log"
import "core:math"
import "core:math/linalg"
import gl "vendor:OpenGL"
import tracy "packages:odin-tracy"

ViewData :: struct {
    projection: mat4,
    view: mat4,
}

SceneData :: struct {
    view_position: vec3, _: f32,
    ambient_color: Color,
}

MAX_SPOTLIGHTS :: 10
MAX_POINTLIGHTS :: 10

LightData :: struct {
    directional: struct {
        direction: vec4,
        color: Color,
        light_space_matrix: mat4,
    },
    point_lights: [MAX_POINTLIGHTS]struct {
        color: Color,
        position: vec3,

        constant: f32,
        linear: f32,
        quadratic: f32,
        _: f32,
    },
}

RenderCamera :: struct {
    position : vec3,
    rotation: quaternion128,
    projection, view: mat4,
}

WorldRenderer :: struct {
    world: ^World,

    view_data: UniformBuffer(ViewData),
    light_data: UniformBuffer(LightData),
    scene_data: UniformBuffer(SceneData),

    depth_frame_buffer:    FrameBuffer,
    world_frame_buffer:    FrameBuffer,
    resolved_frame_buffer: FrameBuffer,
    final_frame_buffer:    FrameBuffer,

    depth_shader:  Shader,
    pbr_shader:    Shader,
    screen_shader: Shader,
}

world_renderer_init :: proc(renderer: ^WorldRenderer) {
    spec := FrameBufferSpecification {
        width = 800,
        height = 800,
        attachments = attachment_list(.RGBA16F, .RED_INTEGER, .DEPTH),
        samples = 1,
    }

    renderer.world_frame_buffer = create_framebuffer(spec)

    spec.attachments = attachment_list(.RGBA16F, .DEPTH)
    renderer.resolved_frame_buffer = create_framebuffer(spec)

    spec.attachments = attachment_list(.RGBA8, .DEPTH)
    renderer.final_frame_buffer = create_framebuffer(spec)

    spec.width       = SHADOW_MAP_RES
    spec.height      = SHADOW_MAP_RES
    spec.attachments = attachment_list(.DEPTH32F)
    spec.samples     = 1
    renderer.depth_frame_buffer = create_framebuffer(spec)

    renderer.view_data = create_uniform_buffer(ViewData, 0)
    renderer.scene_data = create_uniform_buffer(SceneData, 1)
    renderer.light_data = create_uniform_buffer(LightData, 3)

    // TODO(minebill): These shaders should probably be loaded from the asset system.
    ok: bool
    renderer.depth_shader, ok = shader_load_from_file(
        "assets/shaders/depth.vert.glsl",
        "assets/shaders/depth.frag.glsl",
    )
    assert(ok)

    renderer.pbr_shader, ok = shader_load_from_file(
        "assets/shaders/triangle.vert.glsl",
        "assets/shaders/pbr.frag.glsl",
    )
    assert(ok)

    renderer.screen_shader, ok = shader_load_from_file(
        "assets/shaders/screen.vert.glsl",
        "assets/shaders/screen.frag.glsl",
    )
    assert(ok)
}

RenderPacket :: struct {
    camera: RenderCamera,
    world: ^World,
    size: vec2i,
}

render_world :: proc(world_renderer: ^WorldRenderer, packet: RenderPacket) {
    world_renderer.world = packet.world

    world := world_renderer.world
    view_data := &world_renderer.view_data

    mesh_components := make([dynamic]^MeshRenderer, allocator = context.temp_allocator)
    {
        tracy.ZoneN("Mesh Collection")
        for handle, &go in world.objects do if go.enabled && has_component(world, handle, MeshRenderer) {
            mr := get_component(world, handle, MeshRenderer)
            if mr.model != nil && is_model_valid(mr.model^) {
                append(&mesh_components, mr)
            }
        }
    }

    do_depth_pass(world_renderer, mesh_components[:],packet)

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
            light.position = go.transform.position

            num_point_lights += 1
        }

        if num_point_lights > 0 {
            uniform_buffer_upload(
                light_data,
                offset_of(light_data.data.point_lights),
                size_of(light_data.point_lights[0]) * num_point_lights)
        }
    }

    scene_data := &world_renderer.scene_data
    world_fb := &world_renderer.world_frame_buffer

    gl.BindFramebuffer(gl.FRAMEBUFFER, world_fb.handle)
    gl.Viewport(0, 0, packet.size.x, packet.size.y)

    gl.ClearDepth(1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)

    scene_data.view_position = packet.camera.position
    uniform_buffer_upload(
        scene_data,
        offset_of(scene_data.data.view_position),
        size_of(scene_data.view_position))

    view_data.projection = packet.camera.projection
    uniform_buffer_upload(
        view_data,
        offset_of(view_data.data.projection),
        size_of(view_data.projection))

    { // Cubemap Skybox
        if cubemap := find_first_component(world, CubemapComponent); cubemap != nil {
            gl.Disable(gl.DEPTH_TEST)

            view_data.view = linalg.matrix4_from_quaternion(packet.camera.rotation)
            uniform_buffer_upload(view_data, offset_of(view_data.data.view), size_of(view_data.view))

            gl.UseProgram(cubemap.shader.program)
            gl.BindTextureUnit(6, cubemap.texture.handle)
            gl.DrawArrays(gl.TRIANGLES, 0, 36)

            gl.Enable(gl.DEPTH_TEST)
        }
    }

    view_data.view = packet.camera.view
    uniform_buffer_upload(view_data, offset_of(view_data.data.view), size_of(view_data.view))

    // Draw meshes
    {
        pbr_shader := &world_renderer.pbr_shader

        gl.BindTextureUnit(2, get_depth_attachment(world_renderer.depth_frame_buffer))

        gl.UseProgram(pbr_shader.program)
        for mr in mesh_components {
            go := get_object(world, mr.owner)
            gl.BindVertexArray(mr.model.vertex_array)
            bind_material(&mr.material)
            // gl.BindBuffer(gl.UNIFORM_BUFFER, model.material.ubo)

            mm := &go.transform.global_matrix
            gl.UniformMatrix4fv(uniform(pbr_shader, "model"), 1, false, &mm[0][0])
            gl.Uniform1i(uniform(pbr_shader, "gameobject_id"), i32(go.local_id))

            draw_elements(gl.TRIANGLES, mr.model.num_indices, gl.UNSIGNED_SHORT)
        }


        gl.Enable(gl.STENCIL_TEST)
        gl.Disable(gl.DEPTH_TEST)
        gl.ColorMask(false, false, false, false)
        gl.StencilFunc(gl.ALWAYS, 1, 0xFF)
        gl.StencilMask(0xFF)

        gl.UseProgram(pbr_shader.program)
        for handle, &go in world.objects do if go.enabled && .Outlined in go.flags && has_component(world, handle, MeshRenderer) {
            mr := get_component(world, handle, MeshRenderer)
            if mr.model != nil && is_model_valid(mr.model^) {
                gl.BindVertexArray(mr.model.vertex_array)

                mm := &go.transform.global_matrix
                // TODO(minebill): Use a simple shader here.
                gl.UniformMatrix4fv(uniform(pbr_shader, "model"), 1, false, &mm[0][0])

                draw_elements(gl.TRIANGLES, mr.model.num_indices, gl.UNSIGNED_SHORT)
            }
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
        0)

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

        PLANE_VERT_COUNT :: 6

        gl.UseProgram(world_renderer.screen_shader.program)
        gl.BindTextureUnit(0, get_color_attachment(world_renderer.resolved_frame_buffer))

        gl.Disable(gl.DEPTH_TEST)
        draw_arrays(gl.TRIANGLES, 0, PLANE_VERT_COUNT)
        gl.Enable(gl.DEPTH_TEST)    }
}

do_depth_pass :: proc(world_renderer: ^WorldRenderer, mesh_components: []^MeshRenderer, packet: RenderPacket) {
    world := world_renderer.world
    view_data := &world_renderer.view_data

    // Depth Pass, for lighting
    {
        depth_fb := &world_renderer.depth_frame_buffer
        gl.BindFramebuffer(gl.FRAMEBUFFER, depth_fb.handle)
        gl.Viewport(0, 0, SHADOW_MAP_RES, SHADOW_MAP_RES)

        gl.Clear(gl.DEPTH_BUFFER_BIT)

        for handle, &go in world.objects do if go.enabled && has_component(world, handle, DirectionalLight) {
            dir_light := get_component(world, handle, DirectionalLight)
            r := go.transform.local_rotation
            dir_light_quat := linalg.quaternion_from_euler_angles(
                                r.x * math.RAD_PER_DEG,
                                r.y * math.RAD_PER_DEG,
                                r.z * math.RAD_PER_DEG,
                                .XYZ)
            dir := linalg.quaternion_mul_vector3(dir_light_quat, vec3{0, 0, -1})

            corners := get_frustum_corners_world_space(packet.camera.projection, packet.camera.view)

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

                if hm.x < min.x {
                    min.x = hm.x
                }
                if hm.y < min.y {
                    min.y = hm.y
                }
                if hm.z < min.z {
                    min.z = hm.z
                }

                if hm.x > max.x {
                    max.x = hm.x
                }
                if hm.y > max.y {
                    max.y = hm.y
                }
                if hm.z > max.z {
                    max.z = hm.z
                }
            }

            view_data.projection = linalg.matrix_ortho3d_f32(
                left = min.x, 
                right = max.x,
                bottom = min.y,
                top = max.y,
                near = min.z,
                far = max.z)

            uniform_buffer_upload(view_data)

            light_data := &world_renderer.light_data
            light_data.directional.direction = vec4{dir.x, dir.y, dir.z, 0}
            light_data.directional.color = dir_light.color
            light_data.directional.light_space_matrix = view_data.projection * view_data.view

            uniform_buffer_upload(
                light_data,
                offset_of(light_data.data.directional),
                size_of(light_data.directional))

            gl.UseProgram(world_renderer.depth_shader.program)
            gl.UniformMatrix4fv(uniform(&world_renderer.depth_shader, "light_space"), 1, false, &light_data.directional.light_space_matrix[0][0])
            for mr in mesh_components {
                gl.BindVertexArray(mr.model.vertex_array)

                go := get_object(world, mr.owner)
                mm := &go.transform.global_matrix
                gl.UniformMatrix4fv(uniform(&world_renderer.depth_shader, "model"), 1, false, &mm[0][0])

                draw_elements(gl.TRIANGLES, mr.model.num_indices, gl.UNSIGNED_SHORT)
            }
        }
    }
}

world_renderer_resize :: proc(world_renderer: ^WorldRenderer, width, height: int) {
    world_renderer.world_frame_buffer.spec.samples = int(g_msaa_level)

    resize_framebuffer(&world_renderer.final_frame_buffer, width, height)
    resize_framebuffer(&world_renderer.depth_frame_buffer, width, height)
    resize_framebuffer(&world_renderer.world_frame_buffer, width, height)
    resize_framebuffer(&world_renderer.resolved_frame_buffer, width, height)
}

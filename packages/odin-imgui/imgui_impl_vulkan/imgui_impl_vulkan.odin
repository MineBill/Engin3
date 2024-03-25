package imgui_impl_vulkan

import imgui "../"
import vk "vendor:vulkan"

when      ODIN_OS == .Windows do foreign import lib "../imgui_windows_x64.lib"
else when ODIN_OS == .Linux   do foreign import lib "../imgui_linux_x64.a"
else when ODIN_OS == .Darwin {
	when ODIN_ARCH == .amd64 { foreign import lib "../imgui_darwin_x64.a" } else { foreign import lib "../imgui_darwin_arm64.a" }
}

// imgui_impl_vulkan.h
// Last checked 357f752b
InitInfo :: struct {
	Instance:        vk.Instance,
	PhysicalDevice:  vk.PhysicalDevice,
	Device:          vk.Device,
	QueueFamily:     u32,
	Queue:           vk.Queue,
	PipelineCache:   vk.PipelineCache,
	DescriptorPool:  vk.DescriptorPool,
	Subpass:         u32,
	MinImageCount:   u32,                 // >= 2
	ImageCount:      u32,                 // >= MinImageCount
	MSAASamples:     vk.SampleCountFlags, // >= VK_SAMPLE_COUNT_1_BIT (0 -> default to VK_SAMPLE_COUNT_1_BIT)

	// Dynamic Rendering (Optional)
	UseDynamicRendering:   bool,      // Need to explicitly enable VK_KHR_dynamic_rendering extension to use this, even for Vulkan 1.3.
	ColorAttachmentFormat: vk.Format, // Required for dynamic rendering

	// Allocation, Debugging
	Allocator:       ^vk.AllocationCallbacks,
	CheckVkResultFn: proc "c" (err: vk.Result),
}

@(link_prefix="ImGui_ImplVulkan_")
foreign lib {
	// Called by user code
	Init                     :: proc(info: ^InitInfo, render_pass: vk.RenderPass) -> bool ---
	Shutdown                 :: proc() ---
	NewFrame                 :: proc() ---
	RenderDrawData           :: proc(draw_data: ^imgui.DrawData, command_buffer: vk.CommandBuffer, pipeline: vk.Pipeline = {}) ---
	CreateFontsTexture       :: proc(command_buffer: vk.CommandBuffer) -> bool ---
	DestroyFontUploadObjects :: proc() ---
	SetMinImageCount         :: proc(min_image_count: u32) --- // To override MinImageCount after initialization (e.g. if swap chain is recreated)

    AddTexture               :: proc(sampler: vk.Sampler, image_view: vk.ImageView, image_layout: vk.ImageLayout) -> vk.DescriptorSet ---
    RemoveTexture            :: proc(descriptor_set: vk.DescriptorSet) ---

	LoadFunctions :: proc(loader_func: proc "c" (function_name: cstring, user_data: rawptr) -> vk.ProcVoidFunction, user_data: rawptr = nil) -> bool ---
}

// There are some more Vulkan functions/structs, but they aren't necessary

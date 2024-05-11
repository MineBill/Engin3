package main_build
import "core:os"
import "core:log"
import "core:fmt"
import "core:strings"
import "core:path/filepath"
import "packages:odin-build/build"
import "common"
import engine "../engine/build"
import meta "../engine/meta/build"
import mani "packages:mani/build"
import fs "../engine/filesystem"

Target    :: common.Target
RunTarget :: common.RunTarget

debug := RunTarget {
    base = {
        name = "default-debug",
        platform = common.CURRENT_PLATFORM,
    },
    dependencies = {
        &meta.run,
        &mani.run,

        &engine.debug,
    },
    target_to_run = &engine.debug,
}

release := RunTarget {
    base = {
        name = "default-release",
        platform = common.CURRENT_PLATFORM,
    },
    dependencies = {
        &meta.run,
        &mani.run,

        &engine.release,
    },
    target_to_run = &engine.release,
}

copy_vulkan_dlls := RunTarget {
    base = {
        name = "setup-vulkan",
        platform = common.CURRENT_PLATFORM,
    },
    outputs = {
        // Shaderc
        "engine/shaderc/bin/shaderc_combined",

        // Spriv-Cross
        "engine/spirv-cross/bin/SPIRV",
        "engine/spirv-cross/bin/spirv-cross-c",
        "engine/spirv-cross/bin/spirv-cross-c-shared",
        "engine/spirv-cross/bin/spirv-cross-core",
        "engine/spirv-cross/bin/spirv-cross-cpp",
        "engine/spirv-cross/bin/spirv-cross-glsl",
        "engine/spirv-cross/bin/spirv-cross-hlsl",
        "engine/spirv-cross/bin/spirv-cross-msl",
        "engine/spirv-cross/bin/spirv-cross-reflect",
        "engine/spirv-cross/bin/spirv-cross-util",
    }
}

run_copy_vulkan_dlls :: proc(target: ^build.Target, run_mode: build.Run_Mode, args: []build.Arg, loc := #caller_location) -> bool {
    target := cast(^RunTarget) target

    sdk_path := os.get_env("VULKAN_SDK")
    base := filepath.dir(filepath.dir(#file))
    for file in target.outputs {
        file := strings.join({file, common.LIB}, "")
        log.debugf("Copy from %v", filepath.join({sdk_path, "Lib", filepath.base(file)}))
        log.debugf("\tTo %v", build.tabspath(target, file))
        fs.copy_file(
            filepath.join({sdk_path, "Lib", filepath.base(file)}),
            build.tabspath(target, file), true) or_return
    }

    for file in target.outputs {
        file := strings.join({file, "d" + common.LIB}, "")
        log.debugf("Copy from %v", filepath.join({sdk_path, "Lib", filepath.base(file)}))
        log.debugf("\tTo %v", build.tabspath(target, file))
        fs.copy_file(
            filepath.join({sdk_path, "Lib", filepath.base(file)}),
            build.tabspath(target, file), true) or_return
    }
    return true
}

@(init)
_ :: proc() {
    context.allocator = context.temp_allocator
    common.project.name = "Engin3"

    build.add_target(&common.project, &debug, common.run_target)
    build.add_target(&common.project, &release, common.run_target)
    build.add_target(&common.project, &copy_vulkan_dlls, run_copy_vulkan_dlls)
}

main :: proc() {
    context.allocator = context.temp_allocator
    context.logger = log.create_console_logger(opt = log.Options {
        .Terminal_Color,
    })

    if !main_wrapped() {
        log.error("Build system failed.")
        log.infof("This might not apply but it's possible the failure was due to a missing library from the VulkanSDK.")
        log.infof("\tEnsure the debug versions are also installed.")
    }
}

main_wrapped :: proc() -> bool {
    log.info("Checking for VulkanSDK installation...")
    sdk_path, sdk_found := os.lookup_env("VULKAN_SDK")
    if !sdk_found {
        log.errorf("VulkanSDK installation could not be found. Ensure the VULKAN_SDK environment variable is set.")
        log.errorf("Exiting.")
        return false
    }
    log.infof("VulkanSDK found at '%v'", sdk_path)

    build.run_cli(build.Cli_Info {
        project = &common.project,
        default_target = &debug,
    }, os.args) or_return
    return true
}
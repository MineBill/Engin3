package build_common
import "core:fmt"
import "core:path/filepath"
import "packages:odin-build/build"
import "core:log"

when ODIN_OS == .Windows {
    EXE :: ".exe"
} else when ODIN_OS == .Linux {
    EXE :: ""
}

Target :: struct {
    using base: build.Target,

    dependencies: []^build.Target,

    src_dir: string,
    out_dir: string,
    exe_name: string,
}

RunTarget :: struct {
    using target: Target,
    target_to_run: ^Target,
    args: []string,
}

CopyTarget :: struct {
    using base: build.Target,

    from: []string,
    to: string,
}

CURRENT_PLATFORM :: build.Platform {ODIN_OS, ODIN_ARCH}

project: build.Project

// Can be used to hook into the build system.
common_target := build.Target {
    name = "Common",
    platform = CURRENT_PLATFORM,

    run_proc = proc(target: ^build.Target, run_mode: build.Run_Mode, args: []build.Arg, loc := #caller_location) -> bool {
        return true
    }
}

// Executes, meaning builds an odin executable. Executable names and anything else is specified in the Target itself.
execute_target :: proc(target: ^build.Target, run_mode: build.Run_Mode, args: []build.Arg, loc := #caller_location) -> bool {
    target := cast(^Target) target
    log.warnf("[EXECUTING '%v']", target.name)
 	odin_build: build.Odin_Config
	odin_build.platform = target.platform
	odin_build.build_mode = .EXE
	exe_extension: string
	#partial switch target.platform.os {
	case .Windows:
        exe_extension = ".exe"
	case: // Other platforms don't need extension right now.
	}
	odin_build.out_file = fmt.tprintf("%s%s", target.exe_name, exe_extension)

    odin_build.out_dir = build.trelpath(target, target.out_dir)

    if target.src_dir == "" {
        odin_build.src_path = target.root_dir
    } else {
        path := filepath.join({target.root_dir, target.src_dir})
        odin_build.src_path = path
    }

    odin_build.opt = .None
    odin_build.flags += {
        .Debug,
        .Use_Separate_Modules,
        .Ignore_Unknown_Attributes,
    }

	odin_build.timings.mode = .Disabled
    odin_build.collections = {
        { "packages", "packages" },
    }
    odin_build.defines = {
        {"TRACY_ENABLE", true},
        {"VALIDATION", true},
    }

	switch run_mode {
	case .Build:
		build.odin(target, .Build, odin_build) or_return
		return true
	case .Dev:
		return true
	case .Help:
		return false
    }
    return false
}

// Executes a target. The exe to execute is taked from the `target_to_run`.
run_target :: proc(target: ^build.Target, run_mode: build.Run_Mode, args: []build.Arg, loc := #caller_location) -> bool {
    using filepath
    target := cast(^RunTarget) target
    for dep in target.dependencies {
        build.run_target(dep, run_mode, args, loc)
    }

    to_run := target.target_to_run

    out_dir := to_run.out_dir
    t := join({build._project_directory, out_dir, to_run.exe_name})
    path, _ := rel(build._project_directory, t)

    log.infof("[RUNNING '%v']", target.name)
    build.exec(path, target.args)
    return true
}

// Copies files specified by the `CopyTarget`.
copy_target :: proc(target: ^build.Target, run_mode: build.Run_Mode, args: []build.Arg, loc := #caller_location) -> bool {
    target := cast(^CopyTarget) target

    for file in target.from {
        log.info("[COPYING] FROM '%v' -> TO '%v'", file, target.to)
        build.copy_file(file, target.to)
    }

    return true
}
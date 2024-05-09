package main_build
import "core:os"
import "core:log"
import "common"
import "packages:odin-build/build"
import engine "../engine/build"
import meta "../engine/meta/build"
import mani "packages:mani/build"

Target    :: common.Target
RunTarget :: common.RunTarget

run := RunTarget {
    base = {
        name = "default-run",
        platform = common.CURRENT_PLATFORM,
    },
    dependencies = {
        &meta.meta_run_target,
        &mani.mani_run_target,

        &engine.engine_target,
    },
    target_to_run = &engine.engine_target,
}

@(init)
_ :: proc() {
    context.allocator = context.temp_allocator
    common.project.name = "Engin3"

    build.add_target(&common.project, &run, common.run_target)
}

main :: proc() {
    context.allocator = context.temp_allocator
    context.logger = log.create_console_logger(opt = log.Options {
        .Terminal_Color,
    })
    build.run_cli(build.Cli_Info {
        project = &common.project,
        default_target = &run,
    }, os.args)
}
package mani_build
import "packages:odin-build/build"
import "../../../build/common"

build_t := common.Target {
    base = {
        name = "mani-build",
        platform = common.CURRENT_PLATFORM,
    },
    sources = {
        "mani/*.odin",
        "manigen/*.odin",
    },
    outputs = {
        "../../out/mani" + common.EXE,
    },
    src_dir = "manigen",
    out_dir = "out",
    exe_name = "mani",
}

run := common.RunTarget {
    base = {
        name = "mani-run",
        platform = common.CURRENT_PLATFORM,
    },
    dependencies = {
        &build_t,
    },
    target_to_run = &build_t,
    args = {
        "mani_config.json",
        "-show-timings"
    },
}

@(init)
_ :: proc() {
    build.add_target(&common.project, &build_t, common.execute_target)
    build.add_target(&common.project, &run, common.run_target)
}
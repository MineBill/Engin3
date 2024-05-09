package mani_build
import "packages:odin-build/build"
import "../../../build/common"

mani_build_target := common.Target {
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

mani_run_target := common.RunTarget {
    base = {
        name = "mani-run",
        platform = common.CURRENT_PLATFORM,
    },
    dependencies = {
        &mani_build_target,
    },
    target_to_run = &mani_build_target,
    args = {
        "mani_config.json",
        "-show-timings"
    },
}

@(init)
_ :: proc() {
    build.add_target(&common.project, &mani_build_target, common.execute_target)
    build.add_target(&common.project, &mani_run_target, common.run_target)
}
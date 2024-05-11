package meta_build
import "packages:odin-build/build"
import "../../../build/common"

build_t := common.Target {
    base = {
        name = "meta-build",
        platform = common.CURRENT_PLATFORM,
    },
    type = .Release,
    sources = {
        "main.odin"
    },
    outputs = {
        "../../out/meta" + common.EXE,
    },
    out_dir = "out",
    exe_name = "meta",
}

run := common.RunTarget {
    base = {
        name = "meta-run",
        platform = common.CURRENT_PLATFORM,
    },
    dependencies = {
        &build_t,
    },
    target_to_run = &build_t,
    args = {
        "engine"
    },
}

@(init)
_ :: proc() {
    build.add_target(&common.project, &build_t, common.execute_target)
    build.add_target(&common.project, &run, common.run_target)
}
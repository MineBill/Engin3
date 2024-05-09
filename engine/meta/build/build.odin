package meta_build
import "packages:odin-build/build"
import "../../../build/common"

meta_build_target := common.Target {
    base = {
        name = "meta-build",
        platform = common.CURRENT_PLATFORM,
    },
    sources = {
        "main.odin"
    },
    outputs = {
        "../../out/meta" + common.EXE,
    },
    out_dir = "out",
    exe_name = "meta",
}

meta_run_target := common.RunTarget {
    base = {
        name = "meta-run",
        platform = common.CURRENT_PLATFORM,
    },
    dependencies = {
        &meta_build_target,
    },
    target_to_run = &meta_build_target,
    args = {
        "engine"
    },
}

@(init)
_ :: proc() {
    build.add_target(&common.project, &meta_build_target, common.execute_target)
    build.add_target(&common.project, &meta_run_target, common.run_target)
}
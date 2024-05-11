package engine_build

import "packages:odin-build/build"
import common "../../build/common"

Target    :: common.Target
RunTarget :: common.RunTarget

debug := Target {
    base = {
        name = "engine-debug",
        platform = common.CURRENT_PLATFORM,
    },
    type = .Debug,
    sources = {
        "*.odin",
        "gpu/*.odin",
    },
    outputs = {
        "../out/engin3d" + common.EXE
    },
    out_dir = "out",
    exe_name = "engin3d",
}

release := Target {
    base = {
        name = "engine-release",
        platform = common.CURRENT_PLATFORM,
    },
    type = .Release,
    sources = {
        "*.odin",
        "gpu/*.odin",
    },
    outputs = {
        "../out/engin3" + common.EXE
    },
    out_dir = "out",
    exe_name = "engin3",
}

@(init)
_ :: proc() {
    build.add_target(&common.project, &debug, common.execute_target)
    build.add_target(&common.project, &release, common.execute_target)
}
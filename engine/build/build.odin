package engine_build

import "packages:odin-build/build"
import common "../../build/common"

Target    :: common.Target
RunTarget :: common.RunTarget

engine_target := Target {
    base = {
        name = "Engin3",
        platform = common.CURRENT_PLATFORM,
    },
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
    build.add_target(&common.project, &engine_target, common.execute_target)
}
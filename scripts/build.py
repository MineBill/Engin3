from utils import assertx, has_tool, glob_copy, run_vcvars, exec, map_to_folder
from install_vulkan import setup_vulkan
import os
import shutil
import platform
import sys

os_windows = platform.system() == "Windows"
os_linux   = platform.system() == "Linux" or platform.system() == "Darwin"


def build_lua():
    os.chdir("packages/odin-lua")
    BUILD_FOLDER = "build"

    shutil.rmtree(path=BUILD_FOLDER, ignore_errors=True)
    os.mkdir(BUILD_FOLDER)
    os.listdir

    sources = glob_copy("lua_src", "*.c", BUILD_FOLDER)
    glob_copy("lua_src", "*.h", BUILD_FOLDER)

    os.chdir(BUILD_FOLDER)
    if os_windows: run_vcvars(["cl"] + ["-DLUA_USE_WINDOWS"] + sources + ["/c"], "Compiling")
    elif os_linux: exec(["cc"] + ["-DLUA_USE_LINUX"] + sources + ["-c"], "Compiling")
    os.chdir("..")

    all_objects = []
    if os_windows:  all_objects += map(lambda file: file.removesuffix(".c") + ".obj", sources)
    elif os_linux:
        for file in all_sources:
            if file.endswith(".cpp"): all_objects.append(file.removesuffix(".c") + ".o")
            elif file.endswith(".mm"): all_objects.append(file.removesuffix(".mm") + ".o")

    if os_windows:
        exec(["lib", "/OUT:lua546.lib"] + map_to_folder(all_objects, "build"), "Linking")
        os.remove("bin/windows/lua546.lib")
        shutil.move("lua546.lib", "bin/windows/")
    if os_linux:
        exec(["ar", "rcvs", "lua546.a"] + map_to_folder(all_objects, "build"), "Linking")
        shutil.move("lua546.a", "bin/linux/")

    shutil.rmtree(path=BUILD_FOLDER, ignore_errors=True)
    os.chdir("../..")


def main():
    def did_re_execute() -> bool:
        if platform.system() != "Windows": return False
        if has_tool("cl"): return False
        if "-no_reexecute" in sys.argv: return False
        print("Re-executing with vcvarsall..")
        os.system("".join(["vcvarsall.bat x64 && ", sys.executable, " scripts/build.py -no_reexecute"]))
        return True

    if did_re_execute(): return

    ok = setup_vulkan()
    if not ok:
        print("Vulkan setup failed. Exiting early..")
        return
    build_lua()


if __name__ == "__main__":
    main()

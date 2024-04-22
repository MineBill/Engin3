import subprocess
from typing import List
from glob import glob
import os
import shutil


# Assert which doesn't clutter the output
def assertx(cond: bool, msg: str = ""):
    if not cond:
        print(msg)
        exit(1)


def has_tool(tool: str) -> bool:
    try:
        subprocess.check_output([tool], stderr=subprocess.DEVNULL)
    except FileNotFoundError:
        return False
    else:
        return True


def run_vcvars(cmd: List[str], what):
    full_cmd = f"vcvarsall.bat x64 && {' '.join(cmd)}"
    assertx(subprocess.run(full_cmd).returncode == 0, f"Failed to run command '{cmd}'")  # noqa


def exec(cmd: List[str], what: str) -> str:
	max_what_len = 40
	if len(what) > max_what_len:
		what = what[:max_what_len - 2] + ".."
	print(what + (" " * (max_what_len - len(what))) + "> " + " ".join(cmd))
	return subprocess.check_output(cmd).decode().strip()


def glob_copy(root_dir: str, glob_pattern: str, dest_dir: str):
    the_files = glob(root_dir=root_dir, pathname=glob_pattern)
    copy(root_dir, the_files, dest_dir)
    return the_files


def copy(from_path: str, files: List[str], to_path: str):
    for file in files:
        shutil.copy(os.path.join(from_path, file), to_path)


def map_to_folder(files: List[str], folder: str) -> List[str]:
	return list(map(lambda file: os.path.join(folder, file), files))

import os
import platform
import urllib.request
import zipfile
import utils


os_windows = platform.system() == "Windows"
os_linux   = platform.system() == "Linux" or platform.system() == "Darwin"

VULKAN_SDK_VERSION = "1.3.268.0"


def install_vulkan_sdk():
    pass


def locate_sdk() -> (str, bool):
    sdk_path = os.environ.get("VULKAN_SDK")
    if sdk_path == "":
        return "", False
    return sdk_path, True


def setup_vulkan() -> bool:
    path, ok = locate_sdk()
    if not ok:
        print("VulkanSDK was not found.")
        if os_windows:
            url = f"https://sdk.lunarg.com/sdk/download/{VULKAN_SDK_VERSION}/windows/VulkanSDK-{VULKAN_SDK_VERSION}-Installer.exe"
            print("Please install the VulkanSDK and then re-run this script.")
            print(f"Download from: {url}")
        elif os_linux:
            url = f"https://sdk.lunarg.com/sdk/download/{VULKAN_SDK_VERSION}/windows/VulkanSDK-{VULKAN_SDK_VERSION}-Installer.exe"
            print(f"Downloading VulkanSDK from {url}")
            print(f"Once the download is finished please re-run this script.")
        return False

    installed_version = os.path.basename(path)

    if VULKAN_SDK_VERSION is not installed_version:
        print(f"Engin3 requires version {VULKAN_SDK_VERSION} of the VulkanSDK but we found {installed_version}.")
        print("Will keep going for now but keep that in mind.")

    # Copy the files we need from 
    if os_windows:
        utils.glob_copy(f"{path}/Lib", "shaderc_combined.lib", "engine/shaderc/bin")
        utils.glob_copy(f"{path}/Lib", "spirv-cross-*.lib", "engine/spirv-cross/bin")

    return True

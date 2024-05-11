# Engin3
<p align="center">
  <img src="assets/editor/icons/Logo_Shadow.png" />
</p>

This is a very simple project that aims to help me learn how graphics work and how to develop a simple game engine. It is __NOT__ a serious tool but a learning project, so please keep that in mind.

## Status
Currently, only work on the "Editor" part is being done. Once i'm satisfied with that, the next step would be to get the "runtime" working, meaning
being able to load a "cooked" game from a single asset file.

## Architecture
The engine uses a "component" based system. Entities exist in the world and can have multiple components attached to them. It follows the logic of Unity's MonoBehaviour and not an ECS.
The reason for this is that i just feel more comfortable working with this type of components and speed is not a hude concern right now.

## Building and Running
> [!WARNING]  
> The project is highly volatile and there is a chance you won't be able to compile vendor libraries and/or get linking errors.
> If you do encounter such issues, please open in issue, i would love to help you get it working!

### Requirements
- Odin
- Vulkan SDK
  - You __MUST__ make sure the SDK is installed with the debug versions of the shader libraries!
- CMake (I'm sorry)

### Odin
First, you need to [install](https://odin-lang.org/docs/install/) Odin and make sure the `odin` executable is in your PATH.

- Windows
  - Make sure you have the MSVC build tools installed. If not, consider using [this](https://github.com/Data-Oriented-House/PortableBuildTools).

### Building third party libraries
The project (sadly) has to use CMake to build the third party libraries, so you must have it installed. Then:

```shell
cmake -S packages/ -B temp # Put all the cmake generate stuff in temp, which is ignored in this repo
cmake --build temp --config Debug --target copy_libs
```

> Additionally, if you want to use the engine in release mode, you also have to build
> the release version of the 3rd party libs:
> ```shell
> cmake --build temp --config Release --target copy_libs
> ```

### Building Engin3
At the root of the repository, run:
```odin
odin build build -collection:packages=packages
```

This command will create a `build.(exe|bin)` binary which you can then use to build and run the project. However, before doing so, we need to copy some neccesary libraries from the Vulkan SDK. This step only needs to be run once:
```shell
./build.exe setup-vulkan
```

Now we are ready to run the project:
```shell
./build.exe default-debug # This should launch the engine in debug configuration.
```

### Discord
Everybody and their mum has a discord server, so why not me? :)
[Join the Discord](https://discord.gg/K9QfYjKwng)

### Screenshots
![Screenshot_7](https://github.com/MineBill/Engin3/assets/30367251/33772937-d243-48c0-9ba7-8039c686b8ea)

![Screenshot_8](https://github.com/MineBill/Engin3/assets/30367251/72fee72a-f554-4b79-b082-738f9e692d03)

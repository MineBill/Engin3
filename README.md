## Engin3
This is a very simple project that aims to help me learn how graphics work and how to develop a simple game engine.
Currently the editor and the "game" are in the same package, because i don't care about separating them yet. 

~The editor is not meant as a "generic" project editor and is instead tied with the "game" project. In the future, once i figure more stuff out,
this might change.~ UPDATE: Welp, i've figured some stuff out and this has changed. The editor now works on "projects" but lacks the ability to create new ones for now, so you have
to manually set it up.

### Building and Running
First, you need to [install](https://odin-lang.org/docs/install/) Odin and make sure the `odin` executable is in your PATH.

This project uses [Task](https://taskfile.dev), a simple task runner. Task is a single binary and can easily be installed:
- On Windows: `winget install Task.Task`
- On Linux: `Use your package manager`

Right now, library binaries for windows are included in the repo for ease of use.
For linux, you will need to compile them yourself:
- Run `./packages/build.sh` to build the necessary libraries.

Once installed, execute `task run` at the project root and everything should be build correctly.
Task is used to run a meta program when needed and to compile needed libraries for first-time use.

### Screenshots
![Screenshot_7](https://github.com/MineBill/Engin3/assets/30367251/33772937-d243-48c0-9ba7-8039c686b8ea)

![Screenshot_8](https://github.com/MineBill/Engin3/assets/30367251/72fee72a-f554-4b79-b082-738f9e692d03)

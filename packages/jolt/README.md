# JOLT ODIN BINDINGS 

This is an alpha release of the Jolt bindings as I have only tested hello world so far.
The included libs are for single precision mode and windows only at the moment.
Please Contribute and lets get this useable for everyone.
The bindings are set up in such a way that it should be easy to keep them up to date with new versions coming out.
And would like to continue that trend with any contributors. 


---
### Contributers
From here the rest should not be too hard as most of the groundwork has been laid.

Windows users: Help me test things make sure its working.
Linux OSX users: Help me build jolt binaries and set up a jolt_bindings.sh 

How it works: 
## Python carnage: 
I referenced and modified some bindings from a few sources put them in an .h file and made them usable and updated them in where relevant(not all structs checked for completion).
Python scripts runs a preprocesser over the jolt_bind.h which creates a pp.h file for a proper .h file.
Than we run cxxheaderparser that gets type infos etc, and with a bunch of python code that does things specific to this project generate a large string that is output as the jolt.odin file and rebuilds the bindings to make sure the .h and .cpp file are all in sync and built ready to go.

TODO Niceties: 
1. Set up easier way to build with double precision. 
2. Testing 
3. UNIX https://gitlab.com/raygarner13/jolt Untitled 3
4. Separate build directories for single double precision per platform.
others...

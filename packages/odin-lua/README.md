# odin-lua

Updated version of the fork, fixing many bugs and supporting more features (including luajit).


### Usage
  - Add the shared folder to the odin shared collection.
  - Call functions like you would in C; substitute the `lua_/luaL_` prefixes with the corresponding packages: `luaL.dofile`
  - Some function names clash with keywords, therefore they were named with an underscore prefix: `luaL._where` `lua._type`
  - `lua.pushstring` requires to allocate a `cstring` in order to pass to lua. This is done via the final parameter of the procedure. The result value is the allocated cstring which you can delete after. It defaults to `context.temp_allocator`, so you don't have to do anything for the code to work properly. The original `lua_pushstring` was therefore renamed to `lua.pushcstring`
  

### Known issues
  - The library and binary files are made for windows only. If you want to use other OS you need to replace the foreign imports yourself. Feel free to submit a pull request or issue if you have a better approach

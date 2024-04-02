package luaL

import "core:c"

import lua "../lua"


// lua_ident: ^u8

Reg :: struct {
	name: cstring,
	func: lua.CFunction,
}
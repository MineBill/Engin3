package lua

import "core:c" 
import "core:strings"

when JIT_ENABLED {
	when ODIN_OS == .Windows do foreign import liblua "windows/luajit.lib"
	when ODIN_OS == .Linux do foreign import liblua "system:luajit"
	when ODIN_OS == .Darwin do foreign import liblua "system:luajit"
} else {
	when ODIN_OS == .Windows do foreign import liblua "windows/lua542.lib"
	when ODIN_OS == .Linux do foreign import liblua "system:lua"
	when ODIN_OS == .Darwin do foreign import liblua "system:lua"
}

@(default_calling_convention = "c")
@(link_prefix = "lua_")
foreign liblua {
    atpanic :: proc (L: ^State ,  panicf: CFunction) -> CFunction ---
	checkstack :: proc (L: ^State , n: c.int ) -> c.int ---
	close :: proc (L: ^State ) ---
	
	concat :: proc (L: ^State , n: c.int) ---
	
	createtable :: proc (L: ^State , narr: c.int , nrec: c.int ) ---
	
	error :: proc (L: ^State ) -> c.int ---
	gc :: proc (L: ^State , what: c.int, data: c.int) -> c.int ---
	getallocf :: proc (L: ^State , ud: ^rawptr ) -> c.int ---
	getfield :: proc (L: ^State , idx: c.int , k: cstring) -> c.int ---

	gethook :: proc (L: ^State ) -> Hook ---
	gethookcount :: proc(L: ^State ) -> c.int ---
	gethookmask :: proc (L: ^State ) -> c.int ---
	
	getinfo :: proc (L: ^State , what: cstring, ar: ^Debug ) -> c.int ---
	getlocal :: proc (L: ^State , ar: ^Debug , n: c.int) -> cstring ---
	getmetatable :: proc (L: ^State , objindex:c.int ) -> c.int ---
	getstack :: proc (L: ^State ,  level: c.int, ar: ^Debug) -> c.int --- 
	gettable :: proc (L: ^State , idx: c.int ) -> c.int ---
	gettop :: proc (L: ^State ) -> c.int ---
	getupvalue :: proc (L: ^State , funcindex: c.int , n: c.int) -> cstring ---
	getuservalue :: proc (L: ^State , idx: c.int ) -> c.int ---
	iscfunction :: proc (L: ^State , idx: c.int ) -> c.int ---
	isinteger :: proc (L: ^State , idx: c.int ) -> c.int ---
	isnumber :: proc (L: ^State , idx: c.int ) -> c.int ---
	isstring :: proc (L: ^State , idx: c.int ) -> c.int ---
	isuserdata :: proc (L: ^State , idx: c.int ) -> c.int ---
	
	len :: proc (L: ^State , idx: c.int) ---
	load :: proc (L: ^State , reader: Reader, dt: rawptr, chunkname: cstring, mode: cstring) -> c.int --- 
	newstate :: proc (f: Alloc, ud :rawptr) -> ^State ---
	newthread :: proc (L: ^State ) -> ^State ---
	newuserdatauv :: proc (L: ^State, sz: c.ptrdiff_t, nuvalue: c.int) -> rawptr ---
	next :: proc (L: ^State , idx: c.int) -> c.int ---
	pushboolean :: proc (L: ^State , b: c.bool ) ---
	pushcclosure :: proc (L: ^State , fn: CFunction, n:c.int) ---
	pushinteger :: proc (L: ^State , n: Integer ) ---
	pushlightuserdata :: proc (L: ^State , p: rawptr) ---
	
	pushnil :: proc (L: ^State ) ---
	pushnumber :: proc (L: ^State ,  n: Number) ---
	
	pushthread :: proc (L: ^State ) -> c.int ---
	pushvalue :: proc (L: ^State , idx:c.int ) ---
	rawequal :: proc (L: ^State ,  idx1: c.int,  idx2: c.int) -> c.int ---
	rawget :: proc (L: ^State , idx: c.int ) -> c.int ---
	rawgeti :: proc (L: ^State , idx: c.int , n: Integer) -> c.int ---
	
	rawlen :: proc (L: ^State , idx: c.int ) -> c.ptrdiff_t ---
	rawset :: proc (L: ^State , idx: c.int ) ---
	rawseti :: proc (L: ^State , idx: c.int , n: Integer) ---
	
	resume :: proc (L: ^State , from: ^State, narg: c.int) -> c.int ---
	
	setallocf :: proc (L: ^State , f: Alloc , ud: rawptr ) ---
	setfield :: proc (L: ^State , idx: c.int , k: cstring) ---

	sethook :: proc (L: ^State , func: Hook , mask: c.int, count: c.int ) ---
	
	setlocal :: proc (L: ^State , ar: ^Debug , n: c.int) -> cstring ---
	setmetatable :: proc (L: ^State , objindex: c.int ) -> c.int ---
	settable :: proc (L: ^State , idx: c.int ) ---
	settop :: proc (L: ^State , idx:c.int ) ---
	setupvalue :: proc (L: ^State , funcindex: c.int , n: c.int) -> cstring ---
	setuservalue :: proc (L: ^State , idx: c.int ) ---
	status :: proc (L: ^State ) -> c.int ---
	
	toboolean :: proc (L: ^State , idx: c.int ) -> c.int ---
	tocfunction :: proc (L: ^State , idx: c.int ) -> CFunction ---
	tolstring :: proc (L: ^State , idx: c.int , len: ^c.ptrdiff_t) -> cstring ---
	tonumberx :: proc (L: ^State , idx: c.int , isnum: ^c.int) -> Number ---
	topointer :: proc (L: ^State , idx: c.int ) -> rawptr ---
	tothread :: proc (L: ^State , idx: c.int ) -> ^State ---
	touserdata :: proc (L: ^State , idx: c.int ) -> rawptr ---
	typename :: proc (L: ^State , tp: c.int ) -> cstring ---
	
	
	xmove :: proc (from: ^State, to: ^State, n:c.int) ---
	yieldk :: proc (L: ^State , nresults: c.int, ctx: KContext, k: KFunction ) -> c.int ---

	type :: proc (L: ^State , idx: c.int ) -> c.int --- 
}

when !JIT_ENABLED {
    @(default_calling_convention = "c")
    @(link_prefix = "lua_")
    foreign liblua {
        getglobal :: proc (L: ^State , name: cstring) -> c.int ---
        setglobal :: proc (L: ^State , name: cstring) ---
    }
}

when VERSION_NUM <= 500 {
    @(default_calling_convention = "c")
    @(link_prefix = "lua_")
    foreign liblua {
        // Odinify
        @(link_name = "lua_pushstring")
        pushcstring :: proc (L: ^State , s: cstring) 
        pushlstring :: proc (L: ^State , s: cstring, len: c.ptrdiff_t)
    }
    
} else {
    @(default_calling_convention = "c")
    @(link_prefix = "lua_")
    foreign liblua {
        @(link_name = "lua_pushstring")
        pushcstring :: proc (L: ^State , s: cstring) -> cstring ---
        pushlstring :: proc (L: ^State , s: cstring, len: c.ptrdiff_t) -> cstring ---
    
    }
}

when VERSION_NUM <= 501 {
    @(default_calling_convention = "c")
    @(link_prefix = "lua_")
    foreign liblua {
        call :: proc(L: ^State, n: c.int, r: c.int) ---
        pcall :: proc(L: ^State, n: c.int, r: c.int, f: c.int) -> c.int ---
    }
}

when VERSION_NUM >= 502 {
    @(default_calling_convention = "c")
    @(link_prefix = "lua_")
    foreign liblua {
        absindex :: proc (L: ^State , idx: c.int ) -> c.int ---
        arith :: proc (L: ^State , op: c.int ) ---
        compare :: proc (L: ^State ,  idx1: c.int,  idx2: c.int,  op: c.int) -> c.int ---
        copy :: proc (L: ^State , fromidx: c.int , toidx: c.int ) ---
        rawgetp :: proc (L: ^State , idx: c.int , p: rawptr) -> c.int ---
        rawsetp :: proc (L: ^State , idx: c.int , p: rawptr) ---
        upvalueid :: proc (L: ^State , fidx: c.int, n: c.int) -> rawptr ---
        upvaluejoin :: proc (L: ^State , fidx1: c.int, n1: c.int, fidx2: c.int, n2: c.int) ---
        version :: proc (L: ^State ) -> ^Number ---
        pcallk :: proc (L: ^State , nargs: c.int, nresults: c.int, errfunc: c.int, ctx: KContext , k: KFunction ) -> c.int  ---
        callk :: proc (L: ^State , nargs: c.int, nresults: c.int, ctx: KContext , k: KFunction ) ---
    }
}

when VERSION_NUM >= 503 {
    @(default_calling_convention = "c")
    @(link_prefix = "lua_")
    foreign liblua {
        dump :: proc (L: ^State , writer: Writer , data: rawptr, strip:c.int) -> c.int ---
        geti :: proc (L: ^State , idx: c.int , n: Integer) -> c.int ---
        seti :: proc (L: ^State , idx: c.int , n: Integer) ---
        isyieldable :: proc (L: ^State ) -> c.int ---
        rotate :: proc (L: ^State , idx:c.int , n:c.int) ---
        stringtonumber :: proc (L: ^State , s: cstring) -> c.ptrdiff_t ---
        tointegerx :: proc (L: ^State , idx: c.int , isnum: ^c.int) -> Integer ---
    }
}

when VERSION_NUM <= 503 {
    @(default_calling_convention = "c")
    @(link_prefix = "lua_")
    foreign liblua {
        newuserdata :: proc(L: ^State, sz: c.ptrdiff_t) -> rawptr ---
    }
}



when VERSION_NUM >= 504 {
    newuserdata :: proc "c" (L: ^State, sz: c.ptrdiff_t) -> rawptr {
        return newuserdatauv(L, sz, 1)
    }
}

tonumber :: proc "c" (L: ^State, i: c.int) -> Number {
	return Number( tonumberx(L,(i),nil) )
}	

tointeger :: proc "c" (L: ^State, i: c.int) -> Integer {
    when VERSION_NUM >= 503 {
        return cast(Integer)tointegerx(L, i, nil)
    }
	else { // Integers not supported. Emulate them
        result := tonumber(L, i) 
        return cast(Integer)result 
    }
}

pop :: proc "c" (L: ^State, n: c.int ) {
	settop(L, -(n)-1)
}		

newtable :: proc "c" (L: ^State)
{		
	createtable(L, 0, 0)
}

register :: proc "c" (L: ^State, n: cstring, f: CFunction ) {
	pushcfunction(L, (f))
	setglobal(L, (n))
}

pushcfunction :: proc "c" (L: ^State, f: CFunction ) {
	pushcclosure(L, (f), 0)
}	

isfunction :: proc "c" (L: ^State, n: c.int) -> c.bool {
	return (type(L, (n)) == TFUNCTION)
}	

istable :: proc "c" (L: ^State, n:c.int) -> c.bool {
	return (type(L, (n)) == TTABLE)
}

islightuserdata :: proc "c" (L: ^State, n:c.int) -> c.bool {	
	return (type(L, (n)) == TLIGHTUSERDATA)
}

isnil :: proc "c" (L: ^State, n:c.int ) -> c.bool {
	return (type(L, (n)) == TNIL)
}

isboolean :: proc "c" (L: ^State, n: c.int ) -> c.bool {
	return (type(L, (n)) == TBOOLEAN)
}	

isthread :: proc "c" (L: ^State, n: c.int) -> c.bool {
	return (type(L, (n)) == TTHREAD)
}

isnone :: proc "c" (L: ^State, n: c.int) -> c.bool {
	return (type(L, (n)) == TNONE)
}
	
isnoneornil :: proc "c" (L: ^State, n:c.int) -> c.bool {
	return (type(L, (n)) <= 0)
}

pushliteral :: proc "c" (L: ^State, s:cstring) {
	pushcstring(L, s)
}

pushglobaltable :: proc "c" (L: ^State) {
	rawgeti(L, REGISTRYINDEX, RIDX_GLOBALS)
} 
	
tostring :: proc "c" (L: ^State, i: c.int) -> string {
	return string( tolstring(L, (i), nil) ) 
}	

// Note(Dragos): Work on compatibility for these. Implement rotate or something
/*
insert :: proc "c" (L: ^State, idx:c.int) {
	rotate(L, (idx), 1)
}	

remove :: proc "c" (L: ^State, idx: c.int) {	
	rotate(L, (idx), -1)
	pop(L, 1)
}

replace :: proc "c" (L: ^State, idx: c.int)	{
	copy(L, -1, (idx))
	pop(L, 1)
}
*/

yield :: proc "c" (L : ^State, n: c.int) {
	yieldk(L, (n), 0, nil)
}		

when VERSION_NUM >= 502 {
    call :: proc "c" (L: ^State, n: c.int, r: c.int) {
        callk(L, (n), (r), 0, nil)
    }
    
    pcall :: proc "c" (L: ^State, n: c.int, r: c.int, f: c.int) -> c.int {
        return pcallk(L, (n), (r), (f), 0, nil)
    }
}

upvalueindex :: proc "c" (i: c.int) -> c.int {
	return (REGISTRYINDEX - (i))
}



@(private = "file")
_odin_string_backing: [MAX_ODIN_STRLEN]byte 

// lua_pushstring will convert a string to cstring and push.
pushstring :: proc "c" (L: ^State, str: string) {
	context = {}
	sb := strings.builder_from_bytes(_odin_string_backing[:]) // This should be contextless in core
	strings.write_string(&sb, str)
	strings.write_byte(&sb, 0) // make it null terminated
	cstr := strings.unsafe_string_to_cstring(strings.to_string(sb))
	pushcstring(L, cstr)
}

/*
	New macro implementations for LuaJIT compatibility
*/
when JIT_ENABLED {
	setglobal :: jit_setglobal
	getglobal :: jit_getglobal
}

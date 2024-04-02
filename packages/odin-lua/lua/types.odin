package lua

import "core:c"


NUMBER :: c.double
INTEGER :: c.longlong
KCONTEXT :: c.ptrdiff_t
UNSIGNED :: u64

Number :: NUMBER
Integer :: INTEGER
Unsigned :: UNSIGNED
KContext :: KCONTEXT


CFunction :: #type proc "c" (L: ^State ) -> c.int
KFunction :: #type proc "c" (L: ^State , status: c.int , ctx:KContext) -> c.int
Reader :: #type proc "c" (L: ^State , ud: rawptr , sz: ^c.ptrdiff_t) -> cstring
Writer :: #type proc "c" (L: ^State , p: cstring, sz:c.ptrdiff_t , ud:rawptr) -> c.int 
Hook :: #type proc "c" (L: ^State , ar: ^Debug )
Alloc :: #type proc "c" (ud: rawptr, ptr: rawptr, osize:c.ptrdiff_t, nsize:c.ptrdiff_t) -> rawptr

// lua_ident: ^u8;

State :: struct {}


CallInfo :: struct {}

Debug :: struct {
	event : c.int,
	name : cstring,	
	namewhat: cstring,
	what: cstring,
	source: cstring,
	currentline: c.int ,
	linedefined: c.int ,	
	lastlinedefined: c.int ,
	nups: u8,	
	nparams: u8,
	isvararg: i8,
	istailcall: i8,
	short_src: [IDSIZE]i8,
	/* private part */
	i_ci : ^CallInfo ,  
}


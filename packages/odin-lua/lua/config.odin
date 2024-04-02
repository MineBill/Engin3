package lua

@private 
DIGITS :: [?]string {
	0 = "0",
	1 = "1",
	2 = "2", 
	3 = "3",
	4 = "4",
	5 = "5",
	6 = "6",
	7 = "7",
	8 = "8",
	9 = "9",
}

MAX_ODIN_STRLEN :: #config(LUA_MAX_ODIN_STRLEN, 256)
JIT_ENABLED :: #config(LUA_JIT, false)

when  JIT_ENABLED {
	MAJOR_VERSION :: 5
	MINOR_VERSION :: 1
	RELEASE_VERSION :: 4
} else {
	MAJOR_VERSION :: #config(LUA_MAJOR, 5)
	MINOR_VERSION :: #config(LUA_MINOR, 4)
	RELEASE_VERSION :: #config(LUA_RELEASE, 2)
}

// lua defines these as strings. The reverse name was used to define them as integers, which is more useful
VERSION_MAJOR :: DIGITS[MAJOR_VERSION]
VERSION_MINOR :: DIGITS[MINOR_VERSION]
VERSION_RELEASE ::	DIGITS[RELEASE_VERSION]

VERSION_NUM :: MAJOR_VERSION * 100 + MINOR_VERSION
VERSION ::	"Lua " + VERSION_MAJOR + "." + VERSION_MINOR
RELEASE ::	VERSION + "." + VERSION_RELEASE

COPYRIGHT ::	RELEASE + "  Copyright (C) 1994-2018 Lua.org, PUC-Rio"
AUTHORS ::	"R. Ierusalimschy, L. H. de Figueiredo, W. Celes"

SIGNATURE :: "\x1bLua"

when VERSION_NUM <= 500 || VERSION_NUM > 504  {
    #panic("odin-lua is tested to support from version 5.1 to 5.4 - Feel free to submit a PR with more backwards compatibility changes.")
}
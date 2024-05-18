package curl
import "core:dynlib"
//
CURL_BLOB_COPY :: 1
CURL_BLOB_NOCOPY :: 0
curl_blob :: struct {
	data:  [^]u8,
	len:   u32,
	flags: u32, /* bit 0 is defined, the rest are reserved and should be left zeroes */
}
when ODIN_OS == .Linux || ODIN_OS == .Darwin {
	foreign import libcurl "system:curl"
	@(link_prefix = "curl_")
	foreign libcurl {
		//curl.h
		formadd :: proc "c" (httppost: ^^curl_httppost, last_post: ^^curl_httppost, #c_vararg args: ..any) -> CURLFORMcode ---
		formget :: proc "c" (form: ^curl_httppost, arg: rawptr, append: curl_formget_callback) -> int ---
		formfree :: proc "c" (form: ^curl_httppost) ---
		getenv :: proc "c" (variable: cstring) -> cstring ---
		version :: proc "c" () -> cstring ---
		easy_escape :: proc "c" (handle: ^CURL, string: cstring, length: int) -> cstring ---
		escape :: proc "c" (string: cstring, length: int) -> cstring ---
		easy_unescape :: proc "c" (handle: ^CURL, string: cstring, length: int, outlength: ^int) -> cstring ---
		unescape :: proc "c" (string: cstring, length: int) -> cstring ---
		free :: proc "c" (p: rawptr) ---
		global_init :: proc "c" (flags: i32) -> CURLcode ---
		global_init_mem :: proc "c" (flags: i64, m: curl_malloc_callback, f: curl_free_callback, r: curl_realloc_callback, s: curl_strdup_callback, c: curl_calloc_callback) -> CURLcode ---
		global_cleanup :: proc "c" () ---
		//
		global_sslset :: proc "c" (id: curl_sslbackend, name: cstring, avail: ^^^curl_ssl_backend) -> CURLSSLSET ---
		slist_append :: proc "c" (slist: ^curl_slist, str: cstring) -> ^curl_slist ---
		slist_free_all :: proc "c" (slist: ^curl_slist) ---
		getdate :: proc "c" (p: cstring, unused: ^i64) -> i64 ---
		//
		share_init :: proc "c" () -> ^CURLSH ---
		share_setopt :: proc "c" (csh: ^CURLSH, option: CURLSHoption, #c_vararg _args: ..any) -> CURLSHcode ---
		share_cleanup :: proc "c" (csh: ^CURLSH) -> CURLSHcode ---
		//
		version_info :: proc "c" (version: CURLversion) -> ^CURLversion_Info_Data ---
		easy_strerror :: proc "c" (code: CURLcode) -> cstring ---
		share_strerror :: proc "c" (code: CURLSHcode) -> cstring ---
		easy_pause :: proc "c" (handle: ^CURL, bitmask: int) -> CURLcode ---
		//easy.h
		easy_init :: proc "c" () -> ^CURL ---
		easy_setopt :: proc "c" (curl: ^CURL, option: CURLoption, #c_vararg args: ..any) -> CURLcode ---
		easy_perform :: proc "c" (curl: ^CURL) -> CURLcode ---
		easy_cleanup :: proc "c" (curl: ^CURL) ---
		easy_getinfo :: proc "c" (curl: ^CURL, info: CURLINFO, #c_vararg args: ..any) -> CURLcode ---
		easy_duphandle :: proc "c" (curl: ^CURL) -> ^CURL ---
		easy_reset :: proc "c" (curl: ^CURL) ---
		easy_recv :: proc "c" (curl: ^CURL, buffer: [^]u8, buflen: uint, n: ^uint) -> CURLcode ---
		easy_send :: proc "c" (curl: ^CURL, buffer: [^]u8, buflen: uint, n: ^uint) -> CURLcode ---
		easy_upkeep :: proc "c" (curl: ^CURL) -> CURLcode ---
	}
} else when ODIN_OS == .Windows {
	CURL_DLL: dynlib.Library
	//curl.h
	formadd: proc "c" (
		httppost: ^^curl_httppost,
		last_post: ^^curl_httppost,
		#c_vararg args: ..any,
	) -> CURLFORMcode
	formget: proc "c" (form: ^curl_httppost, arg: rawptr, append: curl_formget_callback) -> int
	formfree: proc "c" (form: ^curl_httppost)
	getenv: proc "c" (variable: cstring) -> cstring
	version: proc "c" () -> cstring
	easy_escape: proc "c" (handle: ^CURL, string: cstring, length: int) -> cstring
	escape: proc "c" (string: cstring, length: int) -> cstring
	easy_unescape: proc "c" (
		handle: ^CURL,
		string: cstring,
		length: int,
		outlength: ^int,
	) -> cstring
	unescape: proc "c" (string: cstring, length: int) -> cstring
	free: proc "c" (p: rawptr)
	global_init: proc "c" (flags: i32) -> CURLcode
	global_init_mem: proc "c" (
		flags: i64,
		m: curl_malloc_callback,
		f: curl_free_callback,
		r: curl_realloc_callback,
		s: curl_strdup_callback,
		c: curl_calloc_callback,
	) -> CURLcode
	global_cleanup: proc "c" ()
	//
	global_sslset: proc "c" (
		id: curl_sslbackend,
		name: cstring,
		avail: ^^^curl_ssl_backend,
	) -> CURLSSLSET
	slist_append: proc "c" (slist: ^curl_slist, str: cstring) -> ^curl_slist
	slist_free_all: proc "c" (slist: ^curl_slist)
	getdate: proc "c" (p: cstring, unused: ^i64) -> i64
	//
	share_init: proc "c" () -> ^CURLSH
	share_setopt: proc "c" (
		csh: ^CURLSH,
		option: CURLSHoption,
		#c_vararg _args: ..any,
	) -> CURLSHcode
	share_cleanup: proc "c" (csh: ^CURLSH) -> CURLSHcode
	//
	version_info: proc "c" (version: CURLversion) -> ^CURLversion_Info_Data
	easy_strerror: proc "c" (code: CURLcode) -> cstring
	share_strerror: proc "c" (code: CURLSHcode) -> cstring
	easy_pause: proc "c" (handle: ^CURL, bitmask: int) -> CURLcode
	//easy.h
	easy_init: proc "c" () -> ^CURL
	easy_setopt: proc "c" (curl: ^CURL, option: CURLoption, #c_vararg args: ..any) -> CURLcode
	easy_perform: proc "c" (curl: ^CURL) -> CURLcode
	easy_cleanup: proc "c" (curl: ^CURL)
	easy_getinfo: proc "c" (curl: ^CURL, info: CURLINFO, #c_vararg args: ..any) -> CURLcode
	easy_duphandle: proc "c" (curl: ^CURL) -> ^CURL
	easy_reset: proc "c" (curl: ^CURL)
	easy_recv: proc "c" (curl: ^CURL, buffer: [^]u8, buflen: uint, n: ^uint) -> CURLcode
	easy_send: proc "c" (curl: ^CURL, buffer: [^]u8, buflen: uint, n: ^uint) -> CURLcode
	easy_upkeep: proc "c" (curl: ^CURL) -> CURLcode
	//
	@(init)
	init_dll :: proc() {
		ok: bool
		CURL_DLL, ok = dynlib.load_library("./libcurl-x64.dll")
		assert(ok, "libcurl-x64.dll must be in same directory as the executable.") // todo: allow cfg path?
		//curl.h
		formadd = auto_cast dynlib.symbol_address(CURL_DLL, "curl_formadd")
		formget = auto_cast dynlib.symbol_address(CURL_DLL, "curl_formget")
		formfree = auto_cast dynlib.symbol_address(CURL_DLL, "curl_formfree")
		getenv = auto_cast dynlib.symbol_address(CURL_DLL, "curl_getenv")
		version = auto_cast dynlib.symbol_address(CURL_DLL, "curl_version")
		easy_escape = auto_cast dynlib.symbol_address(CURL_DLL, "curl_easy_escape")
		escape = auto_cast dynlib.symbol_address(CURL_DLL, "curl_escape")
		easy_unescape = auto_cast dynlib.symbol_address(CURL_DLL, "curl_easy_unescape")
		unescape = auto_cast dynlib.symbol_address(CURL_DLL, "curl_unescape")
		free = auto_cast dynlib.symbol_address(CURL_DLL, "curl_free")
		global_init = auto_cast dynlib.symbol_address(CURL_DLL, "curl_global_init")
		global_init_mem = auto_cast dynlib.symbol_address(CURL_DLL, "curl_global_init_mem")
		global_cleanup = auto_cast dynlib.symbol_address(CURL_DLL, "curl_global_cleanup")
		global_sslset = auto_cast dynlib.symbol_address(CURL_DLL, "curl_global_sslset")
		slist_append = auto_cast dynlib.symbol_address(CURL_DLL, "curl_slist_append")
		slist_free_all = auto_cast dynlib.symbol_address(CURL_DLL, "curl_slist_free_all")
		getdate = auto_cast dynlib.symbol_address(CURL_DLL, "curl_getdate")
		share_init = auto_cast dynlib.symbol_address(CURL_DLL, "curl_share_init")
		share_setopt = auto_cast dynlib.symbol_address(CURL_DLL, "curl_share_setopt")
		share_cleanup = auto_cast dynlib.symbol_address(CURL_DLL, "curl_share_cleanup")
		version_info = auto_cast dynlib.symbol_address(CURL_DLL, "curl_version_info")
		easy_strerror = auto_cast dynlib.symbol_address(CURL_DLL, "curl_easy_strerror")
		share_strerror = auto_cast dynlib.symbol_address(CURL_DLL, "curl_share_strerror")
		easy_pause = auto_cast dynlib.symbol_address(CURL_DLL, "curl_easy_pause")
		//easy.h
		easy_init = auto_cast dynlib.symbol_address(CURL_DLL, "curl_easy_init")
		easy_setopt = auto_cast dynlib.symbol_address(CURL_DLL, "curl_easy_setopt")
		easy_perform = auto_cast dynlib.symbol_address(CURL_DLL, "curl_easy_perform")
		easy_cleanup = auto_cast dynlib.symbol_address(CURL_DLL, "curl_easy_cleanup")
		easy_getinfo = auto_cast dynlib.symbol_address(CURL_DLL, "curl_easy_getinfo")
		easy_duphandle = auto_cast dynlib.symbol_address(CURL_DLL, "curl_easy_duphandle")
		easy_reset = auto_cast dynlib.symbol_address(CURL_DLL, "curl_easy_reset")
		easy_recv = auto_cast dynlib.symbol_address(CURL_DLL, "curl_easy_recv")
		easy_send = auto_cast dynlib.symbol_address(CURL_DLL, "curl_easy_send")
		easy_upkeep = auto_cast dynlib.symbol_address(CURL_DLL, "curl_easy_upkeep")

	}
}

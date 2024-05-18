package curl
import "core:fmt"
main :: proc() {
	curl := easy_init()
	fmt.println("end", curl)
}

CURL :: struct {}
CURLSH :: struct {}

SOCKET_BAD :: -1

curl_sslbackend :: enum {
	NONE            = 0,
	OPENSSL         = 1,
	GNUTLS          = 2,
	NSS             = 3,
	OBSOLETE4       = 4, /* Was QSOSSL. */
	GSKIT           = 5,
	POLARSSL        = 6,
	WOLFSSL         = 7,
	SCHANNEL        = 8,
	SECURETRANSPORT = 9,
	AXTLS           = 10, /* never used since 7.63.0 */
	MBEDTLS         = 11,
	MESALINK        = 12,
	BEARSSL         = 13,
	RUSTLS          = 14,
}

CURL_HTTPPOST_FILENAME :: 1 << 0
CURL_HTTPPOST_READFILE :: 1 << 1
CURL_HTTPPOST_PTRNAME :: 1 << 2
CURL_HTTPPOST_PTRCONTENTS :: 1 << 3
CURL_HTTPPOST_BUFFER :: 1 << 4
CURL_HTTPPOST_PTRBUFFER :: 1 << 5
CURL_HTTPPOST_CALLBACK :: 1 << 6
CURL_HTTPPOST_LARGE :: 1 << 7

curl_httppost :: struct {
	next:           ^curl_httppost, // next entry in the list
	name:           cstring, // pointer to allocated name
	namelength:     i32, // length of name length
	contents:       cstring, // pointer to allocated data contents
	contentslength: i32, // length of contents field
	buffer:         cstring, // pointer to allocated buffer contents
	bufferlength:   i32, // length of buffer field
	contenttype:    cstring, // Content-Type
	contentheader:  ^curl_slist, // list of extra headers for this form
	more:           ^curl_httppost, // if one field name has more than one file
	flags:          i32, // as defined below
	showfilename:   cstring, // The file name to show
	userp:          rawptr, // custom pointer used for HTTPPOST_CALLBACK posts
	contentlen:     i32, // alternative length of contents field
}

/* This is a return code for the progress callback that, when returned, will
   signal libcurl to continue executing the default progress function */
CURL_PROGRESSFUNC_CONTINUE :: 0x10000001

/* The maximum receive buffer size configurable via CURLOPT_BUFFERSIZE. */
CURL_MAX_READ_SIZE :: 524288
/* Tests have proven that 20K is a very bad buffer size for uploads on
     Windows, while 16K for some odd reason performed a lot better.
     We do the ifndef check to allow this value to easier be changed at build
     time for those who feel adventurous. The practical minimum is about
     400 bytes since libcurl uses a buffer of this size as a scratch area
     (unrelated to network send operations). */
CURL_MAX_WRITE_SIZE :: 16384
/* The only reason to have a max limit for this is to avoid the risk of a bad
   server feeding libcurl with a never-ending header that will cause reallocs
   infinitely */
CURL_MAX_HTTP_HEADER :: 100 * 1024
/* This is a magic return code for the write callback that, when returned,
   will signal libcurl to pause receiving on the current transfer. */
CURL_WRITEFUNC_PAUSE :: 0x10000001

/* This is the CURLOPT_XFERINFOFUNCTION callback prototype. It was introduced
   in 7.32.0, avoids the use of floating point numbers and provides more
   detailed information. */
curl_xferinfo_callback :: proc "c" (
	clientp: rawptr,
	dltotal: i32,
	dlnow: i32,
	ultotal: i32,
	ulnow: i32,
) -> i32
curl_write_callback :: proc "c" (
	buffer: cstring,
	size: uint,
	nitems: uint,
	outstream: rawptr,
) -> uint
/* This callback will be called when a new resolver request is made */
curl_resolver_start_callback :: proc "c" (
	resolver_state: rawptr,
	reserved: rawptr,
	userdata: rawptr,
) -> i32

/* enumeration of file types */
curlfiletype :: enum {
	FILE = 0,
	DIRECTORY,
	SYMLINK,
	DEVICE_BLOCK,
	DEVICE_CHAR,
	NAMEDPIPE,
	SOCKET,
	DOOR, /* is possible only on Sun Solaris now */
	CURLFILETYPE_UNKNOWN, /* should never occur */
}

CURLFINFOFLAG_KNOWN_FILENAME :: 1 << 0
CURLFINFOFLAG_KNOWN_FILETYPE :: 1 << 1
CURLFINFOFLAG_KNOWN_TIME :: 1 << 2
CURLFINFOFLAG_KNOWN_PERM :: 1 << 3
CURLFINFOFLAG_KNOWN_UID :: 1 << 4
CURLFINFOFLAG_KNOWN_GID :: 1 << 5
CURLFINFOFLAG_KNOWN_SIZE :: 1 << 6
CURLFINFOFLAG_KNOWN_HLINKCOUNT :: 1 << 7

/* Information about a single file, used when doing FTP wildcard matching */
curl_fileinfo :: struct {
	filename:  ^u8,
	filetype:  curlfiletype,
	time:      i64, // 'time_t' 
	perm:      u32,
	uid:       i32,
	gid:       i32,
	size:      i64, // 'curl_off_t' 
	hardlinks: i64,
	strings:   struct {
		time:   ^u8,
		perm:   ^u8,
		user:   ^u8,
		group:  ^u8,
		target: ^u8, // pointer to the target filename of a symlink
	},
	flags:     u32,

	// used internally
	b_data:    ^u8,
	b_size:    uint, // 'size_t' 
	b_used:    uint,
}

/* return codes for CURLOPT_CHUNK_BGN_FUNCTION */
CURL_CHUNK_BGN_FUNC_OK :: 0
CURL_CHUNK_BGN_FUNC_FAIL :: 1 // tell the lib to end the task
CURL_CHUNK_BGN_FUNC_SKIP :: 2 // skip this chunk over

/* if splitting of data transfer is enabled, this callback is called before
   download of an individual chunk started. Note that parameter "remains" works
   only for FTP wildcard downloading (for now), otherwise is not used */
curl_chunk_bgn_callback :: proc "c" (transfer_info: rawptr, ptr: rawptr, remains: i32) -> i64
CURL_CHUNK_END_FUNC_OK :: 0
CURL_CHUNK_END_FUNC_FAIL :: 1 /* tell the lib to end the task */
/* If splitting of data transfer is enabled this callback is called after
   download of an individual chunk finished.
   Note! After this callback was set then it have to be called FOR ALL chunks.
   Even if downloading of this chunk was skipped in CHUNK_BGN_FUNC.
   This is the reason why we don't need "transfer_info" parameter in this
   callback and we are not interested in "remains" parameter too. */
curl_chunk_end_callback :: proc "c" (ptr: rawptr) -> u32


/* return codes for FNMATCHFUNCTION */
CURL_FNMATCHFUNC_MATCH :: 0 /* string corresponds to the pattern */
CURL_FNMATCHFUNC_NOMATCH :: 1 /* pattern doesn't match the string */
CURL_FNMATCHFUNC_FAIL :: 2 /* an error occurred */


curl_fnmatch_callback :: proc "c" (ptr: rawptr, pattern: cstring, str: cstring) -> i32

CURL_SEEKFUNC_OK := 0
CURL_SEEKFUNC_FAIL := 1 // fail the entire transfer
CURL_SEEKFUNC_CANTSEEK := 2 // tell libcurl seeking can't be done, so libcurl might try other means instead

curl_seek_callback :: proc "c" (instream: rawptr, offset: i64, origin: i32) -> i32 // 'curl_off_t' typically translates to 'i64' in Odin

CURL_READFUNC_ABORT := 0x10000000
CURL_READFUNC_PAUSE := 0x10000001

CURL_TRAILERFUNC_OK := 0
CURL_TRAILERFUNC_ABORT := 1

curl_read_callback :: proc "c" (buffer: ^u8, size: uint, nitems: uint, instream: rawptr) -> uint

curl_trailer_callback :: proc "c" (list: ^^curl_slist, userdata: rawptr) -> i32

curlsocktype :: enum {
	IPCXN, /* socket created for a specific IP connection */
	ACCEPT, /* socket created by accept() call */
	LAST, /* never use */
}

/* The return code from the sockopt_callback can signal information back
   to libcurl: */
CURL_SOCKOPT_OK :: 0
CURL_SOCKOPT_ERROR :: 1 // causes libcurl to abort and return CURLE_ABORTED_BY_CALLBACK
CURL_SOCKOPT_ALREADY_CONNECTED :: 2

curl_sockopt_callback :: proc "c" (clientp: rawptr, curlfd: i32, purpose: curlsocktype) -> i32

curl_sockaddr :: struct {
	family:   i32,
	socktype: i32,
	protocol: i32,
	addrlen:  u32, // addrlen was a socklen_t type before 7.18.0 but it turned really ugly and painful on the systems that lack this type
	addr:     SockAddr,
}

SockAddr :: struct {} // TODO/FIXME: better type??

curl_opensocket_callback :: proc "c" (
	clientp: rawptr,
	purpose: curlsocktype,
	address: ^curl_sockaddr,
) -> i32

curl_closesocket_callback :: proc "c" (clientp: rawptr, item: i32) -> i32

curlioerr :: enum i32 {
	CURLIOE_OK, // I/O operation successful
	CURLIOE_UNKNOWNCMD, // command was unknown to callback
	CURLIOE_FAILRESTART, // failed to restart the read
	CURLIOE_LAST, // never use
}

curliocmd :: enum i32 {
	CURLIOCMD_NOP, // no operation
	CURLIOCMD_RESTARTREAD, // restart the read stream from start
	CURLIOCMD_LAST, // never use
}

curl_ioctl_callback :: proc "c" (handle: ^CURL, cmd: i32, clientp: rawptr) -> curlioerr

// The following ::'s are signatures of malloc, free, realloc, strdup and calloc respectively.  
// Function pointers of these types can be passed to the curl_global_init_mem() function to set user defined memory management callback routines.
curl_malloc_callback :: proc "c" (size: uint) -> rawptr
curl_free_callback :: proc "c" (ptr: rawptr)
curl_realloc_callback :: proc "c" (ptr: rawptr, size: uint) -> rawptr
curl_strdup_callback :: proc "c" (str: cstring) -> cstring
curl_calloc_callback :: proc "c" (nmemb: uint, size: uint) -> rawptr

curl_infotype :: enum {
	TEXT = 0,
	HEADER_IN,
	HEADER_OUT,
	DATA_IN,
	DATA_OUT,
	SSL_DATA_IN,
	SSL_DATA_OUT,
	END,
}

curl_debug_callback :: proc "c" (
	handle: ^CURL,
	type: curl_infotype,
	data: cstring,
	size: uint,
	userptr: rawptr,
) -> i32

// This is the CURLOPT_PREREQFUNCTION callback prototype
curl_prereq_callback :: proc "c" (
	clientp: rawptr,
	conn_primary_ip: cstring,
	conn_local_ip: cstring,
	conn_primary_port: i32,
	conn_local_port: i32,
) -> i32

CURL_PREREQFUNC_OK := 0 // Return code for when the pre-request callback has terminated without any errors
CURL_PREREQFUNC_ABORT := 1 // Return code for when the pre-request callback wants to abort the request


/* All possible error codes from all sorts of curl functions. Future versions
   may return other values, stay prepared.

   Always add new return codes last. Never *EVER* remove any. The return
   codes must remain the same!
 */

CURLcode :: enum {
	OK = 0,
	UNSUPPORTED_PROTOCOL, /* 1 */
	FAILED_INIT, /* 2 */
	URL_MALFORMAT, /* 3 */
	NOT_BUILT_IN, /* 4 - [was obsoleted in August 2007 for
                                      7.17.0, reused in April 2011 for 7.21.5] */
	COULDNT_RESOLVE_PROXY, /* 5 */
	COULDNT_RESOLVE_HOST, /* 6 */
	COULDNT_CONNECT, /* 7 */
	WEIRD_SERVER_REPLY, /* 8 */
	REMOTE_ACCESS_DENIED, /* 9 a service was denied by the server
                                      due to lack of access - when login fails
                                      this is not returned. */
	FTP_ACCEPT_FAILED, /* 10 - [was obsoleted in April 2006 for
                                      7.15.4, reused in Dec 2011 for 7.24.0]*/
	FTP_WEIRD_PASS_REPLY, /* 11 */
	FTP_ACCEPT_TIMEOUT, /* 12 - timeout occurred accepting server
                                      [was obsoleted in August 2007 for 7.17.0,
                                      reused in Dec 2011 for 7.24.0]*/
	FTP_WEIRD_PASV_REPLY, /* 13 */
	FTP_WEIRD_227_FORMAT, /* 14 */
	FTP_CANT_GET_HOST, /* 15 */
	HTTP2, /* 16 - A problem in the http2 framing layer.
                                      [was obsoleted in August 2007 for 7.17.0,
                                      reused in July 2014 for 7.38.0] */
	FTP_COULDNT_SET_TYPE, /* 17 */
	PARTIAL_FILE, /* 18 */
	FTP_COULDNT_RETR_FILE, /* 19 */
	OBSOLETE20, /* 20 - NOT USED */
	QUOTE_ERROR, /* 21 - quote command failure */
	HTTP_RETURNED_ERROR, /* 22 */
	WRITE_ERROR, /* 23 */
	OBSOLETE24, /* 24 - NOT USED */
	UPLOAD_FAILED, /* 25 - failed upload "command" */
	READ_ERROR, /* 26 - couldn't open/read from file */
	OUT_OF_MEMORY, /* 27 */
	/* Note: OUT_OF_MEMORY may sometimes indicate a conversion error
             instead of a memory allocation error if CURL_DOES_CONVERSIONS
             is defined
    */
	OPERATION_TIMEDOUT, /* 28 - the timeout time was reached */
	OBSOLETE29, /* 29 - NOT USED */
	FTP_PORT_FAILED, /* 30 - FTP PORT operation failed */
	FTP_COULDNT_USE_REST, /* 31 - the REST command failed */
	OBSOLETE32, /* 32 - NOT USED */
	RANGE_ERROR, /* 33 - RANGE "command" didn't work */
	HTTP_POST_ERROR, /* 34 */
	SSL_CONNECT_ERROR, /* 35 - wrong when connecting with SSL */
	BAD_DOWNLOAD_RESUME, /* 36 - couldn't resume download */
	FILE_COULDNT_READ_FILE, /* 37 */
	LDAP_CANNOT_BIND, /* 38 */
	LDAP_SEARCH_FAILED, /* 39 */
	OBSOLETE40, /* 40 - NOT USED */
	FUNCTION_NOT_FOUND, /* 41 - NOT USED starting with 7.53.0 */
	ABORTED_BY_CALLBACK, /* 42 */
	BAD_FUNCTION_ARGUMENT, /* 43 */
	OBSOLETE44, /* 44 - NOT USED */
	INTERFACE_FAILED, /* 45 - CURLOPT_INTERFACE failed */
	OBSOLETE46, /* 46 - NOT USED */
	TOO_MANY_REDIRECTS, /* 47 - catch endless re-direct loops */
	UNKNOWN_OPTION, /* 48 - User specified an unknown option */
	SETOPT_OPTION_SYNTAX, /* 49 - Malformed setopt option */
	OBSOLETE50, /* 50 - NOT USED */
	OBSOLETE51, /* 51 - NOT USED */
	GOT_NOTHING, /* 52 - when this is a specific error */
	SSL_ENGINE_NOTFOUND, /* 53 - SSL crypto engine not found */
	SSL_ENGINE_SETFAILED, /* 54 - can not set SSL crypto engine as
                                      default */
	SEND_ERROR, /* 55 - failed sending network data */
	RECV_ERROR, /* 56 - failure in receiving network data */
	OBSOLETE57, /* 57 - NOT IN USE */
	SSL_CERTPROBLEM, /* 58 - problem with the local certificate */
	SSL_CIPHER, /* 59 - couldn't use specified cipher */
	PEER_FAILED_VERIFICATION, /* 60 - peer's certificate or fingerprint
                                       wasn't verified fine */
	BAD_CONTENT_ENCODING, /* 61 - Unrecognized/bad encoding */
	LDAP_INVALID_URL, /* 62 - Invalid LDAP URL */
	FILESIZE_EXCEEDED, /* 63 - Maximum file size exceeded */
	USE_SSL_FAILED, /* 64 - Requested FTP SSL level failed */
	SEND_FAIL_REWIND, /* 65 - Sending the data requires a rewind
                                      that failed */
	SSL_ENGINE_INITFAILED, /* 66 - failed to initialise ENGINE */
	LOGIN_DENIED, /* 67 - user, password or similar was not
                                      accepted and we failed to login */
	TFTP_NOTFOUND, /* 68 - file not found on server */
	TFTP_PERM, /* 69 - permission problem on server */
	REMOTE_DISK_FULL, /* 70 - out of disk space on server */
	TFTP_ILLEGAL, /* 71 - Illegal TFTP operation */
	TFTP_UNKNOWNID, /* 72 - Unknown transfer ID */
	REMOTE_FILE_EXISTS, /* 73 - File already exists */
	TFTP_NOSUCHUSER, /* 74 - No such user */
	CONV_FAILED, /* 75 - conversion failed */
	CONV_REQD, /* 76 - caller must register conversion
                                      callbacks using curl_easy_setopt options
                                      CURLOPT_CONV_FROM_NETWORK_FUNCTION,
                                      CURLOPT_CONV_TO_NETWORK_FUNCTION, and
                                      CURLOPT_CONV_FROM_UTF8_FUNCTION */
	SSL_CACERT_BADFILE, /* 77 - could not load CACERT file, missing
                                      or wrong format */
	REMOTE_FILE_NOT_FOUND, /* 78 - remote file not found */
	SSH, /* 79 - error from the SSH layer, somewhat
                                      generic so the error message will be of
                                      interest when this has happened */
	SSL_SHUTDOWN_FAILED, /* 80 - Failed to shut down the SSL
                                      connection */
	AGAIN, /* 81 - socket is not ready for send/recv,
                                      wait till it's ready and try again (Added
                                      in 7.18.2) */
	SSL_CRL_BADFILE, /* 82 - could not load CRL file, missing or
                                      wrong format (Added in 7.19.0) */
	SSL_ISSUER_ERROR, /* 83 - Issuer check failed.  (Added in
                                      7.19.0) */
	FTP_PRET_FAILED, /* 84 - a PRET command failed */
	RTSP_CSEQ_ERROR, /* 85 - mismatch of RTSP CSeq numbers */
	RTSP_SESSION_ERROR, /* 86 - mismatch of RTSP Session Ids */
	FTP_BAD_FILE_LIST, /* 87 - unable to parse FTP file list */
	CHUNK_FAILED, /* 88 - chunk callback reported error */
	NO_CONNECTION_AVAILABLE, /* 89 - No connection available, the
                                      session will be queued */
	SSL_PINNEDPUBKEYNOTMATCH, /* 90 - specified pinned public key did not
                                       match */
	SSL_INVALIDCERTSTATUS, /* 91 - invalid certificate status */
	HTTP2_STREAM, /* 92 - stream error in HTTP/2 framing layer
                                      */
	RECURSIVE_API_CALL, /* 93 - an api function was called from
                                      inside a callback */
	AUTH_ERROR, /* 94 - an authentication function returned an
                                      error */
	HTTP3, /* 95 - An HTTP/3 layer problem */
	QUIC_CONNECT_ERROR, /* 96 - QUIC connection error */
	PROXY, /* 97 - proxy handshake error */
	SSL_CLIENTCERT, /* 98 - client-side certificate required */
	CURL_LAST, /* never use! */
}

/*
 * Proxy error codes. Returned in CURLINFO_PROXY_ERROR if CURLE_PROXY was
 * return for the transfers.
 */
CURLproxycode :: enum {
	OK,
	BAD_ADDRESS_TYPE,
	BAD_VERSION,
	CLOSED,
	GSSAPI,
	GSSAPI_PERMSG,
	GSSAPI_PROTECTION,
	IDENTD,
	IDENTD_DIFFER,
	LONG_HOSTNAME,
	LONG_PASSWD,
	LONG_USER,
	NO_AUTH,
	RECV_ADDRESS,
	RECV_AUTH,
	RECV_CONNECT,
	RECV_REQACK,
	REPLY_ADDRESS_TYPE_NOT_SUPPORTED,
	REPLY_COMMAND_NOT_SUPPORTED,
	REPLY_CONNECTION_REFUSED,
	REPLY_GENERAL_SERVER_FAILURE,
	REPLY_HOST_UNREACHABLE,
	REPLY_NETWORK_UNREACHABLE,
	REPLY_NOT_ALLOWED,
	REPLY_TTL_EXPIRED,
	REPLY_UNASSIGNED,
	REQUEST_FAILED,
	RESOLVE_HOST,
	SEND_AUTH,
	SEND_CONNECT,
	SEND_REQUEST,
	UNKNOWN_FAIL,
	UNKNOWN_MODE,
	USER_REJECTED,
	LAST, /* never use */
}
/* This prototype applies to all conversion callbacks */
curl_conv_callback :: proc "c" (buffer: [^]u8, len: uint) -> CURLcode
curl_ssl_ctx_callback :: proc "c" (curl: ^CURL, ssl_ctx: rawptr, userptr: rawptr) -> CURLcode

curl_proxytype :: enum {
	HTTP            = 0, /* added in 7.10, new in 7.19.4 default is to use CONNECT HTTP/1.1 */
	HTTP_1_0        = 1, /* added in 7.19.4, force to use CONNECT HTTP/1.0  */
	HTTPS           = 2, /* added in 7.52.0 */
	SOCKS4          = 4, /* support added in 7.15.2, enum existed already in 7.10 */
	SOCKS5          = 5, /* added in 7.10 */
	SOCKS4A         = 6, /* added in 7.18.0 */
	SOCKS5_HOSTNAME = 7, /* Use the SOCKS5 protocol but pass along the
                                     host name rather than the IP address. added in 7.18.0 */
}

/*
 * Bitmasks for CURLOPT_HTTPAUTH and CURLOPT_PROXYAUTH options:
 *
 * CURLAUTH_NONE         - No HTTP authentication
 * CURLAUTH_BASIC        - HTTP Basic authentication (default)
 * CURLAUTH_DIGEST       - HTTP Digest authentication
 * CURLAUTH_NEGOTIATE    - HTTP Negotiate (SPNEGO) authentication
 * CURLAUTH_GSSNEGOTIATE - Alias for CURLAUTH_NEGOTIATE (deprecated)
 * CURLAUTH_NTLM         - HTTP NTLM authentication
 * CURLAUTH_DIGEST_IE    - HTTP Digest authentication with IE flavour
 * CURLAUTH_NTLM_WB      - HTTP NTLM authentication delegated to winbind helper
 * CURLAUTH_BEARER       - HTTP Bearer token authentication
 * CURLAUTH_ONLY         - Use together with a single other type to force no
 *                         authentication or just that single type
 * CURLAUTH_ANY          - All fine types set
 * CURLAUTH_ANYSAFE      - All fine types except Basic
 */
CURLAUTH_NONE: u32 : 0
CURLAUTH_BASIC: u32 : 1 << 0
CURLAUTH_DIGEST: u32 : 1 << 1
CURLAUTH_NEGOTIATE: u32 : 1 << 2
/* Deprecated since the advent of CURLAUTH_NEGOTIATE */
CURLAUTH_GSSNEGOTIATE := CURLAUTH_NEGOTIATE
/* Used for CURLOPT_SOCKS5_AUTH to stay terminologically correct */
CURLAUTH_GSSAPI := CURLAUTH_NEGOTIATE
CURLAUTH_NTLM: u32 : 1 << 3
CURLAUTH_DIGEST_IE: u32 : 1 << 4
CURLAUTH_NTLM_WB: u32 : 1 << 5
CURLAUTH_BEARER: u32 : 1 << 6
CURLAUTH_AWS_SIGV4: u32 : 1 << 7
CURLAUTH_ONLY: u32 : 1 << 31
CURLAUTH_ANY: u32 : ~CURLAUTH_DIGEST_IE
CURLAUTH_ANYSAFE: u32 : ~(CURLAUTH_BASIC | CURLAUTH_DIGEST_IE)

CURLSSH_AUTH_ANY :: ~u32(0) /* all types supported by the server */
CURLSSH_AUTH_NONE :: 0 /* none allowed, silly but complete */
CURLSSH_AUTH_PUBLICKEY :: 1 << 0 /* public/private key files */
CURLSSH_AUTH_PASSWORD :: 1 << 1 /* password */
CURLSSH_AUTH_HOST :: 1 << 2 /* host key files */
CURLSSH_AUTH_KEYBOARD :: 1 << 3 /* keyboard interactive */
CURLSSH_AUTH_AGENT :: 1 << 4 /* agent (ssh-agent, pageant...) */
CURLSSH_AUTH_GSSAPI :: 1 << 5 /* gssapi (kerberos, ...) */
CURLSSH_AUTH_DEFAULT := CURLSSH_AUTH_ANY

CURLGSSAPI_DELEGATION_NONE :: 0 /* no delegation (default) */
CURLGSSAPI_DELEGATION_POLICY_FLAG :: 1 << 0 /* if permitted by policy */
CURLGSSAPI_DELEGATION_FLAG :: 1 << 1 /* delegate always */

CURL_ERROR_SIZE :: 256

curl_khtype :: enum {
	UNKNOWN,
	RSA1,
	RSA,
	DSS,
	ECDSA,
	ED25519,
}

curl_khkey :: struct {
	key:     [^]u8, /* points to a null-terminated string encoded with base64 if len is zero, otherwise to the "raw" data */
	len:     uint,
	keytype: curl_khtype,
}

/* this is the set of return values expected from the curl_sshkeycallback
   callback */
curl_khstat :: enum {
	FINE_ADD_TO_FILE,
	FINE,
	REJECT, /* reject the connection, return an error */
	DEFER, /* do not accept it, but we can't answer right now so
                          this causes a CURLE_DEFER error but otherwise the
                          connection will be left intact etc */
	FINE_REPLACE, /* accept and replace the wrong key*/
	LAST, /* not for use, only a marker for last-in-list */
}

/* this is the set of status codes pass in to the callback */
curl_khmatch :: enum {
	OK, /* match */
	MISMATCH, /* host found, key mismatch! */
	MISSING, /* no matching host/key found */
	LAST, /* not for use, only a marker for last-in-list */
}

curl_sshkeycallback: proc "c" (
	easy: ^CURL,
	knownkey: ^curl_khkey,
	foundkey: ^curl_khkey,
	khmatch: curl_khmatch,
	clientp: rawptr,
)

/* parameter for the CURLOPT_USE_SSL option */
curl_usessl :: enum {
	NONE, /* do not attempt to use SSL */
	TRY, /* try using SSL, proceed anyway otherwise */
	CONTROL, /* SSL for the control connection or fail */
	ALL, /* SSL for all communication or fail */
	LAST, /* not an option, never use */
}

/* Definition of bits for the CURLOPT_SSL_OPTIONS argument: */

/* - ALLOW_BEAST tells libcurl to allow the BEAST SSL vulnerability in the
     name of improving interoperability with older servers. Some SSL libraries
     have introduced work-arounds for this flaw but those work-arounds sometimes
     make the SSL communication fail. To regain functionality with those broken
     servers, a user can this way allow the vulnerability back. */
CURLSSLOPT_ALLOW_BEAST :: 1 << 0

/* - NO_REVOKE tells libcurl to disable certificate revocation checks for those
     SSL backends where such behavior is present. */
CURLSSLOPT_NO_REVOKE :: 1 << 1

/* - NO_PARTIALCHAIN tells libcurl to *NOT* accept a partial certificate chain
     if possible. The OpenSSL backend has this ability. */
CURLSSLOPT_NO_PARTIALCHAIN :: 1 << 2

/* - REVOKE_BEST_EFFORT tells libcurl to ignore certificate revocation offline
     checks and ignore missing revocation list for those SSL backends where such
     behavior is present. */
CURLSSLOPT_REVOKE_BEST_EFFORT :: 1 << 3

/* - CURLSSLOPT_NATIVE_CA tells libcurl to use standard certificate store of
     operating system. Currently implemented under MS-Windows. */
CURLSSLOPT_NATIVE_CA :: 1 << 4

/* - CURLSSLOPT_AUTO_CLIENT_CERT tells libcurl to automatically locate and use
     a client certificate for authentication. (Schannel) */
CURLSSLOPT_AUTO_CLIENT_CERT :: 1 << 5

/* The default connection attempt delay in milliseconds for happy eyeballs.
     CURLOPT_HAPPY_EYEBALLS_TIMEOUT_MS.3 and happy-eyeballs-timeout-ms.d document
     this value, keep them in sync. */
CURL_HET_DEFAULT: i32 : 200

/* The default connection upkeep interval in milliseconds. */
CURL_UPKEEP_INTERVAL_DEFAULT: i32 : 60000

/* parameter for the CURLOPT_FTP_SSL_CCC option */
curl_ftpccc :: enum {
	NONE, /* do not send CCC */
	PASSIVE, /* Let the server initiate the shutdown */
	ACTIVE, /* Initiate the shutdown */
	LAST, /* not an option, never use */
}

/* parameter for the CURLOPT_FTPSSLAUTH option */
curl_ftpauth :: enum {
	DEFAULT, /* let libcurl decide */
	SSL, /* use "AUTH SSL" */
	TLS, /* use "AUTH TLS" */
	LAST, /* not an option, never use */
}

/* parameter for the CURLOPT_FTP_CREATE_MISSING_DIRS option */
curl_ftpcreatedir :: enum {
	CURLFTP_CREATE_DIR_NONE, /* do NOT create missing dirs! */
	CURLFTP_CREATE_DIR, /* (FTP/SFTP) if CWD fails, try MKD and then CWD
                                 again if MKD succeeded, for SFTP this does
                                 similar magic */
	CURLFTP_CREATE_DIR_RETRY, /* (FTP only) if CWD fails, try MKD and then CWD
                                 again even if MKD failed! */
	CURLFTP_CREATE_DIR_LAST, /* not an option, never use */
}

/* parameter for the CURLOPT_FTP_FILEMETHOD option */
curl_ftpmethod :: enum {
	DEFAULT, /* let libcurl pick */
	MULTICWD, /* single CWD operation for each path part */
	NOCWD, /* no CWD at all */
	SINGLECWD, /* one CWD to full dir, then work on file */
	LAST, /* not an option, never use */
}

CURLHEADER_UNIFIED :: 0
CURLHEADER_SEPARATE :: 1 << 0

CURLALTSVC_READONLYFILE :: 1 << 2
CURLALTSVC_H1 :: 1 << 3
CURLALTSVC_H2 :: 1 << 4
CURLALTSVC_H3 :: 1 << 5

curl_hstsentry :: struct {
	name:              ^u8,
	namelen:           uint,
	includeSubDomains: u32, // unsigned int includeSubDomains:1;
	expire:            [18]u8, /* YYYYMMDD HH:MM:SS [null-terminated] */
}

curl_index :: struct {
	index: uint, // the provided entry's "index" or count
	total: uint, // total number of entries to save
}

CURLSTScode :: enum {
	OK,
	DONE,
	FAIL,
}

curl_hstsread_callback :: proc(easy: ^CURL, e: ^curl_hstsentry, userp: rawptr) -> CURLSTScode
curl_hstswrite_callback :: proc(
	easy: ^CURL,
	e: ^curl_hstsentry,
	i: ^curl_index,
	userp: rawptr,
) -> CURLSTScode
/* CURLHSTS_* are bits for the CURLOPT_HSTS option */
CURLHSTS_ENABLE: i32 : 1 << 0
CURLHSTS_READONLYFILE: i32 : 1 << 1
/* CURLPROTO_ defines are for the CURLOPT_*PROTOCOLS options */

CURLPROTO_HTTP :: 1 << 0
CURLPROTO_HTTPS :: 1 << 1
CURLPROTO_FTP :: 1 << 2
CURLPROTO_FTPS :: 1 << 3
CURLPROTO_SCP :: 1 << 4
CURLPROTO_SFTP :: 1 << 5
CURLPROTO_TELNET :: 1 << 6
CURLPROTO_LDAP :: 1 << 7
CURLPROTO_LDAPS :: 1 << 8
CURLPROTO_DICT :: 1 << 9
CURLPROTO_FILE :: 1 << 10
CURLPROTO_TFTP :: 1 << 11
CURLPROTO_IMAP :: 1 << 12
CURLPROTO_IMAPS :: 1 << 13
CURLPROTO_POP3 :: 1 << 14
CURLPROTO_POP3S :: 1 << 15
CURLPROTO_SMTP :: 1 << 16
CURLPROTO_SMTPS :: 1 << 17
CURLPROTO_RTSP :: 1 << 18
CURLPROTO_RTMP :: 1 << 19
CURLPROTO_RTMPT :: 1 << 20
CURLPROTO_RTMPE :: 1 << 21
CURLPROTO_RTMPTE :: 1 << 22
CURLPROTO_RTMPS :: 1 << 23
CURLPROTO_RTMPTS :: 1 << 24
CURLPROTO_GOPHER :: 1 << 25
CURLPROTO_SMB :: 1 << 26
CURLPROTO_SMBS :: 1 << 27
CURLPROTO_MQTT :: 1 << 28
CURLPROTO_GOPHERS :: 1 << 29
CURLPROTO_ALL :: ~u32(0) // enable everything

CURLOPTTYPE_LONG :: 0
CURLOPTTYPE_OBJECTPOINT :: 10000
CURLOPTTYPE_FUNCTIONPOINT :: 20000
CURLOPTTYPE_OFF_T :: 30000
CURLOPTTYPE_BLOB :: 40000

/* 'char *' argument to a string with a trailing zero */
CURLOPTTYPE_STRINGPOINT :: CURLOPTTYPE_OBJECTPOINT
/* 'struct curl_slist *' argument */
CURLOPTTYPE_SLISTPOINT :: CURLOPTTYPE_OBJECTPOINT
/* 'void *' argument passed untouched to callback */
CURLOPTTYPE_CBPOINT :: CURLOPTTYPE_OBJECTPOINT
/* 'long' argument with a set of values/bitmask */
CURLOPTTYPE_VALUES :: CURLOPTTYPE_LONG

CURLoption :: enum {
	WRITEDATA = CURLOPTTYPE_CBPOINT + 1,
	URL = CURLOPTTYPE_STRINGPOINT + 2,
	PORT = CURLOPTTYPE_LONG + 3,
	PROXY = CURLOPTTYPE_STRINGPOINT + 4,
	USERPWD = CURLOPTTYPE_STRINGPOINT + 5,
	PROXYUSERPWD = CURLOPTTYPE_STRINGPOINT + 6,
	RANGE = CURLOPTTYPE_STRINGPOINT + 7,
	READDATA = CURLOPTTYPE_CBPOINT + 9,
	ERRORBUFFER = CURLOPTTYPE_OBJECTPOINT + 10,
	WRITEFUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 11,
	READFUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 12,
	TIMEOUT = CURLOPTTYPE_LONG + 13,
	INFILESIZE = CURLOPTTYPE_LONG + 14,
	POSTFIELDS = CURLOPTTYPE_OBJECTPOINT + 15,
	REFERER = CURLOPTTYPE_STRINGPOINT + 16,
	FTPPORT = CURLOPTTYPE_STRINGPOINT + 17,
	USERAGENT = CURLOPTTYPE_STRINGPOINT + 18,
	LOW_SPEED_LIMIT = CURLOPTTYPE_LONG + 19,
	LOW_SPEED_TIME = CURLOPTTYPE_LONG + 20,
	RESUME_FROM = CURLOPTTYPE_LONG + 21,
	COOKIE = CURLOPTTYPE_STRINGPOINT + 22,
	HTTPHEADER = CURLOPTTYPE_SLISTPOINT + 23,
	HTTPPOST = CURLOPTTYPE_OBJECTPOINT + 24,
	SSLCERT = CURLOPTTYPE_STRINGPOINT + 25,
	KEYPASSWD = CURLOPTTYPE_STRINGPOINT + 26,
	CRLF = CURLOPTTYPE_LONG + 27,
	QUOTE = CURLOPTTYPE_SLISTPOINT + 28,
	HEADERDATA = CURLOPTTYPE_CBPOINT + 29,
	COOKIEFILE = CURLOPTTYPE_STRINGPOINT + 31,
	SSLVERSION = CURLOPTTYPE_VALUES + 32,
	TIMECONDITION = CURLOPTTYPE_VALUES + 33,
	TIMEVALUE = CURLOPTTYPE_LONG + 34,
	CUSTOMREQUEST = CURLOPTTYPE_STRINGPOINT + 36,
	STDERR = CURLOPTTYPE_OBJECTPOINT + 37,
	POSTQUOTE = CURLOPTTYPE_SLISTPOINT + 39,
	VERBOSE = CURLOPTTYPE_LONG + 41,
	HEADER = CURLOPTTYPE_LONG + 42,
	NOPROGRESS = CURLOPTTYPE_LONG + 43,
	NOBODY = CURLOPTTYPE_LONG + 44,
	FAILONERROR = CURLOPTTYPE_LONG + 45,
	UPLOAD = CURLOPTTYPE_LONG + 46,
	POST = CURLOPTTYPE_LONG + 47,
	DIRLISTONLY = CURLOPTTYPE_LONG + 48,
	APPEND = CURLOPTTYPE_LONG + 50,
	NETRC = CURLOPTTYPE_VALUES + 51,
	FOLLOWLOCATION = CURLOPTTYPE_LONG + 52,
	TRANSFERTEXT = CURLOPTTYPE_LONG + 53,
	PUT = CURLOPTTYPE_LONG + 54,
	XFERINFODATA = CURLOPTTYPE_CBPOINT + 57,
	PROGRESSDATA = CURLOPTTYPE_CBPOINT + 57, //COPY .XFERINFODATA
	AUTOREFERER = CURLOPTTYPE_LONG + 58,
	PROXYPORT = CURLOPTTYPE_LONG + 59,
	POSTFIELDSIZE = CURLOPTTYPE_LONG + 60,
	HTTPPROXYTUNNEL = CURLOPTTYPE_LONG + 61,
	INTERFACE = CURLOPTTYPE_STRINGPOINT + 62,
	KRBLEVEL = CURLOPTTYPE_STRINGPOINT + 63,
	SSL_VERIFYPEER = CURLOPTTYPE_LONG + 64,
	CAINFO = CURLOPTTYPE_STRINGPOINT + 65,
	MAXREDIRS = CURLOPTTYPE_LONG + 68,
	FILETIME = CURLOPTTYPE_LONG + 69,
	TELNETOPTIONS = CURLOPTTYPE_SLISTPOINT + 70,
	MAXCONNECTS = CURLOPTTYPE_LONG + 71,
	FRESH_CONNECT = CURLOPTTYPE_LONG + 74,
	FORBID_REUSE = CURLOPTTYPE_LONG + 75,
	RANDOM_FILE = CURLOPTTYPE_STRINGPOINT + 76,
	EGDSOCKET = CURLOPTTYPE_STRINGPOINT + 77,
	CONNECTTIMEOUT = CURLOPTTYPE_LONG + 78,
	HEADERFUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 79,
	HTTPGET = CURLOPTTYPE_LONG + 80,
	SSL_VERIFYHOST = CURLOPTTYPE_LONG + 81,
	COOKIEJAR = CURLOPTTYPE_STRINGPOINT + 82,
	SSL_CIPHER_LIST = CURLOPTTYPE_STRINGPOINT + 83,
	HTTP_VERSION = CURLOPTTYPE_VALUES + 84,
	FTP_USE_EPSV = CURLOPTTYPE_LONG + 85,
	SSLCERTTYPE = CURLOPTTYPE_STRINGPOINT + 86,
	SSLKEY = CURLOPTTYPE_STRINGPOINT + 87,
	SSLKEYTYPE = CURLOPTTYPE_STRINGPOINT + 88,
	SSLENGINE = CURLOPTTYPE_STRINGPOINT + 89,
	SSLENGINE_DEFAULT = CURLOPTTYPE_LONG + 90,
	DNS_USE_GLOBAL_CACHE = CURLOPTTYPE_LONG + 91,
	DNS_CACHE_TIMEOUT = CURLOPTTYPE_LONG + 92,
	PREQUOTE = CURLOPTTYPE_SLISTPOINT + 93,
	DEBUGFUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 94,
	DEBUGDATA = CURLOPTTYPE_CBPOINT + 95,
	COOKIESESSION = CURLOPTTYPE_LONG + 96,
	CAPATH = CURLOPTTYPE_STRINGPOINT + 97,
	BUFFERSIZE = CURLOPTTYPE_LONG + 98,
	NOSIGNAL = CURLOPTTYPE_LONG + 99,
	SHARE = CURLOPTTYPE_OBJECTPOINT + 100,
	PROXYTYPE = CURLOPTTYPE_VALUES + 101,
	ACCEPT_ENCODING = CURLOPTTYPE_STRINGPOINT + 102,
	PRIVATE = CURLOPTTYPE_OBJECTPOINT + 103,
	HTTP200ALIASES = CURLOPTTYPE_SLISTPOINT + 104,
	UNRESTRICTED_AUTH = CURLOPTTYPE_LONG + 105,
	FTP_USE_EPRT = CURLOPTTYPE_LONG + 106,
	HTTPAUTH = CURLOPTTYPE_VALUES + 107,
	SSL_CTX_FUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 108,
	SSL_CTX_DATA = CURLOPTTYPE_CBPOINT + 109,
	FTP_CREATE_MISSING_DIRS = CURLOPTTYPE_LONG + 110,
	PROXYAUTH = CURLOPTTYPE_VALUES + 111,
	FTP_RESPONSE_TIMEOUT = CURLOPTTYPE_LONG + 112,
	CURLOPT_SERVER_RESPONSE_TIMEOUT = CURLOPTTYPE_LONG + 112, //CURLOPT_FTP_RESPONSE_TIMEOUT COPY
	IPRESOLVE = CURLOPTTYPE_VALUES + 113,
	MAXFILESIZE = CURLOPTTYPE_LONG + 114,
	INFILESIZE_LARGE = CURLOPTTYPE_OFF_T + 115,
	RESUME_FROM_LARGE = CURLOPTTYPE_OFF_T + 116,
	MAXFILESIZE_LARGE = CURLOPTTYPE_OFF_T + 117,
	NETRC_FILE = CURLOPTTYPE_STRINGPOINT + 118,
	USE_SSL = CURLOPTTYPE_VALUES + 119,
	POSTFIELDSIZE_LARGE = CURLOPTTYPE_OFF_T + 120,
	TCP_NODELAY = CURLOPTTYPE_LONG + 121,
	FTPSSLAUTH = CURLOPTTYPE_VALUES + 129,
	IOCTLFUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 130,
	IOCTLDATA = CURLOPTTYPE_CBPOINT + 131,
	FTP_ACCOUNT = CURLOPTTYPE_STRINGPOINT + 134,
	COOKIELIST = CURLOPTTYPE_STRINGPOINT + 135,
	IGNORE_CONTENT_LENGTH = CURLOPTTYPE_LONG + 136,
	FTP_SKIP_PASV_IP = CURLOPTTYPE_LONG + 137,
	FTP_FILEMETHOD = CURLOPTTYPE_VALUES + 138,
	LOCALPORT = CURLOPTTYPE_LONG + 139,
	LOCALPORTRANGE = CURLOPTTYPE_LONG + 140,
	CONNECT_ONLY = CURLOPTTYPE_LONG + 141,
	CONV_FROM_NETWORK_FUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 142,
	CONV_TO_NETWORK_FUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 143,
	CONV_FROM_UTF8_FUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 144,
	MAX_SEND_SPEED_LARGE = CURLOPTTYPE_OFF_T + 145,
	MAX_RECV_SPEED_LARGE = CURLOPTTYPE_OFF_T + 146,
	FTP_ALTERNATIVE_TO_USER = CURLOPTTYPE_STRINGPOINT + 147,
	SOCKOPTFUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 148,
	SOCKOPTDATA = CURLOPTTYPE_CBPOINT + 149,
	SSL_SESSIONID_CACHE = CURLOPTTYPE_LONG + 150,
	SSH_AUTH_TYPES = CURLOPTTYPE_VALUES + 151,
	SSH_PUBLIC_KEYFILE = CURLOPTTYPE_STRINGPOINT + 152,
	SSH_PRIVATE_KEYFILE = CURLOPTTYPE_STRINGPOINT + 153,
	FTP_SSL_CCC = CURLOPTTYPE_LONG + 154,
	TIMEOUT_MS = CURLOPTTYPE_LONG + 155,
	CONNECTTIMEOUT_MS = CURLOPTTYPE_LONG + 156,
	HTTP_TRANSFER_DECODING = CURLOPTTYPE_LONG + 157,
	HTTP_CONTENT_DECODING = CURLOPTTYPE_LONG + 158,
	NEW_FILE_PERMS = CURLOPTTYPE_LONG + 159,
	NEW_DIRECTORY_PERMS = CURLOPTTYPE_LONG + 160,
	POSTREDIR = CURLOPTTYPE_VALUES + 161,
	SSH_HOST_PUBLIC_KEY_MD5 = CURLOPTTYPE_STRINGPOINT + 162,
	OPENSOCKETFUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 163,
	OPENSOCKETDATA = CURLOPTTYPE_CBPOINT + 164,
	COPYPOSTFIELDS = CURLOPTTYPE_OBJECTPOINT + 165,
	PROXY_TRANSFER_MODE = CURLOPTTYPE_LONG + 166,
	SEEKFUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 167,
	SEEKDATA = CURLOPTTYPE_CBPOINT + 168,
	CRLFILE = CURLOPTTYPE_STRINGPOINT + 169,
	ISSUERCERT = CURLOPTTYPE_STRINGPOINT + 170,
	ADDRESS_SCOPE = CURLOPTTYPE_LONG + 171,
	CERTINFO = CURLOPTTYPE_LONG + 172,
	USERNAME = CURLOPTTYPE_STRINGPOINT + 173,
	PASSWORD = CURLOPTTYPE_STRINGPOINT + 174,
	PROXYUSERNAME = CURLOPTTYPE_STRINGPOINT + 175,
	PROXYPASSWORD = CURLOPTTYPE_STRINGPOINT + 176,
	NOPROXY = CURLOPTTYPE_STRINGPOINT + 177,
	TFTP_BLKSIZE = CURLOPTTYPE_LONG + 178,
	SOCKS5_GSSAPI_NEC = CURLOPTTYPE_LONG + 180,
	PROTOCOLS = CURLOPTTYPE_LONG + 181,
	REDIR_PROTOCOLS = CURLOPTTYPE_LONG + 182,
	SSH_KNOWNHOSTS = CURLOPTTYPE_STRINGPOINT + 183,
	SSH_KEYFUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 184,
	SSH_KEYDATA = CURLOPTTYPE_CBPOINT + 185,
	MAIL_FROM = CURLOPTTYPE_STRINGPOINT + 186,
	MAIL_RCPT = CURLOPTTYPE_SLISTPOINT + 187,
	FTP_USE_PRET = CURLOPTTYPE_LONG + 188,
	RTSP_REQUEST = CURLOPTTYPE_VALUES + 189,
	RTSP_SESSION_ID = CURLOPTTYPE_STRINGPOINT + 190,
	RTSP_STREAM_URI = CURLOPTTYPE_STRINGPOINT + 191,
	RTSP_TRANSPORT = CURLOPTTYPE_STRINGPOINT + 192,
	RTSP_CLIENT_CSEQ = CURLOPTTYPE_LONG + 193,
	RTSP_SERVER_CSEQ = CURLOPTTYPE_LONG + 194,
	INTERLEAVEDATA = CURLOPTTYPE_CBPOINT + 195,
	INTERLEAVEFUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 196,
	WILDCARDMATCH = CURLOPTTYPE_LONG + 197,
	CHUNK_BGN_FUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 198,
	CHUNK_END_FUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 199,
	FNMATCH_FUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 200,
	CHUNK_DATA = CURLOPTTYPE_CBPOINT + 201,
	FNMATCH_DATA = CURLOPTTYPE_CBPOINT + 202,
	RESOLVE = CURLOPTTYPE_SLISTPOINT + 203,
	TLSAUTH_USERNAME = CURLOPTTYPE_STRINGPOINT + 204,
	TLSAUTH_PASSWORD = CURLOPTTYPE_STRINGPOINT + 205,
	TLSAUTH_TYPE = CURLOPTTYPE_STRINGPOINT + 206,
	TRANSFER_ENCODING = CURLOPTTYPE_LONG + 207,
	CLOSESOCKETFUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 208,
	CLOSESOCKETDATA = CURLOPTTYPE_CBPOINT + 209,
	GSSAPI_DELEGATION = CURLOPTTYPE_VALUES + 210,
	DNS_SERVERS = CURLOPTTYPE_STRINGPOINT + 211,
	ACCEPTTIMEOUT_MS = CURLOPTTYPE_LONG + 212,
	TCP_KEEPALIVE = CURLOPTTYPE_LONG + 213,
	TCP_KEEPIDLE = CURLOPTTYPE_LONG + 214,
	TCP_KEEPINTVL = CURLOPTTYPE_LONG + 215,
	SSL_OPTIONS = CURLOPTTYPE_VALUES + 216,
	MAIL_AUTH = CURLOPTTYPE_STRINGPOINT + 217,
	SASL_IR = CURLOPTTYPE_LONG + 218,
	XFERINFOFUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 219,
	XOAUTH2_BEARER = CURLOPTTYPE_STRINGPOINT + 220,
	DNS_INTERFACE = CURLOPTTYPE_STRINGPOINT + 221,
	DNS_LOCAL_IP4 = CURLOPTTYPE_STRINGPOINT + 222,
	DNS_LOCAL_IP6 = CURLOPTTYPE_STRINGPOINT + 223,
	LOGIN_OPTIONS = CURLOPTTYPE_STRINGPOINT + 224,
	SSL_ENABLE_NPN = CURLOPTTYPE_LONG + 225,
	SSL_ENABLE_ALPN = CURLOPTTYPE_LONG + 226,
	EXPECT_100_TIMEOUT_MS = CURLOPTTYPE_LONG + 227,
	PROXYHEADER = CURLOPTTYPE_SLISTPOINT + 228,
	HEADEROPT = CURLOPTTYPE_VALUES + 229,
	PINNEDPUBLICKEY = CURLOPTTYPE_STRINGPOINT + 230,
	UNIX_SOCKET_PATH = CURLOPTTYPE_STRINGPOINT + 231,
	SSL_VERIFYSTATUS = CURLOPTTYPE_LONG + 232,
	SSL_FALSESTART = CURLOPTTYPE_LONG + 233,
	PATH_AS_IS = CURLOPTTYPE_LONG + 234,
	PROXY_SERVICE_NAME = CURLOPTTYPE_STRINGPOINT + 235,
	SERVICE_NAME = CURLOPTTYPE_STRINGPOINT + 236,
	PIPEWAIT = CURLOPTTYPE_LONG + 237,
	DEFAULT_PROTOCOL = CURLOPTTYPE_STRINGPOINT + 238,
	STREAM_WEIGHT = CURLOPTTYPE_LONG + 239,
	STREAM_DEPENDS = CURLOPTTYPE_OBJECTPOINT + 240,
	STREAM_DEPENDS_E = CURLOPTTYPE_OBJECTPOINT + 241,
	TFTP_NO_OPTIONS = CURLOPTTYPE_LONG + 242,
	CONNECT_TO = CURLOPTTYPE_SLISTPOINT + 243,
	TCP_FASTOPEN = CURLOPTTYPE_LONG + 244,
	KEEP_SENDING_ON_ERROR = CURLOPTTYPE_LONG + 245,
	PROXY_CAINFO = CURLOPTTYPE_STRINGPOINT + 246,
	PROXY_CAPATH = CURLOPTTYPE_STRINGPOINT + 247,
	PROXY_SSL_VERIFYPEER = CURLOPTTYPE_LONG + 248,
	PROXY_SSL_VERIFYHOST = CURLOPTTYPE_LONG + 249,
	PROXY_SSLVERSION = CURLOPTTYPE_VALUES + 250,
	PROXY_TLSAUTH_USERNAME = CURLOPTTYPE_STRINGPOINT + 251,
	PROXY_TLSAUTH_PASSWORD = CURLOPTTYPE_STRINGPOINT + 252,
	PROXY_TLSAUTH_TYPE = CURLOPTTYPE_STRINGPOINT + 253,
	PROXY_SSLCERT = CURLOPTTYPE_STRINGPOINT + 254,
	PROXY_SSLCERTTYPE = CURLOPTTYPE_STRINGPOINT + 255,
	PROXY_SSLKEY = CURLOPTTYPE_STRINGPOINT + 256,
	PROXY_SSLKEYTYPE = CURLOPTTYPE_STRINGPOINT + 257,
	PROXY_KEYPASSWD = CURLOPTTYPE_STRINGPOINT + 258,
	PROXY_SSL_CIPHER_LIST = CURLOPTTYPE_STRINGPOINT + 259,
	PROXY_CRLFILE = CURLOPTTYPE_STRINGPOINT + 260,
	PROXY_SSL_OPTIONS = CURLOPTTYPE_LONG + 261,
	PRE_PROXY = CURLOPTTYPE_STRINGPOINT + 262,
	PROXY_PINNEDPUBLICKEY = CURLOPTTYPE_STRINGPOINT + 263,
	ABSTRACT_UNIX_SOCKET = CURLOPTTYPE_STRINGPOINT + 264,
	SUPPRESS_CONNECT_HEADERS = CURLOPTTYPE_LONG + 265,
	REQUEST_TARGET = CURLOPTTYPE_STRINGPOINT + 266,
	SOCKS5_AUTH = CURLOPTTYPE_LONG + 267,
	SSH_COMPRESSION = CURLOPTTYPE_LONG + 268,
	MIMEPOST = CURLOPTTYPE_OBJECTPOINT + 269,
	TIMEVALUE_LARGE = CURLOPTTYPE_OFF_T + 270,
	HAPPY_EYEBALLS_TIMEOUT_MS = CURLOPTTYPE_LONG + 271,
	RESOLVER_START_FUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 272,
	RESOLVER_START_DATA = CURLOPTTYPE_CBPOINT + 273,
	HAPROXYPROTOCOL = CURLOPTTYPE_LONG + 274,
	DNS_SHUFFLE_ADDRESSES = CURLOPTTYPE_LONG + 275,
	TLS13_CIPHERS = CURLOPTTYPE_STRINGPOINT + 276,
	PROXY_TLS13_CIPHERS = CURLOPTTYPE_STRINGPOINT + 277,
	DISALLOW_USERNAME_IN_URL = CURLOPTTYPE_LONG + 278,
	DOH_URL = CURLOPTTYPE_STRINGPOINT + 279,
	UPLOAD_BUFFERSIZE = CURLOPTTYPE_LONG + 280,
	UPKEEP_INTERVAL_MS = CURLOPTTYPE_LONG + 281,
	CURLU = CURLOPTTYPE_OBJECTPOINT + 282,
	TRAILERFUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 283,
	TRAILERDATA = CURLOPTTYPE_CBPOINT + 284,
	HTTP09_ALLOWED = CURLOPTTYPE_LONG + 285,
	ALTSVC_CTRL = CURLOPTTYPE_LONG + 286,
	ALTSVC = CURLOPTTYPE_STRINGPOINT + 287,
	MAXAGE_CONN = CURLOPTTYPE_LONG + 288,
	SASL_AUTHZID = CURLOPTTYPE_STRINGPOINT + 289,
	MAIL_RCPT_ALLLOWFAILS = CURLOPTTYPE_LONG + 290,
	SSLCERT_BLOB = CURLOPTTYPE_BLOB + 291,
	SSLKEY_BLOB = CURLOPTTYPE_BLOB + 292,
	PROXY_SSLCERT_BLOB = CURLOPTTYPE_BLOB + 293,
	PROXY_SSLKEY_BLOB = CURLOPTTYPE_BLOB + 294,
	ISSUERCERT_BLOB = CURLOPTTYPE_BLOB + 295,
	PROXY_ISSUERCERT = CURLOPTTYPE_STRINGPOINT + 296,
	PROXY_ISSUERCERT_BLOB = CURLOPTTYPE_BLOB + 297,
	SSL_EC_CURVES = CURLOPTTYPE_STRINGPOINT + 298,
	HSTS_CTRL = CURLOPTTYPE_LONG + 299,
	HSTS = CURLOPTTYPE_STRINGPOINT + 300,
	HSTSREADFUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 301,
	HSTSREADDATA = CURLOPTTYPE_CBPOINT + 302,
	HSTSWRITEFUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 303,
	HSTSWRITEDATA = CURLOPTTYPE_CBPOINT + 304,
	AWS_SIGV4 = CURLOPTTYPE_STRINGPOINT + 305,
	DOH_SSL_VERIFYPEER = CURLOPTTYPE_LONG + 306,
	DOH_SSL_VERIFYHOST = CURLOPTTYPE_LONG + 307,
	DOH_SSL_VERIFYSTATUS = CURLOPTTYPE_LONG + 308,
	CAINFO_BLOB = CURLOPTTYPE_BLOB + 309,
	PROXY_CAINFO_BLOB = CURLOPTTYPE_BLOB + 310,
	SSH_HOST_PUBLIC_KEY_SHA256 = CURLOPTTYPE_STRINGPOINT + 311,
	PREREQFUNCTION = CURLOPTTYPE_FUNCTIONPOINT + 312,
	PREREQDATA = CURLOPTTYPE_CBPOINT + 313,
	MAXLIFETIME_CONN = CURLOPTTYPE_LONG + 314,
	MIME_OPTIONS = CURLOPTTYPE_LONG + 315,
	LASTENTRY,
}


/* Below here follows defines for the CURLOPT_IPRESOLVE option. If a host
     name resolves addresses using more than one IP protocol version, this
     option might be handy to force libcurl to use a specific IP version. */
CURL_IPRESOLVE_WHATEVER :: 0 /* default, uses addresses to all IP versions that your system allows */
CURL_IPRESOLVE_V4 :: 1 /* uses only IPv4 addresses/connections */
CURL_IPRESOLVE_V6 :: 2 /* uses only IPv6 addresses/connections */
/* three convenient "aliases" that follow the name scheme better */

curl_http_version :: enum {
	VERSION_NONE, // setting this means we don't care, and that we'd like the library to choose the best possible for us! 
	VERSION_1_0,
	VERSION_1_1,
	VERSION_2_0,
	VERSION_2TLS, // version 2 for HTTPS, version 1.1 for HTTP 
	VERSION_2_PRIOR_KNOWLEDGE, // HTTP 2 without HTTP/1.1 upgrade 
	VERSION_3 = 30, // Makes use of explicit HTTP/3 without fallback. Use CURLOPT_ALTSVC to enable HTTP/3 upgrade 
	VERSION_LAST, // *ILLEGAL* 
}


/*
 * Public API enums for RTSP requests
 */
CURL_RTSPREQ :: enum {
	NONE, /* first in list */
	OPTIONS,
	DESCRIBE,
	ANNOUNCE,
	SETUP,
	PLAY,
	PAUSE,
	TEARDOWN,
	GET_PARAMETER,
	SET_PARAMETER,
	RECORD,
	RECEIVE,
	LAST, /* last in list */
}

/* These enums are for use with the CURLOPT_NETRC option. */
CURL_NETRC_OPTION :: enum {
	IGNORED,
	/* The .netrc will never be read.
                           * This is the default. */
	OPTIONAL,
	/* A user:password in the URL will be preferred
                           * to one in the .netrc. */
	REQUIRED,
	/* A user:password in the URL will be ignored.
                           * Unless one is set programmatically, the .netrc
                           * will be queried. */
	LAST,
}

CURL_SSLVERSION :: enum {
	DEFAULT,
	TLSv1, /* TLS 1.x */
	SSLv2,
	SSLv3,
	TLSv1_0,
	TLSv1_1,
	TLSv1_2,
	TLSv1_3,
	LAST, /* never use, keep last */
}

CURL_SSLVERSION_MAX :: enum {
	NONE    = 0,
	DEFAULT = (1 << 16),
	TLSv1_0 = (4 << 16),
	TLSv1_1 = (5 << 16),
	TLSv1_2 = (6 << 16),
	TLSv1_3 = (7 << 16),
	/* never use, keep last */
	LAST    = (8 << 16),
}

CURL_TLSAUTH :: enum {
	NONE,
	SRP,
	LAST, /* never use, keep last */
}

/* symbols to use with CURLOPT_POSTREDIR.
   CURL_REDIR_POST_301, CURL_REDIR_POST_302 and CURL_REDIR_POST_303
   can be bitwise ORed so that CURL_REDIR_POST_301 | CURL_REDIR_POST_302
   | CURL_REDIR_POST_303 == CURL_REDIR_POST_ALL */
CURL_REDIR_GET_ALL :: 0
CURL_REDIR_POST_301 :: 1
CURL_REDIR_POST_302 :: 2
CURL_REDIR_POST_303 :: 4
CURL_REDIR_POST_ALL :: CURL_REDIR_POST_301 | CURL_REDIR_POST_302 | CURL_REDIR_POST_303

curl_TimeCond :: enum {
	None,
	IfModSince,
	IfUnModSince,
	LastMod,
	Last,
}

CURL_ZERO_TERMINATED := transmute(uint)int(-1)

// curl_strequal :: proc(s1: cstring, s2: cstring) -> int ---
// curl_strnequal :: proc(s1: cstring, s2: cstring, n: size_t) -> int ---

mime :: distinct rawptr
mimepart :: distinct rawptr

/* CURLMIMEOPT_ defines are for the CURLOPT_MIME_OPTIONS option. */
CURLMIMEOPT_FORMESCAPE :: 1 << 0 // use backslash-escaping forms

// curl_mime_init :: proc(easy: ^Curl) -> ^Curl_mime ---
// curl_mime_free :: proc(mime: ^Curl_mime) ---
// curl_mime_addpart :: proc(mime: ^Curl_mime) -> ^Curl_mimepart ---
// curl_mime_name :: proc(part: ^Curl_mimepart, name: cstring) -> Curl_code ---
// curl_mime_filename :: proc(part: ^Curl_mimepart, filename: cstring) -> Curl_code ---
// curl_mime_type :: proc(part: ^Curl_mimepart, mimetype: cstring) -> Curl_code ---
// curl_mime_encoder :: proc(part: ^Curl_mimepart, encoding: cstring) -> Curl_code ---
// curl_mime_data :: proc(part: ^Curl_mimepart, data: cstring, datasize: size_t) -> Curl_code ---
// curl_mime_filedata :: proc(part: ^Curl_mimepart, filename: cstring) -> Curl_code ---
// curl_mime_data_cb :: proc(
// 	part: ^Curl_mimepart,
// 	datasize: curl_off_t,
// 	readfunc: Curl_read_callback,
// 	seekfunc: Curl_seek_callback,
// 	freefunc: Curl_free_callback,
// 	arg: rawptr,
// ) -> Curl_code ---
// curl_mime_subparts :: proc(part: ^Curl_mimepart, subparts: ^Curl_mime) -> Curl_code ---
// curl_mime_headers :: proc(
// 	part: ^Curl_mimepart,
// 	headers: ^Curl_slist,
// 	take_ownership: int,
// ) -> Curl_code ---

CURLformoption :: enum {
	NOTHING, // unused entry
	COPYNAME,
	PTRNAME,
	NAMELENGTH,
	COPYCONTENTS,
	PTRCONTENTS,
	CONTENTSLENGTH,
	FILECONTENT,
	ARRAY,
	OBSOLETE,
	FILE,
	BUFFER,
	BUFFERPTR,
	BUFFERLENGTH,
	CONTENTTYPE,
	CONTENTHEADER,
	FILENAME,
	END,
	OBSOLETE2,
	STREAM,
	CONTENTLEN, /* added in 7.46.0, provide a curl_off_t length */
	LASTENTRY, /* the last unused */
}
/* structure to be used as parameter for CURLFORM_ARRAY */
curl_forms :: struct {
	option: CURLformoption,
	value:  cstring,
}
curl_formget_callback :: proc "c" (arg: rawptr, buf: [^]u8, len: i32) -> uint
/* use this for multipart formpost building */
/* Returns code for curl_formadd()
 *
 * Returns:
 * CURL_FORMADD_OK             on success
 * CURL_FORMADD_MEMORY         if the FormInfo allocation fails
 * CURL_FORMADD_OPTION_TWICE   if one option is given twice for one Form
 * CURL_FORMADD_NULL           if a null pointer was given for a char
 * CURL_FORMADD_MEMORY         if the allocation of a FormInfo struct failed
 * CURL_FORMADD_UNKNOWN_OPTION if an unknown option was used
 * CURL_FORMADD_INCOMPLETE     if the some FormInfo is not complete (or error)
 * CURL_FORMADD_MEMORY         if a curl_httppost struct cannot be allocated
 * CURL_FORMADD_MEMORY         if some allocation for string copying failed.
 * CURL_FORMADD_ILLEGAL_ARRAY  if an illegal option is used in an array
 *
 ***************************************************************************/
CURLFORMcode :: enum {
	OK,
	MEMORY,
	OPTION_TWICE,
	NULL,
	UNKNOWN_OPTION,
	INCOMPLETE,
	ILLEGAL_ARRAY,
	DISABLED, // libcurl was built with this disabled 
	LAST,
}

curl_slist :: struct {
	data: ^u8,
	next: ^curl_slist,
}

/*
 * NAME curl_global_sslset()
 *
 * DESCRIPTION
 *
 * When built with multiple SSL backends, curl_global_sslset() allows to
 * choose one. This function can only be called once, and it must be called
 * *before* curl_global_init().
 *
 * The backend can be identified by the id (e.g. CURLSSLBACKEND_OPENSSL). The
 * backend can also be specified via the name parameter (passing -1 as id).
 * If both id and name are specified, the name will be ignored. If neither id
 * nor name are specified, the function will fail with
 * CURLSSLSET_UNKNOWN_BACKEND and set the "avail" pointer to the
 * NULL-terminated list of available backends.
 *
 * Upon success, the function returns CURLSSLSET_OK.
 *
 * If the specified SSL backend is not available, the function returns
 * CURLSSLSET_UNKNOWN_BACKEND and sets the "avail" pointer to a NULL-terminated
 * list of available SSL backends.
 *
 * The SSL backend can be set only once. If it has already been set, a
 * subsequent attempt to change it will result in a CURLSSLSET_TOO_LATE.
 */
curl_ssl_backend :: struct {
	id:   curl_sslbackend,
	name: cstring,
}

CURLSSLSET :: enum {
	OK = 0,
	UNKNOWN_BACKEND,
	TOO_LATE,
	NO_BACKENDS, // libcurl was built without any SSL support
}

curl_certinfo :: struct {
	num_of_certs: i32, // number of certificates with information
	certinfo:     ^^curl_slist, // for each index in this array, there's a linked list with textual information in the format "name: value"
}

curl_tlssessioninfo :: struct {
	backend:   curl_sslbackend,
	internals: rawptr,
}

CURLINFO_STRING :: 0x100000
CURLINFO_LONG :: 0x200000
CURLINFO_DOUBLE :: 0x300000
CURLINFO_SLIST :: 0x400000
CURLINFO_PTR :: 0x400000 // same as SLIST
CURLINFO_SOCKET :: 0x500000
CURLINFO_OFF_T :: 0x600000
CURLINFO_MASK :: 0x0fffff
CURLINFO_TYPEMASK :: 0xf00000

CURLINFO :: enum {
	NONE,
	EFFECTIVE_URL = CURLINFO_STRING + 1,
	RESPONSE_CODE = CURLINFO_LONG + 2,
	TOTAL_TIME = CURLINFO_DOUBLE + 3,
	NAMELOOKUP_TIME = CURLINFO_DOUBLE + 4,
	CONNECT_TIME = CURLINFO_DOUBLE + 5,
	PRETRANSFER_TIME = CURLINFO_DOUBLE + 6,
	SIZE_UPLOAD = CURLINFO_DOUBLE + 7,
	SIZE_UPLOAD_T = CURLINFO_OFF_T + 7,
	SIZE_DOWNLOAD = CURLINFO_DOUBLE + 8,
	SIZE_DOWNLOAD_T = CURLINFO_OFF_T + 8,
	SPEED_DOWNLOAD = CURLINFO_DOUBLE + 9,
	SPEED_DOWNLOAD_T = CURLINFO_OFF_T + 9,
	SPEED_UPLOAD = CURLINFO_DOUBLE + 10,
	SPEED_UPLOAD_T = CURLINFO_OFF_T + 10,
	HEADER_SIZE = CURLINFO_LONG + 11,
	REQUEST_SIZE = CURLINFO_LONG + 12,
	SSL_VERIFYRESULT = CURLINFO_LONG + 13,
	FILETIME = CURLINFO_LONG + 14,
	FILETIME_T = CURLINFO_OFF_T + 14,
	CONTENT_LENGTH_DOWNLOAD = CURLINFO_DOUBLE + 15,
	CONTENT_LENGTH_DOWNLOAD_T = CURLINFO_OFF_T + 15,
	CONTENT_LENGTH_UPLOAD = CURLINFO_DOUBLE + 16,
	CONTENT_LENGTH_UPLOAD_T = CURLINFO_OFF_T + 16,
	STARTTRANSFER_TIME = CURLINFO_DOUBLE + 17,
	CONTENT_TYPE = CURLINFO_STRING + 18,
	REDIRECT_TIME = CURLINFO_DOUBLE + 19,
	REDIRECT_COUNT = CURLINFO_LONG + 20,
	PRIVATE = CURLINFO_STRING + 21,
	HTTP_CONNECTCODE = CURLINFO_LONG + 22,
	HTTPAUTH_AVAIL = CURLINFO_LONG + 23,
	PROXYAUTH_AVAIL = CURLINFO_LONG + 24,
	OS_ERRNO = CURLINFO_LONG + 25,
	NUM_CONNECTS = CURLINFO_LONG + 26,
	SSL_ENGINES = CURLINFO_SLIST + 27,
	COOKIELIST = CURLINFO_SLIST + 28,
	LASTSOCKET = CURLINFO_LONG + 29,
	FTP_ENTRY_PATH = CURLINFO_STRING + 30,
	REDIRECT_URL = CURLINFO_STRING + 31,
	PRIMARY_IP = CURLINFO_STRING + 32,
	APPCONNECT_TIME = CURLINFO_DOUBLE + 33,
	CERTINFO = CURLINFO_PTR + 34,
	CONDITION_UNMET = CURLINFO_LONG + 35,
	RTSP_SESSION_ID = CURLINFO_STRING + 36,
	RTSP_CLIENT_CSEQ = CURLINFO_LONG + 37,
	RTSP_SERVER_CSEQ = CURLINFO_LONG + 38,
	RTSP_CSEQ_RECV = CURLINFO_LONG + 39,
	PRIMARY_PORT = CURLINFO_LONG + 40,
	LOCAL_IP = CURLINFO_STRING + 41,
	LOCAL_PORT = CURLINFO_LONG + 42,
	TLS_SESSION = CURLINFO_PTR + 43,
	ACTIVESOCKET = CURLINFO_SOCKET + 44,
	TLS_SSL_PTR = CURLINFO_PTR + 45,
	HTTP_VERSION = CURLINFO_LONG + 46,
	PROXY_SSL_VERIFYRESULT = CURLINFO_LONG + 47,
	PROTOCOL = CURLINFO_LONG + 48,
	SCHEME = CURLINFO_STRING + 49,
	TOTAL_TIME_T = CURLINFO_OFF_T + 50,
	NAMELOOKUP_TIME_T = CURLINFO_OFF_T + 51,
	CONNECT_TIME_T = CURLINFO_OFF_T + 52,
	PRETRANSFER_TIME_T = CURLINFO_OFF_T + 53,
	STARTTRANSFER_TIME_T = CURLINFO_OFF_T + 54,
	REDIRECT_TIME_T = CURLINFO_OFF_T + 55,
	APPCONNECT_TIME_T = CURLINFO_OFF_T + 56,
	RETRY_AFTER = CURLINFO_OFF_T + 57,
	EFFECTIVE_METHOD = CURLINFO_STRING + 58,
	PROXY_ERROR = CURLINFO_LONG + 59,
	REFERER = CURLINFO_STRING + 60,
	LASTONE = 60,
}
curl_closepolicy :: enum {
	NONE,
	OLDEST,
	LEAST_RECENTLY_USED,
	LEAST_TRAFFIC,
	SLOWEST,
	CALLBACK,
	LAST,
}
/*****************************************************************************
 * Setup defines, protos etc for the sharing stuff.
 */

/* Different data locks for a single share */
curl_lock_data :: enum {
	NONE = 0,
	/*  CURL_LOCK_DATA_SHARE is used internally to say that
     *  the locking is just made to change the internal state of the share
     *  itself.
     */
	SHARE,
	COOKIE,
	DNS,
	SSL_SESSION,
	CONNECT,
	PSL,
	HSTS,
	LAST,
}
curl_lock_access :: enum {
	NONE = 0, /* unspecified action */
	SHARED = 1, /* for read perhaps */
	SINGLE = 2, /* for write perhaps */
	LAST, /* never use */
}
curl_lock_function: proc "c" (
	handle: ^CURL,
	data: curl_lock_data,
	locktype: curl_lock_access,
	userptr: ^any,
)
curl_unlock_function: proc "c" (handle: ^CURL, data: curl_lock_data, userptr: ^any)

CURLSHcode :: enum {
	CURLSHE_OK,
	CURLSHE_BAD_OPTION,
	CURLSHE_IN_USE,
	CURLSHE_INVALID,
	CURLSHE_NOMEM,
	CURLSHE_NOT_BUILT_IN,
	CURLSHE_LAST,
}
CURLSHoption :: enum {
	CURLSHOPT_NONE, /* don't use */
	CURLSHOPT_SHARE, /* specify a data type to share */
	CURLSHOPT_UNSHARE, /* specify which data type to stop sharing */
	CURLSHOPT_LOCKFUNC, /* pass in a 'curl_lock_function' pointer */
	CURLSHOPT_UNLOCKFUNC, /* pass in a 'curl_unlock_function' pointer */
	CURLSHOPT_USERDATA, /* pass in a user data pointer used in the lock/unlock callback functions */
	CURLSHOPT_LAST, /* never use */
}

/****************************************************************************
 * Structures for querying information about the curl library at runtime.
 */
CURLversion :: enum {
	FIRST,
	SECOND,
	THIRD,
	FOURTH,
	FIFTH,
	SIXTH,
	SEVENTH,
	EIGHTH,
	NINTH,
	TENTH, // <-- current
	LAST, /* never actually use this */
}

CURLversion_Info_Data :: struct {
	age:             CURLversion, // age of the returned struct
	version:         cstring, // LIBCURL_VERSION
	version_num:     u32, // LIBCURL_VERSION_NUM
	host:            cstring, // OS/host/cpu/machine when configured
	features:        int, // bitmask, see defines below
	ssl_version:     cstring, // human readable string
	ssl_version_num: i32, // not used anymore, always 0
	libz_version:    cstring, // human readable string
	protocols:       ^^cstring, // protocols is terminated by an entry with a NULL protoname

	// The fields below this were added in CURLVERSION_SECOND
	ares:            cstring,
	ares_num:        int,

	// This field was added in CURLVERSION_THIRD
	libidn:          cstring,

	// These fields were added in CURLVERSION_FOURTH
	iconv_ver_num:   int, // Same as '_libiconv_version' if built with HAVE_ICONV
	libssh_version:  cstring, // human readable string

	// These fields were added in CURLVERSION_FIFTH
	brotli_ver_num:  u32, // Numeric Brotli version (MAJOR << 24) | (MINOR << 12) | PATCH
	brotli_version:  cstring, // human readable string.

	// These fields were added in CURLVERSION_SIXTH
	nghttp2_ver_num: u32, // Numeric nghttp2 version (MAJOR << 16) | (MINOR << 8) | PATCH
	nghttp2_version: cstring, // human readable string.
	quic_version:    cstring, // human readable quic (+ HTTP/3) library + version or NULL

	// These fields were added in CURLVERSION_SEVENTH
	cainfo:          cstring, // the built-in default CURLOPT_CAINFO, might be NULL
	capath:          cstring, // the built-in default CURLOPT_CAPATH, might be NULL

	// These fields were added in CURLVERSION_EIGHTH
	zstd_ver_num:    u32, // Numeric Zstd version (MAJOR << 24) | (MINOR << 12) | PATCH
	zstd_version:    cstring, // human readable string.

	// These fields were added in CURLVERSION_NINTH
	hyper_version:   cstring, // human readable string.

	// These fields were added in CURLVERSION_TENTH
	gsasl_version:   cstring, // human readable string.
}


CURL_VERSION_IPV6 :: (1 << 0) /* IPv6-enabled */
CURL_VERSION_KERBEROS4 :: (1 << 1) /* Kerberos V4 auth is supported(deprecated) */
CURL_VERSION_SSL :: (1 << 2) /* SSL options are present */
CURL_VERSION_LIBZ :: (1 << 3) /* libz features are present */
CURL_VERSION_NTLM :: (1 << 4) /* NTLM auth is supported */
CURL_VERSION_GSSNEGOTIATE :: (1 << 5) /* Negotiate auth is supported(deprecated) */
CURL_VERSION_DEBUG :: (1 << 6) /* Built with debug capabilities */
CURL_VERSION_ASYNCHDNS :: (1 << 7) /* Asynchronous DNS resolves */
CURL_VERSION_SPNEGO :: (1 << 8) /* SPNEGO auth is supported */
CURL_VERSION_LARGEFILE :: (1 << 9) /* Supports files larger than 2GB */
CURL_VERSION_IDN :: (1 << 10) /* Internationized Domain Names are supported */
CURL_VERSION_SSPI :: (1 << 11) /* Built against Windows SSPI */
CURL_VERSION_CONV :: (1 << 12) /* Character conversions supported */
CURL_VERSION_CURLDEBUG :: (1 << 13) /* Debug memory tracking supported */
CURL_VERSION_TLSAUTH_SRP :: (1 << 14) /* TLS-SRP auth is supported */
CURL_VERSION_NTLM_WB :: (1 << 15) /* NTLM delegation to winbind helper is supported */
CURL_VERSION_HTTP2 :: (1 << 16) /* HTTP2 support built-in */
CURL_VERSION_GSSAPI :: (1 << 17) /* Built against a GSS-API library */
CURL_VERSION_KERBEROS5 :: (1 << 18) /* Kerberos V5 auth is supported */
CURL_VERSION_UNIX_SOCKETS :: (1 << 19) /* Unix domain sockets support */
CURL_VERSION_PSL ::
	(1 << 20) /* Mozilla's Public Suffix List, used for cookie domain verification */
CURL_VERSION_HTTPS_PROXY :: (1 << 21) /* HTTPS-proxy support built-in */
CURL_VERSION_MULTI_SSL :: (1 << 22) /* Multiple SSL backends available */
CURL_VERSION_BROTLI :: (1 << 23) /* Brotli features are present. */
CURL_VERSION_ALTSVC :: (1 << 24) /* Alt-Svc handling built-in */
CURL_VERSION_HTTP3 :: (1 << 25) /* HTTP3 support built-in */
CURL_VERSION_ZSTD :: (1 << 26) /* zstd features are present */
CURL_VERSION_UNICODE :: (1 << 27) /* Unicode support on Windows */
CURL_VERSION_HSTS :: (1 << 28) /* HSTS is supported */
CURL_VERSION_GSASL :: (1 << 29) /* libgsasl is supported */

CURLPAUSE_RECV :: (1 << 0)
CURLPAUSE_RECV_CONT :: (0)
CURLPAUSE_SEND :: (1 << 2)
CURLPAUSE_SEND_CONT :: (0)
CURLPAUSE_ALL :: (CURLPAUSE_RECV | CURLPAUSE_SEND)
CURLPAUSE_CONT :: (CURLPAUSE_RECV_CONT | CURLPAUSE_SEND_CONT)

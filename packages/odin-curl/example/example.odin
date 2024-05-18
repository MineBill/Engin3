package cli
import curl "../"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:runtime"
//
_main :: proc() {
	using curl
	url := "https://jsonplaceholder.typicode.com/posts"
	// form-data format:
	// post_data := "field1=value1&field2=value2" 
	json_data: cstring = `{"key42":"value24"}`
	h := easy_init()
	defer easy_cleanup(h)

	headers: ^curl_slist
	headers = slist_append(nil, "content-type: application/json")
	headers = slist_append(headers, "Accept: application/json")
	headers = slist_append(headers, "charset: utf-8")
	defer slist_free_all(headers)

	easy_setopt(h, CURLoption.URL, url)
	hres := easy_setopt(h, CURLoption.HTTPHEADER, headers)
	// Verify option was set correctly:
	if hres != CURLcode.OK {
		fmt.println("Failed to set HTTPHEADER: ", easy_strerror(hres))
	}
	easy_setopt(h, CURLoption.POST, 1)
	easy_setopt(h, CURLoption.POSTFIELDS, json_data)
	easy_setopt(h, CURLoption.POSTFIELDSIZE, len(json_data))

	// DIAGNOSTIC OUTPUTS
	// easy_setopt(h, CURLoption.VERBOSE, 1) 

	easy_setopt(h, CURLoption.WRITEFUNCTION, write_callback)
	data := DataContext{nil, context}
	easy_setopt(h, .WRITEDATA, &data)

	// Turn off SSL Cert Verification:
	// easy_setopt(h, CURLoption.SSL_VERIFYPEER, 0)

	result := easy_perform(h)
	if result != CURLcode.OK {
		fmt.println("Error occurred: ", result)
	} else {
		fmt.println("DATA", string(data.data))
		delete(data.data)
	}
	fmt.println("END")
}

DataContext :: struct {
	data: []u8,
	ctx:  runtime.Context,
}

write_callback :: proc "c" (contents: rawptr, size: uint, nmemb: uint, userp: rawptr) -> uint {
	dc := transmute(^DataContext)userp
	context = dc.ctx
	total_size := size * nmemb
	content_str := transmute([^]u8)contents
	dc.data = make([]u8, int(total_size)) // <-- ALLOCATION
	mem.copy(&dc.data[0], content_str, int(total_size))
	return total_size
}

// Tracking Allocator Setup:
main :: proc() {
	when false {
		_main()
	} else {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)
		_main()
		for _, leak in track.allocation_map do fmt.printf("%v leaked %v bytes\n", leak.location, leak.size)
		for bad_free in track.bad_free_array do fmt.printf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory)
	}
}

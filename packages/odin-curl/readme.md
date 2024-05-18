# CURL Bindings

Odin-Bindings to CURL.

The procedure bindings are incomplete (eg no `multi`), however the main header (`curl.h`) is complete. Feel free to PR in additional bindings as desired, please include both windows and nix codepaths.

- Linux & Darwin expect curl to be installed on the system.
- Windows uses the curl dll (a copy of v8.1.2 is provided). It can also be downloaded directly from [curl.se](https://curl.se/download.html). Curl is typically quite backward compatible, so newer versions should work fine with the bindings.

## Syntax

This package provides Odin-bindings to curl. Stylistically, it does not change syntax from curl, other than enum prefixes which are shortened for readability. Note that curl's header syntax is not always consistent, this binding copies it as-is.

## License

BSD-3: Jon Lipstate 2023

## Example

A functioning JSON POST request can be found in `/example/`.

```odin
main :: proc() {
	using curl
	url := "https://jsonplaceholder.typicode.com/posts"
	json_data: cstring = `{"key42":"value24"}`
	h := easy_init()
	defer easy_cleanup(h)

	headers: ^curl_slist
	defer slist_free_all(headers)
	headers = slist_append(nil, "content-type: application/json")
	headers = slist_append(headers, "Accept: application/json")
	headers = slist_append(headers, "charset: utf-8")

	easy_setopt(h, CURLoption.URL, url)
	easy_setopt(h, CURLoption.HTTPHEADER, headers)

	easy_setopt(h, CURLoption.POST, 1)
	easy_setopt(h, CURLoption.POSTFIELDS, json_data)
	easy_setopt(h, CURLoption.POSTFIELDSIZE, len(json_data))

	data: [^]u8
	easy_setopt(h, CURLoption.WRITEFUNCTION, write_callback)
	easy_setopt(h, .WRITEDATA, &data)

	result := easy_perform(h)
	if result != CURLcode.OK {
		fmt.println("Error occurred: ", result)
	} else {
		s := into_string(data)
		fmt.println("DATA", s)
	}
}
```

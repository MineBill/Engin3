package filesystem
import "core:strings"
import "core:os"
import "core:path/filepath"
import "core:fmt"

WatchCallback :: #type proc(data: rawptr, file: string)

make_directory_recursive :: proc(path: string) {
    path, _ := strings.clone(path, context.temp_allocator)
    path, _ = filepath.to_slash(path, context.temp_allocator)

    temp: string
    for dir in strings.split_iterator(&path, "/") {
        temp = strings.join({temp, dir, "/"}, "", context.temp_allocator)
        os.make_directory(temp)
    }
}

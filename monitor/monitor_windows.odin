package monitor
import "core:sys/windows"
import "core:mem"
import "core:strings"

Monitor :: struct {
    handle:     windows.HANDLE,

    // Paths to look out for
    paths:      []string,

    triggered:  bool,
    path_index: int,
}

init :: proc(monitor: ^Monitor, directory: string, paths: []string) {
    monitor.handle = windows.FindFirstChangeNotificationW(
        windows.utf8_to_wstring(directory),
        true,
        windows.FILE_NOTIFY_CHANGE_LAST_WRITE,
    )

    monitor.paths = make([]string, len(paths))
    copy(monitor.paths, paths)
}

deinit :: proc(monitor: ^Monitor) {
    delete(monitor.paths)
}

thread_proc :: proc(data: rawptr) {
    monitor := cast(^Monitor)data

    for {
        wait_status := windows.WaitForSingleObject(monitor.handle, windows.INFINITE)
        switch wait_status {
        case windows.WAIT_OBJECT_0:
            buffer: [1024]byte
            bytes_returned: u32
            windows.ReadDirectoryChangesW(
                monitor.handle,
                &buffer,
                u32(len(buffer)),
                false,
                windows.FILE_NOTIFY_CHANGE_LAST_WRITE,
                &bytes_returned,
                nil,
                nil,
            )

            file_info := cast(^windows.FILE_NOTIFY_INFORMATION)&buffer

            name, _ := windows.wstring_to_utf8(
                &file_info.file_name[0],
                cast(int)file_info.file_name_length,
            )

            for path, i in monitor.paths {
                if strings.contains(path, name) {
                    monitor.triggered = true
                    monitor.path_index = i
                }
            }

            windows.FindNextChangeNotification(monitor.handle)
        case windows.WAIT_TIMEOUT:
            // Does this need to be handled?
            unreachable()
        }
    }
}

package filesystem
import "core:sys/windows"
import "core:mem"
import "core:strings"
import "core:sync"
import "core:thread"
import "core:path/filepath"

copy_file :: proc(from: string, to: string, overwrite: bool = false, allocator := context.temp_allocator) -> (ok: bool) {
    from_w := windows.utf8_to_wstring(from)
    to_w := windows.utf8_to_wstring(to)

    return bool(windows.CopyFileW(from_w, to_w, !overwrite))
}

open_file_explorer :: proc(dir: string) {
    handle := windows.GetCurrentProcess()

    windows.ShellExecuteW(
        nil,
        windows.L("open"),
        windows.L("explorer.exe"),
        windows.utf8_to_wstring(dir),
        nil,
        windows.SW_SHOWNORMAL,
    )
}

Watcher :: struct {
    handle:     windows.HANDLE,

    mutex: sync.Mutex,

    triggered:  bool,
    changed_file: string,
}

watcher_init :: proc(watcher: ^Watcher, directory: string) {
    watcher.handle = windows.FindFirstChangeNotificationW(
        windows.utf8_to_wstring(directory),
        true,
        windows.FILE_NOTIFY_CHANGE_LAST_WRITE,
    )

    thread.run_with_data(watcher, watcher_thread_proc)
}

watcher_deinit :: proc(watcher: ^Watcher) {
    windows.FindCloseChangeNotification(watcher.handle)
}

@(private = "file")
watcher_thread_proc :: proc(data: rawptr) {
    watcher := cast(^Watcher)data

    for {
        wait_status := windows.WaitForSingleObject(watcher.handle, windows.INFINITE)
        switch wait_status {
        case windows.WAIT_OBJECT_0:
            buffer: [1024]byte
            bytes_returned: u32
            windows.ReadDirectoryChangesW(
                watcher.handle,
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
            name, _ = filepath.to_slash(name, context.temp_allocator)

            sync.mutex_lock(&watcher.mutex)
            delete(watcher.changed_file)
            watcher.triggered = true
            watcher.changed_file = strings.clone(name)
            sync.mutex_unlock(&watcher.mutex)

            windows.FindNextChangeNotification(watcher.handle)
        case windows.WAIT_TIMEOUT:
            // Does this need to be handled?
            unreachable()
        }
    }
}

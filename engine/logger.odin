package engine
import "core:log"
import "core:os"
import "core:strings"
import "core:fmt"
import "core:time"

// Custom console logger that colors the entire log text.


create_custom_console_logger :: proc(lowest := log.Level.Debug, opt := log.Default_Console_Logger_Opts, ident := "") -> log.Logger {
    data := new(log.File_Console_Logger_Data)
    data.file_handle = os.INVALID_HANDLE
    data.ident = ident
    return log.Logger{file_console_logger_proc, data, lowest, opt}
}

file_console_logger_proc :: proc(logger_data: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) {
    data := cast(^log.File_Console_Logger_Data)logger_data
    h: os.Handle = os.stdout if level <= log.Level.Error else os.stderr
    if data.file_handle != os.INVALID_HANDLE {
        h = data.file_handle
    }
    backing: [1024]byte //NOTE(Hoej): 1024 might be too much for a header backing, unless somebody has really long paths.
    buf := strings.builder_from_bytes(backing[:])

    do_level_header(options, level, &buf)

    when time.IS_SUPPORTED {
        if log.Full_Timestamp_Opts & options != nil {
            fmt.sbprint(&buf, "[")
            t := time.now()
            y, m, d := time.date(t)
            h, min, s := time.clock(t)
            if .Date in options { fmt.sbprintf(&buf, "%d-%02d-%02d ", y, m, d)    }
            if .Time in options { fmt.sbprintf(&buf, "%02d:%02d:%02d", h, min, s) }
            fmt.sbprint(&buf, "] ")
        }
    }

    log.do_location_header(options, &buf, location)

    if .Thread_Id in options {
        // NOTE(Oskar): not using context.thread_id here since that could be
        // incorrect when replacing context for a thread.
        fmt.sbprintf(&buf, "[{}] ", os.current_thread_id())
    }

    if data.ident != "" {
        fmt.sbprintf(&buf, "[%s] ", data.ident)
    }
    //TODO(Hoej): When we have better atomics and such, make this thread-safe
    fmt.fprintf(h, "%s%s\n", strings.to_string(buf), text)
}


do_level_header :: proc(opts: log.Options, level: log.Level, str: ^strings.Builder) {

    RESET     :: "\x1b[0m"
    RED       :: "\x1b[31m"
    YELLOW    :: "\x1b[33m"
    DARK_GREY :: "\x1b[90m"

    col := RESET
    switch level {
    case .Debug:   col = DARK_GREY
    case .Info:    col = RESET
    case .Warning: col = YELLOW
    case .Error, .Fatal: col = RED
    }

    if .Level in opts {
        if .Terminal_Color in opts {
            fmt.sbprint(str, col)
        }
        fmt.sbprint(str, log.Level_Headers[level])
        // if .Terminal_Color in opts {
        //     fmt.sbprint(str, RESET)
        // }
    }
}

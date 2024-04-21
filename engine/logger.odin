package engine
import "core:log"
import "core:os"
import "core:strings"
import "core:fmt"
import "core:time"
import intr "base:intrinsics"
import rt "base:runtime"
import "core:reflect"

when USE_EDITOR {
    LogCategory :: enum {
        Editor,

        Engine,
        Renderer,
        EntitySystem,
        AssetSystem,
        PhysicsSystem,
        ScriptingEngine,
        UserScript,
    }
} else {
    LogCategory :: enum {
        Engine,
        Renderer,
        EntitySystem,
        AssetSystem,
        PhysicsSystem,
        ScriptingEngine,
        UserScript,
    }
}

LC :: LogCategory

LogCategories :: bit_set[LogCategory]

LogEntry :: struct {
    level: log.Level,
    category: reflect.Enum_Field,
    text: string,
    options: log.Options,
    locations: rt.Source_Code_Location,
}

RawCategoryLogger :: struct {
    base_logger: log.Logger,
    typed_category_logger: rawptr,

    log_entries: ^[dynamic]LogEntry,
}

CategoryLogger :: struct($T: typeid) where intr.type_is_enum(T) {
    categories: bit_set[T],
}

create_category_logger :: proc(
    typed_category_logger: ^CategoryLogger($T),
    log_entries: ^[dynamic]LogEntry,
    base_logger := context.logger,
    level: log.Level = .Debug,
    options := log.Options{.Level, .Short_File_Path, .Line, .Procedure},
) -> log.Logger {
    logger := new(RawCategoryLogger)
    logger.base_logger = base_logger
    logger.typed_category_logger = typed_category_logger
    logger.log_entries = log_entries

    return log.Logger {
        raw_category_logger_proc,
        logger,
        level,
        options,
    }
}

@(private = "file")
raw_category_logger_proc :: proc(logger_data: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) {
    raw_category_logger := cast(^RawCategoryLogger) logger_data

    raw_category_logger.base_logger.procedure(raw_category_logger.base_logger.data, level, text, options, location)
}

cat_logger_proc :: proc(raw_logger: ^RawCategoryLogger, category: $T, level: log.Level, text: string, options: log.Options, location := #caller_location) {
    raw_logger.base_logger.procedure(raw_logger.base_logger.data, level, text, options, location)

    name, ok := reflect.enum_name_from_value(category)
    append(
        raw_logger.log_entries,
        LogEntry{level, {
            name, cast(reflect.Type_Info_Enum_Value) category,
        },
        fmt.aprintf("[%v] %v", name, text),
        options,
        location})
}

@(private = "file")
log_actual :: proc(category: $T, level: log.Level, text: string, location := #caller_location) where intr.type_is_enum(T) {
    if context.logger.procedure == raw_category_logger_proc {
        raw_logger := cast(^RawCategoryLogger) context.logger.data

        category_logger := cast(^CategoryLogger(T)) raw_logger.typed_category_logger
        cat_logger_proc(raw_logger, category, level, text, context.logger.options, location)
    }
}

log_set_categories :: proc(logger: ^CategoryLogger($T), categories: bit_set[T]) where intr.type_is_enum(T) {
    logger.categories = categories
}

log_debug :: proc(category: $T, text: string, args: ..any, location := #caller_location) {
    log_actual(category, .Debug, fmt.tprintf(text, ..args), location)
}

log_info :: proc(category: $T, text: string, args: ..any, location := #caller_location) where intr.type_is_enum(T) {
    log_actual(category, .Info, fmt.tprintf(text, ..args), location)
}

log_warning :: proc(category: $T, text: string, args: ..any, location := #caller_location) where intr.type_is_enum(T) {
    log_actual(category, .Warning, fmt.tprintf(text, ..args), location)
}

log_error :: proc(category: $T, text: string, args: ..any, location := #caller_location) where intr.type_is_enum(T) {
    log_actual(category, .Error, fmt.tprintf(text, ..args), location)
}

_ :: proc() {
    Category :: enum {
        All,
        Physics,
        Editor,
        Scripts,
    }

    Categories :: bit_set[Category]

    category_logger: CategoryLogger(Category)
    context.logger = create_category_logger(&category_logger, nil)

    log_set_categories(&category_logger, Categories{.Editor, .Physics})

    log_info(Category.Editor, "Hello, world!")
    log_warning(Category.Editor, "")
    log_error(Category.Editor, "")
}

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

package engine
import "core:strings"
import "core:log"
import "core:strconv"

ArgValue :: union {
    int,
    bool,
    string,
}

Args :: map[string]ArgValue

ArgParseError :: enum {
    None,
    InvalidValue,
    InvalidKey,
}

parse_args :: proc(os_args: []string) -> (args: Args, err: ArgParseError) {
    for arg_string in os_args {
        if arg_string[0] == '-' {
            max_splits :: 2
            colon_splits := strings.split_n(arg_string[1:], ":", max_splits)
            log.infof("color_splits: %v", colon_splits)
            switch len(colon_splits) {
                case 1:
                    args[colon_splits[0]] = nil
                case 2:
                    args[colon_splits[0]] = parse_value(colon_splits[1])
                case:
                    unreachable()
            }
        }
    }
    return
}

parse_value :: proc(s: string) -> ArgValue {
    switch s {
        case "true", "True", "TRUE", "false", "False", "FALSE":
            lower := strings.to_lower(s)
            b, ok := strconv.parse_bool(s)
            assert(ok, "strconv failed. Impossible.")
            return b
        case:
            i, ok := strconv.parse_int(s, 10)
            if !ok {
                return s
            }
            return i
    }
    return nil
}
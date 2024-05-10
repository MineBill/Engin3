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
            colon_count := strings.count(arg_string[1:], ":")
            if colon_count >= 2 {
                return {}, .InvalidKey
            }

            colon := strings.index(arg_string[1:], ":")
            switch colon {
                case -1:
                    args[arg_string[1:]] = nil
                case:
                    args[arg_string[1:colon + 1]] = parse_value(arg_string[colon + 2:])
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
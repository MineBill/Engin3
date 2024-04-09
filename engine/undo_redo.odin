package engine
import "core:mem"
import "core:slice"
import "core:log"
import "core:runtime"

MAX_UNDO_DATA_BYTES :: 512

Undo :: struct {
    undo_items: [dynamic]UndoItem,
    redo_items: [dynamic]UndoItem,
    temp_items: [dynamic]UndoItem,

    single_items: map[string]UndoItem,
}

UndoItem :: struct {
    ptr: rawptr,
    size: int,
    data: [MAX_UNDO_DATA_BYTES]byte,
    loc: runtime.Source_Code_Location,
    tag: string,
}

undo_init :: proc(undo: ^Undo) {
    using undo
    undo_items = make([dynamic]UndoItem)
    redo_items = make([dynamic]UndoItem)
}

undo_push :: proc(undo: ^Undo, data: ^$T, size := size_of(T), tag: string = "", loc := #caller_location) {
    assert(size < MAX_UNDO_DATA_BYTES)

    for item in undo.temp_items {
        if item.ptr == data {
            // Data exists in the stack.
            return
        }
    }

    item := UndoItem {
        ptr = data,
        size = size,
        loc = loc,
        tag = tag,
    }

    mem.copy(raw_data(item.data[:]), data, size)

    append(&undo.temp_items, item)
}

undo_push_single :: proc(undo: ^Undo, data: ^$T, size := size_of(T), tag: string, loc := #caller_location) {
    assert(size < MAX_UNDO_DATA_BYTES)

    for item in undo.temp_items {
        if item.ptr == data {
            // Data exists in the stack.
            return
        }
    }

    item := UndoItem {
        ptr = data,
        size = size,
        loc = loc,
        tag = tag,
    }

    mem.copy(raw_data(item.data[:]), data, size)

    undo.single_items[tag] = item
    // append(&undo.temp_items, item)
}

undo_commit_single :: proc(undo: ^Undo, tag: string) {
    if tag in undo.single_items {
        item := undo.single_items[tag]

        current := mem.byte_slice(item.ptr, item.size)
        if mem.compare(current, item.data[:item.size]) != 0 {
            append(&undo.undo_items, item)
        }

        delete_key(&undo.single_items, tag)
    }
}

undo_commit :: proc(undo: ^Undo) {
    for len(undo.temp_items) > 0 {
        item := pop(&undo.temp_items)

        current := mem.byte_slice(item.ptr, item.size)
        if mem.compare(current, item.data[:item.size]) != 0 {
            append(&undo.undo_items, item)
        }
    }
}

undo_undo :: proc(undo: ^Undo) {
    if len(undo.undo_items) > 0 {
        item := pop(&undo.undo_items)
        if item.ptr == nil {
            return
        }

        {
            item := item
            mem.copy(raw_data(item.data[:]), item.ptr, item.size)
            append(&undo.redo_items, item)
        }

        mem.copy(item.ptr, raw_data(item.data[:]), item.size)
    }
}

undo_redo :: proc(undo: ^Undo) {
    if len(undo.redo_items) > 0 {
        item := pop(&undo.redo_items)
        if item.ptr == nil {
            return
        }

        {
            item := item
            mem.copy(raw_data(item.data[:]), item.ptr, item.size)
            append(&undo.undo_items, item)
        }
        mem.copy(item.ptr, raw_data(item.data[:]), item.size)
    }
}

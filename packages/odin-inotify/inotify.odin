package inotify

import "core:os"
import "core:c"
import "core:strings"
import "core:mem"
import "core:fmt"
import bind "./bindings"

Event :: struct
{
     wd:     os.Handle, /* Watch Descriptor */
     mask:   u32,   /* Mask of events */
     cookie: u32,   /* Unique cookie associating related events */
     name:   string,  /* Optional name */
}

Event_Kind :: enum u8
{
     Access,
     Modify,
     Attrib,
     Close_Write,
     Close_NoWrite,
     Open,
     Moved_From,
     Moved_To,
     Create,
     Delete,
     Delete_Self,
     Move_Self,
     _,
     Unmount,
     Q_Overflow,
     Ignored,
     
     Only_Dir = 24,
     Dont_Follow,
     Excl_Link,
     _,
     Mask_Create,
     Mask_Add,
     Is_Dir,
     One_Shot,
}

Event_Mask :: bit_set[Event_Kind; u32]

init  :: proc() -> os.Handle { return bind.init() }
init1 :: proc(flags: int) -> os.Handle { return bind.init1(c.int(flags)) }

add_watch :: proc(fd: os.Handle, pathname: string, mask: Event_Mask) -> (os.Handle, os.Errno)
{
     c_pathname := strings.clone_to_cstring(pathname, context.temp_allocator)
     wd := bind.add_watch(fd, (^byte)(c_pathname), transmute(u32)mask)
     if wd == -1 
     {
         return os.INVALID_HANDLE, os.Errno(os.get_last_error())
     }
     return cast(os.Handle)wd, os.ERROR_NONE
}

rm_watch :: proc(fd: os.Handle, wd: os.Handle) -> int
{
     return int(bind.rm_watch(fd, os.Handle(wd)))
}

@(deferred_out=free_events)
read_events :: proc(fd: os.Handle, count := 16, allocator := context.allocator) -> [dynamic]Event
{
     bytes := make([]byte, count * (size_of(bind.Event)+256))
     out := make([dynamic]Event)
     length, ok := os.read(fd, bytes[:])
     if ok != 0 do return out
     i := 0
     for i < length
         {
         bevent := (^bind.Event)(&bytes[i])
         event := Event{}
         event.wd = bevent.wd
         event.mask = bevent.mask
         event.cookie = bevent.cookie
         
         n := 0
         #no_bounds_check for n < int(bevent.length) && bevent.name[n] != 0 
         {
             n += 1
         }
         #no_bounds_check name_slice := mem.slice_ptr(&bevent.name[0], n)
         
         event.name = strings.clone(cast(string)name_slice)
         append(&out, event)
         
         i += size_of(bind.Event)+int(bevent.length)
     }
     return out
}

free_events :: proc(buffer: [dynamic]Event)
{
     for event in buffer 
     {
         delete(event.name)
     }
     delete(buffer)
}

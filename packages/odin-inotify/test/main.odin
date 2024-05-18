package main

import ".."
import "core:os"
import "core:fmt"
import "core:sys/unix"
import "base:runtime"
import "core:time"

check_events :: proc "c" (arg: rawptr) -> rawptr
{
     context = runtime.default_context();
     fd : os.Handle = (cast(^os.Handle)arg)^;
     _check_events(fd);
     return nil;
}

_check_events :: proc(fd: os.Handle)
{
     for
     {
         events := inotify.read_events(fd);
         for event in events
         {
             fmt.printf("FILE: %s\n", event.name);
         }
     }
}

main :: proc()
{
     fd := inotify.init();
     wd := inotify.add_watch(fd, "/home/tyler/Odin/inotify/test", .Create | .Delete);

     t: unix.pthread_t;
     unix.pthread_create(&t, nil, check_events, &fd);

     for
     {
         time.sleep(time.Second);
         fmt.printf("FOO\n");
     }
}

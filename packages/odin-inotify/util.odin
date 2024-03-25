package inotify

// Putting this here as it's not currently in the core library

foreign import libc "system:c"

import "core:c"

foreign libc {
@(link_name="poll") _unix_poll :: proc(fds: ^Poll_Fd, nfds: u64, timeout: c.int) -> c.int ---;
}

Poll_Fd :: struct
{
    fd: c.int,
    events: c.ushort,
    revents: c.ushort,
}

POLLIN  :: 0x001;
POLLPRI :: 0x002;
POLLOUT :: 0x004;

POLLERR  :: 0x008;
POLLHUP  :: 0x010;
POLLNVAL :: 0x020;

POLLRDNORM :: 0x040;
POLLRDBAND :: 0x080;
POLLWRNORM :: 0x100;
POLLWRBAND :: 0x200;

POLLMSG    :: 0x0400;
POLLREMOVE :: 0x1000;
POLLRDHUP  :: 0x2000;
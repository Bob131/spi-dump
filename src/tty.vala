[PrintfFormat]
IOError ioerror(string message, ...) {
    return new IOError.FAILED("%s: %s", message.vprintf(va_list()),
        strerror(errno));
}

// just provides a convenience function
class InputWrap : Object {
    public InputStream stream {construct; get;}

    public new async void read_all(uint8[] buffer) throws Error {
        size_t _;
        yield stream.read_all_async(buffer, Priority.DEFAULT, null, out _);
    }

    public async void skip(ssize_t length) throws IOError {
        yield stream.skip_async(length);
    }

    public InputWrap(InputStream stream) {
        Object(stream: stream);
    }
}

class TTY : Object {
    public InputWrap @in {construct; get;}
    public OutputStream @out {construct; get;}

    public TTY(string tty_path) throws IOError {
        var tty_fd = Posix.open((!) tty_path, Posix.O_RDWR);
        if (tty_fd == -1)
            throw ioerror("Failed to open TTY '%s'", tty_path);
        if (!Posix.isatty(tty_fd))
            throw new IOError.FAILED("File '%s' is not a TTY", tty_path);

        Posix.termios termios;
        if (Posix.tcgetattr(tty_fd, out termios) == -1)
            throw ioerror("Failed getting TTY settings");
        Posix.cfmakeraw(ref termios);
        if (Posix.cfsetspeed(ref termios, Posix.B57600) == -1)
            throw ioerror("Failed setting TTY baud rate");
        if (Posix.tcsetattr(tty_fd, 0, termios) == -1)
            throw ioerror("Failed setting TTY settings");

        Object(@in: new InputWrap(new UnixInputStream(tty_fd, false)),
            @out: new UnixOutputStream(tty_fd, false));
    }
}

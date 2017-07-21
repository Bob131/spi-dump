// ptsname is missing from posix.vapi
[CCode (type = "char*")]
extern unowned string ptsname (int file_descriptor);

async void loop (TTY tty) {
    var buf = new uint8[1];

    try {
        while (true) {
            yield tty.in.read_all (buf);

            switch (buf[0]) {
                case 0x03:
                    yield tty.in.skip (3);
                    for (var i = 0; i < 4; i++)
                        yield tty.out.write_async ({0x00});
                    break;

                case 0x00:
                    yield tty.out.write_async ({0x00});
                    break;

                case 0xFF:
                    yield tty.in.read_all (buf);
                    yield tty.out.write_async ({buf[0] ^ 0xFF});
                    break;

                default:
                    assert_not_reached ();
            }
        }
    } catch (Error e) {
        stderr.printf ("Operation failed: %s\n", e.message);
        Posix.exit (Posix.EXIT_FAILURE);
    }
}

int main(string[] args) {
    var fd = Posix.posix_openpt (Posix.O_RDWR | Posix.O_NOCTTY);

    if (fd == -1)
        error ("Failed to create PTY: %s", strerror (errno));

    if (Posix.grantpt (fd) == -1)
        error ("Failed to set PTY permissions: %s", strerror (errno));

    if (Posix.unlockpt (fd) == -1)
        error ("Failed to unlock PTY: %s", strerror (errno));

    message ("Successfully opened PTY %s", ptsname (fd));

    var mainloop = new MainLoop ();

    TTY tty;
    try {
        tty = new TTY.from_fd (fd);
    } catch (IOError e) {
        error ("Failed to init TTY: %s", e.message);
    }

    loop.begin (tty);

    mainloop.run ();

    return 0;
}

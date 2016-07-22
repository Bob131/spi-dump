[CCode (cname = "g_io_error_from_errno", type = "GIOErrorEnum")]
extern int ioerr_from_errno(int err_no);
[PrintfFormat]
IOError ioerror(string message, ...) {
    return (IOError) new Error(IOError.quark(),
        ioerr_from_errno(Posix.errno),
        "%s: %s".printf(message.vprintf(va_list()),
        Posix.strerror(Posix.errno)));
}

class TTY : Object {
    public InputStream @in {construct; get;}
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

        Object(@in: new UnixInputStream(tty_fd, false),
            @out: new UnixOutputStream(tty_fd, false));
    }
}

string seconds_to_readable(double seconds) {
    return "%.0fm%02.0fs".printf(Math.floor(seconds / 60), seconds % 60);
}

class ProgressBar : Object {
    public uint32 num_bytes {construct; get;}
    public uint32 bytes_read {set; get; default = 0;}
    public string status {set; get;}

    Timer timer = new Timer();
    uint64 avg = 0;

    public double elapsed {get {return timer.elapsed();}}

    void paint(bool recalc_avg = false) {
        Linux.winsize ws;
        Linux.ioctl(stdout.fileno(), Linux.Termios.TIOCGWINSZ, out ws);
        var avail = ws.ws_col - 2;

        var right_justify = "  ";

        if (recalc_avg) {
            var time = timer.elapsed();
            avg = (uint64) Math.ceil(bytes_read / time);
        }
        if (avg != 0) {
            right_justify += "%s/s  ".printf(format_size((uint64) avg));
            right_justify += "ETA %s  ".printf(
                seconds_to_readable((num_bytes-bytes_read)/avg));
        }

        double percent = (bytes_read / (double) num_bytes) * 100;
        right_justify += "%4.1f%% ".printf(percent);

        stderr.printf(" %-*s %s\r", avail-right_justify.length, status,
            right_justify);
    }

    public ProgressBar(uint32 num_bytes) {
        Object(num_bytes: num_bytes);
        this.notify["bytes-read"].connect(() => {paint(true);});
        this.notify["status"].connect(() => {paint();});
        timer.start();
    }
}

class Transfer : Object {
    public TTY tty {construct; get;}

    async void read_all(InputStream stream, uint8[] buffer) throws Error {
        size_t _;
        yield stream.read_all_async(buffer, Priority.DEFAULT, null, out _);
    }

    public async void do_transfer(OutputStream stream, uint32 num_bytes)
        throws Error
    {
        message("Beginning SPI transfer...");

        var byte = new uint8[1];
        uint32 bytes_read = 0;
        var progress = new ProgressBar(num_bytes);
        var read_count = 0;
        var checksum_fails = 0;

        try {
            while (bytes_read < num_bytes) {
                progress.status = "Downloading";

                assert (bytes_read < 0xFFFFFF);

                // 0x03: Read array opcode
                // address bytes are big-endian
                uint8[4] send_buffer = {0x03,
                     (uint8) (bytes_read >> 16 & 0xff),
                     (uint8) (bytes_read >> 8  & 0xff),
                     (uint8) (bytes_read       & 0xff)};

                // we don't have to escape 0xFF in send_buffer since there
                // shouldn't ever be an 0xFF byte in the address

                var buffer = new uint8[
                    uint32.min(2048, num_bytes - bytes_read)];
                ulong checksum = 0;
                while (true) {
                    // pull chip select low
                    tty.out.write_async.begin({0xff, 0x01});
                    yield read_all(tty.in, byte);
                    // the arduino should send us back 0x01 XOR'd against 0xff
                    if (byte[0] != 0xfe)
                        throw new IOError.FAILED(
                            "Failed to pull chip select low. Aborting");

                    tty.out.write_async.begin(send_buffer);
                    yield tty.in.skip_async(send_buffer.length);

                    for (var i = 0; i < buffer.length; i++) {
                        tty.out.write_async.begin({0x00});
                        yield read_all(tty.in, byte);
                        buffer[i] = byte[0];
                    }

                    tty.out.write_async.begin({0xff, 0x2});
                    yield read_all(tty.in, byte);
                    if (byte[0] != 0xfd)
                        throw new IOError.FAILED(
                            "Failed to pull chip select high. Aborting");

                    read_count++;

                    var current_checksum =
                        ZLib.Utility.crc32(ZLib.Utility.crc32(), buffer);
                    if (checksum == 0) {
                        checksum = current_checksum;
                        progress.status = "Verifying";
                    } else if (current_checksum == checksum) {
                        break;
                    } else {
                        checksum_fails++;
                        checksum = 0;
                        progress.status = "Redownloading (CRC mismatch)";
                    }
                }

                bytes_read += buffer.length;
                progress.bytes_read = bytes_read;
                stream.write_bytes_async.begin(new Bytes.take(buffer));
            }
            stderr.printf("\nDone! (%s)\n",
                seconds_to_readable(progress.elapsed));
            stderr.printf(
                "Read %u byte%s in %d read%s, including %d retr%s\n",
                bytes_read, bytes_read == 1 ? "" : "s",
                read_count, read_count == 1 ? "" : "s",
                checksum_fails, checksum_fails == 1 ? "y" : "ies");
        } catch (Error e) {
            throw e;
        } finally {
            try {
                // pull chip select high, finishing the transfer
                yield tty.out.write_async({0xff, 0x2});
            } catch (IOError e) {
                warning("Failed toggling CS pin: %s. Please reset your Arduino",
                    e.message);
            } finally {
                SourceFunc cb = do_transfer.callback;
                if (stream.has_pending()) {
                    Idle.add((owned) cb);
                    yield;
                }
                try {
                    yield stream.flush_async();
                } catch (Error e) {
                    warning("Failed to flush data to disk: %s", e.message);
                }
            }
        }
    }

    public Transfer(TTY tty) {
        Object(tty: tty);
    }
}

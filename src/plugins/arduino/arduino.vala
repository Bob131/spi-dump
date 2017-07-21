[PrintfFormat]
IOError ioerror (string message, ...) {
    return new IOError.FAILED ("%s: %s", message.vprintf (va_list ()),
        strerror (errno));
}

class Arduino.TTY : SpiDump.DeviceIOStream {
    public override async void set_chip_select (SpiDump.PinState state)
        throws Error
    {
        uint8 command = state == SpiDump.PinState.LOW ? 0x1 : 0x2;

        this.@out.write_all.begin ({0xFF, command});

        if ((yield this.@in.read_byte ()) != (command ^ 0xFF))
            throw new IOError.FAILED ("Invalid response");
    }

    public TTY.from_fd (int tty_fd) throws IOError {
        Posix.termios termios;

        if (Posix.tcgetattr (tty_fd, out termios) == -1)
            throw ioerror ("Failed getting TTY settings");

        Posix.cfmakeraw (ref termios);
        if (Posix.cfsetspeed (ref termios, Posix.B57600) == -1)
            throw ioerror ("Failed setting TTY baud rate");
        if (Posix.tcsetattr (tty_fd, 0, termios) == -1)
            throw ioerror ("Failed setting TTY settings");

        Object (
            @in: new SpiDump.SimpleDeviceInputStream (
                new UnixInputStream (tty_fd, false)
            ),
            @out: new SpiDump.SimpleDeviceOutputStream (
                new UnixOutputStream (tty_fd, false)
            )
        );
    }

    public TTY (string tty_path) throws IOError {
        var tty_fd = Posix.open ((!) tty_path, Posix.O_RDWR);

        if (tty_fd == -1)
            throw ioerror ("Failed to open TTY '%s'", tty_path);
        if (!Posix.isatty (tty_fd))
            throw new IOError.FAILED ("File '%s' is not a TTY", tty_path);

        this.from_fd (tty_fd);
    }
}

class Arduino.Plugin : Object, SpiDump.HardwarePlugin {
    string tty_path;

    public OptionEntry[] get_options () {
        return {
            OptionEntry () {
                long_name = "tty",
                arg = OptionArg.FILENAME,
                arg_data = &tty_path,
                description = "Path to Arduino serial console",
                arg_description = "/dev/ttyUSB0"
            }
        };
    }

    public SpiDump.DeviceIOStream open () throws Error {
        if ((void*) tty_path == null)
            throw new SpiDump.HardwarePluginError.INVALID_ARGS (
                "TTY path not specified"
            );

        return new TTY (tty_path);
    }
}

[ModuleInit]
public void peas_register_types (TypeModule module) {
    ((Peas.ObjectModule) module).register_extension_type (
        typeof (SpiDump.HardwarePlugin),
        typeof (Arduino.Plugin)
    );
}

[NoReturn]
[PrintfFormat]
void error(string message, ...) {
    stderr.printf("** ERROR: %s\n", message.vprintf(va_list()));
    Posix.exit(1);
}

class app : Application {
    bool force = false;
    uint64 num_bytes = 128;
    string output_path = "eeprom.bin";

    internal override void open(File[] files, string hint) {
        // we use a 64 bit int to make dealing with GLib's command line
        // parser a little easier
        if (num_bytes > 0xFFFFFF)
            error(@"Can't read more than $(0xFFFFFF) bytes over SPI");

        if (files.length != 1)
            error("Please provide only one TTY path");

        TTY tty;
        try {
            tty = new TTY(files[0]);
        } catch (IOError e) {
            error(e.message);
        }

        var output_file = File.new_for_commandline_arg(output_path);

        var can_overwrite = force;
        if (!can_overwrite && output_file.query_exists()) {
            FileInfo info;
            try {
                info = output_file.query_info(FileAttribute.STANDARD_SIZE, 0);
            } catch (Error e) {
                error("Cannot access '%s': %s", output_path, e.message);
            }
            if (info.get_size() == 0)
                can_overwrite = true;
            else
                can_overwrite = false;
        }
        if (!can_overwrite)
            error("File '%s' exists and is non-empty. Use --force to overwrite",
                output_path);

        OutputStream stream;
        try {
            stream = new BufferedOutputStream(
                output_file.replace(null, false, 0));
        } catch (Error e) {
            error("Failed to create '%s': %s", output_path, e.message);
        }

        var transfer = new Transfer(tty);
        this.hold();
        transfer.do_transfer.begin(stream, (uint32) num_bytes,
            (obj, res) => {
                try {
                    transfer.do_transfer.end(res);
                } catch (Error e) {
                    warning(e.message);
                }
                this.release();
            });
    }

    internal override void activate() {
        error("You must provide the TTY to open");
    }

    app() {
        Object(flags: ApplicationFlags.HANDLES_OPEN);

        var opts = new OptionEntry[4];
        opts[0] = {"force", 'f', 0, OptionArg.NONE, ref force,
            "Don't ask whether overwriting the output file is okay"};
        opts[1] = {"num", 'n', 0, OptionArg.INT64, ref num_bytes,
            "Number of bytes to read from the tty", num_bytes.to_string()};
        opts[2] = {"output", 'o', 0, OptionArg.FILENAME, ref output_path,
            "File to write the output into", output_path};
        opts[3] = {(string) null};
        this.add_main_option_entries(opts);
    }

    public static int main(string[] args) {
        return new app().run(args);
    }
}

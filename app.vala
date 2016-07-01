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
        if (output_file.query_exists() && !force) {
            var resp = Readline.readline(
                "Warning: File '%s' exists. Overwrite? [y/N] ".printf(
                output_path));
            if (resp != null)
                resp = ((!) resp).down();
            if (resp == "y" || resp == "yes") {
                stdout.printf("Aborting\n");
                return;
            }
            try {
                output_file.delete();
            } catch (Error e) {
                error(e.message);
            }
        }

        var transfer = new Transfer(tty);
        this.hold();
        transfer.do_transfer.begin(output_file, (uint32) num_bytes,
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

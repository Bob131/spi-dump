[CCode (cname = "G_OPTION_REMAINING")]
extern const string OPTION_REMAINING;

extern const string PLUGINDIR;

[NoReturn]
[PrintfFormat]
void error(string message, ...) {
    stderr.printf("** ERROR: %s\n", message.vprintf(va_list()));
    Posix.exit(Posix.EXIT_FAILURE);
}

class SpiDump : Application {
    int64 num_bytes = 128;
    string output_path = "eeprom.bin";
    bool force = false;

    [CCode (array_null_terminated = true)]
    string[] tty_path = {};

    internal override void activate() {
        // we use a 64 bit int to make dealing with GLib's command line
        // parser a little easier, since it only supports signed values
        if (num_bytes > 0xFFFFFF)
            error(@"Can't read more than $(0xFFFFFF) bytes over SPI");
        else if (num_bytes < 1)
            error("-n must be greater than 0");

        if (tty_path.length < 1)
            error("You must provide the TTY to open");
        if (tty_path.length > 1)
            error("Please provide only one TTY path");

        TTY tty;
        try {
            tty = new TTY(tty_path[0]);
        } catch (IOError e) {
            error(e.message);
        }

        var output_file = File.new_for_commandline_arg(output_path);

        bool can_overwrite;
        if (!(can_overwrite = force || !output_file.query_exists())) {
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

        var num_bytes_truncated = (uint32) (num_bytes & 0xFFFFFFF);

        var transfer = new Transfer(tty);
        var progress = new ProgressBar("", num_bytes_truncated);

        transfer.notify["bytes-read"].connect(
            () => progress.update(transfer.bytes_read));
        transfer.notify["status"].connect(
            () => progress.update_label(transfer.status.to_string()));

        this.hold();
        transfer.do_transfer.begin(stream, num_bytes_truncated, (obj, res) => {
            try {
                transfer.do_transfer.end(res);

                var seconds = time_t() - progress.start;
                stderr.printf("\nDone! (%.0fm%02.0fs)\n",
                    Math.floor(seconds / 60), seconds % 60);

                stderr.printf(
                    "Read %u byte%s in %u read%s, including %u retr%s\n",
                    transfer.bytes_read, transfer.bytes_read == 1 ? "" : "s",
                    transfer.read_count, transfer.read_count == 1 ? "" : "s",
                    transfer.checksum_fails,
                    transfer.checksum_fails == 1 ? "y" : "ies");
            } catch (Error e) {
                warning(e.message);
            }
            this.release();
        });
    }

    SpiDump() {
        Object(flags: ApplicationFlags.NON_UNIQUE);

        var opts = new OptionEntry[5];
        // hard-code "128" since some sort of buffer overrun was happening
        opts[0] = {"num", 'n', 0, OptionArg.INT64, ref num_bytes,
            "Number of bytes to read from the tty", "128"};
        opts[1] = {"output", 'o', 0, OptionArg.FILENAME, ref output_path,
            "Output file path", output_path};
        opts[2] = {"force", 'f', 0, OptionArg.NONE, ref force,
            "Overwrite output file"};
        opts[3] = {OPTION_REMAINING, 0, 0, OptionArg.FILENAME_ARRAY,
            ref tty_path, "", "TTY"};
        opts[4] = {(string) null};
        this.add_main_option_entries(opts);
    }

    public static int main(string[] args) {
        return new SpiDump().run(args);
    }
}

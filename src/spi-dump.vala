[CCode (cname = "G_OPTION_REMAINING")]
extern const string OPTION_REMAINING;

extern const string PLUGINDIR;

const string PLUGIN_PATH_ENV = "SPI_DUMP_PLUGIN_PATH";
const int64 MAX_SPI_READ = (1 << 24) - 1;

[NoReturn]
[PrintfFormat]
void error (string message, ...) {
    stderr.printf ("** ERROR: %s\n", message.vprintf (va_list ()));
    Posix.exit (Posix.EXIT_FAILURE);
}

SpiDump.HardwarePlugin extension;
[CCode (array_length = false, array_null_terminated = true)]
string[] filenames;

public int main (string[] args) {
    var args_copy = args;

    string? plugin_path = null;
    string cable = "";
    int64 num_bytes = 128;
    bool force = false;

    var option_context = new OptionContext ("OUTPUT-FILE");
    option_context.set_help_enabled (false);
    option_context.set_ignore_unknown_options (true);

    option_context.add_main_entries ({
        OptionEntry () {
            long_name = "cable",
            short_name = 'c',
            arg = OptionArg.STRING,
            arg_data = &cable,
            description = "The cable type to use. "
                + "Specify '?' to list supported cables",
            arg_description = "CABLE"
        },

        OptionEntry () {
            long_name = "plugin-path",
            arg = OptionArg.STRING,
            arg_data = &plugin_path,
            description = "Path to cable plugins",
            arg_description = "PATH"
        },

        OptionEntry () {
            long_name = "num",
            short_name = 'n',
            arg = OptionArg.INT64,
            arg_data = &num_bytes,
            description = "Number of bytes to read from the device",
            arg_description = "128"
        },

        OptionEntry () {
            long_name = "force",
            arg_data = &force,
            description = "Overwrite output file"
        }
    }, null);

    try {
        option_context.parse_strv (ref args_copy);
    } catch (OptionError e) {
        error (e.message);
    }

    var plugins = new PluginEngine<SpiDump.HardwarePlugin> ();
    plugins.add_search_path (PLUGINDIR);
    plugins.prepend_search_path (
        Path.build_filename (Environment.get_home_dir (), ".local", "lib",
            "spi-dump", "plugins")
    );

    if (plugin_path != null)
        plugins.prepend_search_path (
            Path.build_filename (Environment.get_current_dir (),
                (!) plugin_path)
        );

    if (Environment.get_variable (PLUGIN_PATH_ENV) != null)
        plugins.prepend_search_path (
            (!) Environment.get_variable (PLUGIN_PATH_ENV)
        );

    switch (cable) {
        case "?":
            stderr.printf ("Known cables:\n");

            foreach (unowned Peas.PluginInfo plugin in plugins.get_all ())
                stderr.printf ("  %s\t%s\n", plugin.get_name (),
                    plugin.get_description ());

            return 0;

        case "":
            break;

        default:
            unowned List<SpiDump.HardwarePlugin> extensions;
            try {
                extensions = plugins[cable];
            } catch (PluginError e) {
                error ("Failed to load cable plugin: %s", e.message);
            }

            assert (extensions.length () == 1);
            extension = extensions.nth_data (0);

            var cable_options = new OptionGroup (
                cable,
                @"Options for cable '$cable':",
                "Show cable help options"
            );
            cable_options.add_entries (extension.get_options ());
            option_context.add_group ((owned) cable_options);

            break;
    }

    option_context.set_help_enabled (true);
    option_context.set_ignore_unknown_options (false);

    option_context.add_main_entries ({
        OptionEntry () {
            long_name = OPTION_REMAINING,
            arg = OptionArg.FILENAME_ARRAY,
            arg_data = &filenames
        }
    }, null);

    try {
        option_context.parse_strv (ref args_copy);
    } catch (OptionError e) {
        error (e.message);
    }

    if (cable == "")
        error ("No cable specified!");

    assert ((void*) extension != null);

    if (filenames.length == 0)
        error ("You must provide a file path to save");
    else if (filenames.length > 1)
        error ("Unrecognized extra options");

    var output_file = File.new_for_commandline_arg (filenames[0]);

    bool can_overwrite;

    if (!(can_overwrite = force || !output_file.query_exists ())) {
        FileInfo info;
        try {
            info = output_file.query_info (
                string.joinv (",", new string?[] {
                    FileAttribute.STANDARD_SIZE,
                    FileAttribute.STANDARD_TYPE
                }),
                FileQueryInfoFlags.NONE
            );
        } catch (Error e) {
            error ("Cannot access '%s': %s", filenames[0], e.message);
        }

        if (info.get_file_type () == FileType.DIRECTORY)
            error ("Cannot open file: is a directory");

        if (info.get_size () == 0)
            can_overwrite = true;
        else
            can_overwrite = false;
    }

    if (!can_overwrite)
        error (
            "File '%s' exists and is non-empty. Use --force to overwrite",
            filenames[0]
        );

    // We use a 64 bit int to make dealing with GLib's command line
    // parser a little easier, since it only supports signed values.
    if (num_bytes > MAX_SPI_READ)
        error (@"Can't read more than %s bytes over SPI",
               MAX_SPI_READ.to_string ("0x%lX"));
    else if (num_bytes < 1)
        error ("-n must be greater than 0");

    OutputStream file_stream;
    try {
        file_stream = new BufferedOutputStream (
            output_file.replace (null, false, FileCreateFlags.NONE)
        );
    } catch (Error e) {
        error ("Failed to create '%s': %s", filenames[0], e.message);
    }

    SpiDump.DeviceIOStream device_stream;
    try {
        device_stream = extension.open ();
    } catch (Error e) {
        if (e is SpiDump.HardwarePluginError)
            error (e.message);
        error ("Failed to open device: %s", e.message);
    }

    var num_bytes_truncated = (uint32) (num_bytes & MAX_SPI_READ);

    var transfer = new Transfer (device_stream);
    var progress = new ProgressBar ("", num_bytes_truncated);

    transfer.notify["bytes-read"].connect (
        () => progress.update (transfer.bytes_read)
    );

    transfer.notify["status"].connect (
        () => progress.update_label (transfer.status.to_string ())
    );

    var main_loop = new MainLoop ();

    transfer.write.begin (file_stream, num_bytes_truncated, (obj, res) => {
        try {
            transfer.write.end (res);
        } catch (Error e) {
            warning (e.message);
            main_loop.quit ();
            return;
        }

        var seconds = time_t () - progress.start;
        stderr.printf ("\nDone! (%.0fm%02.0fs)\n",
            Math.floor (seconds / 60), seconds % 60);

        stderr.printf ("Read %u byte%s in %u read%s, including %u retr%s\n",
            transfer.bytes_read, transfer.bytes_read == 1 ? "" : "s",
            transfer.read_count, transfer.read_count == 1 ? "" : "s",
            transfer.checksum_fails,
            transfer.checksum_fails == 1 ? "y" : "ies");

        main_loop.quit ();
    });

    main_loop.run ();

    return 0;
}

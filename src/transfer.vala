string seconds_to_readable(double seconds) {
    return "%.0fm%02.0fs".printf(Math.floor(seconds / 60), seconds % 60);
}

class Transfer : Object {
    public TTY tty {construct; get;}

    public async void do_transfer(OutputStream stream, uint32 num_bytes)
        throws Error
    {
        message("Beginning SPI transfer...");

        var byte = new uint8[1];
        uint32 bytes_read = 0;
        var progress = new ProgressBar("", num_bytes);
        var read_count = 0;
        var checksum_fails = 0;

        try {
            while (bytes_read < num_bytes) {
                progress.update_label("Downloading");

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
                    yield tty.in.read_all(byte);
                    // the arduino should send us back 0x01 XOR'd against 0xff
                    if (byte[0] != 0xfe)
                        throw new IOError.FAILED(
                            "Failed to pull chip select low. Aborting");

                    tty.out.write_async.begin(send_buffer);
                    yield tty.in.skip(send_buffer.length);

                    for (var i = 0; i < buffer.length; i++) {
                        tty.out.write_async.begin({0x00});
                        yield tty.in.read_all(byte);
                        buffer[i] = byte[0];
                    }

                    tty.out.write_async.begin({0xff, 0x2});
                    yield tty.in.read_all(byte);
                    if (byte[0] != 0xfd)
                        throw new IOError.FAILED(
                            "Failed to pull chip select high. Aborting");

                    read_count++;

                    var current_checksum =
                        ZLib.Utility.crc32(ZLib.Utility.crc32(), buffer);
                    if (checksum == 0) {
                        checksum = current_checksum;
                        progress.update_label("Verifying");
                    } else if (current_checksum == checksum) {
                        break;
                    } else {
                        checksum_fails++;
                        checksum = 0;
                        progress.update_label("Redownloading (CRC mismatch)");
                    }
                }

                bytes_read += buffer.length;
                progress.update(bytes_read);
                stream.write_bytes_async.begin(new Bytes.take(buffer));
            }
            stderr.printf("\nDone! (%s)\n",
                seconds_to_readable(time_t() - progress.start));
            stderr.printf(
                "Read %u byte%s in %d read%s, including %d retr%s\n",
                bytes_read, bytes_read == 1 ? "" : "s",
                read_count, read_count == 1 ? "" : "s",
                checksum_fails, checksum_fails == 1 ? "y" : "ies");
        } catch (Error e) {
            throw e;
        } finally {
            // finally code in a different function so we don't overwrite this
            // function's GError
            yield transfer_cleanup(stream);
        }
    }

    async void transfer_cleanup(OutputStream stream) {
        try {
            // pull chip select high, finishing the transfer
            yield tty.out.write_async({0xff, 0x2});
        } catch (IOError e) {
            warning("Failed toggling CS pin: %s. Please reset your Arduino",
                e.message);
        }

        while (stream.has_pending()) {
            Idle.add(transfer_cleanup.callback);
            yield;
        }

        try {
            yield stream.flush_async();
        } catch (Error e) {
            warning("Failed to flush data to disk: %s", e.message);
        }
    }

    public Transfer(TTY tty) {
        Object(tty: tty);
    }
}

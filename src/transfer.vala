enum TransferStatus {
    STOPPED,
    DOWNLOADING,
    VERIFYING,
    REDOWNLOADING;

    public string to_string() {
        switch (this) {
            case STOPPED:
                return "Stopped";
            case DOWNLOADING:
                return "Downloading";
            case VERIFYING:
                return "Verifying";
            case REDOWNLOADING:
                return "Redownloading (CRC mismatch)";
            default:
                assert_not_reached();
        }
    }
}

class Transfer : Object {
    public TTY tty {construct; get;}
    public TransferStatus status {private set; get;}

    public uint bytes_read {private set; get;}
    public uint read_count {private set; get;}
    public uint checksum_fails {private set; get;}

    public async void do_transfer(OutputStream stream, uint32 num_bytes)
        throws Error
    {
        try {
            var byte = new uint8[1];

            while (bytes_read < num_bytes) {
                status = TransferStatus.DOWNLOADING;

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
                        status = TransferStatus.VERIFYING;
                    } else if (current_checksum == checksum) {
                        break;
                    } else {
                        checksum_fails++;
                        checksum = 0;
                        status = TransferStatus.REDOWNLOADING;
                    }
                }

                bytes_read += buffer.length;
                stream.write_bytes_async.begin(new Bytes.take(buffer));
            }
        } catch (Error e) {
            throw e;
        } finally {
            // finally code in a different function so we don't overwrite this
            // function's GError
            yield transfer_cleanup(stream);
            status = TransferStatus.STOPPED;
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

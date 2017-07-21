enum TransferStatus {
    STOPPED,
    DOWNLOADING,
    VERIFYING,
    REDOWNLOADING;

    public string to_string () {
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
                assert_not_reached ();
        }
    }
}

class Transfer : Object {
    public SpiDump.DeviceIOStream device {construct; get;}
    public TransferStatus status {private set; get;}

    public uint32 bytes_read {private set; get;}
    public uint32 read_count {private set; get;}
    public uint32 checksum_fails {private set; get;}

    public async void write (OutputStream file, uint32 num_bytes)
        throws Error
    {
        try {
            var byte = new uint8[1];

            while (bytes_read < num_bytes) {
                status = TransferStatus.DOWNLOADING;

                assert (bytes_read < MAX_SPI_READ);

                // 0x03: Read array opcode
                // address bytes are big-endian
                uint8[4] send_buffer = {
                    0x03,
                    (uint8) (bytes_read >> 16 & 0xFF),
                    (uint8) (bytes_read >> 8  & 0xFF),
                    (uint8) (bytes_read       & 0xFF)
                };

                // we don't have to escape 0xFF in send_buffer since there
                // shouldn't ever be an 0xFF byte in the address

                var buffer = new uint8[
                    uint32.min(2048, num_bytes - bytes_read)
                ];
                ulong checksum = 0;

                while (true) {
                    yield device.set_chip_select (SpiDump.PinState.LOW);

                    device.out.write_async.begin (send_buffer);
                    yield device.in.skip (send_buffer.length);

                    for (var i = 0; i < buffer.length; i++) {
                        device.out.write_async.begin ({0x00});
                        yield device.in.read_all (byte);
                        buffer[i] = byte[0];
                    }

                    yield device.set_chip_select (SpiDump.PinState.HIGH);

                    read_count++;

                    var current_checksum =
                        ZLib.Utility.crc32 (ZLib.Utility.crc32 (), buffer);

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
                file.write_bytes_async.begin (new Bytes.take (buffer));
            }

        } catch (Error e) {
            throw e;
        } finally {
            // finally code in a different function so we don't overwrite this
            // function's GError
            yield transfer_cleanup (file);
            status = TransferStatus.STOPPED;
        }
    }

    async void transfer_cleanup (OutputStream stream) {
        try {
            yield device.set_chip_select (SpiDump.PinState.HIGH);
        } catch (Error e) {
            warning ("Failed toggling CS pin: %s", e.message);
        }

        while (stream.has_pending ()) {
            Idle.add (transfer_cleanup.callback);
            yield;
        }

        try {
            yield stream.flush_async ();
        } catch (Error e) {
            warning ("Failed to flush data to disk: %s", e.message);
        }
    }

    public Transfer (SpiDump.DeviceIOStream device) {
        Object (device: device);
    }
}

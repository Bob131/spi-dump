namespace SpiDump {
    public enum PinState {
        LOW, HIGH
    }

    public errordomain HardwarePluginError {
        INVALID_ARGS
    }

    public interface DeviceInputStream : InputStream {
        public new async void read_all (uint8[] buffer) throws Error {
            yield this.read_all_async (buffer, Priority.DEFAULT, null, null);
        }

        public async uint8 read_byte () throws Error {
            var ret = new uint8[1];
            yield read_all (ret);
            return ret[0];
        }

        public async void skip (ssize_t length) throws IOError {
            yield this.skip_async (length);
        }
    }

    public class SimpleDeviceInputStream : InputStream, DeviceInputStream {
        public InputStream inner {construct; get;}

        public override bool close (Cancellable? cancellable = null)
            throws IOError
        {
            return inner.close (cancellable);
        }

        public override async bool close_async (
            int io_priority = Priority.DEFAULT,
            Cancellable? cancellable = null
        )
            throws IOError
        {
            return yield inner.close_async ();
        }

        public override ssize_t skip (
            size_t count,
            Cancellable? cancellable = null
        )
            throws IOError
        {
            return inner.skip (count, cancellable);
        }

        public override async ssize_t skip_async (
            size_t count,
            int io_priority = Priority.DEFAULT,
            Cancellable? cancellable = null
        )
            throws IOError
        {
            return yield inner.skip_async (count, io_priority, cancellable);
        }

        public override ssize_t read (
            uint8[] buffer,
            Cancellable? cancellable = null
        )
            throws IOError
        {
            return inner.read (buffer, cancellable);
        }

        public override async ssize_t read_async (
            uint8[]? buffer,
            int io_priority = Priority.DEFAULT,
            Cancellable? cancellable = null
        )
            throws IOError
        {
            return yield inner.read_async (buffer, io_priority, cancellable);
        }

        public SimpleDeviceInputStream (InputStream inner) {
            Object (inner: inner);
        }
    }

    public interface DeviceOutputStream : OutputStream {
        public new async void write_all (uint8[] buffer) throws Error {
            yield this.write_all_async (buffer, Priority.DEFAULT, null, null);
        }
    }

    public class SimpleDeviceOutputStream : OutputStream, DeviceOutputStream {
        public OutputStream inner {construct; get;}

        public override bool close (Cancellable? cancellable = null)
            throws IOError
        {
            return inner.close (cancellable);
        }

        public override async bool close_async (
            int io_priority = Priority.DEFAULT,
            Cancellable? cancellable = null
        )
            throws IOError
        {
            return yield inner.close_async ();
        }

        public override bool flush (Cancellable? cancellable = null)
            throws Error
        {
            return inner.flush (cancellable);
        }

        public override async bool flush_async (
            int io_priority = Priority.DEFAULT,
            Cancellable? cancellable = null
        )
            throws Error
        {
            return yield inner.flush_async (io_priority, cancellable);
        }

        public override ssize_t write (
            uint8[] buffer,
            Cancellable? cancellable = null
        )
            throws IOError
        {
            return inner.write (buffer, cancellable);
        }

        public override async ssize_t write_async (
            uint8[]? buffer,
            int io_priority = Priority.DEFAULT,
            Cancellable? cancellable = null
        )
            throws IOError
        {
            return yield inner.write_async (buffer, io_priority, cancellable);
        }

        public SimpleDeviceOutputStream (OutputStream inner) {
            Object (inner: inner);
        }
    }

    public abstract class DeviceIOStream : Object {
        public DeviceInputStream @in {construct; get;}
        public DeviceOutputStream @out {construct; get;}

        public abstract async void set_chip_select (PinState state)
            throws Error;
    }

    public interface HardwarePlugin : Object {
        [CCode (array_length = false, array_null_terminated = true)]
        public abstract OptionEntry[] get_options ();
        public abstract DeviceIOStream open () throws Error;
    }
}

string seconds_to_readable(double seconds) {
    return "%.0fm%02.0fs".printf(Math.floor(seconds / 60), seconds % 60);
}

class ProgressBar : Object {
    public uint32 num_bytes {construct; get;}
    public uint32 bytes_read {set; get; default = 0;}
    public string status {set; get;}

    Timer timer = new Timer();
    uint64 avg = 0;

    public string elapsed {owned get {
        return seconds_to_readable(timer.elapsed());
    }}

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


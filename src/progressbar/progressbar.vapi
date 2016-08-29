[Compact]
[CCode (cheader_filename = "progressbar/progressbar.h", cname = "progressbar", lower_case_cprefix = "progressbar_")]
public class ProgressBar {
    public time_t start;
    public void update(ulong @value);
    public void update_label(string label);
    [DestroysInstance]
    public void finish();
    public ProgressBar(string label, ulong max);
}

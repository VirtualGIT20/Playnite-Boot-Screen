namespace PlayniteBoot.Models
{
    public class VideoOption
    {
        public VideoOption(string path, string label, string toolTip)
        {
            Path = path;
            Label = label;
            ToolTip = toolTip;
        }

        public string Path { get; }
        public string Label { get; }
        public string ToolTip { get; }
    }
}

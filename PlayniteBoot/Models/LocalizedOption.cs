namespace PlayniteBoot.Models
{
    public class LocalizedOption
    {
        public LocalizedOption(string value, string label)
        {
            Value = value;
            Label = label;
        }

        public string Value { get; }
        public string Label { get; }
    }
}

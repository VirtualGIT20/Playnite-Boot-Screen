namespace PlayniteBoot.Services
{
    public class CommandGenerator
    {
        private readonly RuntimePaths paths;

        public CommandGenerator(RuntimePaths paths)
        {
            this.paths = paths;
        }

        public string DirectCommand => BuildCommand(null);
        public string PreloadCommand => BuildCommand("Preload");
        public string ContinueCommand => BuildCommand("Continue");

        private string BuildCommand(string mode)
        {
            var command = $"\"{WindowsPowerShell.ExecutablePath}\" -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File \"{paths.ScriptPath}\"";
            return string.IsNullOrWhiteSpace(mode) ? command : $"{command} -Mode {mode}";
        }
    }
}

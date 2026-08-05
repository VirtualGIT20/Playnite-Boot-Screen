using System;
using System.IO;

namespace PlayniteBoot.Services
{
    public static class WindowsPowerShell
    {
        public static string ExecutablePath
        {
            get
            {
                var systemRoot = Environment.GetEnvironmentVariable("SystemRoot");
                if (string.IsNullOrWhiteSpace(systemRoot))
                {
                    systemRoot = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
                }

                var executablePath = Path.Combine(
                    systemRoot ?? string.Empty,
                    "System32",
                    "WindowsPowerShell",
                    "v1.0",
                    "powershell.exe");

                if (!File.Exists(executablePath))
                {
                    throw new FileNotFoundException(
                        "Windows PowerShell 5.1 executable was not found.",
                        executablePath);
                }

                return executablePath;
            }
        }
    }
}

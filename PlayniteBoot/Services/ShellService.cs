using System.Diagnostics;
using System.IO;

namespace PlayniteBoot.Services
{
    public static class ShellService
    {
        public static void OpenFolder(string path)
        {
            Directory.CreateDirectory(path);
            Process.Start(new ProcessStartInfo
            {
                FileName = path,
                UseShellExecute = true
            });
        }
    }
}

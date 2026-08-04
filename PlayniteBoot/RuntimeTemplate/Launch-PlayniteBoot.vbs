Option Explicit

Dim shell, fileSystem, scriptDirectory, launcherPath, powershellPath, command, result

Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

scriptDirectory = fileSystem.GetParentFolderName(WScript.ScriptFullName)
launcherPath = fileSystem.BuildPath(scriptDirectory, "PlayniteBoot.ps1")
powershellPath = shell.ExpandEnvironmentStrings("%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")

If Not fileSystem.FileExists(launcherPath) Then
    WScript.Quit 2
End If

If Not fileSystem.FileExists(powershellPath) Then
    WScript.Quit 3
End If

shell.CurrentDirectory = scriptDirectory
command = QuoteArgument(powershellPath) & _
    " -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File " & _
    QuoteArgument(launcherPath)

result = shell.Run(command, 0, False)
WScript.Quit result

Function QuoteArgument(ByVal value)
    QuoteArgument = Chr(34) & Replace(value, Chr(34), Chr(34) & Chr(34)) & Chr(34)
End Function

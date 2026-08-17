' Central System Checker - 100% Windowless & Silent Launcher
Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
currentDir = fso.GetParentFolderName(WScript.ScriptFullName)

' Ensure backend service is running with pythonw silently
backendScript = currentDir & "\backend\main.py"
WshShell.Run "cmd /c netstat -ano | findstr :18088 >nul || start """" pythonw """ & backendScript & """ --port 18088", 0, False

' Wait 1 second for backend
WScript.Sleep 1000

' Launch Release executable
exePath = currentDir & "\frontend\build\windows\x64\runner\Release\CentralSystemChecker.exe"
if fso.FileExists(exePath) Then
    WshShell.Run """" & exePath & """", 1, False
Else
    WshShell.Run "cmd /c cd /d """ & currentDir & "\frontend"" && flutter run -d windows", 1, False
End If

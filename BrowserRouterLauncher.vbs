Option Explicit

' ------------------------------------------------------------
' Browser Router invisible launcher
'
' Windows launches this script instead of powershell.exe.
' WScript runs without a console window.
'
' This file only starts PowerShell.
' All routing logic remains in BrowserRouter.ps1.
' ------------------------------------------------------------

Dim shell
Dim fso
Dim scriptDir
Dim routerScript
Dim url
Dim command
Dim quote


' Create Windows Shell and filesystem objects.
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")


' Double-quote character.
' Using Chr(34) makes the command easier to read
' and avoids complicated quote escaping.
quote = Chr(34)


' ------------------------------------------------------------
' Check for the URL
' ------------------------------------------------------------

If WScript.Arguments.Count = 0 Then
    WScript.Quit 1
End If


' ------------------------------------------------------------
' Find BrowserRouter.ps1
' ------------------------------------------------------------

' Get the directory containing this VBS file.
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)

' BrowserRouter.ps1 is in the same directory.
routerScript = fso.BuildPath(scriptDir, "BrowserRouter.ps1")


' Make sure the PowerShell script exists.
If Not fso.FileExists(routerScript) Then
    WScript.Quit 1
End If


' ------------------------------------------------------------
' Get the URL
' ------------------------------------------------------------

url = WScript.Arguments(0)


' ------------------------------------------------------------
' Build the PowerShell command
' ------------------------------------------------------------

command = "powershell.exe " & _
          "-NoProfile " & _
          "-WindowStyle Hidden " & _
          "-ExecutionPolicy RemoteSigned " & _
          "-File " & quote & routerScript & quote & " " & _
          quote & Replace(url, quote, quote & quote) & quote


' ------------------------------------------------------------
' Start PowerShell
' ------------------------------------------------------------

' 0     = hidden window
' False = do not wait for PowerShell to finish
shell.Run command, 0, False


' ------------------------------------------------------------
' Clean up
' ------------------------------------------------------------

Set fso = Nothing
Set shell = Nothing
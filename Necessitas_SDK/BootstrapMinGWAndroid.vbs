' This script sets up a MinGW and MSYS environment ready for Necessitas compilation
' It's a bit different from a 'normal' MinGW environment in that most of MSYS ends
' up in /usr/local (everything except the actual batch file).
dim WshShell
set WshShell = WScript.CreateObject("WScript.Shell")
WshShell.CurrentDirectory = WshShell.ExpandEnvironmentStrings("%TEMP%")

function downloadHTTP(sourceUrl,destFilepath)
	dim xmlhttp
	set xmlhttp=createobject("MSXML2.XMLHTTP.3.0")
	'xmlhttp.SetOption 2, 13056 'If https -> Ignore all SSL errors
	xmlhttp.Open "GET", sourceUrl, false
	xmlhttp.Send
	Wscript.Echo "Download-Status: " & xmlhttp.Status & " " & xmlhttp.statusText
  	if xmlhttp.Status = 200 then
		dim objStream
		set objStream = CreateObject("ADODB.Stream")
		objStream.Type = 1 'adTypeBinary
		objStream.Open
		objStream.Write xmlhttp.responseBody
		objStream.SaveToFile destFilepath, 2
		objStream.Close
	end if
end function

function run(ByVal command)
	dim shell
	set shell = CreateObject("WScript.Shell")
	shell.Run command, 1, true
end function

function copy(source,dest)
	dim FSO
	set FSO = CreateObject("Scripting.FileSystemObject")
	FSO.CopyFile source, dest
end function

function move(source,dest)
    dim FSO
    set FSO = CreateObject("Scripting.FileSystemObject")
    if FSO.FolderExists(source) then
        FSO.MoveFolder source, dest
    end if
end function

minGWInstaller=WshShell.CurrentDirectory & "\mingw-get-inst-20110530.exe"
gitInstaller=WshShell.CurrentDirectory & "\Git-1.7.4-preview20110204.exe"
wgetExe=WshShell.CurrentDirectory & "\wget.exe"
downloadHTTP "http://kent.dl.sourceforge.net/project/mingw/Automated%20MinGW%20Installer/mingw-get-inst/mingw-get-inst-20110530/mingw-get-inst-20110530.exe", minGWInstaller
downloadHTTP "http://msysgit.googlecode.com/files/Git-1.7.4-preview20110204.exe", gitInstaller
downloadHTTP "http://users.ugent.be/~bpuype/cgi-bin/fetch.pl?dl=wget/wget.exe", wgetExe
msgbox "Launching MinGW installer, Use pre-packaged repository," & vbcrlf & "install to C:\usr," & vbcrlf & "select C and C++ compilers," & vbcrlf & "MSYS Basic System and MinGW Developer Toolkit"
run minGWInstaller
msgbox "Launching Windows Git installer, install to C:\msys-git"
run gitInstaller
copy wgetExe,"C:\usr\bin\wget.exe"
run "cmd /c xcopy /S /R /Y C:\usr\msys\1.0 C:\usr"
run "cmd /c del /F /Q /S C:\usr\msys"
copy "C:\msys-git\bin\msys-1.0.dll","C:\usr\bin\msys-1.0.dll"
'run "cmd /c mkdir C:\usr\local"
'run "cmd /c xcopy /S /R /Y C:\usr\msys\1.0 C:\usr\local"
'run "cmd /c xcopy /S /R /Y C:\usr\local\msys.bat C:\usr\"
'run "cmd /c xcopy /S /R /Y C:\usr\local\bin\sh.exe C:\usr\bin"
'run "cmd /c xcopy /S /R /Y C:\usr\local\bin\msys-1.0.exe C:\usr\bin"
'run "cmd /c del /F /Q C:\usr\local\msys.bat"

@echo off
setlocal enableextensions enabledelayedexpansion

REM Ensure we're executing from this directory
cd /D "%~dp0"

if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" (
 	FOR /F "delims=" %%E in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\installer\vswhere.exe" -latest -property installationPath') DO (
 		set "MSBUILD_EXE=%%E\MSBuild\15.0\Bin\MSBuild.exe"
 		if exist "!MSBUILD_EXE!" goto :build
 	)
 )

FOR %%E in (Enterprise, Professional, Community) DO (
	set "MSBUILD_EXE=%ProgramFiles(x86)%\Microsoft Visual Studio\2017\%%E\MSBuild\15.0\Bin\MSBuild.exe"
	if exist "!MSBUILD_EXE!" goto :build
)

REM Couldn't be located in the standard locations, expand search
FOR /F "delims=" %%E IN ('dir /b /ad "%ProgramFiles(x86)%\Microsoft Visual Studio\"') DO (
  set "MSBUILD_EXE=%ProgramFiles(x86)%\Microsoft Visual Studio\%%E\MSBuild\15.0\Bin\MSBuild.exe"
	if exist "!MSBUILD_EXE!" goto :build

	FOR /F "delims=" %%F IN ('dir /b /ad "%ProgramFiles(x86)%\Microsoft Visual Studio\%%E"') DO (
		set "MSBUILD_EXE=%ProgramFiles(x86)%\Microsoft Visual Studio\%%E\%%F\MSBuild\15.0\Bin\MSBuild.exe"
		if exist "!MSBUILD_EXE!" goto :build
	)
)

echo Could not find MSBuild v15
exit /b 1

:build

echo Using MSBuild: '%MSBUILD_EXE%'
echo Syncing Git Submodules...

git submodule sync || goto :error
git submodule update --init --recursive || goto :error

echo Restoring solution...
"external\nuget-binary\NuGet.exe" restore Main.sln

"%MSBUILD_EXE%" external\fsharpbinding\.paket\paket.targets /t:RestorePackages /p:PaketReferences="%~dp0external\fsharpbinding\MonoDevelop.FSharpBinding\paket.references"

if not defined CONFIG (set "CONFIG=DebugWin32")
set "PLATFORM=Any CPU"

echo Building solution...
"%MSBUILD_EXE%" Main.sln /bl:MonoDevelop.binlog /r /m "/p:Configuration=%CONFIG%" "/p:Platform=%PLATFORM%" %* || goto :error
goto :eof

:error

for %%x in (%CMDCMDLINE%) do if /i "%%~x" == "/c" pause
exit /b %ERRORLEVEL%
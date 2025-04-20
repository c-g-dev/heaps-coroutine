@echo off
setlocal

if not exist "haxelib" mkdir haxelib

echo Deleting existing contents in haxelib folder...
del /q "haxelib\*"
for /d %%i in ("haxelib\*") do rmdir /s /q "%%i"

echo Copying files to haxelib folder...
for %%f in (*.*) do (
    if /i not "%%f"=="toHaxelib.bat" if /i not "%%f"=="build.hxml" (
        copy "%%f" "haxelib" /y >nul
    )
)

for /d %%d in (*) do (
    if /i not "%%d"=="bin" if /i not "%%d"=="haxelib" (
        xcopy "%%d" "haxelib\%%d" /e /i /y >nul
    )
)
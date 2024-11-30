@echo off
del /f /q ".\\mhypbase.dll"
cd ".\\FireflyDumper"
cargo build
move /y ".\\target\\debug\\mhypbase.dll" "..\\mhypbase.dll"
pause

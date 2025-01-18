@echo off
del /f /q ".\\mhypbase.dll"
cargo build
move /y ".\\target\\debug\\mhypbase.dll" ".\\mhypbase.dll"
pause

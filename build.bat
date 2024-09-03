@echo off
del /f /q ".\\mhypbase.dll"
cargo build --release
move /y ".\\target\\release\\mhypbase.dll" ".\\mhypbase.dll"
pause

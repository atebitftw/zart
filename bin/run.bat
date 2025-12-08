@echo off
if "%1"=="" (
    echo Please provide a game file.
    exit /b 1
)
dart run zart.dart %1

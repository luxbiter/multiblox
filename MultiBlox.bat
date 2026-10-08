@echo off
title MultiBlox - Roblox Multi-Instance Holder
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0MultiBlox.ps1" %*
pause

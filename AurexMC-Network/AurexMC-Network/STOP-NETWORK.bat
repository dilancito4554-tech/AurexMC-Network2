@echo off
title AurexMC Network - Parada de emergencia
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Stop-Network.ps1"

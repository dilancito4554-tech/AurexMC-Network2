@echo off
title AurexMC Network - Iniciando panel
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\NetworkManager.ps1"

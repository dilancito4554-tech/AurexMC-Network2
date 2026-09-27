@echo off
title AurexMC Network - Instalador
cd /d "%~dp0"

echo ====================================================
echo    AUREXMC NETWORK - INSTALADOR
echo ====================================================
echo.
echo Este proceso descargara Velocity, Paper y los plugins
echo base. Necesitas conexion a internet.
echo.
pause

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Install-Network.ps1"

echo.
echo Instalador finalizado. Puedes cerrar esta ventana.
pause >nul

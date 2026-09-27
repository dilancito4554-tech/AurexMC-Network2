<#
    AurexMC Network - Parada de emergencia
    ------------------------------------------------------------
    Usa esto SOLO si el panel de control (START-NETWORK.bat) se
    cerro sin detener la network correctamente. Este script no
    puede pedirle "stop" a los servidores (no tiene su entrada
    estandar), asi que hace un cierre forzado mediante taskkill.
    Es mejor detener siempre desde la opcion [3] del panel.
#>

$Root    = Split-Path -Parent $PSScriptRoot
$ToolsDir = Join-Path $Root "tools"
$PidFile = Join-Path $ToolsDir "aurexmc-pids.json"

Write-Host "===================================================="
Write-Host "   AUREXMC NETWORK - Parada de emergencia"
Write-Host "===================================================="
Write-Host ""
Write-Host "AVISO: esto fuerza el cierre de los procesos Java." -ForegroundColor Yellow
Write-Host "Puede no guardar el mundo correctamente. Usalo solo" -ForegroundColor Yellow
Write-Host "si el panel de control ya no esta disponible." -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path $PidFile)) {
    Write-Host "No hay registro de procesos en ejecucion (aurexmc-pids.json no existe)." -ForegroundColor Gray
    Write-Host "Puede que la network ya este detenida, o que nunca se haya iniciado desde el panel."
    Read-Host "Pulsa ENTER para cerrar"
    exit 0
}

$state = Get-Content $PidFile -Raw | ConvertFrom-Json
$anyFound = $false

foreach ($name in $state.PSObject.Properties.Name) {
    $procId = $state.$name
    try {
        $p = Get-Process -Id $procId -ErrorAction Stop
        if ($p.ProcessName -match "java") {
            Write-Host "Deteniendo $name (PID $procId)..." -ForegroundColor Cyan
            Stop-Process -Id $procId -Force
            $anyFound = $true
        }
    } catch {
        Write-Host "$name (PID $procId) ya no estaba en ejecucion." -ForegroundColor Gray
    }
}

if (-not $anyFound) {
    Write-Host ""
    Write-Host "No se encontro ningun proceso de AurexMC Network en ejecucion." -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "Procesos detenidos." -ForegroundColor Green
}

Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
Read-Host "Pulsa ENTER para cerrar"

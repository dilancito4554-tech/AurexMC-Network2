<#
    AurexMC Network - Panel de control
    ------------------------------------------------------------
    Controla Velocity, Lobby y Survival desde una unica ventana.
    Cada servidor se abre en su propia ventana de consola (para
    poder ver sus logs y escribir comandos si hace falta), pero
    el apagado normal se hace de forma segura desde este panel
    (se envia "stop" al proceso, no se mata a la fuerza).
#>

$ErrorActionPreference = "Stop"

$Root     = Split-Path -Parent $PSScriptRoot
$VeloDir  = Join-Path $Root "Velocity"
$LobbyDir = Join-Path $Root "Lobby"
$SurvDir  = Join-Path $Root "Survival"
$ToolsDir = Join-Path $Root "tools"
$PidFile  = Join-Path $ToolsDir "aurexmc-pids.json"

$host.UI.RawUI.WindowTitle = "AUREXMC NETWORK - Panel de control"

# Handles de proceso vivos durante esta sesion del panel (permiten apagado limpio)
$script:Procs = @{
    Velocity = $null
    Lobby    = $null
    Survival = $null
}

# ----------------------------------------------------------------
# Utilidades
# ----------------------------------------------------------------
function Save-PidState {
    $state = @{}
    foreach ($key in $script:Procs.Keys) {
        $p = $script:Procs[$key]
        if ($p -and -not $p.HasExited) { $state[$key] = $p.Id }
    }
    $state | ConvertTo-Json | Set-Content -Path $PidFile -Encoding UTF8
}

function Test-EulaAccepted {
    param([string]$ServerDir)
    $eula = Join-Path $ServerDir "eula.txt"
    if (-not (Test-Path $eula)) { return $false }
    return (Get-Content $eula -Raw) -match "eula\s*=\s*true"
}

function Start-ServerProcess {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$WorkDir,
        [Parameter(Mandatory)][string]$JarName,
        [Parameter(Mandatory)][string]$XmsXmx,
        [Parameter(Mandatory)][string]$ExtraFlags,
        [switch]$RequiresEula
    )

    $existing = $script:Procs[$Name]
    if ($existing -and -not $existing.HasExited) {
        Write-Host "$Name ya esta en ejecucion (PID $($existing.Id))." -ForegroundColor Yellow
        return
    }

    $jarPath = Join-Path $WorkDir $JarName
    if (-not (Test-Path $jarPath)) {
        Write-Host "No se encontro $jarPath. Ejecuta INSTALL-AurexMC.bat primero." -ForegroundColor Red
        return
    }

    if ($RequiresEula -and -not (Test-EulaAccepted -ServerDir $WorkDir)) {
        Write-Host "$Name no se puede iniciar: falta aceptar la EULA en $WorkDir\eula.txt (eula=true)." -ForegroundColor Red
        return
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "java"
    $psi.Arguments = "$XmsXmx $ExtraFlags -jar `"$JarName`" nogui"
    $psi.WorkingDirectory = $WorkDir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.CreateNoWindow = $false

    Write-Host "Iniciando $Name ..." -ForegroundColor Cyan
    $proc = [System.Diagnostics.Process]::Start($psi)
    $script:Procs[$Name] = $proc
    Save-PidState
    Start-Sleep -Milliseconds 500
    Write-Host "$Name iniciado (PID $($proc.Id))." -ForegroundColor Green
}

function Stop-ServerProcess {
    param([Parameter(Mandatory)][string]$Name)

    $proc = $script:Procs[$Name]
    if (-not $proc -or $proc.HasExited) {
        Write-Host "$Name no esta en ejecucion (desde este panel)." -ForegroundColor Yellow
        $script:Procs[$Name] = $null
        Save-PidState
        return
    }

    Write-Host "Deteniendo $Name (apagado seguro, guardando el mundo si aplica)..." -ForegroundColor Cyan
    try {
        $proc.StandardInput.WriteLine("stop")
        $proc.StandardInput.Flush()
    } catch {
        Write-Host "No se pudo enviar 'stop' a $Name, se intentara cerrar de otra forma." -ForegroundColor Yellow
    }

    $waited = 0
    while (-not $proc.HasExited -and $waited -lt 60) {
        Start-Sleep -Seconds 1
        $waited++
    }

    if (-not $proc.HasExited) {
        Write-Host "$Name no respondio a tiempo, forzando cierre." -ForegroundColor Yellow
        try { $proc.Kill() } catch {}
    }

    Write-Host "$Name detenido." -ForegroundColor Green
    $script:Procs[$Name] = $null
    Save-PidState
}

function Start-AllServers {
    Start-ServerProcess -Name "Velocity" -WorkDir $VeloDir -JarName "velocity.jar" `
        -XmsXmx "-Xms512M -Xmx512M" -ExtraFlags ""

    Start-Sleep -Seconds 2

    Start-ServerProcess -Name "Lobby" -WorkDir $LobbyDir -JarName "paper.jar" -RequiresEula `
        -XmsXmx "-Xms1536M -Xmx1536M" `
        -ExtraFlags "-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15"

    Start-ServerProcess -Name "Survival" -WorkDir $SurvDir -JarName "paper.jar" -RequiresEula `
        -XmsXmx "-Xms3072M -Xmx3072M" `
        -ExtraFlags "-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15"
}

function Stop-AllServers {
    # Orden inverso: primero los backend, luego el proxy
    Stop-ServerProcess -Name "Survival"
    Stop-ServerProcess -Name "Lobby"
    Stop-ServerProcess -Name "Velocity"
}

function Show-Status {
    Write-Host ""
    Write-Host "Estado de la network:" -ForegroundColor Cyan
    foreach ($name in @("Velocity", "Lobby", "Survival")) {
        $p = $script:Procs[$name]
        if ($p -and -not $p.HasExited) {
            Write-Host ("  {0,-10} ACTIVO (PID {1})" -f $name, $p.Id) -ForegroundColor Green
        } else {
            Write-Host ("  {0,-10} DETENIDO" -f $name) -ForegroundColor DarkGray
        }
    }
}

function Open-Console {
    param([string]$Name)
    $p = $script:Procs[$Name]
    if ($p -and -not $p.HasExited) {
        try {
            $wshell = New-Object -ComObject WScript.Shell
            $wshell.AppActivate($p.Id) | Out-Null
            Write-Host "Ventana de $Name enfocada." -ForegroundColor Green
        } catch {
            Write-Host "$Name esta activo (PID $($p.Id)) pero no se pudo enfocar su ventana automaticamente. Buscala en la barra de tareas." -ForegroundColor Yellow
        }
    } else {
        Write-Host "$Name no esta en ejecucion. Iniciala primero con la opcion [1]." -ForegroundColor Yellow
    }
}

# ----------------------------------------------------------------
# Menu principal
# ----------------------------------------------------------------
function Show-Menu {
    Clear-Host
    Write-Host "===================================================="
    Write-Host "   AUREXMC NETWORK"
    Write-Host "===================================================="
    Write-Host ""
    Write-Host "  [1] Iniciar Network"
    Write-Host "  [2] Reiniciar Network"
    Write-Host "  [3] Detener Network"
    Write-Host "  [4] Ver estado"
    Write-Host "  [5] Abrir consola Lobby"
    Write-Host "  [6] Abrir consola Survival"
    Write-Host "  [7] Abrir carpeta Velocity"
    Write-Host "  [8] Abrir carpeta Lobby"
    Write-Host "  [9] Abrir carpeta Survival"
    Write-Host "  [0] Salir"
    Write-Host ""
}

$exit = $false
while (-not $exit) {
    Show-Menu
    $choice = Read-Host "Elige una opcion"

    switch ($choice) {
        "1" { Start-AllServers }
        "2" { Stop-AllServers; Start-Sleep -Seconds 2; Start-AllServers }
        "3" { Stop-AllServers }
        "4" { Show-Status }
        "5" { Open-Console -Name "Lobby" }
        "6" { Open-Console -Name "Survival" }
        "7" { Invoke-Item $VeloDir }
        "8" { Invoke-Item $LobbyDir }
        "9" { Invoke-Item $SurvDir }
        "0" {
            $anyRunning = $script:Procs.Values | Where-Object { $_ -and -not $_.HasExited }
            if ($anyRunning) {
                Write-Host ""
                Write-Host "Hay servidores en ejecucion. Se recomienda detenerlos (opcion 3) antes de salir." -ForegroundColor Yellow
                $confirm = Read-Host "Escribe SI para salir dejandolos encendidos, o cualquier otra cosa para cancelar"
                if ($confirm -eq "SI") { $exit = $true }
            } else {
                $exit = $true
            }
        }
        default { Write-Host "Opcion no valida." -ForegroundColor Red }
    }

    if (-not $exit) {
        Write-Host ""
        Read-Host "Pulsa ENTER para volver al menu"
    }
}

Write-Host "Panel cerrado."

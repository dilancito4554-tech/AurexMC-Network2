<#
    AurexMC Network - Instalador
    ------------------------------------------------------------
    Este script:
      1) Comprueba que Java 21+ esta instalado.
      2) Descarga Velocity y Paper (Lobby y Survival) usando la
         API oficial y actual de PaperMC (fill.papermc.io v3).
      3) Genera la clave de forwarding (forwarding.secret) y la
         aplica tanto en Velocity como en Lobby/Survival.
      4) Intenta descargar los plugins base desde Hangar
         (repositorio oficial de PaperMC). Si un plugin no se
         puede descargar de forma fiable, NO se inventa una URL:
         se deja documentado en plugins\PLUGIN-PLAN.txt.
      5) No crea nunca un archivo .jar falso. Si una descarga
         falla o el archivo resultante no es valido, se borra
         y se informa con un mensaje claro.
    ------------------------------------------------------------
#>

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ----------------------------------------------------------------
# Rutas base
# ----------------------------------------------------------------
$Root      = Split-Path -Parent $PSScriptRoot
$VeloDir   = Join-Path $Root "Velocity"
$LobbyDir  = Join-Path $Root "Lobby"
$SurvDir   = Join-Path $Root "Survival"
$ToolsDir  = Join-Path $Root "tools"
$PluginDoc = Join-Path $Root "plugins\PLUGIN-PLAN.txt"
$LogFile   = Join-Path $ToolsDir "install-log.txt"

$UserAgent = "AurexMC-Network-Installer/1.0 (contacto: aurexmc-network@example.local)"

# ----------------------------------------------------------------
# Utilidades
# ----------------------------------------------------------------
function Write-Log {
    param([string]$Message, [string]$Color = "Gray")
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $LogFile -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message)
}

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
    Add-Content -Path $LogFile -Value ""
    Add-Content -Path $LogFile -Value ("==> " + $Text)
}

function Fail-Install {
    param([string]$Reason)
    Write-Host ""
    Write-Host "ERROR: $Reason" -ForegroundColor Red
    Write-Log ("INSTALACION DETENIDA: " + $Reason) "Red"
    Write-Host ""
    Write-Host "La instalacion se ha detenido. No se ha creado ningun archivo falso." -ForegroundColor Yellow
    Read-Host "Pulsa ENTER para cerrar"
    exit 1
}

New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null
"AurexMC Network - log de instalacion" | Out-File -FilePath $LogFile -Encoding UTF8

Write-Host "===================================================="
Write-Host "   AUREXMC NETWORK - INSTALADOR"
Write-Host "===================================================="

# ----------------------------------------------------------------
# 1) Comprobar Java 21+
# ----------------------------------------------------------------
Write-Step "Comprobando instalacion de Java"

try {
    $javaVersionRaw = (& java -version) 2>&1 | Out-String
} catch {
    Fail-Install "No se encontro el comando 'java'. Instala Java 21 (Temurin) y asegurate de que 'java -version' funcione desde CMD."
}

Write-Log $javaVersionRaw.Trim()

$versionMatch = [regex]::Match($javaVersionRaw, '"(\d+)(\.\d+)*(\.\d+)*"')
if (-not $versionMatch.Success) {
    Fail-Install "No se pudo interpretar la version de Java detectada:`n$javaVersionRaw"
}

$majorVersion = [int]$versionMatch.Groups[1].Value
Write-Log ("Version de Java detectada: " + $majorVersion) "Green"

if ($majorVersion -lt 21) {
    Fail-Install "Se requiere Java 21 o superior. Version detectada: $majorVersion. Instala Java 21 Temurin y vuelve a ejecutar el instalador."
}

Write-Host "Java $majorVersion detectado correctamente." -ForegroundColor Green

# ----------------------------------------------------------------
# 2) Descarga desde la API oficial de PaperMC (fill.papermc.io v3)
# ----------------------------------------------------------------
function Get-LatestStablePaperBuild {
    param([Parameter(Mandatory)][string]$Project)

    $headers = @{ "User-Agent" = $UserAgent }

    try {
        $projectInfo = Invoke-RestMethod -Uri "https://fill.papermc.io/v3/projects/$Project" -Headers $headers -Method Get
    } catch {
        throw "No se pudo consultar la API de PaperMC para '$Project'. Comprueba tu conexion a internet. Detalle: $($_.Exception.Message)"
    }

    # Las versiones vienen agrupadas; las aplanamos y ordenamos de mas nueva a mas antigua.
    $allVersions = @()
    foreach ($group in $projectInfo.versions.PSObject.Properties) {
        foreach ($v in $group.Value) { $allVersions += $v }
    }
    if ($allVersions.Count -eq 0) {
        throw "La API de PaperMC no devolvio ninguna version disponible para '$Project'."
    }
    $allVersions = $allVersions | Sort-Object { [version]($_ -replace '[^\d\.]', '') } -Descending -ErrorAction SilentlyContinue
    if (-not $allVersions -or $allVersions.Count -eq 0) {
        $allVersions = $projectInfo.versions.PSObject.Properties.Value | ForEach-Object { $_ } | Select-Object -Unique
    }

    foreach ($version in $allVersions) {
        try {
            $builds = Invoke-RestMethod -Uri "https://fill.papermc.io/v3/projects/$Project/versions/$version/builds" -Headers $headers -Method Get
        } catch {
            continue
        }
        if (-not $builds -or $builds.Count -eq 0) { continue }

        $stable = $builds | Where-Object { $_.channel -eq "STABLE" } | Select-Object -First 1
        if ($null -ne $stable) {
            $download = $stable.downloads.'server:default'
            if ($null -eq $download) { continue }
            return [PSCustomObject]@{
                Version  = $version
                Build    = $stable.id
                Url      = $download.url
                FileName = $download.name
                Sha256   = $download.checksums.sha256
            }
        }
    }

    throw "No se encontro ningun build ESTABLE disponible para '$Project' en ninguna version."
}

function Save-VerifiedFile {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Destination,
        [string]$ExpectedSha256
    )

    $tempFile = "$Destination.download"
    if (Test-Path $tempFile) { Remove-Item $tempFile -Force }

    try {
        Invoke-WebRequest -Uri $Url -Headers @{ "User-Agent" = $UserAgent } -OutFile $tempFile -UseBasicParsing
    } catch {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
        throw "Fallo la descarga desde $Url. Detalle: $($_.Exception.Message)"
    }

    if (-not (Test-Path $tempFile) -or (Get-Item $tempFile).Length -lt 1000) {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
        throw "El archivo descargado desde $Url parece invalido o incompleto (demasiado pequeno)."
    }

    if ($ExpectedSha256) {
        $actualHash = (Get-FileHash -Path $tempFile -Algorithm SHA256).Hash.ToLower()
        if ($actualHash -ne $ExpectedSha256.ToLower()) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            throw "El archivo descargado desde $Url no coincide con el checksum SHA256 esperado. Se ha descartado por seguridad."
        }
    }

    if (Test-Path $Destination) { Remove-Item $Destination -Force }
    Move-Item -Path $tempFile -Destination $Destination -Force
}

function Install-PaperMCComponent {
    param(
        [Parameter(Mandatory)][string]$Project,
        [Parameter(Mandatory)][string]$TargetDir,
        [Parameter(Mandatory)][string]$FinalJarName,
        [Parameter(Mandatory)][string]$FriendlyName
    )

    Write-Step "Descargando $FriendlyName (proyecto: $Project)"

    try {
        $info = Get-LatestStablePaperBuild -Project $Project
    } catch {
        Fail-Install "No se pudo obtener informacion de descarga para $FriendlyName. Detalle: $($_.Exception.Message)"
    }

    Write-Log ("$FriendlyName -> version $($info.Version), build $($info.Build), archivo $($info.FileName)") "Green"

    $destPath = Join-Path $TargetDir $FinalJarName
    try {
        Save-VerifiedFile -Url $info.Url -Destination $destPath -ExpectedSha256 $info.Sha256
    } catch {
        Fail-Install "No se pudo descargar $FriendlyName de forma fiable. Detalle: $($_.Exception.Message)"
    }

    Write-Host "$FriendlyName instalado correctamente ($($info.Version) build $($info.Build))." -ForegroundColor Green
    return $info
}

$veloInfo  = Install-PaperMCComponent -Project "velocity" -TargetDir $VeloDir  -FinalJarName "velocity.jar" -FriendlyName "Velocity"
$lobbyInfo = Install-PaperMCComponent -Project "paper"    -TargetDir $LobbyDir -FinalJarName "paper.jar"    -FriendlyName "Paper (Lobby)"
$survInfo  = Install-PaperMCComponent -Project "paper"    -TargetDir $SurvDir  -FinalJarName "paper.jar"    -FriendlyName "Paper (Survival)"

# ----------------------------------------------------------------
# 3) Generar forwarding.secret y aplicarlo en Velocity/Lobby/Survival
# ----------------------------------------------------------------
Write-Step "Generando la clave secreta de forwarding"

function New-RandomSecret {
    $bytes = New-Object byte[] 32
    [Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return ([Convert]::ToBase64String($bytes) -replace '[^a-zA-Z0-9]', '').Substring(0, 32)
}

$secret = New-RandomSecret
Set-Content -Path (Join-Path $VeloDir "forwarding.secret") -Value $secret -NoNewline -Encoding ASCII
Write-Log "forwarding.secret generado (32 caracteres)." "Green"

foreach ($cfgPath in @((Join-Path $LobbyDir "config\paper-global.yml"), (Join-Path $SurvDir "config\paper-global.yml"))) {
    if (Test-Path $cfgPath) {
        (Get-Content $cfgPath -Raw) -replace "secret: '.*'", "secret: '$secret'" | Set-Content -Path $cfgPath -Encoding UTF8
    }
}
Write-Host "Clave de forwarding aplicada en Velocity, Lobby y Survival." -ForegroundColor Green

# ----------------------------------------------------------------
# 4) Aceptar recordatorio de EULA (no se activa automaticamente)
# ----------------------------------------------------------------
Write-Step "Comprobando archivos eula.txt"
Write-Host "Recuerda: debes aceptar manualmente la EULA en Lobby\eula.txt y Survival\eula.txt (cambia eula=false por eula=true) antes de iniciar la network. Lee: https://aka.ms/MinecraftEULA" -ForegroundColor Yellow
Write-Log "Recordatorio de EULA mostrado al usuario." "Yellow"

# ----------------------------------------------------------------
# 5) Descarga de plugins base desde Hangar (best-effort, sin URLs inventadas)
# ----------------------------------------------------------------
Write-Step "Descargando plugins base desde Hangar (repositorio oficial PaperMC)"

function Get-HangarLatestDownload {
    param(
        [Parameter(Mandatory)][string]$Author,
        [Parameter(Mandatory)][string]$Slug
    )

    $headers = @{ "User-Agent" = $UserAgent; "Accept" = "application/json" }
    $base = "https://hangar.papermc.io/api/v1/projects/$Author/$Slug"

    $latestVersion = (Invoke-RestMethod -Uri "$base/latestrelease" -Headers $headers -Method Get).Trim('"')
    if ([string]::IsNullOrWhiteSpace($latestVersion)) {
        throw "Hangar no devolvio una version 'latestrelease' valida para $Author/$Slug."
    }

    $versionInfo = Invoke-RestMethod -Uri "$base/versions/$latestVersion" -Headers $headers -Method Get

    $platformKey = $versionInfo.downloads.PSObject.Properties.Name | Where-Object { $_ -match "PAPER" } | Select-Object -First 1
    if (-not $platformKey) {
        throw "La version $latestVersion de $Author/$Slug no ofrece descarga para la plataforma PAPER."
    }

    $download = $versionInfo.downloads.$platformKey
    $url = $download.downloadUrl
    if ([string]::IsNullOrWhiteSpace($url)) { $url = $download.externalUrl }
    if ([string]::IsNullOrWhiteSpace($url)) {
        throw "No se encontro una URL de descarga directa para $Author/$Slug $latestVersion (puede requerir descarga manual)."
    }

    return [PSCustomObject]@{
        Version  = $latestVersion
        Url      = $url
        FileName = "$Slug-$latestVersion.jar"
    }
}

$hangarPlugins = @(
    @{ Author = "LuckPerms"; Slug = "LuckPerms";  Targets = @($LobbyDir, $SurvDir) }
    @{ Author = "EssentialsX"; Slug = "Essentials"; Targets = @($SurvDir) }
    @{ Author = "ViaVersion"; Slug = "ViaVersion"; Targets = @($LobbyDir, $SurvDir) }
    @{ Author = "EngineHub"; Slug = "WorldEdit";   Targets = @($SurvDir) }
    @{ Author = "EngineHub"; Slug = "WorldGuard";  Targets = @($SurvDir) }
    @{ Author = "Intelli";   Slug = "CoreProtect"; Targets = @($SurvDir) }
    @{ Author = "aikar";     Slug = "spark";       Targets = @($LobbyDir, $SurvDir) }
)

$pluginResults = @()

foreach ($p in $hangarPlugins) {
    Write-Host ""
    Write-Host "-- $($p.Slug) --" -ForegroundColor Cyan
    try {
        $dl = Get-HangarLatestDownload -Author $p.Author -Slug $p.Slug
        foreach ($target in $p.Targets) {
            $destPath = Join-Path (Join-Path $target "plugins") $dl.FileName
            Save-VerifiedFile -Url $dl.Url -Destination $destPath
        }
        Write-Host "$($p.Slug) instalado (version $($dl.Version))." -ForegroundColor Green
        Write-Log ("$($p.Slug) -> OK, version $($dl.Version)") "Green"
        $pluginResults += "$($p.Slug): OK (version $($dl.Version))"
    } catch {
        Write-Host "$($p.Slug) NO se pudo descargar automaticamente: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Log ("$($p.Slug) -> FALLO: " + $_.Exception.Message) "Yellow"
        $pluginResults += "$($p.Slug): PENDIENTE (descarga manual, ver PLUGIN-PLAN.txt) - motivo: $($_.Exception.Message)"
    }
}

Add-Content -Path $PluginDoc -Value ""
Add-Content -Path $PluginDoc -Value "----------------------------------------------------"
Add-Content -Path $PluginDoc -Value ("RESULTADO DE LA ULTIMA INSTALACION (" + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + ")")
Add-Content -Path $PluginDoc -Value "----------------------------------------------------"
foreach ($r in $pluginResults) { Add-Content -Path $PluginDoc -Value $r }

# ----------------------------------------------------------------
# 6) Resumen final
# ----------------------------------------------------------------
Write-Host ""
Write-Host "===================================================="
Write-Host "   INSTALACION COMPLETADA"
Write-Host "===================================================="
Write-Host "Velocity : version $($veloInfo.Version) build $($veloInfo.Build)"
Write-Host "Lobby    : Paper $($lobbyInfo.Version) build $($lobbyInfo.Build)"
Write-Host "Survival : Paper $($survInfo.Version) build $($survInfo.Build)"
Write-Host ""
Write-Host "Plugins:" -ForegroundColor Cyan
foreach ($r in $pluginResults) { Write-Host "  - $r" }
Write-Host ""
Write-Host "SIGUIENTE PASO OBLIGATORIO:" -ForegroundColor Yellow
Write-Host "  Acepta la EULA en Lobby\eula.txt y Survival\eula.txt" -ForegroundColor Yellow
Write-Host "  (cambia eula=false por eula=true) y luego ejecuta START-NETWORK.bat" -ForegroundColor Yellow
Write-Host ""
Write-Log "INSTALACION COMPLETADA CORRECTAMENTE." "Green"

Read-Host "Pulsa ENTER para cerrar"

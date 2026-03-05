$ErrorActionPreference = "Stop"

function Pausa-Exito($mensaje) {
    Write-Host "[OK] $mensaje verificado correctamente." -ForegroundColor Green
    Read-Host "Presiona Enter para continuar al siguiente paso..."
}

function Die($mensaje) {
    Write-Host "[ERROR] $mensaje" -ForegroundColor Red -BackgroundColor Black
    pause; exit
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Die "Debes ejecutar este script como Administrador."
}

Write-Host "=== PASO 1: Selección de PC ===" -ForegroundColor Cyan
$opcion = ""
while ($opcion -notmatch "^[12]$") {
    $opcion = Read-Host "Ingresa [1] para PC1 o [2] para PC2"
}
if ($opcion -eq "1") { $ip = "2000::10"; $gw = "2000::11"; $tag = "PC1" } 
else { $ip = "2000::20"; $gw = "2000::21"; $tag = "PC2" }


Write-Host "`n=== PASO 2: Configuración de Red ===" -ForegroundColor Cyan
$adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Virtual -eq $false } | Select-Object -First 1
if (-not $adapter) { $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1 }
if (-not $adapter) { Die "No se detectó ningún adaptador de red conectado." }

Remove-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv6 -Confirm:$false -ErrorAction SilentlyContinue
Remove-NetRoute -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv6 -Confirm:$false -ErrorAction SilentlyContinue
New-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -IPAddress $ip -PrefixLength 124 -DefaultGateway $gw -AddressFamily IPv6 | Out-Null

# VERIFICACIÓN PASO 2: Buscar si la IP realmente está asignada en el adaptador
$ipCheck = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -IPAddress $ip -ErrorAction SilentlyContinue
if (-not $ipCheck) { Die "No se pudo asignar la dirección IP al adaptador." }
Pausa-Exito "Dirección IP y Gateway asignados"


Write-Host "`n=== PASO 3: Creación de Carpetas ===" -ForegroundColor Cyan
$rutas = @("C:\CarpetaA_$tag", "C:\CarpetaB_$tag")
foreach ($ruta in $rutas) {
    if (-not (Test-Path $ruta)) { New-Item -Path $ruta -ItemType Directory -Force | Out-Null }
    $nombreShare = Split-Path $ruta -Leaf
    Remove-SmbShare -Name $nombreShare -Force -ErrorAction SilentlyContinue
    New-SmbShare -Name $nombreShare -Path $ruta -FullAccess Everyone | Out-Null
}

# VERIFICACIÓN PASO 3: Comprobar que los recursos compartidos existan en el sistema
$share1 = Get-SmbShare -Name "CarpetaA_$tag" -ErrorAction SilentlyContinue
$share2 = Get-SmbShare -Name "CarpetaB_$tag" -ErrorAction SilentlyContinue
if (-not $share1 -or -not $share2) { Die "Fallo al crear o compartir las carpetas." }
Pausa-Exito "Carpetas creadas y compartidas en red"


Write-Host "`n=== PASO 4: Reglas de Firewall ===" -ForegroundColor Cyan
Enable-NetFirewallRule -DisplayName "Compartir archivos e impresoras (solicitud de eco: ICMPv6 de entrada)" -ErrorAction SilentlyContinue
Enable-NetFirewallRule -DisplayGroup "Compartir archivos e impresoras" -ErrorAction SilentlyContinue

# VERIFICACIÓN PASO 4: Comprobar que la regla de ping está activada
$firewallRule = Get-NetFirewallRule -DisplayName "Compartir archivos e impresoras (solicitud de eco: ICMPv6 de entrada)" | Select-Object -First 1
if ($firewallRule.Enabled -ne "True") {
    Write-Host "[ADVERTENCIA] La regla de Firewall para Ping no se activó. Podría bloquear traceroute." -ForegroundColor Yellow
} else {
    Pausa-Exito "Reglas de Firewall activadas"
}

Write-Host "`n[ÉXITO TOTAL] La máquina $tag está completamente lista." -ForegroundColor Green
pause
$ErrorActionPreference = "Stop"

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] Por favor, abre PowerShell como Administrador." -ForegroundColor Red
    pause; exit
}

Write-Host "--- Configuración de Clientes Windows ---" -ForegroundColor Cyan
$opcion = Read-Host "Ingresa [1] si esta es la PC1 (Conectada a R2) o [2] si es la PC2 (Conectada a R3)"

if ($opcion -eq "1") {
    $ip = "2000::10"; $gw = "2000::11"; $tag = "PC1"
} elseif ($opcion -eq "2") {
    $ip = "2000::20"; $gw = "2000::21"; $tag = "PC2"
} else {
    Write-Host "[ERROR] Opción no válida." -ForegroundColor Red
    pause; exit
}

# 1. Configurar Adaptador de Red
try {
    $adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
    if (-not $adapter) { throw "No se detectó ningún cable de red conectado." }
    
    Write-Host "Configurando IPv6 en $($adapter.Name)..."
    Remove-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv6 -Confirm:$false -ErrorAction SilentlyContinue
    New-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -IPAddress $ip -PrefixLength 124 -DefaultGateway $gw -AddressFamily IPv6 | Out-Null
} catch {
    Write-Host "[ERROR de Red] $($_.Exception.Message)" -ForegroundColor Red
    pause; exit
}

# 2. Configurar Carpetas y Compartición
try {
    Write-Host "Generando carpetas compartidas..."
    $rutas = @("C:\CarpetaA_$tag", "C:\CarpetaB_$tag")
    
    foreach ($ruta in $rutas) {
        if (-not (Test-Path $ruta)) { New-Item -Path $ruta -ItemType Directory -Force | Out-Null }
        $nombreShare = Split-Path $ruta -Leaf
        Remove-SmbShare -Name $nombreShare -Force -ErrorAction SilentlyContinue
        New-SmbShare -Name $nombreShare -Path $ruta -FullAccess Everyone | Out-Null
    }
} catch {
    Write-Host "[ERROR de Archivos] $($_.Exception.Message)" -ForegroundColor Red
    pause; exit
}

# 3. Reglas de Firewall
try {
    Write-Host "Aplicando reglas de Firewall para Ping y SMB..."
    Enable-NetFirewallRule -DisplayName "Compartir archivos e impresoras (solicitud de eco: ICMPv6 de entrada)" -ErrorAction SilentlyContinue
    Enable-NetFirewallRule -DisplayGroup "Compartir archivos e impresoras" -ErrorAction SilentlyContinue
} catch {
    Write-Host "[ADVERTENCIA] No se pudo ajustar el Firewall automáticamente." -ForegroundColor Yellow
}

Write-Host "[ÉXITO] Máquina configurada correctamente como $tag." -ForegroundColor Green
pause
# 1. Solicitar privilegios de Administrador si no los tiene
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Por favor, ejecuta este script como ADMINISTRADOR."
    exit
}

# 2. Identificar la interfaz activa
$interface = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1 -ExpandProperty Name

Write-Host "--- CONFIGURACIÓN DE LABORATORIO IPv6 ---" -ForegroundColor Yellow
Write-Host "1. Configurar como PC1 (Red 2000::10/124)"
Write-Host "2. Configurar como PC2 (Red 2000::20/124)"
$choice = Read-Host "Selecciona una opción (1 o 2)"

if ($choice -eq "1") {
    $ip = "2000::10"
    $gw = "2000::1"
    $name = "PC1-Lab"
} else {
    $ip = "2000::20"
    $gw = "2000::1"
    $name = "PC2-Lab"
}

# 3. Limpiar configuraciones previas y asignar IP
Write-Host "Asignando IP $ip a la interfaz $interface..." -ForegroundColor Cyan
Remove-NetIPAddress -InterfaceAlias $interface -AddressFamily IPv6 -Confirm:$false 2>$null
New-NetIPAddress -InterfaceAlias $interface -IPAddress $ip -PrefixLength 124 -DefaultGateway $gw

# 4. Crear y Compartir carpetas (Requerimiento del Lab)
Write-Host "Creando carpetas compartidas..." -ForegroundColor Cyan
$paths = "C:\Compartida_A", "C:\Compartida_B"
foreach ($path in $paths) {
    if (!(Test-Path $path)) { New-Item -Path $path -ItemType Directory }
    # Compartir con permisos totales para 'Todos'
    New-SmbShare -Name "$(Split-Path $path -Leaf)_$name" -Path $path -FullAccess Everyone -ErrorAction SilentlyContinue
}

# 5. Habilitar Reglas de Firewall (Crucial para Traceroute y SMB)
Write-Host "Abriendo Firewall..." -ForegroundColor Cyan
Enable-NetFirewallRule -DisplayName "Compartir archivos e impresoras (solicitud de eco: ICMPv6 de entrada)"
Enable-NetFirewallRule -DisplayGroup "Compartir archivos e impresoras"

Write-Host "¡LISTO! Esta máquina ahora es $name." -ForegroundColor Green
Write-Host "IP: $ip | Gateway: $gw"
pause
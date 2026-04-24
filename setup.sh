#!/bin/bash

# Validar privilegios de root
if [[ $EUID -ne 0 ]]; then 
    echo "ERROR: Debes ejecutar este script con sudo."
    exit 1
fi

# Definición de rutas absolutas para evitar errores de "orden no encontrada"
IP_CMD="/sbin/ip"
MOD_CMD="/sbin/modprobe"
VTY_CMD="/usr/bin/vtysh"

echo "[*] Iniciando configuración de red..."

# 1. Preparación del Kernel
$MOD_CMD sit 2>/dev/null
$MOD_CMD ip6_gre 2>/dev/null
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

# 2. Limpieza de residuos de configuraciones previas
echo "[*] Limpiando interfaces y túneles anteriores..."
for t in tunR0 tunR1 tunR3 tunR4; do $IP_CMD tunnel del $t 2>/dev/null; $IP_CMD link del $t 2>/dev/null; done
for i in enp0s3 enp0s8 enp0s9; do $IP_CMD addr flush dev $i 2>/dev/null; done

echo "================================================="
echo "   CONFIGURACIÓN SEGÚN TOPOLOGÍA DE IMAGEN      "
echo "================================================="
echo "Selecciona el Router a configurar:"
echo "0) R0 | 1) R1 | 2) R2 | 3) R3 | 4) R4 | 5) R5"
read -p "Router: " OPC

case $OPC in
    0) # R0: LAN v6 (2000::/125) -> WAN v4 (200.0.0.0/30)
        $IP_CMD addr add 2000::2/125 dev enp0s3
        $IP_CMD addr add 200.0.0.1/30 dev enp0s8
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up
        # Túnel SIT hacia R1
        $IP_CMD tunnel add tunR1 mode sit remote 200.0.0.2 local 200.0.0.1
        $IP_CMD link set tunR1 up
        $IP_CMD addr add 2000::19/125 dev tunR1
        $VTY_CMD -c "conf t" -c "ipv6 route 2000::/110 2000::19 tunR1" -c "exit" -c "write"
        ;;
    1) # R1: Dual Stack (Puente SIT y GRE)
        $IP_CMD addr add 200.0.0.2/30 dev enp0s3
        $IP_CMD addr add 2000::17/125 dev enp0s8
        $IP_CMD addr add 8.0.0.254/24 dev enp0s9
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up; $IP_CMD link set enp0s9 up
        # SIT hacia R0
        $IP_CMD tunnel add tunR0 mode sit remote 200.0.0.1 local 200.0.0.2
        $IP_CMD link set tunR0 up
        # GRE hacia R3 (Encapsula IPv4 sobre la red IPv6 de R2)
        $IP_CMD link add tunR3 type ip6gre local 2000::17 remote 2000::22
        $IP_CMD link set tunR3 up
        $IP_CMD addr add 10.0.0.1/30 dev tunR3
        $VTY_CMD -c "conf t" \
              -c "ipv6 route 2000::/125 tunR0" \
              -c "ip route 9.0.0.0/24 10.0.0.2" \
              -c "ip route 11.0.0.0/24 10.0.0.2" \
              -c "exit" -c "write"
        ;;
    2) # R2: Core IPv6 puro
        $IP_CMD addr add 2000::18/125 dev enp0s3
        $IP_CMD addr add 2000::21/125 dev enp0s8
        $IP_CMD addr add 2000::14/125 dev enp0s9
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up; $IP_CMD link set enp0s9 up
        $VTY_CMD -c "conf t" \
              -c "ipv6 route 2000::/125 2000::17" \
              -c "ipv6 route 2000::10/125 2000::21" \
              -c "ipv6 route 2000::22/125 2000::21" \
              -c "exit" -c "write"
        ;;
    3) # R3: Dual Stack (Puente GRE y SIT)
        $IP_CMD addr add 2000::22/125 dev enp0s3
        $IP_CMD addr add 200.0.0.5/30 dev enp0s8
        $IP_CMD addr add 9.0.0.254/24 dev enp0s9
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up; $IP_CMD link set enp0s9 up
        # GRE hacia R1
        $IP_CMD link add tunR1 type ip6gre local 2000::22 remote 2000::17
        $IP_CMD link set tunR1 up
        $IP_CMD addr add 10.0.0.2/30 dev tunR1
        # SIT hacia R4 (Encapsula IPv6 sobre la red IPv4 de R4)
        $IP_CMD tunnel add tunR4 mode sit remote 200.0.0.6 local 200.0.0.5
        $IP_CMD link set tunR4 up
        $IP_CMD addr add 2000::25/125 dev tunR4
        $VTY_CMD -c "conf t" \
              -c "ip route 8.0.0.0/24 10.0.0.1" \
              -c "ipv6 route 2000::10/125 2000::25 tunR4" \
              -c "ipv6 route 2000::/125 2000::21" \
              -c "exit" -c "write"
        ;;
    4) # R4: Core IPv4 puro
        $IP_CMD addr add 200.0.0.6/30 dev enp0s3
        $IP_CMD addr add 200.0.0.9/30 dev enp0s8
        $IP_CMD addr add 2000::13/125 dev enp0s9
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up; $IP_CMD link set enp0s9 up
        $VTY_CMD -c "conf t" \
              -c "ip route 8.0.0.0/24 200.0.0.5" \
              -c "ip route 11.0.0.0/24 200.0.0.10" \
              -c "ipv6 route 2000::/110 200.0.0.5" \
              -c "exit" -c "write"
        ;;
    5) # R5: LAN v4 (11.0.0.0/24)
        $IP_CMD addr add 200.0.0.10/30 dev enp0s3
        $IP_CMD addr add 11.0.0.254/24 dev enp0s8
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up
        $VTY_CMD -c "conf t" -c "ip route 0.0.0.0/0 200.0.0.9" -c "exit" -c "write"
        ;;
esac

# Reiniciar el servicio de enrutamiento
systemctl restart frr
echo "[!] R$OPC configurado exitosamente."
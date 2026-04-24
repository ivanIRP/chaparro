#!/bin/bash

# Validar privilegios
if [[ $EUID -ne 0 ]]; then 
    echo "DEBES ejecutarlo con sudo: sudo $0"
    exit 1
fi

# Definir rutas de binarios manualmente para evitar errores de PATH
IP_CMD=$(command -v ip || echo "/sbin/ip")
MOD_CMD=$(command -v modprobe || echo "/sbin/modprobe")
SYS_CMD=$(command -v sysctl || echo "/sbin/sysctl")

echo "[*] Cargando módulos y activando forwarding..."
$MOD_CMD sit 2>/dev/null
$MOD_CMD ip6_gre 2>/dev/null

# Forwarding (Directo a proc para no depender de sysctl)
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

# Limpieza profunda
$IP_CMD tunnel del tunR0 2>/dev/null; $IP_CMD tunnel del tunR1 2>/dev/null
$IP_CMD tunnel del tunR3 2>/dev/null; $IP_CMD tunnel del tunR4 2>/dev/null
$IP_CMD link del tunR3 2>/dev/null; $IP_CMD link del tunR1 2>/dev/null
$IP_CMD addr flush dev enp0s3 2>/dev/null; $IP_CMD addr flush dev enp0s8 2>/dev/null; $IP_CMD addr flush dev enp0s9 2>/dev/null

echo "================================================="
echo "   CONFIGURACIÓN FINAL (PATH & KMOD FIX)        "
echo "================================================="
echo "0) R0 | 1) R1 | 2) R2 | 3) R3 | 4) R4 | 5) R5"
read -p "Router: " OPC

case $OPC in
    0)
        $IP_CMD addr add 2000::2/125 dev enp0s3 2>/dev/null
        $IP_CMD addr add 200.0.0.1/30 dev enp0s8 2>/dev/null
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up
        $IP_CMD tunnel add tunR1 mode sit remote 200.0.0.2 local 200.0.0.1
        $IP_CMD link set tunR1 up
        $IP_CMD addr add 2000::19/125 dev tunR1
        vtysh -c "conf t" -c "ipv6 route 2000::/110 2000::19 tunR1" -c "exit" -c "write"
        ;;
    1)
        $IP_CMD addr add 200.0.0.2/30 dev enp0s3 2>/dev/null
        $IP_CMD addr add 2000::17/125 dev enp0s8 2>/dev/null
        $IP_CMD addr add 8.0.0.254/24 dev enp0s9 2>/dev/null
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up; $IP_CMD link set enp0s9 up
        $IP_CMD tunnel add tunR0 mode sit remote 200.0.0.1 local 200.0.0.2
        $IP_CMD link set tunR0 up
        $IP_CMD link add tunR3 type ip6gre local 2000::17 remote 2000::22
        $IP_CMD link set tunR3 up
        $IP_CMD addr add 10.0.0.1/30 dev tunR3
        vtysh -c "conf t" -c "ipv6 route 2000::/125 tunR0" -c "ip route 9.0.0.0/24 10.0.0.2" -c "ip route 11.0.0.0/24 10.0.0.2" -c "exit" -c "write"
        ;;
    2)
        $IP_CMD addr add 2000::18/125 dev enp0s3 2>/dev/null
        $IP_CMD addr add 2000::21/125 dev enp0s8 2>/dev/null
        $IP_CMD addr add 2000::14/125 dev enp0s9 2>/dev/null
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up; $IP_CMD link set enp0s9 up
        vtysh -c "conf t" -c "ipv6 route 2000::/125 2000::17" -c "ipv6 route 2000::22/125 2000::21" -c "exit" -c "write"
        ;;
    3)
        $IP_CMD addr add 2000::22/125 dev enp0s3 2>/dev/null
        $IP_CMD addr add 200.0.0.5/30 dev enp0s8 2>/dev/null
        $IP_CMD addr add 9.0.0.254/24 dev enp0s9 2>/dev/null
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up; $IP_CMD link set enp0s9 up
        $IP_CMD link add tunR1 type ip6gre local 2000::22 remote 2000::17
        $IP_CMD link set tunR1 up
        $IP_CMD addr add 10.0.0.2/30 dev tunR1
        $IP_CMD tunnel add tunR4 mode sit remote 200.0.0.6 local 200.0.0.5
        $IP_CMD link set tunR4 up
        $IP_CMD addr add 2000::25/125 dev tunR4
        vtysh -c "conf t" -c "ip route 8.0.0.0/24 10.0.0.1" -c "ipv6 route 2000::10/125 2000::25 tunR4" -c "exit" -c "write"
        ;;
    4)
        $IP_CMD addr add 200.0.0.6/30 dev enp0s3 2>/dev/null
        $IP_CMD addr add 200.0.0.9/30 dev enp0s8 2>/dev/null
        $IP_CMD addr add 2000::13/125 dev enp0s9 2>/dev/null
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up; $IP_CMD link set enp0s9 up
        vtysh -c "conf t" -c "ip route 8.0.0.0/24 200.0.0.5" -c "ip route 11.0.0.0/24 200.0.0.10" -c "exit" -c "write"
        ;;
    5)
        $IP_CMD addr add 200.0.0.10/30 dev enp0s3 2>/dev/null
        $IP_CMD addr add 11.0.0.254/24 dev enp0s8 2>/dev/null
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up
        vtysh -c "conf t" -c "ip route 0.0.0.0/0 200.0.0.9" -c "exit" -c "write"
        ;;
esac

systemctl restart frr
echo "[!] Configuración aplicada correctamente."
#!/bin/bash

if [[ $EUID -ne 0 ]]; then echo "Ejecuta como root"; exit 1; fi

# 1. PREPARACIÓN TOTAL DEL SISTEMA
echo "[*] Limpiando residuos, cargando módulos y activando forwarding..."
modprobe sit
modprobe ip6_gre
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

# Apagar interfaz de internet para evitar conflictos de rutas (Opcional pero recomendado)
ip link set enp0s10 down 2>/dev/null

# Limpiar túneles e IPs previas
for t in tunR0 tunR1 tunR3 tunR4; do ip tunnel del $t 2>/dev/null; ip link del $t 2>/dev/null; done
for i in enp0s3 enp0s8 enp0s9; do ip addr flush dev $i 2>/dev/null; done

echo "================================================="
echo "   CONFIGURACIÓN FINAL - PROYECTO REDES         "
echo "================================================="
echo "Selecciona el Router actual:"
echo "0) R0 | 1) R1 | 2) R2 | 3) R3 | 4) R4 | 5) R5"
read -p "Router: " OPC

case $OPC in
    0) # R0 (IPv6 LAN -> IPv4 Link)
        ip addr add 2000::2/125 dev enp0s3
        ip addr add 200.0.0.1/30 dev enp0s8
        ip link set enp0s3 up; ip link set enp0s8 up
        ip tunnel add tunR1 mode sit remote 200.0.0.2 local 200.0.0.1
        ip link set tunR1 up
        ip addr add 2000::19/125 dev tunR1
        vtysh -c "conf t" -c "ipv6 route 2000::/110 2000::19 tunR1" -c "exit" -c "write"
        ;;
    1) # R1 (Gateway Dual Stack)
        ip addr add 200.0.0.2/30 dev enp0s3
        ip addr add 2000::17/125 dev enp0s8
        ip addr add 8.0.0.254/24 dev enp0s9
        ip link set enp0s3 up; ip link set enp0s8 up; ip link set enp0s9 up
        ip tunnel add tunR0 mode sit remote 200.0.0.1 local 200.0.0.2
        ip link set tunR0 up
        ip link add tunR3 type ip6gre local 2000::17 remote 2000::22
        ip link set tunR3 up
        ip addr add 10.0.0.1/30 dev tunR3
        vtysh -c "conf t" \
              -c "ipv6 route 2000::/125 tunR0" \
              -c "ip route 9.0.0.0/24 10.0.0.2" \
              -c "ip route 11.0.0.0/24 10.0.0.2" \
              -c "exit" -c "write"
        ;;
    2) # R2 (Core IPv6)
        ip addr add 2000::18/125 dev enp0s3
        ip addr add 2000::21/125 dev enp0s8
        ip addr add 2000::14/125 dev enp0s9
        ip link set enp0s3 up; ip link set enp0s8 up; ip link set enp0s9 up
        vtysh -c "conf t" \
              -c "ipv6 route 2000::/125 2000::17" \
              -c "ipv6 route 2000::10/125 2000::21" \
              -c "ipv6 route 2000::22/125 2000::21" \
              -c "exit" -c "write"
        ;;
    3) # R3 (Gateway Dual Stack)
        ip addr add 2000::22/125 dev enp0s3
        ip addr add 200.0.0.5/30 dev enp0s8
        ip addr add 9.0.0.254/24 dev enp0s9
        ip link set enp0s3 up; ip link set enp0s8 up; ip link set enp0s9 up
        ip link add tunR1 type ip6gre local 2000::22 remote 2000::17
        ip link set tunR1 up
        ip addr add 10.0.0.2/30 dev tunR1
        ip tunnel add tunR4 mode sit remote 200.0.0.6 local 200.0.0.5
        ip link set tunR4 up
        ip addr add 2000::25/125 dev tunR4
        vtysh -c "conf t" \
              -c "ip route 8.0.0.0/24 10.0.0.1" \
              -c "ipv6 route 2000::10/125 2000::25 tunR4" \
              -c "ipv6 route 2000::/125 2000::21" \
              -c "exit" -c "write"
        ;;
    4) # R4 (Core IPv4)
        ip addr add 200.0.0.6/30 dev enp0s3
        ip addr add 200.0.0.9/30 dev enp0s8
        ip addr add 2000::13/125 dev enp0s9
        ip link set enp0s3 up; ip link set enp0s8 up; ip link set enp0s9 up
        vtysh -c "conf t" \
              -c "ip route 8.0.0.0/24 200.0.0.5" \
              -c "ip route 11.0.0.0/24 200.0.0.10" \
              -c "ipv6 route 2000::/110 200.0.0.5" \
              -c "exit" -c "write"
        ;;
    5) # R5 (IPv4 LAN)
        ip addr add 200.0.0.10/30 dev enp0s3
        ip addr add 11.0.0.254/24 dev enp0s8
        ip link set enp0s3 up; ip link set enp0s8 up
        vtysh -c "conf t" -c "ip route 0.0.0.0/0 200.0.0.9" -c "exit" -c "write"
        ;;
esac

systemctl restart frr
echo "[!] R$OPC configurado. Verifica con 'show ipv6 route' o 'show ip route' en vtysh."
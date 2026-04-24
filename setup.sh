#!/bin/bash

if [[ $EUID -ne 0 ]]; then echo "Ejecuta como root"; exit 1; fi

echo "[*] Configurando Forwarding (Vía /proc)..."

# Activamos forwarding sin usar el comando sysctl
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

# Asegurar demonios de FRR
sed -i 's/zebra=no/zebra=yes/' /etc/frr/daemons
sed -i 's/staticd=no/staticd=yes/' /etc/frr/daemons

echo "================================================="
echo " CONFIGURACIÓN DE ROUTER - VERSIÓN FRR 8.4.4 "
echo "================================================="
echo "0) R0 | 1) R1 | 2) R2 | 3) R3 | 4) R4 | 5) R5"
read -p "Router: " OPC

case $OPC in
    0)
        # R0: LAN IPv6 -> WAN IPv4
        ip addr add 2000::2/125 dev enp0s3 2>/dev/null
        ip addr add 200.0.0.1/30 dev enp0s8 2>/dev/null
        ip link set enp0s3 up; ip link set enp0s8 up
        # Túnel SIT
        ip tunnel add tunR1 mode sit remote 200.0.0.2 local 200.0.0.1
        ip link set tunR1 up
        ip addr add 2000::19/125 dev tunR1
        # En FRR 8.4 es mejor usar la sintaxis completa
        vtysh -c "conf t" -c "ipv6 route 2000::/110 2000::19 tunR1" -c "exit" -c "write"
        ;;
    1)
        # R1: Puente Dual Stack
        ip addr add 200.0.0.2/30 dev enp0s3 2>/dev/null
        ip addr add 2000::17/125 dev enp0s8 2>/dev/null
        ip addr add 8.0.0.254/24 dev enp0s9 2>/dev/null
        ip link set enp0s3 up; ip link set enp0s8 up; ip link set enp0s9 up
        # SIT hacia R0
        ip tunnel add tunR0 mode sit remote 200.0.0.1 local 200.0.0.2
        ip link set tunR0 up
        # GRE hacia R3 (v4 sobre v6)
        ip link add tunR3 type ip6gre local 2000::17 remote 2000::22
        ip link set tunR3 up
        ip addr add 10.0.0.1/30 dev tunR3
        vtysh -c "conf t" \
              -c "ipv6 route 2000::/125 tunR0" \
              -c "ip route 9.0.0.0/24 10.0.0.2 tunR3" \
              -c "ip route 11.0.0.0/24 10.0.0.2 tunR3" \
              -c "exit" -c "write"
        ;;
    2)
        # R2: Core IPv6 (No necesita túneles, solo pasar tráfico)
        ip addr add 2000::18/125 dev enp0s3 2>/dev/null
        ip addr add 2000::21/125 dev enp0s8 2>/dev/null
        ip addr add 2000::14/125 dev enp0s9 2>/dev/null
        ip link set enp0s3 up; ip link set enp0s8 up; ip link set enp0s9 up
        vtysh -c "conf t" \
              -c "ipv6 route 2000::/125 2000::17" \
              -c "ipv6 route 2000::22/125 2000::21" \
              -c "exit" -c "write"
        ;;
    3)
        # R3: Puente Dual Stack
        ip addr add 2000::22/125 dev enp0s3 2>/dev/null
        ip addr add 200.0.0.5/30 dev enp0s8 2>/dev/null
        ip addr add 9.0.0.254/24 dev enp0s9 2>/dev/null
        ip link set enp0s3 up; ip link set enp0s8 up; ip link set enp0s9 up
        # GRE hacia R1
        ip link add tunR1 type ip6gre local 2000::22 remote 2000::17
        ip link set tunR1 up
        ip addr add 10.0.0.2/30 dev tunR1
        # SIT hacia R4
        ip tunnel add tunR4 mode sit remote 200.0.0.6 local 200.0.0.5
        ip link set tunR4 up
        ip addr add 2000::25/125 dev tunR4
        vtysh -c "conf t" \
              -c "ip route 8.0.0.0/24 10.0.0.1 tunR1" \
              -c "ipv6 route 2000::10/125 2000::25 tunR4" \
              -c "exit" -c "write"
        ;;
    4)
        # R4: Core IPv4
        ip addr add 200.0.0.6/30 dev enp0s3 2>/dev/null
        ip addr add 200.0.0.9/30 dev enp0s8 2>/dev/null
        ip addr add 2000::13/125 dev enp0s9 2>/dev/null
        ip link set enp0s3 up; ip link set enp0s8 up; ip link set enp0s9 up
        vtysh -c "conf t" \
              -c "ip route 8.0.0.0/24 200.0.0.5" \
              -c "ip route 11.0.0.0/24 200.0.0.10" \
              -c "exit" -c "write"
        ;;
    5)
        # R5: Borde IPv4
        ip addr add 200.0.0.10/30 dev enp0s3 2>/dev/null
        ip addr add 11.0.0.254/24 dev enp0s8 2>/dev/null
        ip link set enp0s3 up; ip link set enp0s8 up
        vtysh -c "conf t" -c "ip route 0.0.0.0/0 200.0.0.9" -c "exit" -c "write"
        ;;
esac

# Reiniciamos FRR usando systemctl al final
systemctl restart frr
echo "[!] R$OPC configurado exitosamente."
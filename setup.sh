#!/bin/bash

if [[ $EUID -ne 0 ]]; then echo "Usa sudo"; exit 1; fi

IP="/sbin/ip"
VTY="/usr/bin/vtysh"

echo "[*] Limpiando red y activando forwarding..."
/sbin/modprobe sit 2>/dev/null; /sbin/modprobe ip6_gre 2>/dev/null
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

# Nuke de túneles viejos
for t in tunR0 tunR1 tunR3 tunR4; do $IP tunnel del $t 2>/dev/null; $IP link del $t 2>/dev/null; done
for i in enp0s3 enp0s8 enp0s9; do $IP addr flush dev $i 2>/dev/null; done

echo "================================================="
echo "   CONFIGURACIÓN ESTÁTICA BLINDADA (SIN OSPF)   "
echo "================================================="
echo "0) R0 | 1) R1 | 2) R2 | 3) R3 | 4) R4 | 5) R5"
read -p "Router: " OPC

case $OPC in
    0) # R0
        $IP addr add 2000::2/125 dev enp0s3
        $IP addr add 200.0.0.1/30 dev enp0s8
        $IP link set enp0s3 up; $IP link set enp0s8 up
        $IP tunnel add tunR1 mode sit remote 200.0.0.2 local 200.0.0.1
        $IP link set tunR1 up; $IP addr add 2000::19/125 dev tunR1
        $VTY -c "conf t" -c "ipv6 route 2000::/110 tunR1" -c "exit" -c "write"
        ;;
    1) # R1
        $IP addr add 200.0.0.2/30 dev enp0s3
        $IP addr add 2000::17/125 dev enp0s8
        $IP addr add 8.0.0.254/24 dev enp0s9
        $IP link set enp0s3 up; $IP link set enp0s8 up; $IP link set enp0s9 up
        
        $IP tunnel add tunR0 mode sit remote 200.0.0.1 local 200.0.0.2
        $IP link set tunR0 up
        
        $IP link add tunR3 type ip6gre local 2000::17 remote 2000::22
        $IP link set tunR3 up; $IP addr add 10.0.0.1/30 dev tunR3
        
        $VTY -c "conf t" \
             -c "ipv6 route 2000::/125 tunR0" \
             -c "ip route 9.0.0.0/24 tunR3" \
             -c "ip route 11.0.0.0/24 tunR3" \
             -c "ip route 200.0.0.4/30 tunR3" \
             -c "ip route 200.0.0.8/30 tunR3" -c "exit" -c "write"
        ;;
    2) # R2
        $IP addr add 2000::18/125 dev enp0s3
        $IP addr add 2000::21/125 dev enp0s8
        $IP addr add 2000::14/125 dev enp0s9
        $IP link set enp0s3 up; $IP link set enp0s8 up; $IP link set enp0s9 up
        
        $VTY -c "conf t" \
             -c "ipv6 route 2000::/125 2000::17" \
             -c "ipv6 route 2000::10/125 2000::22" \
             -c "exit" -c "write"
        ;;
    3) # R3
        $IP addr add 2000::22/125 dev enp0s3
        $IP addr add 200.0.0.5/30 dev enp0s8
        $IP addr add 9.0.0.254/24 dev enp0s9
        $IP link set enp0s3 up; $IP link set enp0s8 up; $IP link set enp0s9 up
        
        $IP link add tunR1 type ip6gre local 2000::22 remote 2000::17
        $IP link set tunR1 up; $IP addr add 10.0.0.2/30 dev tunR1
        
        $IP tunnel add tunR4 mode sit remote 200.0.0.6 local 200.0.0.5
        $IP link set tunR4 up
        
        $VTY -c "conf t" \
             -c "ip route 8.0.0.0/24 tunR1" \
             -c "ip route 200.0.0.0/30 tunR1" \
             -c "ip route 11.0.0.0/24 200.0.0.6" \
             -c "ipv6 route 2000::10/125 tunR4" \
             -c "ipv6 route 2000::/125 2000::21" \
             -c "ipv6 route 2000::8/125 2000::21" -c "exit" -c "write"
        ;;
    4) # R4 (¡TÚNEL AGREGADO AQUÍ!)
        $IP addr add 200.0.0.6/30 dev enp0s3
        $IP addr add 200.0.0.9/30 dev enp0s8
        $IP addr add 2000::13/125 dev enp0s9
        $IP link set enp0s3 up; $IP link set enp0s8 up; $IP link set enp0s9 up
        
        # Este túnel faltaba para recibir el IPv6 de R3
        $IP tunnel add tunR3 mode sit remote 200.0.0.5 local 200.0.0.6
        $IP link set tunR3 up
        
        $VTY -c "conf t" \
             -c "ip route 8.0.0.0/24 200.0.0.5" \
             -c "ip route 9.0.0.0/24 200.0.0.5" \
             -c "ip route 11.0.0.0/24 200.0.0.10" \
             -c "ipv6 route 2000::/110 tunR3" -c "exit" -c "write"
        ;;
    5) # R5
        $IP addr add 200.0.0.10/30 dev enp0s3
        $IP addr add 11.0.0.254/24 dev enp0s8
        $IP link set enp0s3 up; $IP link set enp0s8 up
        
        $VTY -c "conf t" -c "ip route 0.0.0.0/0 200.0.0.9" -c "exit" -c "write"
        ;;
esac

echo "[!] R$OPC inyectado. Revisa con 'vtysh -c \"show ip route\"'."
#!/bin/bash

# Validar privilegios
if [[ $EUID -ne 0 ]]; then echo "ERROR: Ejecuta con sudo."; exit 1; fi

IP_CMD="/sbin/ip"
MOD_CMD="/sbin/modprobe"
VTY_CMD="/usr/bin/vtysh"

echo "[*] Preparando Kernel y Forwarding..."
$MOD_CMD sit 2>/dev/null
$MOD_CMD ip6_gre 2>/dev/null
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

# Habilitar demonios OSPF en FRR
sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons
sed -i 's/ospf6d=no/ospf6d=yes/' /etc/frr/daemons
systemctl restart frr
sleep 2 # Dar tiempo a que los demonios inicien

echo "[*] Limpiando red anterior..."
for t in tunR0 tunR1 tunR3 tunR4; do $IP_CMD tunnel del $t 2>/dev/null; $IP_CMD link del $t 2>/dev/null; done
for i in enp0s3 enp0s8 enp0s9; do $IP_CMD addr flush dev $i 2>/dev/null; done

echo "================================================="
echo "   CONFIGURACIÓN AVANZADA OSPF (V2 y V3)        "
echo "================================================="
echo "0) R0 | 1) R1 | 2) R2 | 3) R3 | 4) R4 | 5) R5"
read -p "Router: " OPC

case $OPC in
    0)
        $IP_CMD addr add 2000::2/125 dev enp0s3; $IP_CMD addr add 200.0.0.1/30 dev enp0s8
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up
        $IP_CMD tunnel add tunR1 mode sit remote 200.0.0.2 local 200.0.0.1
        $IP_CMD link set tunR1 up; $IP_CMD addr add 2000::19/125 dev tunR1
        
        $VTY_CMD <<EOF
conf t
interface enp0s3
 ipv6 ospf6 area 0
exit
interface tunR1
 ipv6 ospf6 network point-to-point
 ipv6 ospf6 area 0
exit
router ospf6
 ospf6 router-id 0.0.0.0
exit
write
EOF
        ;;
    1)
        $IP_CMD addr add 200.0.0.2/30 dev enp0s3; $IP_CMD addr add 2000::17/125 dev enp0s8; $IP_CMD addr add 8.0.0.254/24 dev enp0s9
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up; $IP_CMD link set enp0s9 up
        $IP_CMD tunnel add tunR0 mode sit remote 200.0.0.1 local 200.0.0.2; $IP_CMD link set tunR0 up
        $IP_CMD link add tunR3 type ip6gre local 2000::17 remote 2000::22; $IP_CMD link set tunR3 up
        $IP_CMD addr add 10.0.0.1/30 dev tunR3

        $VTY_CMD <<EOF
conf t
interface tunR0
 ipv6 ospf6 network point-to-point
 ipv6 ospf6 area 0
exit
interface enp0s8
 ipv6 ospf6 area 0
exit
router ospf6
 ospf6 router-id 1.1.1.1
exit
router ospf
 ospf router-id 1.1.1.1
 network 8.0.0.0/24 area 0
 network 10.0.0.0/30 area 0
exit
interface tunR3
 ip ospf network point-to-point
exit
write
EOF
        ;;
    2)
        $IP_CMD addr add 2000::18/125 dev enp0s3; $IP_CMD addr add 2000::21/125 dev enp0s8; $IP_CMD addr add 2000::14/125 dev enp0s9
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up; $IP_CMD link set enp0s9 up

        $VTY_CMD <<EOF
conf t
interface enp0s3
 ipv6 ospf6 area 0
exit
interface enp0s8
 ipv6 ospf6 area 0
exit
interface enp0s9
 ipv6 ospf6 area 0
exit
router ospf6
 ospf6 router-id 2.2.2.2
exit
write
EOF
        ;;
    3)
        $IP_CMD addr add 2000::22/125 dev enp0s3; $IP_CMD addr add 200.0.0.5/30 dev enp0s8; $IP_CMD addr add 9.0.0.254/24 dev enp0s9
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up; $IP_CMD link set enp0s9 up
        $IP_CMD link add tunR1 type ip6gre local 2000::22 remote 2000::17; $IP_CMD link set tunR1 up; $IP_CMD addr add 10.0.0.2/30 dev tunR1
        $IP_CMD tunnel add tunR4 mode sit remote 200.0.0.6 local 200.0.0.5; $IP_CMD link set tunR4 up; $IP_CMD addr add 2000::25/125 dev tunR4

        $VTY_CMD <<EOF
conf t
interface enp0s3
 ipv6 ospf6 area 0
exit
interface tunR4
 ipv6 ospf6 network point-to-point
 ipv6 ospf6 area 0
exit
router ospf6
 ospf6 router-id 3.3.3.3
exit
router ospf
 ospf router-id 3.3.3.3
 network 9.0.0.0/24 area 0
 network 10.0.0.0/30 area 0
exit
interface tunR1
 ip ospf network point-to-point
exit
write
EOF
        ;;
    4)
        $IP_CMD addr add 200.0.0.6/30 dev enp0s3; $IP_CMD addr add 200.0.0.9/30 dev enp0s8; $IP_CMD addr add 2000::13/125 dev enp0s9
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up; $IP_CMD link set enp0s9 up

        $VTY_CMD <<EOF
conf t
router ospf
 ospf router-id 4.4.4.4
 network 200.0.0.4/30 area 0
 network 200.0.0.8/30 area 0
exit
write
EOF
        ;;
    5)
        $IP_CMD addr add 200.0.0.10/30 dev enp0s3; $IP_CMD addr add 11.0.0.254/24 dev enp0s8
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up

        $VTY_CMD <<EOF
conf t
router ospf
 ospf router-id 5.5.5.5
 network 200.0.0.8/30 area 0
 network 11.0.0.0/24 area 0
exit
write
EOF
        ;;
esac

echo "[!] Configuración OSPF inyectada con éxito en R$OPC."
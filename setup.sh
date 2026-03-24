#!/bin/bash

echo "=============================="
echo " CONFIGURADOR FRR (OSPFv3) "
echo "=============================="
echo "Selecciona router (0 - 11): "
read R

# Activar forwarding IPv6
sysctl -w net.ipv6.conf.all.forwarding=1

RID="1.1.1.$((R+1))"

# Limpiar interfaces
ip -6 addr flush dev enp0s3 2>/dev/null
ip -6 addr flush dev enp0s8 2>/dev/null
ip -6 addr flush dev enp0s9 2>/dev/null

# Levantar interfaces
ip link set enp0s3 up 2>/dev/null
ip link set enp0s8 up 2>/dev/null
ip link set enp0s9 up 2>/dev/null

# Variables
LAN=""
LEFT=""
RIGHT=""

case $R in

0)
LAN="2000::1/118"
RIGHT="2000::1:1/125"
;;

1)
LAN="2000::1001/118"
LEFT="2000::1:2/125"
RIGHT="2000::2:1/125"
;;

2)
LAN="2000::2001/118"
LEFT="2000::2:2/125"
RIGHT="2000::3:1/126"
;;

3)
LEFT="2000::3:2/126"
RIGHT="2000::4:1/126"
EXTRA="2000::8:1/125"
;;

4)
LAN="2000::3001/118"
LEFT="2000::4:2/126"
RIGHT="2000::5:1/125"
;;

5)
LAN="2000::4001/118"
LEFT="2000::5:2/125"
RIGHT="2000::6:1/126"
;;

6)
LAN="2000::5001/118"
LEFT="2000::6:2/126"
RIGHT="2000::7:1/126"
;;

7)
LAN="2000::6001/118"
LEFT="2000::7:2/126"
;;

8)
LAN="2000::7001/118"
LEFT="2000::8:2/125"
RIGHT="2000::9:1/125"
;;

9)
LAN="2000::8001/118"
LEFT="2000::9:2/125"
RIGHT="2000::10:1/125"
;;

10)
LAN="2000::9001/118"
LEFT="2000::10:2/125"
RIGHT="2000::11:1/125"
;;

11)
LAN="2000::A001/118"
LEFT="2000::11:2/125"
;;

*)
echo "Router inválido"
exit
;;

esac

# Asignar IPs
[ ! -z "$LAN" ] && ip -6 addr add $LAN dev enp0s3
[ ! -z "$LEFT" ] && ip -6 addr add $LEFT dev enp0s8
[ ! -z "$RIGHT" ] && ip -6 addr add $RIGHT dev enp0s9

# Caso especial R3 (tercer enlace)
if [ "$R" == "3" ]; then
    ip -6 addr add $EXTRA dev enp0s3
fi

# Configuración FRR
cat > /etc/frr/frr.conf <<EOF
frr version 8.4.4
frr defaults traditional
hostname R$R
log syslog informational

router ospf6
 router-id $RID

 interface enp0s3 area 0.0.0.0
 interface enp0s8 area 0.0.0.0
 interface enp0s9 area 0.0.0.0
EOF

# Permisos
chown frr:frr /etc/frr/frr.conf

# Reiniciar FRR
systemctl restart frr

echo "=============================="
echo " Router R$R configurado"
echo " Router-ID: $RID"
echo "=============================="
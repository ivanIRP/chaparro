#!/bin/bash

echo "=============================="
echo " CONFIGURADOR AUTOMATICO FRR "
echo "=============================="
echo "Selecciona router (0 - 11): "
read R

# Habilitar IPv6 forwarding
sysctl -w net.ipv6.conf.all.forwarding=1

# Instalar FRR si no está
apt update -y
apt install frr -y

# Habilitar OSPFv3
sed -i 's/ospf6d=no/ospf6d=yes/g' /etc/frr/daemons

# Variables
RID="1.1.1.$((R+1))"

# Configuración por router
case $R in

0)
LAN="2000::1/118"
S1="2000::1:1/125"
;;

1)
LAN="2000::1001/118"
S1="2000::1:2/125"
S2="2000::2:1/125"
;;

2)
LAN="2000::2001/118"
S1="2000::2:2/125"
S2="2000::3:1/126"
;;

3)
S1="2000::3:2/126"
S2="2000::4:1/126"
S3="2000::8:1/125"
;;

4)
LAN="2000::3001/118"
S1="2000::4:2/126"
S2="2000::5:1/125"
;;

5)
LAN="2000::4001/118"
S1="2000::5:2/125"
S2="2000::6:1/126"
;;

6)
LAN="2000::5001/118"
S1="2000::6:2/126"
S2="2000::7:1/126"
;;

7)
LAN="2000::6001/118"
S1="2000::7:2/126"
;;

8)
LAN="2000::7001/118"
S1="2000::8:2/125"
S2="2000::9:1/125"
;;

9)
LAN="2000::8001/118"
S1="2000::9:2/125"
S2="2000::10:1/125"
;;

10)
LAN="2000::9001/118"
S1="2000::10:2/125"
S2="2000::11:1/125"
;;

11)
LAN="2000::A001/118"
S1="2000::11:2/125"
;;

*)
echo "Router inválido"
exit
;;

esac

# Configurar interfaces (asumiendo nombres estándar)
ip link set eth0 up
ip link set eth1 up
ip link set eth2 up

# Limpiar IPs
ip -6 addr flush dev eth0
ip -6 addr flush dev eth1
ip -6 addr flush dev eth2

# Asignar direcciones
[ ! -z "$LAN" ] && ip -6 addr add $LAN dev eth0
[ ! -z "$S1" ] && ip -6 addr add $S1 dev eth1
[ ! -z "$S2" ] && ip -6 addr add $S2 dev eth2

# Crear configuración FRR
cat > /etc/frr/frr.conf <<EOF
frr version 8.4.4
frr defaults traditional
hostname R$R
log syslog informational

router ospf6
 router-id $RID

 interface eth0 area 0.0.0.0
 interface eth1 area 0.0.0.0
 interface eth2 area 0.0.0.0
EOF

# Permisos
chown frr:frr /etc/frr/frr.conf

# Reiniciar servicio
systemctl restart frr

echo "=============================="
echo " Router R$R configurado"
echo " Router-ID: $RID"
echo "=============================="
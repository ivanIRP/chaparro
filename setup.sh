#!/bin/bash

if [ "$EUID" -ne 0 ]; then
echo "Ejecuta con sudo"
exit
fi

while true
do

echo ""
echo "1 Configurar Router R0"
echo "2 Configurar Router R1"
echo "3 Salir"

read -p "Seleccione opcion: " op

case $op in

1.

cat > /etc/frr/frr.conf <<EOF
hostname R0
service integrated-vtysh-config

ipv6 forwarding

interface enp0s3
ipv6 address 2001:1::1/64
ipv6 rip RIP enable

interface enp0s8
ipv6 address 2001:2::1/64
ipv6 rip RIP enable

interface enp0s9
ipv6 address 2001:3::1/64
ipv6 rip RIP enable

ipv6 router rip RIP

line vty
EOF

systemctl restart frr

echo "Router R0 configurado"

;;

2.

cat > /etc/frr/frr.conf <<EOF
hostname R1
service integrated-vtysh-config

ipv6 forwarding

interface enp0s3
ipv6 address 2001:4::1/64
ipv6 rip RIP enable

interface enp0s8
ipv6 address 2001:5::1/64
ipv6 rip RIP enable

interface enp0s9
ipv6 address 2001:3::2/64
ipv6 rip RIP enable

ipv6 router rip RIP

line vty
EOF

systemctl restart frr

echo "Router R1 configurado"

;;

3.

exit
;;

*)
echo "Opcion invalida"
;;

esac

done

#!/bin/bash

if [ "$EUID" -ne 0 ]; then
echo "Ejecuta con sudo"
exit
fi

clear
echo "CONFIGURADOR FRR LIMPIO"

echo "1) Configurar R0"
echo "2) Configurar R1"
echo "3) Salir"

read -p "Seleccione router: " op

systemctl stop frr

ip addr flush dev enp0s3
ip addr flush dev enp0s8
ip addr flush dev enp0s9

rm -f /etc/frr/frr.conf

if [ "$op" = "1" ]; then

echo "hostname R0
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
line vty" > /etc/frr/frr.conf

systemctl start frr
echo "R0 configurado correctamente"

elif [ "$op" = "2" ]; then

echo "hostname R1
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
line vty" > /etc/frr/frr.conf

systemctl start frr
echo "R1 configurado correctamente"

else

echo "Saliendo"
exit

fi

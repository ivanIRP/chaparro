#!/bin/bash

clear
echo "CONFIGURADOR FRR"

echo "1) Configurar R0"
echo "2) Configurar R1"
read -p "Selecciona router: " op

if [ "$op" = "1" ]; then

echo "Configurando R0..."

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

systemctl restart frr
echo "R0 configurado"

elif [ "$op" = "2" ]; then

echo "Configurando R1..."

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

systemctl restart frr
echo "R1 configurado"

else

echo "Opcion invalida"

fi

#!/bin/bash

error_exit(){
echo "ERROR: $1"
exit 1
}

check_root(){
if [ "$EUID" -ne 0 ]; then
echo "Ejecuta con sudo"
exit 1
fi
}

check_vtysh(){
command -v vtysh >/dev/null 2>&1 || error_exit "vtysh no instalado"
}

interface_check(){
ip link show "$1" >/dev/null 2>&1
return $?
}

activar_interfaz(){
if interface_check "$1"; then
ip link set "$1" up
else
echo "Interfaz $1 no existe"
fi
}

config_R0(){

IF1="enp0s8"
IF2="enp0s9"
IF3="enp0s10"

if interface_check "$IF1" && interface_check "$IF2" && interface_check "$IF3"
then

activar_interfaz "$IF1"
activar_interfaz "$IF2"
activar_interfaz "$IF3"

vtysh <<EOF
configure terminal
hostname R0
interface $IF1
ipv6 address 2001:2::1/64
ipv6 rip red enable
interface $IF2
ipv6 address 2001:1::1/64
ipv6 rip red enable
interface $IF3
ipv6 address 2001:3::1/64
ipv6 rip red enable
ipv6 router rip red
end
write
EOF

echo "R0 configurado"

else
echo "Interfaces requeridas no encontradas"
fi

}

config_R1(){

IF1="enp0s8"
IF2="enp0s9"
IF3="enp0s10"

if interface_check "$IF1" && interface_check "$IF2" && interface_check "$IF3"
then

activar_interfaz "$IF1"
activar_interfaz "$IF2"
activar_interfaz "$IF3"

vtysh <<EOF
configure terminal
hostname R1
interface $IF1
ipv6 address 2001:4::1/64
ipv6 rip red enable
interface $IF2
ipv6 address 2001:5::1/64
ipv6 rip red enable
interface $IF3
ipv6 address 2001:3::2/64
ipv6 rip red enable
ipv6 router rip red
end
write
EOF

echo "R1 configurado"

else
echo "Interfaces requeridas no encontradas"
fi

}

config_PC0(){
IF="enp0s8"
if interface_check "$IF"
then
ip link set "$IF" up
ip -6 addr add 2001:2::2/64 dev "$IF"
ip -6 route add default via 2001:2::1
echo "PC0 configurada"
else
echo "Interfaz no encontrada"
fi
}

config_PC1(){
IF="enp0s8"
if interface_check "$IF"
then
ip link set "$IF" up
ip -6 addr add 2001:1::2/64 dev "$IF"
ip -6 route add default via 2001:1::1
echo "PC1 configurada"
else
echo "Interfaz no encontrada"
fi
}

config_PC2(){
IF="enp0s8"
if interface_check "$IF"
then
ip link set "$IF" up
ip -6 addr add 2001:5::2/64 dev "$IF"
ip -6 route add default via 2001:5::1
echo "PC2 configurada"
else
echo "Interfaz no encontrada"
fi
}

config_PC3(){
IF="enp0s8"
if interface_check "$IF"
then
ip link set "$IF" up
ip -6 addr add 2001:4::2/64 dev "$IF"
ip -6 route add default via 2001:4::1
echo "PC3 configurada"
else
echo "Interfaz no encontrada"
fi
}

check_root
check_vtysh

while true
do

echo ""
echo "1 Router R0"
echo "2 Router R1"
echo "3 PC0"
echo "4 PC1"
echo "5 PC2"
echo "6 PC3"
echo "7 Salir"

read -p "Seleccione opcion: " opc

case $opc in

1. config_R0 ;;
2. config_R1 ;;
3. config_PC0 ;;
4. config_PC1 ;;
5. config_PC2 ;;
6. config_PC3 ;;
7. exit 0 ;;
   *) echo "Opcion invalida" ;;
   esac

done

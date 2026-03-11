
function error_exit() {
echo "ERROR: $1"
exit 1
}

function check_root() {
if [ "$EUID" -ne 0 ]; then
error_exit "Debe ejecutar el script como root o con sudo."
fi
}

function check_frr() {

```
if ! command -v vtysh &> /dev/null
then
    error_exit "FRR o vtysh no estan instalados."
else
    echo "FRR detectado correctamente."
fi
```

}

function interface_exists() {

```
ip link show "$1" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    return 1
else
    return 0
fi
```

}

function activate_interface() {

```
if interface_exists "$1"; then
    ip link set "$1" up
    echo "Interfaz $1 activada"
else
    echo "Interfaz $1 no existe"
fi
```

}

function clean_interface() {

```
if interface_exists "$1"; then
    ip -6 addr flush dev "$1"
fi
```

}

function config_R0(){

echo "Configurando Router R0..."

IF1="eth0"
IF2="eth1"
IF3="eth2"

if interface_exists $IF1 && interface_exists $IF2 && interface_exists $IF3
then

activate_interface $IF1
activate_interface $IF2
activate_interface $IF3

clean_interface $IF1
clean_interface $IF2
clean_interface $IF3

vtysh << EOF

configure terminal

hostname R0

interface $IF1
ipv6 address 2001:2::1/64
ipv6 rip cisco enable

interface $IF2
ipv6 address 2001:1::1/64
ipv6 rip cisco enable

interface $IF3
ipv6 address 2001:3::1/64
ipv6 rip cisco enable

ipv6 router rip cisco

end
write

EOF

echo "Router R0 configurado correctamente."

else

echo "ERROR: Interfaces necesarias no encontradas."
fi

}

function config_R1(){

echo "Configurando Router R1..."

IF1="eth0"
IF2="eth1"
IF3="eth2"

if interface_exists $IF1 && interface_exists $IF2 && interface_exists $IF3
then

activate_interface $IF1
activate_interface $IF2
activate_interface $IF3

clean_interface $IF1
clean_interface $IF2
clean_interface $IF3

vtysh << EOF

configure terminal

hostname R1

interface $IF1
ipv6 address 2001:4::1/64
ipv6 rip cisco enable

interface $IF2
ipv6 address 2001:5::1/64
ipv6 rip cisco enable

interface $IF3
ipv6 address 2001:3::2/64
ipv6 rip cisco enable

ipv6 router rip cisco

end
write

EOF

echo "Router R1 configurado correctamente."

else

echo "ERROR: Interfaces necesarias no encontradas."
fi

}

function config_PC0(){

IF="eth0"

if interface_exists $IF
then

activate_interface $IF
clean_interface $IF

ip -6 addr add 2001:2::2/64 dev $IF
ip -6 route add default via 2001:2::1

echo "PC0 configurada."

else
echo "ERROR: interfaz $IF no encontrada"
fi

}

function config_PC1(){

IF="eth0"

if interface_exists $IF
then

activate_interface $IF
clean_interface $IF

ip -6 addr add 2001:1::2/64 dev $IF
ip -6 route add default via 2001:1::1

echo "PC1 configurada."

else
echo "ERROR: interfaz $IF no encontrada"
fi

}

function config_PC2(){

IF="eth0"

if interface_exists $IF
then

activate_interface $IF
clean_interface $IF

ip -6 addr add 2001:5::2/64 dev $IF
ip -6 route add default via 2001:5::1

echo "PC2 configurada."

else
echo "ERROR: interfaz $IF no encontrada"
fi

}

function config_PC3(){

IF="eth0"

if interface_exists $IF
then

activate_interface $IF
clean_interface $IF

ip -6 addr add 2001:4::2/64 dev $IF
ip -6 route add default via 2001:4::1

echo "PC3 configurada."

else
echo "ERROR: interfaz $IF no encontrada"
fi

}

check_root
check_frr

while true
do

echo ""
echo "================================"
echo " CONFIGURADOR DE RED IPv6"
echo "================================"
echo "1) Configurar Router R0"
echo "2) Configurar Router R1"
echo "3) Configurar PC0"
echo "4) Configurar PC1"
echo "5) Configurar PC2"
echo "6) Configurar PC3"
echo "7) Salir"
echo ""

read -p "Seleccione una opcion: " opc

case $opc in

1. config_R0 ;;
2. config_R1 ;;
3. config_PC0 ;;
4. config_PC1 ;;
5. config_PC2 ;;
6. config_PC3 ;;
7. echo "Saliendo..."; exit 0 ;;
   *) echo "Opcion invalida";;

esac

done

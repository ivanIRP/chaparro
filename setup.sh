#!/bin/bash
# Auto-configurador de Clientes Debian 12

IF_PC="enp0s3"

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root (sudo)"
  exit 1
fi

echo "======================================="
echo "   CONFIGURACION DE EQUIPO FINAL (PC)  "
echo "======================================="
echo "En tu topologia, solo los Routers 0, 1, 4 y 5 tienen PCs conectadas."
echo "A que Router esta conectado este equipo? (Ingresa 0, 1, 4 o 5):"
read -p "Conectado a Router R: " ROUTER_NUM

ip addr flush dev $IF_PC 2>/dev/null
ip -6 route flush dev $IF_PC 2>/dev/null

case $ROUTER_NUM in
  0)
    echo "Configurando PC0 (Conectada a R0)..."
    ip link set up dev $IF_PC
    ip -6 addr add 2000::2/64 dev $IF_PC
    ip -6 route add default via 2000::1 dev $IF_PC
    ;;
  1)
    echo "Configurando PC1 (Conectada a R1)..."
    ip link set up dev $IF_PC
    ip -6 addr add 2001::2/64 dev $IF_PC
    ip -6 route add default via 2001::1 dev $IF_PC
    ;;
  2|3)
    echo "Error: En tu diagrama, el Router R$ROUTER_NUM es de transito IPv4 y no tiene PC conectada."
    exit 1
    ;;
  4)
    echo "Configurando PC2 (Conectada a R4)..."
    ip link set up dev $IF_PC
    ip -6 addr add 2003::2/64 dev $IF_PC
    ip -6 route add default via 2003::1 dev $IF_PC
    ;;
  5)
    echo "Configurando PC3 (Conectada a R5)..."
    ip link set up dev $IF_PC
    ip -6 addr add 2004::2/64 dev $IF_PC
    ip -6 route add default via 2004::1 dev $IF_PC
    ;;
  *)
    echo "Error: Numero de router no valido. Debe ser 0, 1, 4 o 5."
    exit 1
    ;;
esac

echo "======================================="
echo "Configuracion completada."
echo "======================================="
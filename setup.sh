#!/bin/bash

clear

echo "CONFIGURADOR DE ROUTERS FRR"
echo "1) R0 RIPng"
echo "2) R1 RIPng"
echo "3) R0 EIGRP"
echo "4) R1 EIGRP"
echo "5) R0 OSPFv3"
echo "6) R1 OSPFv3"
echo ""

read -p "Selecciona una opcion: " opc

if [ "$opc" == "1" ]; then

sudo systemctl restart frr

sudo vtysh << EOF
conf t
router ripng
network enp0s3
network enp0s8
network enp0s9
exit
end
write
EOF

echo "R0 configurado con RIPng"

elif [ "$opc" == "2" ]; then

sudo systemctl restart frr

sudo vtysh << EOF
conf t
router ripng
network enp0s3
network enp0s8
network enp0s9
exit
end
write
EOF

echo "R1 configurado con RIPng"

elif [ "$opc" == "3" ]; then

sudo systemctl restart frr

sudo vtysh << EOF
conf t
router eigrp 10
network enp0s3
network enp0s8
network enp0s9
exit
end
write
EOF

echo "R0 configurado con EIGRP"

elif [ "$opc" == "4" ]; then

sudo systemctl restart frr

sudo vtysh << EOF
conf t
router eigrp 10
network enp0s3
network enp0s8
network enp0s9
exit
end
write
EOF

echo "R1 configurado con EIGRP"

elif [ "$opc" == "5" ]; then

sudo systemctl restart frr

sudo vtysh << EOF
conf t
router ospf6
interface enp0s3 area 0
interface enp0s8 area 0
interface enp0s9 area 0
exit
end
write
EOF

echo "R0 configurado con OSPFv3"

elif [ "$opc" == "6" ]; then

sudo systemctl restart frr

sudo vtysh << EOF
conf t
router ospf6
interface enp0s3 area 0
interface enp0s8 area 0
interface enp0s9 area 0
exit
end
write
EOF

echo "R1 configurado con OSPFv3"

else
echo "Opcion no valida"
fi

#Aktibvera så att internet fungerar

# sudo ip link set ens4 up
# sudo dhclient -v ens4

# ladda ner skriptet på:
# curl -O andreymsh.se/script.sh

#gör den körbar chmod +x script.sh 

#!/bin/bash

# Installera SSH om det inte redan är installerat
if ! command -v ssh &> /dev/null; then
    sudo apt update
    sudo apt install -y openssh-server
fi

# Aktivera IP forwarding om det inte redan är aktiverat
if [[ $(sysctl -n net.ipv4.ip_forward) != 1 ]]; then
    sudo sysctl -w net.ipv4.ip_forward=1
fi

# Ta bort befintlig IP-adress från ens5 om den finns
sudo ip addr flush dev ens5

# Ändra konfigurationen i /etc/network/interfaces
sudo tee /etc/network/interfaces > /dev/null <<EOF
auto lo
iface lo inet loopback

auto ens4
iface ens4 inet dhcp

auto ens5
iface ens5 inet static
    address 192.168.1.1
    netmask 255.255.255.0
EOF

# Starta om nätverket för att tillämpa ändringarna
sudo systemctl restart networking

# Installera och konfigurera DHCP-server om det inte redan är installerat
if ! dpkg -l | grep -q isc-dhcp-server; then
    sudo apt install -y isc-dhcp-server
    # Ändra DHCP-serverkonfigurationen för att använda ens5
    sudo sed -i 's/INTERFACESv4=""/INTERFACESv4="ens5"/' /etc/default/isc-dhcp-server
    # Konfigurera DHCP-servern
    sudo cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak  # Säkerhetskopiera konfigurationsfilen
    if sudo tee -a /etc/dhcp/dhcpd.conf > /dev/null <<EOF

option domain-name-servers 8.8.8.8, 8.8.4.4;
option routers 192.168.1.1;

subnet 192.168.1.0 netmask 255.255.255.0 {
  range 192.168.1.100 192.168.1.200;
  option broadcast-address 192.168.1.255;
}
EOF
    then
        echo "Tee-kommando kördes"
    else
        echo "Tee-kommandot misslyckades" >&2
        exit 1
    fi

    sudo systemctl restart isc-dhcp-server
fi

# Installera och konfigurera Nftables om det inte redan är installerat
if ! dpkg -l | grep -q nftables; then
    sudo apt install -y nftables
    # Skapa och applicera Nftables-regler
    sudo tee /etc/nftables.conf > /dev/null <<EOF
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy accept;
        tcp dport 22 accept
    }

    chain forward {
        type filter hook forward priority 0; policy accept;
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}

table inet nat {
    chain prerouting {
        type nat hook prerouting priority 0; policy accept;
    }

    chain postrouting {
        type nat hook postrouting priority 100; policy accept;
        oif ens4 masquerade
    }
}
EOF
    sudo systemctl restart nftables
    sudo systemctl restart isc-dhcp-server
fi

echo "Installation och konfiguration av nätverkskomponenter är klar."

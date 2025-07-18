#!/bin/bash
IPADDR=$1
CIDR=$2
GATEWAY=$3
sudo mkdir -p /etc/netplan/backup
sudo mv /etc/netplan/*.yaml /etc/netplan/backup/
sudo tee /etc/netplan/99-mine.yaml > /dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
      dhcp4-overrides:
        use-routes: false
      dhcp6: false
    eth1:
      dhcp4: false
      dhcp6: false
      addresses: [$IPADDR/$CIDR]
      routes:
        - to: default
          via: $GATEWAY
EOF
sudo chmod 600 /etc/netplan/99-mine.yaml
sudo netplan generate
sudo netplan apply
# mirror ubuntu to kakao
sudo sed -i 's|http://.*\.ubuntu\.com/ubuntu/|http://mirror.kakao.com/ubuntu/|g' /etc/apt/sources.list.d/ubuntu.sources
sudo apt update -y >/dev/null 2>&1

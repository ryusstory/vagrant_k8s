#!/bin/bash
echo "--- Netplan configuration start ---"
if [[ ! -f /usr/local/bin/yq ]]; then
    cp /_shared/yq /usr/local/bin/yq && chmod +x /usr/local/bin/yq
fi

INSTANCE_INDEX=$1
SUBNET=$(cat /_shared/config.yaml | yq '.network.subnet')
IP_OFFSET=$(cat /_shared/config.yaml | yq '.network.ip_offset')
if [[ "$(hostname)" == k8c* ]]; then
  IPADDR="${SUBNET}.$((IP_OFFSET + INSTANCE_INDEX))"
elif [[ "$(hostname)" == k8w* ]]; then
  IPADDR="${SUBNET}.$((IP_OFFSET + 10 + INSTANCE_INDEX))"
elif [[ "$(hostname)" == k8ha ]]; then
  IPADDR="${SUBNET}.${IP_OFFSET}"
else
  echo "Unknown hostname format: $(hostname)"
  exit 1
fi
CIDR=$(cat /_shared/config.yaml | yq '.network.cidr')
GATEWAY=$(cat /_shared/config.yaml | yq '.network.gateway')

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

sed -i 's|http://.*\.ubuntu\.com/ubuntu/|http://mirror.kakao.com/ubuntu/|g' /etc/apt/sources.list.d/ubuntu.sources

echo "--- Netplan configuration applied ---"
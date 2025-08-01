#!/bin/bash
K8S_VERSION=$(cat /_shared/config.yaml | yq '.k8s.k8s_version')
K8S_RELEASE_VERSION=$(echo "$K8S_VERSION" | cut -d '.' -f 1-2)
CONTAINERD_VERSION=$(cat /_shared/config.yaml | yq '.k8s.containerd_version')

if [[ -f ~/.$(basename "$0").done ]]; then
    echo "--- This script has already been executed. Exiting."
    exit 0
fi

echo "--- $(hostname) Initial Config Start ---"

echo 'alias vi=vim' >> /etc/profile
echo 'sudo su - && exit' >> /home/vagrant/.bashrc
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime

systemctl stop ufw && systemctl disable ufw >/dev/null 2>&1
systemctl stop apparmor && systemctl disable apparmor >/dev/null 2>&1

swapoff -a && sed -i '/swap/s/^/#/' /etc/fstab
rm -f /swapfile >/dev/null 2>&1

# mirror ubuntu to kakao
apt update -y -qq >/dev/null 2>&1
apt install apt-transport-https ca-certificates curl gpg -y -qq >/dev/null 2>&1

# packets traversing the bridge are processed by iptables for filtering
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/k8s.conf
sysctl --system >/dev/null 2>&1

# enable br_netfilter for iptables 
modprobe br_netfilter
modprobe overlay
modprobe vxlan
modprobe geneve
echo "br_netfilter" >> /etc/modules-load.d/k8s.conf
echo "overlay" >> /etc/modules-load.d/k8s.conf

# Download the public signing key for the Kubernetes package repositories.
mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v$K8S_RELEASE_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg 2>/dev/null
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$K8S_RELEASE_VERSION/deb/ /" >> /etc/apt/sources.list.d/kubernetes.list 2>/dev/null

# Update the apt package index, install kubelet, kubeadm and kubectl, and pin their version
apt update -qq >/dev/null 2>&1

# containerd.io
if [[ $CONTAINERD_VERSION == 2.* ]]; then
  #https://github.com/containerd/containerd/releases/
  wget https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VERSION/containerd-$CONTAINERD_VERSION-linux-amd64.tar.gz 2>/dev/null
  tar -xvf containerd-$CONTAINERD_VERSION-linux-amd64.tar.gz &>/dev/null
  cp bin/* /usr/local/bin/ 2>/dev/null
  rm -f containerd-$CONTAINERD_VERSION-linux-amd64.tar.gz 2>/dev/null
  wget https://raw.githubusercontent.com/containerd/containerd/v$CONTAINERD_VERSION/containerd.service -O /etc/systemd/system/containerd.service >/dev/null 2>&1
  sudo mkdir -p /etc/containerd
  sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
  wget https://github.com/opencontainers/runc/releases/download/v1.3.0/runc.amd64 -O /usr/local/sbin/runc 2>/dev/null
  chmod +x /usr/local/sbin/runc
else
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt install -y containerd.io=$CONTAINERD_VERSION >/dev/null
fi

apt list -a kubelet | grep amd64 > /tmp/k8s_versions.txt
K8S_FULL_VERSION=$(cat /tmp/k8s_versions.txt | head -n 1 | awk '{print $2}')
apt install -y kubelet=$K8S_FULL_VERSION kubectl=$K8S_FULL_VERSION kubeadm=$K8S_FULL_VERSION >/dev/null 2>&1
apt-mark hold kubelet kubeadm kubectl >/dev/null 2>&1

# containerd configure to default and cgroup managed by systemd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# avoid WARN&ERRO(default endpoints) when crictl run  
cat <<EOF > /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
EOF

# ready to install for k8s 
systemctl restart containerd && systemctl enable containerd >/dev/null 2>&1
systemctl enable --now kubelet >/dev/null 2>&1

apt install -y bridge-utils sshpass net-tools conntrack ngrep tcpdump ipset arping wireguard jq tree bash-completion unzip kubecolor >/dev/null 2>&1

echo "--- Initial Config End ---"
touch ~/.$(basename "$0").done

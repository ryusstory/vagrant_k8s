#!/bin/bash
SUBNET=$(ip -4 addr show eth1 | grep inet | awk '{print $2}' | cut -d. -f1-3)
NODE_NUMBER=$(ip -4 addr show eth1 | grep inet | awk '{print $2}' | cut -d/ -f1 | rev | cut -c1)
NETWORK_IP_OFFSET=$(cat /_shared/config.yaml | yq '.network.ip_offset')
K8S_VERSION=$(cat /_shared/config.yaml | yq '.k8s.k8s_version')
POD_SUBNET=$(cat /_shared/config.yaml | yq '.k8s.pod_subnet')
SERVICE_SUBNET=$(cat /_shared/config.yaml | yq '.k8s.service_subnet')
K8S_KUBEPROXY=$(cat /_shared/config.yaml | yq '.k8s.kubeproxy')
NETWORK_IP_OFFSET=$(cat /_shared/config.yaml | yq '.network.ip_offset')

if [[ -f ~/.$(basename "$0").done ]]; then
    echo "--- This script has already been executed. Exiting."
    exit 0
fi
sudo tee kubeadm-init.yaml > /dev/null <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 0s
  usages:
  - signing
  - authentication
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
localAPIEndpoint:
  advertiseAddress: "$SUBNET.$((NETWORK_IP_OFFSET + NODE_NUMBER))"
  bindPort: 6443
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
networking:
  podSubnet: $POD_SUBNET
  serviceSubnet: $SERVICE_SUBNET
kubernetesVersion: "v$K8S_VERSION"
controlPlaneEndpoint: $SUBNET.$NETWORK_IP_OFFSET:6443
EOF
if [[ $K8S_KUBEPROXY == "false" ]]; then
  yq -i 'select(.kind == "ClusterConfiguration").proxy.disabled = true' kubeadm-init.yaml
  yq -i 'select(.kind == "InitConfiguration").skipPhases = ["addon/kube-proxy"]' kubeadm-init.yaml
fi

kubeadm config images pull --kubernetes-version $K8S_VERSION
kubeadm init --config kubeadm-init.yaml --upload-certs | tee /_shared/kubeadm_init.log
if [ $? -ne 0 ]; then
    echo "kubeadm init failed. Please check the logs for details."
    exit 1
fi

echo "kubeadm config images pull --kubernetes-version $K8S_VERSION" > /_shared/kubeadm_control_join.sh
awk '/You can now join any number of control-plane nodes/,/Please note/' /_shared/kubeadm_init.log | grep -v "Please note" | grep "kubeadm join" -A 2 | sed 's/^  //' >> /_shared/kubeadm_control_join.sh  

echo "kubeadm config images pull --kubernetes-version $K8S_VERSION" > /_shared/kubeadm_worker_join.sh
awk '/Then you can join any number of worker nodes/,/EOF/' /_shared/kubeadm_init.log | grep "kubeadm join" -A 1 | sed 's/^//' >> /_shared/kubeadm_worker_join.sh

chmod +x /_shared/kubeadm_*.sh

sudo cp /etc/kubernetes/admin.conf /_shared/kube_config

curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash >/dev/null 2>&1

echo "--- K8S Controlplane Config End ---"
touch ~/.$(basename "$0").done

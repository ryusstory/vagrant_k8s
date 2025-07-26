#!/bin/bash
set -euo pipefail

ARGS_JSON=$(cat /_shared/args.json)
SUBNET=$(ip -4 addr show eth1 | grep inet | awk '{print $2}' | cut -d. -f1-3)
NODE_NUMBER=$(ip -4 addr show eth1 | grep inet | awk '{print $2}' | cut -d/ -f1 | rev | cut -c1)
NETWORK_IP_OFFSET=$(echo "$ARGS_JSON" | jq -r '.network.ip_offset')
SHARED_DIR=$(echo "$ARGS_JSON" | jq -r '.shared_dir')
K8S_VERSION=$(echo "$ARGS_JSON" | jq -r '.k8s.k8s_version')
POD_SUBNET=$(echo "$ARGS_JSON" | jq -r '.k8s.pod_subnet')
SERVICE_SUBNET=$(echo "$ARGS_JSON" | jq -r '.k8s.service_subnet')
K8S_CNI=$(echo "$ARGS_JSON" | jq -r '.k8s.cni')
K8S_CILIUM_PROXY=$(echo "$ARGS_JSON" | jq -r '.k8s.cilium.proxy')
NETWORK_IP_OFFSET=$(echo "$ARGS_JSON" | jq -r '.network.ip_offset')

if [[ -f ~/.$(basename "$0").done ]]; then
    echo "This script has already been executed. Exiting."
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
kubernetesVersion: "v1.33.3"
controlPlaneEndpoint: $SUBNET.$NETWORK_IP_OFFSET:6443
EOF
if [[ $K8S_CNI == "cilium" ]] && [[ $K8S_CILIUM_PROXY == "false" ]]; then
    yq 'select(.kind == "InitConfiguration").proxy.disabled = true' kubeadm-init.yaml
fi

kubeadm config images pull --kubernetes-version $K8S_VERSION
kubeadm init --config kubeadm-init.yaml --upload-certs | tee /$SHARED_DIR/kubeadm_init.log
if [ $? -ne 0 ]; then
    echo "kubeadm init failed. Please check the logs for details."
    exit 1
fi

echo "kubeadm config images pull --kubernetes-version $K8S_VERSION" > /$SHARED_DIR/kubeadm_control_join.sh
awk '/You can now join any number of control-plane nodes/,/Please note/' /$SHARED_DIR/kubeadm_init.log | grep -v "Please note" | grep "kubeadm join" -A 2 | sed 's/^  //' >> /$SHARED_DIR/kubeadm_control_join.sh  

echo "kubeadm config images pull --kubernetes-version $K8S_VERSION" > /$SHARED_DIR/kubeadm_worker_join.sh
awk '/Then you can join any number of worker nodes/,/EOF/' /$SHARED_DIR/kubeadm_init.log | grep "kubeadm join" -A 1 | sed 's/^//' >> /$SHARED_DIR/kubeadm_worker_join.sh

chmod +x /$SHARED_DIR/kubeadm_*.sh

sudo cp /etc/kubernetes/admin.conf /$SHARED_DIR/kube_config

curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash >/dev/null 2>&1

echo ">>>> K8S Controlplane Config End <<<<"
touch ~/.$(basename "$0").done

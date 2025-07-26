#!/bin/bash
set -euo pipefail

# --- VARIABLES ---
ARGS_JSON="$1" #{"box_image":"ubu24","network":{"bridge_adapter":"en0: Wi-Fi","subnet":"172.21.30","cidr":"16","gateway":"172.21.0.1"},"k8s":{"version":"1.33.3-1.1","containerd_version":"2.1.3"},"node_counts":{"control_plane":1,"worker":4},"node_resources":{"control_plane":{"cpu":2,"memory_mb":4096},"worker":{"cpu":2,"memory_mb":4096}}}
# ARGS_JSON="$(cat /_shared/args.json)"
CONTROL_PLANE_COUNT=$(echo "$ARGS_JSON" | jq -r '.node_counts.control_plane')
WORKER_COUNT=$(echo "$ARGS_JSON" | jq -r '.node_counts.worker')
NETWORK_SUBNET=$(echo "$ARGS_JSON" | jq -r '.network.subnet')
NETWORK_IP_OFFSET=$(echo "$ARGS_JSON" | jq -r '.network.ip_offset')
K8S_CNI=$(echo "$ARGS_JSON" | jq -r '.k8s.cni')
K8S_VERSION=$(echo "$ARGS_JSON" | jq -r '.k8s.k8s_version')
CONTAINERD_VERSION=$(echo "$ARGS_JSON" | jq -r '.k8s.containerd_version')
SHARED_DIR=$(echo "$ARGS_JSON" | jq -r '.shared_dir')
NODE_IP_ADDRS=""
for (( i=1; i<=CONTROL_PLANE_COUNT; i++ )); do NODE_IP_ADDRS+=" $NETWORK_SUBNET.$((NETWORK_IP_OFFSET + i))"; done
for (( i=1; i<=WORKER_COUNT; i++ )); do NODE_IP_ADDRS+=" $NETWORK_SUBNET.$((NETWORK_IP_OFFSET + 10 + i))"; done
SSH_PREFIX="-o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null root"

# --- MAIN SCRIPT ---
echo "--- check node status ---"
echo "IP 목록: $NODE_IP_ADDRS"
while true; do
    ALL_NODES_READY="true"
    for NODE_IP in $NODE_IP_ADDRS; do
        if ! ssh $SSH_PREFIX@$NODE_IP "hostname" 2>/dev/null; then
            ALL_NODES_READY="false"
            break
        fi
    done
    if [ "$ALL_NODES_READY" = "true" ]; then
        echo "OK"
        break
    else
        echo "Waiting 10 seconds..."
        sleep 10
    fi
done
echo "--- copy scripts ---"
for NODE_IP in $NODE_IP_ADDRS; do
    ssh $SSH_PREFIX@$NODE_IP "cp /$SHARED_DIR/scripts/* /tmp/ && chmod +x /tmp/*.sh"
done

echo "--- Kubernetes init script ---"
for NODE_IP in $NODE_IP_ADDRS; do
    ssh $SSH_PREFIX@$NODE_IP "sudo /tmp/_k8s_init.sh" && echo "Initialized $NODE_IP" &
done
wait

echo "--- kubeadm init on first control node ---"
ssh $SSH_PREFIX@$NETWORK_SUBNET.$((NETWORK_IP_OFFSET + 1)) "sudo /tmp/_k8s_kubeadm_init.sh > /dev/null 2>&1" && echo "kubeadm init complete"

echo "--- Join control plane nodes ---"
if [[ ! -f "/$SHARED_DIR/kubeadm_control_join.sh" ]] || [[ ! -f "/$SHARED_DIR/kubeadm_worker_join.sh" ]]; then
    echo "kubeadm_control_join.sh or kubeadm_worker_join.sh not found."
    exit 1
fi

for (( i=2; i<=CONTROL_PLANE_COUNT; i++ )); do
    ssh $SSH_PREFIX@$NETWORK_SUBNET.$((NETWORK_IP_OFFSET + i)) "cp /$SHARED_DIR/kubeadm_control_join.sh /tmp/ && chmod +x /tmp/kubeadm_control_join.sh && sudo /tmp/kubeadm_control_join.sh > /dev/null 2>&1" &
done
echo "--- Join worker nodes ---"
for (( i=1; i<=WORKER_COUNT; i++ )); do
    ssh $SSH_PREFIX@$NETWORK_SUBNET.$((NETWORK_IP_OFFSET + 10 + i)) "cp /$SHARED_DIR/kubeadm_worker_join.sh /tmp/ && chmod +x /tmp/kubeadm_worker_join.sh && sudo /tmp/kubeadm_worker_join.sh > /dev/null 2>&1" &
done

echo "--- Node post configuration ---"
for NODE_IP in $NODE_IP_ADDRS; do
    ssh $SSH_PREFIX@$NODE_IP "sudo /tmp/_k8s_post_setting.sh"
done

echo "--- Install CNI ---"
ssh $SSH_PREFIX@$NETWORK_SUBNET.$((NETWORK_IP_OFFSET + 1)) "sudo /tmp/_k8s_cni_install.sh > /dev/null 2>&1" && echo "CNI installed"
echo "installing $K8S_CNI"

echo "--------------------------------------------------------------------------"
echo ""
echo " Powershell/Mac/Linux >>> cp $SHARED_DIR/kube_config ~/.kube/config "
echo ""
echo "--------------------------------------------------------------------------"

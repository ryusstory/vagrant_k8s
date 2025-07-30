#!/bin/bash
# --- VARIABLES ---
CONTROL_PLANE_COUNT=$(cat /_shared/config.yaml | yq '.node_counts.control_plane')
WORKER_COUNT=$(cat /_shared/config.yaml | yq '.node_counts.worker')
NETWORK_SUBNET=$(cat /_shared/config.yaml | yq '.network.subnet')
NETWORK_IP_OFFSET=$(cat /_shared/config.yaml | yq '.network.ip_offset')

NODE_IP_ADDRS=""
for (( i=1; i<=CONTROL_PLANE_COUNT; i++ )); do NODE_IP_ADDRS+=" $NETWORK_SUBNET.$((NETWORK_IP_OFFSET + i))"; done
for (( i=1; i<=WORKER_COUNT; i++ )); do NODE_IP_ADDRS+=" $NETWORK_SUBNET.$((NETWORK_IP_OFFSET + 10 + i))"; done
SSH_PREFIX="-o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null root"

# --- MAIN SCRIPT ---
echo "--- Check node status ---"
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
echo "--- Copying scripts ---"
for NODE_IP in $NODE_IP_ADDRS; do
    ssh $SSH_PREFIX@$NODE_IP "cp /_shared/scripts/* /tmp/ && chmod +x /tmp/*.sh"
    ssh $SSH_PREFIX@$NODE_IP "cp /_shared/yq /usr/local/bin/yq && chmod +x /usr/local/bin/yq"
done

echo "--- Kubernetes init script ---"
for NODE_IP in $NODE_IP_ADDRS; do
    ssh $SSH_PREFIX@$NODE_IP "sudo /tmp/_k8s_init.sh" && echo "Initialized $NODE_IP" &
done
wait

echo "--- kubeadm init on first control node ---"
ssh $SSH_PREFIX@$NETWORK_SUBNET.$((NETWORK_IP_OFFSET + 1)) "sudo /tmp/_k8s_kubeadm_init.sh" && \
echo "--- kubeadm init complete ---"

echo "--- Join control plane nodes ---"
if [[ ! -f "/_shared/kubeadm_control_join.sh" ]] || [[ ! -f "/_shared/kubeadm_worker_join.sh" ]]; then
    echo "kubeadm_control_join.sh or kubeadm_worker_join.sh not found."
    exit 1
fi

for (( i=2; i<=CONTROL_PLANE_COUNT; i++ )); do
    ssh $SSH_PREFIX@$NETWORK_SUBNET.$((NETWORK_IP_OFFSET + i)) "cp /_shared/kubeadm_control_join.sh /tmp/ && chmod +x /tmp/kubeadm_control_join.sh && sudo /tmp/kubeadm_control_join.sh > /dev/null 2>&1" &
done
echo "--- Join worker nodes ---"
for (( i=1; i<=WORKER_COUNT; i++ )); do
    ssh $SSH_PREFIX@$NETWORK_SUBNET.$((NETWORK_IP_OFFSET + 10 + i)) "cp /_shared/kubeadm_worker_join.sh /tmp/ && chmod +x /tmp/kubeadm_worker_join.sh && sudo /tmp/kubeadm_worker_join.sh > /dev/null 2>&1" &
done

echo "--- Node post configuration ---"
for NODE_IP in $NODE_IP_ADDRS; do
    ssh $SSH_PREFIX@$NODE_IP "sudo /tmp/_k8s_post_setting.sh"
done

echo "--------------------------------------------------------------------------"
echo ""
echo " Powershell/Mac/Linux >>> cp _shared/kube_config ~/.kube/config "
echo " or >>> vagrant ssh k8c1 "
echo ""
echo "--------------------------------------------------------------------------"

#!/bin/bash
ARGS_JSON="$1"
SHARED_DIR=$(echo "$ARGS_JSON" | jq -r '.shared_dir')

if [[ -f "/$SHARED_DIR/kubeadm_control_join.sh" ]] || [[ -f "/$SHARED_DIR/kubeadm_worker_join.sh" ]]; then
    echo "later join node detected."
    HOSTNAME=$(hostname)
    cp /$SHARED_DIR/scripts/* /tmp/ && chmod +x /tmp/*.sh
    sudo /tmp/_k8s_init.sh && echo "Initialized $HOSTNAME"
    if [[ $HOSTNAME =~ k8c[2-9] ]]; then
        echo "This is a control plane node."
        cp /$SHARED_DIR/kubeadm_control_join.sh /tmp/
        chmod +x /tmp/kubeadm_control_join.sh
        sudo /tmp/_k8s_post_setting.sh
        sudo /tmp/kubeadm_control_join.sh
    elif [[ $HOSTNAME == k8w* ]]; then
        cp /$SHARED_DIR/kubeadm_worker_join.sh /tmp/
        chmod +x /tmp/kubeadm_worker_join.sh
        sudo /tmp/kubeadm_worker_join.sh
        sudo /tmp/_k8s_post_setting.sh
        echo "This is a worker node."
    else
        echo "Unknown node type. Exiting."
        exit 1
    fi
else
    echo "initial provisioning detected."
    exit 0
fi

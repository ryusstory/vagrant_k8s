#!/bin/bash
if [[ -f "/_shared/kubeadm_control_join.sh" ]] || [[ -f "/_shared/kubeadm_worker_join.sh" ]]; then
    echo "--- Kubernetes later join script started ---"
    HOSTNAME=$(hostname)
    cp /_shared/scripts/* /tmp/ && chmod +x /tmp/*.sh
    sudo /tmp/_k8s_init.sh && echo "Initialized $HOSTNAME"
    if [[ $HOSTNAME =~ k8c[2-9] ]]; then
        echo "--- Control plane node detected: $HOSTNAME"
        cp /_shared/kubeadm_control_join.sh /tmp/
        chmod +x /tmp/kubeadm_control_join.sh
        sudo /tmp/_k8s_post_setting.sh
        sudo /tmp/kubeadm_control_join.sh
    elif [[ $HOSTNAME == k8w* ]]; then
        echo "--- Worker node detected: $HOSTNAME"
        cp /_shared/kubeadm_worker_join.sh /tmp/
        chmod +x /tmp/kubeadm_worker_join.sh
        sudo /tmp/kubeadm_worker_join.sh
        sudo /tmp/_k8s_post_setting.sh
    else
        echo "Unknown node type. Exiting."
        exit 1
    fi
    echo "--- Kubernetes later join script completed ---"
else
    exit 0
fi

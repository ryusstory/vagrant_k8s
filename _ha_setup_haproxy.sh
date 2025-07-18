#!/bin/bash
ARGS_JSON="$1" #{"box_image":"ubu24","network":{"bridge_adapter":"en0: Wi-Fi","subnet":"172.21.30","cidr":"16","gateway":"172.21.0.1"},"k8s":{"version":"1.33.3-1.1","containerd_version":"2.1.3"},"node_counts":{"control_plane":1,"worker":4},"node_resources":{"control_plane":{"cpu":2,"memory_mb":4096},"worker":{"cpu":2,"memory_mb":4096}}}
NETWORK_SUBNET=$(echo "$ARGS_JSON" | jq -r '.network.subnet')
CONTROL_PLANE_NODE_COUNT=$(echo "$ARGS_JSON" | jq -r '.node_counts.control_plane')
NETWORK_IP_OFFSET=$(echo "$ARGS_JSON" | jq -r '.network.ip_offset')

sudo apt install -y haproxy net-tools >/dev/null 2>&1

sudo tee /etc/haproxy/haproxy.cfg >/dev/null <<EOF
global
    log stdout format raw local0
    daemon

defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 1
    timeout http-request    10s
    timeout queue           20s
    timeout connect         5s
    timeout client          35s
    timeout server          35s
    timeout http-keep-alive 10s
    timeout check           10s

frontend apiserver
    bind *:6443
    mode tcp
    option tcplog
    default_backend apiserverbackend

#---------------------------------------------------------------------
# round robin balancing for apiserver
#---------------------------------------------------------------------
backend apiserverbackend
    option httpchk

    http-check connect ssl
    http-check send meth GET uri /healthz
    http-check expect status 200

    mode tcp
    balance     roundrobin
EOF
for ((i=1; i<=$CONTROL_PLANE_NODE_COUNT; i++)); do
    echo "    server k8c${i} ${NETWORK_SUBNET}.$((NETWORK_IP_OFFSET + i)):6443 check verify none" | sudo tee -a /etc/haproxy/haproxy.cfg >/dev/null
done

sudo systemctl enable haproxy >/dev/null 2>&1
sudo systemctl restart haproxy >/dev/null 2>&1

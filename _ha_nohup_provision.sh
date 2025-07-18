#!/bin/bash
ARGS_JSON="$1" #{"box_image":"ubu24","network":{"bridge_adapter":"en0: Wi-Fi","subnet":"172.21.30","cidr":"16","gateway":"172.21.0.1"},"k8s":{"version":"1.33.3-1.1","containerd_version":"2.1.3"},"node_counts":{"control_plane":1,"worker":4},"node_resources":{"control_plane":{"cpu":2,"memory_mb":4096},"worker":{"cpu":2,"memory_mb":4096}}}
# ARGS_JSON=$(cat /_shared/args.json)
SHARED_DIR=$(echo "$ARGS_JSON" | jq -r '.shared_dir')

echo 'sudo su - && exit' >> /home/vagrant/.bashrc

rm -f /$SHARED_DIR/*.log
if [[ -f ~/.ssh/id_rsa ]]; then
    echo "SSH key pair already exists. Skipping generation."
else
    ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
fi
cp ~/.ssh/id_rsa.pub /$SHARED_DIR/ha_id_rsa.pub
chmod +x /$SHARED_DIR/scripts/*.sh

echo $ARGS_JSON > /$SHARED_DIR/args.json
nohup sudo /$SHARED_DIR/scripts/_ha_provision_k8s.sh "$ARGS_JSON" > /$SHARED_DIR/ha.log 2>&1 &

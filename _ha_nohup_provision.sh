#!/bin/bash
ARGS_JSON="$1"
# ARGS_JSON=$(cat /_shared/args.json)
SHARED_DIR=$(echo "$ARGS_JSON" | jq -r '.shared_dir')

echo 'sudo su - && exit' >> /home/vagrant/.bashrc

find /_shared/ -maxdepth 1 -type f -exec rm -f {} \;
if [[ -f ~/.ssh/id_rsa ]]; then
    echo "SSH key pair already exists. Skipping generation."
else
    ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
fi
cp ~/.ssh/id_rsa.pub /$SHARED_DIR/ha_id_rsa.pub
chmod +x /$SHARED_DIR/scripts/*.sh

echo $ARGS_JSON > /$SHARED_DIR/args.json

# nohup sudo /$SHARED_DIR/scripts/_ha_provision_k8s.sh "$ARGS_JSON" > /$SHARED_DIR/ha.log 2>&1 &
cp /$SHARED_DIR/scripts/* /tmp/ && chmod +x /tmp/*.sh # for windows compatibility
nohup sudo /tmp/_ha_provision_k8s.sh "$ARGS_JSON" > /$SHARED_DIR/ha.log 2>&1 &

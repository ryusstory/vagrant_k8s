#!/bin/bash
echo 'sudo su - && exit' >> /home/vagrant/.bashrc
if [[ -f ~/.ssh/id_rsa ]]; then
    echo "SSH key pair already exists. Skipping generation."
else
    ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
fi
cp ~/.ssh/id_rsa.pub /_shared/ha_id_rsa.pub
chmod +x /_shared/scripts/*.sh

# for use yq instead of jq
cp /_shared/scripts/* /tmp/ && chmod +x /tmp/*.sh # for windows compatibility
nohup sudo /tmp/_ha_provision_k8s.sh > /_shared/ha.log 2>&1 &

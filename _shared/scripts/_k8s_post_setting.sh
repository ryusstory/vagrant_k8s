#!/bin/bash
echo "[TASK] Setting kube config file"
mkdir -p $HOME/.kube
sudo cp /_shared/kube_config $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "[TASK] Source the completion"
echo 'source <(kubectl completion bash)' >> /etc/profile
echo 'source <(kubeadm completion bash)' >> /etc/profile

echo "[TASK] Alias kubectl to k"
echo 'alias k=kubectl' >> /etc/profile
echo 'alias kc=kubecolor' >> /etc/profile
echo 'complete -F __start_kubectl k' >> /etc/profile

echo "[TASK] Install Kubectx & Kubens"
git clone https://github.com/ahmetb/kubectx /opt/kubectx >/dev/null 2>&1
ln -s /opt/kubectx/kubens /usr/local/bin/kubens
ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx

echo "[TASK] Install Kubeps & Setting PS1"
git clone https://github.com/jonmosco/kube-ps1.git /root/kube-ps1 >/dev/null 2>&1
cat <<"EOT" >> /root/.bash_profile
source /root/kube-ps1/kube-ps1.sh
KUBE_PS1_SYMBOL_ENABLE=true
function get_cluster_short() {
    echo "$1" | cut -d . -f1
}
KUBE_PS1_CLUSTER_FUNCTION=get_cluster_short
KUBE_PS1_SUFFIX=') '
PS1='$(kube_ps1)'$PS1
alias ll='ls -alF --color=auto'
EOT
kubectl config rename-context "kubernetes-admin@kubernetes" "lab" >/dev/null 2>&1

echo "[TASK] Install K9S"
wget https://github.com/derailed/k9s/releases/latest/download/k9s_linux_amd64.deb > /dev/null 2>&1
sudo apt install ./k9s_linux_amd64.deb -y -qq >/dev/null 2>&1
rm k9s_linux_amd64.deb

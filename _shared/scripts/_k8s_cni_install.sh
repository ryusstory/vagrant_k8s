#!/bin/bash
ARGS_JSON=$(cat /_shared/args.json)
POD_SUBNET=$(echo "$ARGS_JSON" | jq -r '.k8s.pod_subnet')
K8S_CNI=$(echo "$ARGS_JSON" | jq -r '.k8s.cni')
K8S_CILIUM_VERSION=$(echo "$ARGS_JSON" | jq -r '.k8s.cilium.version')
K8S_CILIUM_PROXY=$(echo "$ARGS_JSON" | jq -r '.k8s.cilium.proxy')
K8S_CILIUM_HUBBLE=$(echo "$ARGS_JSON" | jq -r '.k8s.cilium.hubble')
K8S_CILIUM_ROUTINGCIDR=$(echo "$ARGS_JSON" | jq -r '.k8s.cilium.routingcidr')
NETWORK_SUBNET=$(echo "$ARGS_JSON" | jq -r '.network.subnet')
NETWORK_IP_OFFSET=$(echo "$ARGS_JSON" | jq -r '.network.ip_offset')

FLANNEL_INSTALL() {
  kubectl create ns kube-flannel
  kubectl label --overwrite ns kube-flannel pod-security.kubernetes.io/enforce=privileged

  sudo tee flannel-helm-values.yaml >/dev/null <<EOF
podCidr: "$POD_SUBNET"
flannel:
  args:
  - "--ip-masq"
  - "--kube-subnet-mgr"
  - "--iface=eth1"
EOF
  helm repo add flannel https://flannel-io.github.io/flannel/
  helm install flannel --namespace kube-flannel flannel/flannel -f flannel-helm-values.yaml
}

CILIUM_INSTALL() {
  sudo tee cilium-helm-values.yaml >/dev/null <<EOF
k8sServiceHost: $NETWORK_SUBNET.$NETWORK_IP_OFFSET
k8sServicePort: 6443
ipam:
  mode: cluster-pool
  operator:
    clusterPoolIPv4PodCIDRList:
      - $K8S_CILIUM_ROUTINGCIDR
ipv4NativeRoutingCIDR: $K8S_CILIUM_ROUTINGCIDR
routingMode: native
autoDirectNodeRoutes: true
endpointRoutes:
  enabled: true
kubeProxyReplacement: true
bpf:
  masquerade: true
installNoConntrackIptablesRules: true
endpointHealthChecking:
  enabled: false
healthChecking: false
hubble:
  enabled: $K8S_CILIUM_HUBBLE
operator:
  replicas: 1
debug:
  enabled: true
EOF
  helm repo add cilium https://helm.cilium.io/
  helm install cilium cilium/cilium --version $K8S_CILIUM_VERSION --namespace kube-system -f cilium-helm-values.yaml
  if [[ "$K8S_CILIUM_HUBBLE" == "true" ]]; then
    sudo tee cilium-hubble-helm-values.yaml >/dev/null <<EOF
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
    service:
      type: NodePort
      nodePort: 31234
  export:
    static:
      enabled: true
      filePath: /var/run/cilium/hubble/events.log
  metrics:
    enableOpenMetrics: true
    enabled:
      - dns
      - drop
      - tcp
      - flow
      - port-distribution
      - icmp
      - "httpV2:exemplars=true;labelsContext=source_ip,source_namespace,source_workload,destination_ip,destination_namespace,destination_workload,traffic_direction"
prometheus:
  enabled: true
operator:
  prometheus:
    enabled: true
EOF
  helm upgrade cilium cilium/cilium --namespace kube-system --reuse-values -f cilium-hubble-helm-values.yaml
  fi
}

if [[ "$K8S_CNI" == "flannel" ]]; then
    echo "[TASK] Installing Flannel CNI"
    FLANNEL_INSTALL
elif [[ "$K8S_CNI" == "cilium" ]]; then
    echo "[TASK] Installing Cilium CNI"
    CILIUM_INSTALL
fi

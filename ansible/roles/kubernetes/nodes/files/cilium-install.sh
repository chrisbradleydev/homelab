#!/bin/bash

cilium_version="1.17.5"
cilium_yaml="/tmp/cilium.yaml"

nodes=$(kubectl get nodes -o=jsonpath='{.items[*].metadata.name}')

for node in $nodes; do
    kubectl taint nodes $node node.cilium.io/agent-not-ready=true:NoSchedule
done

helm repo add cilium https://helm.cilium.io/

helm upgrade cilium cilium/cilium \
    --install \
    --namespace kube-system \
    --version "$cilium_version" \
    -f "$cilium_yaml"

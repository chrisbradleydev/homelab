# kubernetes-nodes

## Copy and update vars example

```sh
cp roles/kubernetes/nodes/vars/main.example.yaml cp roles/kubernetes/nodes/vars/main.yaml
vim roles/kubernetes/nodes/vars/main.yaml
```

## Update playbook hosts

```sh
vim playbooks/kubernetes-nodes.yaml
```

## Initialize Kubernetes nodes

```sh
ansible-playbook playbooks/kubernetes-nodes.yaml
```

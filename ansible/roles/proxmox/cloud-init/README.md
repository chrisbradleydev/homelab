# proxmox-cloud-init

## Copy and update vars example

```sh
cp roles/proxmox/cloud-init/vars/main.example.yaml roles/proxmox/cloud-init/vars/main.yaml
vim roles/proxmox/cloud-init/vars/main.yaml
```

## Update playbook hosts

```sh
vim playbooks/proxmox-cloud-init.yaml
```

## Create Proxmox Ubuntu 22.04 & 24.04 cloud-init templates

```sh
ansible-playbook playbooks/proxmox-cloud-init.yaml
```

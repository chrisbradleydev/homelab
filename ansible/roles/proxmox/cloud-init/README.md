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

## Create Proxmox Cloud Init templates

```sh
ansible-playbook playbooks/proxmox-cloud-init.yaml
```

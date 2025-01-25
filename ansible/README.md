# ansible

## Prerequisites

- [Ansible](https://docs.ansible.com/)
- [Python](https://www.python.org/)

Clone the repository.

```sh
git clone https://github.com/chrisbradleydev/homelab.git
```

## Copy and update vars example

```sh
cd homelab/ansible
cp roles/proxmox/cloud-init/vars/main.example.yaml roles/proxmox/cloud-init/vars/main.yaml
vim roles/proxmox/cloud-init/vars/main.yaml
```

## Update inventory

```sh
vim inventory.yaml
```

## Update playbook

```sh
vim playbooks/proxmox-cloud-init.yaml
```

## Install requirements

```sh
ansible-galaxy collection install -r requirements.yaml
```

## Create Proxmox Ubuntu 22.04 & 24.04 cloud-init templates

```sh
ansible-playbook playbooks/proxmox-cloud-init.yaml
```

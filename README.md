# homelab

> A home to manage and maintain my personal infrastructure

## Prerequisites

- [Ansible](https://docs.ansible.com/)
- [Python](https://www.python.org/)

## Installation

### Clone the Repository

```sh
git clone https://github.com/chrisbradleydev/homelab.git
```

### Update inventory

```sh
cd homelab/ansible
vim inventory.yaml
```

### Install requirements

```sh
ansible-galaxy collection install -r requirements.yaml
```

## Playbooks

- [Default Debian Installs](./ansible/roles/debian/defaults/README.md)
- [Initialize Kubernetes Nodes](./ansible/roles/kubernetes/nodes/README.md)
- [Proxmox Cloud Init templates](./ansible/roles/proxmox/cloud-init/README.md)

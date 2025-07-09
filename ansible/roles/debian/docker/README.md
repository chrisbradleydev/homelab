# debian-docker

## Copy and update vars example

```sh
cp roles/debian/docker/vars/main.example.yaml cp roles/debian/docker/vars/main.yaml
vim roles/debian/docker/vars/main.yaml
```

## Update playbook hosts

```sh
vim playbooks/debian-docker.yaml
```

## Debian Docker Install

```sh
ansible-playbook playbooks/debian-docker.yaml
```

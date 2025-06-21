# debian-defaults

## Copy and update vars example

```sh
cp roles/debian/defaults/vars/main.example.yaml cp roles/debian/defaults/vars/main.yaml
vim roles/debian/defaults/vars/main.yaml
```

## Update playbook hosts

```sh
vim playbooks/debian-defaults.yaml
```

## Default Debian Installs

```sh
ansible-playbook playbooks/debian-defaults.yaml
```

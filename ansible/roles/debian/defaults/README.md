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

## Proton VPN

`tasks/protonvpn.yaml` installs the Proton VPN CLI with the standard kill switch on headless Debian. It runs on hosts with `debian_protonvpn: true` in `inventory.yaml`. The task moves the LAN interface from systemd-networkd to NetworkManager, unlocks gnome-keyring at boot, signs in, connects, checks for leaks, and then enables `protonvpn.service` at boot.

Before the first run:

- Open the Proxmox console for the VM. The SSH session can drop while the LAN moves.
- Reserve the VM's MAC address on the router. NetworkManager does not reuse networkd's DHCP DUID.
- Set `debian_protonvpn_keyring_password`, `debian_protonvpn_username` and `debian_protonvpn_password` in `vars/main.yaml`. The keyring is created with that password on the first run, and changing the variable later does not rekey it.

```sh
ansible-playbook playbooks/debian-defaults.yaml --tags protonvpn
```

If the account has a second factor, pass a fresh token on the run that signs in:

```sh
ansible-playbook playbooks/debian-defaults.yaml --tags protonvpn -e debian_protonvpn_totp=123456
```

Before relying on the kill switch, check these from the console:

```sh
# The tunnel dropping cuts the host off, and curl fails
nmcli -f NAME,TYPE,DEVICE connection show --active
nmcli connection down "ProtonVPN CH#242"
curl -4 --max-time 15 https://icanhazip.com
protonvpn disconnect

# After a reboot the host connects with no sign-in
sudo reboot
curl -4 --max-time 15 https://icanhazip.com
```

The kill switch lives in memory only. It is armed after each successful `protonvpn connect`, and not before. A failed connect can leave the host cut off. To clear it from the console, delete every connection whose name starts with `pvpn-`:

```sh
nmcli connection delete pvpn-killswitch pvpn-routed-killswitch pvpn-killswitch-ipv6
```

Remove:

```sh
systemctl --user disable --now protonvpn.service gnome-keyring-proton.service
protonvpn config set kill-switch off
sudo apt autoremove proton-vpn-cli
sudo apt purge protonvpn-stable-release
```

NetworkManager stays, since the LAN uses it. Restore `/etc/netplan/50-cloud-init.yaml.bak` before removing it.

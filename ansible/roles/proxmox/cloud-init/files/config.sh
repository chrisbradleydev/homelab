#!/bin/bash

vmid=$1
ipconfig=$2
sshkey=$3
ciuser=$4
datastore=$5
img=$6

agent=1
autostart=1
balloon=1024
bios=ovmf
boot="order=ide2;scsi0;net0"
bootdisk=scsi0
cputype=x86-64-v2-AES
efidisk0="storage:1,efitype=4m,pre-enrolled-keys=1"
ide2="$datastore:cloudinit"
onboot=1
ostype=l26
machine="type=q35"
scsi0="$datastore:0,discard=on,ssd=on,iothread=on,cache=writeback,import-from=$img"
scsihw=virtio-scsi-pci
serial0=socket
tags=ansible,ubuntu
vga=serial0

# https://pve.proxmox.com/pve-docs/pve-admin-guide.html
config=$(qm config $vmid)

# agent
if [[ ! $config =~ "agent:" ]]; then
	qm set $vmid --agent="$agent"
fi

# autostart
if [[ ! $config =~ "autostart:" ]]; then
	qm set $vmid --autostart="$autostart"
fi

# balloon
if [[ ! $config =~ "balloon:" ]]; then
	qm set $vmid --balloon="$balloon"
fi

# bios
if [[ ! $config =~ "bios:" ]]; then
	qm set $vmid --bios="$bios"
fi

# boot, bootdisk
if [[ ! $config =~ "bootdisk:" ]]; then
	qm set $vmid --boot="$boot" --bootdisk="$bootdisk"
fi

# ciuser
if [[ ! $config =~ "ciuser:" ]]; then
	qm set $vmid --ciuser=$ciuser
fi

# cpu
if [[ ! $config =~ "cpu:" ]]; then
	qm set $vmid --cpu cputype="$cputype"
fi

# efidisk0
if [[ ! $config =~ "efidisk0:" ]]; then
	qm set $vmid --efidisk0="$efidisk0"
fi

# ide2
if [[ ! $config =~ "ide2: $datastore:vm-$vmid-cloudinit" ]]; then
	qm set $vmid --ide2="$ide2"
fi

# ipconfig0
if [[ ! $config =~ "ipconfig0:" ]]; then
	qm set $vmid --ipconfig0="$ipconfig"
fi

# machine
if [[ ! $config =~ "machine:" ]]; then
	qm set $vmid --machine="$machine"
fi

# onboot
if [[ ! $config =~ "onboot:" ]]; then
	qm set $vmid --onboot="$onboot"
fi

# ostype
if [[ ! $config =~ "ostype:" ]]; then
	qm set $vmid --ostype="$ostype"
fi

# scsihw, scsi0
if [[ ! $config =~ "scsi0: $datastore:vm-$vmid-disk-0" ]]; then
	qm set $vmid --scsihw="$scsihw" --scsi0="$scsi0"
fi

# sshkeys
if [[ ! $config =~ "sshkeys:" ]]; then
	qm set $vmid --sshkey="$sshkey"
fi

# tags
if [[ ! $config =~ "tags:" ]]; then
	qm set $vmid --tags="$tags"
fi

# serial0, vga
if [[ ! $config =~ "serial0:" ]]; then
	qm set $vmid --serial0="$serial0" --vga="$vga"
fi

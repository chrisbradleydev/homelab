#!/bin/bash
# Copy the newest etcd snapshot and the Secrets encryption key from the
# control plane to this machine, encrypted to the sops PGP key. Encrypting
# needs only the public key, so the script runs unattended.
#
# Without the key, nobody can read the Secrets in a snapshot, so the script
# stores the two in separate directories. Keep the directories on separate
# disks if you can.
#
# Usage: scripts/etcd-backup-pull.sh [host]   (default host: kube1)
# Environment: ETCD_BACKUP_DEST (default ~/backups), ETCD_BACKUP_KEEP_DAYS (default 30)
set -o errexit -o nounset -o pipefail
umask 077

host=${1:-kube1}
recipient=B4A1F58E3A0ADDB07AF1178F629810C9E11DAEE0
dest=${ETCD_BACKUP_DEST:-$HOME/backups}
keep_days=${ETCD_BACKUP_KEEP_DAYS:-30}

encrypt() {
  gpg --batch --yes --trust-model always --encrypt --recipient "$recipient" --output "$1"
}

mkdir -p "$dest/etcd" "$dest/etcd-encryption-key"

# Only root can read /var/backups/etcd, so the glob runs in a root shell
latest=$(ssh "$host" "sudo sh -c 'ls -1t /var/backups/etcd/etcd-*.db | head -n 1'")
if [ -z "$latest" ]; then
  echo "No etcd snapshot found on $host" >&2
  exit 1
fi
ssh "$host" "sudo cat '$latest'" | encrypt "$dest/etcd/$(basename "$latest").gpg"
ssh "$host" 'sudo cat /etc/kubernetes/enc/encryption-config.yaml' |
  encrypt "$dest/etcd-encryption-key/encryption-config-$(date --utc +%Y%m%d).yaml.gpg"

find "$dest/etcd" "$dest/etcd-encryption-key" -maxdepth 1 -name '*.gpg' -mtime +"$keep_days" -delete
echo "Saved $(basename "$latest").gpg to $dest/etcd"

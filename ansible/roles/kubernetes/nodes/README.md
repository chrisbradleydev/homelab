# kubernetes-nodes

Provisions a kubeadm cluster on Debian with CRI-O, Cilium and Helm, and keeps
it at the versions pinned in `defaults/main.yaml`. The same playbook
initializes a new control plane, joins new workers, and upgrades an existing
cluster one minor version at a time.

## Copy and update vars example

```sh
cp roles/kubernetes/nodes/vars/main.example.yaml roles/kubernetes/nodes/vars/main.yaml
vim roles/kubernetes/nodes/vars/main.yaml
```

## Update inventory groups

Put the control plane node in `kubernetes_control_plane` and the workers in
`kubernetes_workers`. The role supports exactly one control plane node. It
can't join a second one, so it fails if `kubernetes_control_plane` lists more
than one host. The control plane node runs `kubeadm init`, installs Helm and
Cilium, and drives upgrades.

Set `kubernetes_zone` on every node to the Proxmox host it runs on. The role
labels each node with `topology.kubernetes.io/zone`, so workloads can spread
their replicas across Proxmox hosts. Update the value if a VM moves to another
host.

```sh
vim inventory.yaml
```

## Pin versions

```sh
vim roles/kubernetes/nodes/defaults/main.yaml
```

| Variable | Purpose |
|---|---|
| `kubernetes_version` | kubeadm, kubelet, kubectl |
| `kubernetes_cri_o_version` | CRI-O |
| `kubernetes_cilium_version` | Cilium Helm chart |
| `kubernetes_helm_version` | Helm |
| `kubernetes_gateway_api_version` | Gateway API CRDs. Use the version the pinned Cilium release supports, and change both together. |

## Run

```sh
ansible-playbook playbooks/kubernetes-nodes.yaml
```

Every node gets the kernel modules, sysctl settings, swap off, a cgroup v2
check, and the Kubernetes and CRI-O apt repositories for the pinned minor
version. Nodes that have not joined a cluster install the pinned packages and
reboot. The control plane initializes with `templates/kubeadm-config.yaml.j2`
and the static pod patches in `files/kubeadm-patches/`. Workers join with a
short-lived token.

The role also sets `vm.overcommit_memory=1` and raises the inotify limits in
`/etc/sysctl.d/90-kubernetes.conf`. It sets transparent huge pages to
`madvise` in `/etc/tmpfiles.d/thp.conf`, because PostgreSQL and Valkey both
see latency spikes with `always`.

## Kubelet reservations

`kubernetes_system_reserved_*`, `kubernetes_kube_reserved_*` and
`kubernetes_eviction_*` size the kubelet reservations for nodes with 4 vCPU
and 16 GiB of memory. New nodes get them when they join.

For running nodes, the role uploads the values to the `kubelet-config`
ConfigMap. Then, one node at a time, it runs
`kubeadm upgrade node phase kubelet-config` and restarts the kubelet on each
node whose configuration differs. Running pods keep running.

## Secrets encryption at rest

The API server encrypts Secrets in etcd with the `secretbox` provider. The
first time the role runs, it generates the key on the control plane in
`/etc/kubernetes/enc/encryption-config.yaml`. The key leaves the node only
inside backups.

On a running cluster, the role:

1. Regenerates the API server manifest with
   `kubeadm init phase control-plane apiserver`.
2. Uploads the cluster configuration, so `kubeadm upgrade` keeps the setting.
3. Rewrites every Secret, so etcd stores it encrypted.
4. Reads one Secret straight from etcd to confirm that it's encrypted.

**Without this key, nobody can read the Secrets in an etcd snapshot, including
you.** Back up the key separately from the snapshots, as described in the next
section.

## etcd backups

A systemd timer on the control plane (`etcd-backup.timer`) runs
`/usr/local/sbin/etcd-backup` at about 03:00 every day. The script saves a
snapshot to `/var/backups/etcd/` and keeps the last 7 days
(`kubernetes_etcd_backup_keep_days`).

Those snapshots live only on the control plane. `scripts/etcd-backup-pull.sh`
copies the newest snapshot and the encryption key to another machine. It
encrypts both to the sops PGP key and stores them in separate directories under
`~/backups`. To run it daily on the workstation, install the systemd user units
from the repository root:

```sh
mkdir -p ~/.config/systemd/user
cp scripts/systemd/etcd-backup-pull.service scripts/systemd/etcd-backup-pull.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now etcd-backup-pull.timer
loginctl enable-linger "$USER"
```

The last command lets the timer run while you're logged out. The units expect
the repository at `~/Repos/github.com/chrisbradleydev/homelab` and `gpg` in
`/home/linuxbrew/.linuxbrew/bin`.

The role also snapshots etcd before every upgrade hop, into
`/root/kubernetes-upgrade-backups/`.

## Gateway API and L2 announcements

Cilium serves Gateway API and answers ARP for LoadBalancer IPs on `eth0`. The
role installs the standard-channel Gateway API CRDs at
`kubernetes_gateway_api_version` before it installs or upgrades Cilium. The
Cilium operator registers the `cilium` GatewayClass only when the CRDs exist
at startup. The role doesn't create IP pools or announcement policies.

## kube-proxy

Cilium runs with `kubeProxyReplacement`, so the cluster has no kube-proxy.
New clusters set `proxy.disabled` in the kubeadm config. On an existing
cluster the control plane node records that setting in the
`kubeadm-config` ConfigMap, deletes the kube-proxy DaemonSet, ConfigMap and
RBAC objects, waits for its pods to go, and removes its `KUBE-*` iptables
rules on every node, following
<https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/>.
`kubernetes_kube_proxy_mode` (nftables) is only declared for the case where
the addon is enabled again; it has no effect while kube-proxy is absent.

## Change Cilium values

To change a Cilium setting, edit `templates/cilium.yaml.j2` and run the
playbook. If the pinned Cilium version is already installed and the release's
values differ from the template, the role runs `helm upgrade` at that version.
A Cilium version upgrade applies the template as well. The role keeps the
release's `upgradeCompatibility` value, which the last minor version hop set.

## Upgrades

When the cluster is older than the pinned versions the control plane node
upgrades it in place. Skipping minor versions is unsupported by kubeadm
and by Cilium, so the role steps through every minor version in between:

1. Cilium, one minor version at a time, with the pre-flight check before each
   hop. Intermediate hops use the newest patch of that minor version.
2. Kubernetes, one minor version at a time. Each hop backs up etcd and
   `/etc/kubernetes` to `/root/kubernetes-upgrade-backups/`, switches the apt
   repositories, runs `kubeadm upgrade apply` on the control plane, then for
   every node drains it, upgrades kubelet, kubectl and CRI-O, restarts them,
   waits for Ready, and uncordons it. Before it drains the next node, it waits
   until no PodDisruptionBudget blocks an eviction and every PostgreSQL
   cluster has all its instances Ready. A database replica that moved off the
   previous node is then Ready again before the next drain. If you change only
   `kubernetes_cri_o_version`, the role runs one hop. It skips the kubeadm
   steps and upgrades CRI-O on every node whose CRI-O is older than the
   pinned version.

The run is resumable. If it stops part way, run the playbook again and it
continues from the oldest component version it finds.

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
   waits for Ready, and uncordons it. If you change only
   `kubernetes_cri_o_version`, the role runs one hop. It skips the kubeadm
   steps and upgrades CRI-O on every node whose CRI-O is older than the
   pinned version.

The run is resumable. If it stops part way, run the playbook again and it
continues from the oldest component version it finds.

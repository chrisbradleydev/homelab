# terraform-kube

Manages the platform on the cluster: namespaces, storage, the Gateway, TLS,
OpenBao, External Secrets, PostgreSQL, Valkey and Gitea. The
`kubernetes-nodes` Ansible role owns the nodes, Cilium and the Gateway API
CRDs. OpenBao's own configuration lives in
[terraform/openbao](../openbao/README.md).

## Prerequisites

- Terraform 1.16
- sops 3.13 and the PGP key named in `.sops.yaml`, with its passphrase
- A kubeconfig at `~/.kube/config` with a context named `home`
- helm, kubeconform, cosign and cmctl for the checks below

The hosts' CPUs support x86-64-v2 and nothing newer. An image built on
Rocky Linux 10, UBI 10 or any other EL10 base needs x86-64-v3 and exits with
"Fatal glibc error: CPU does not support x86-64-v3". Check the base image
before you bump a chart or an image. That limit is why ceph-csi-rbd stays at
3.17.1, and why CloudNativePG replaced Percona as the PostgreSQL operator.

## Layout

| File | Manages |
|---|---|
| `providers.tf` | The helm, kubernetes and sops providers, all against the `home` context |
| `secrets.tf` | The two sops files, read as ephemeral resources |
| `ceph.tf`, `ceph.yaml` | ceph-csi-rbd, its credentials Secret and the `ceph-rbd` VolumeSnapshotClass |
| `snapshot-controller.tf` | The snapshot controller and the VolumeSnapshot CRDs |
| `namespaces.tf` | Every platform and product namespace, through `modules/product-namespace` |
| `cluster-base.tf` | The `ceph-rbd-retain` StorageClass, the LoadBalancer IP pool and L2 policy, and the PriorityClasses |
| `cert-manager.tf`, `cert-manager.yaml` | cert-manager, the Porkbun DNS-01 webhook, trust-manager, the internal CA and the Let's Encrypt issuers |
| `openbao.tf`, `openbao.yaml` | The seal key Secret, OpenBao's certificate, network policies and snapshot job, and OpenBao itself |
| `external-secrets.tf` | External Secrets, and the cert-manager SecretStore that copies the Porkbun key |
| `gateway.tf` | The internal Gateway, its wildcard certificate and the HTTP redirect |
| `pg-operator.tf` | CloudNativePG |
| `gitea-extras.tf`, `gitea-pg.tf`, `gitea-valkey.tf`, `gitea.tf` and their `.yaml` files | Gitea's secrets, database, Valkey and the app |

Custom resources live in local charts under `charts/`, one chart per concern,
because `helm_release` doesn't need their CRDs to exist at plan time.
`charts/postgres` is reusable: `gitea-pg.tf` installs it with the values in
`gitea-pg.yaml`. Each `helm_release` pins an exact chart version, and each
image reference pins a digest. The comment above a digest records the cosign
command that verified it.

`helm_release` upgrades a local chart only when a value changes, so each
release passes a `checksum` value: a hash of every file in the chart. A
template edit therefore triggers an upgrade on the next apply.

The state is local and gitignored. Secrets never enter it, as described under
"Secrets" below, but the state still records every release's values.

## Run

Every plan and apply decrypts `secrets/*.enc.yaml`, so gpg asks for the PGP
passphrase once per run.

```sh
cd terraform/kube
terraform init
terraform plan
terraform apply
```

Before an apply, check the code and the local charts:

```sh
terraform fmt -check -recursive
terraform validate
helm lint charts/postgres
helm template gitea-pg charts/postgres -f gitea-pg.yaml | kubeconform -strict -ignore-missing-schemas -summary
```

Before a chart bump, run this for the pinned version and for the new one,
then diff the two outputs:

```sh
helm template openbao openbao --repo https://openbao.github.io/openbao-helm --version 0.30.4 -n openbao -f openbao.yaml
```

### First bring-up

The releases declare their dependencies, so one apply orders them. On an
empty cluster, stop after OpenBao. It needs a one-time initialization before
anything can read secrets from it:

```sh
terraform apply -target helm_release.openbao
```

Initialize OpenBao, apply `terraform/openbao` and store the Porkbun key, as
the [terraform/openbao README](../openbao/README.md) describes. Then run a
full apply.

## Secrets

Secrets come in two tiers.

**sops holds what OpenBao needs before it can start.** The files are
encrypted to the PGP key in `.sops.yaml`.

| File | Keys | Written to |
|---|---|---|
| `secrets/ceph.enc.yaml` | `userId`, `userKey` | Secret `csi-cephfs-secret` in `ceph-csi-rbd` |
| `secrets/openbao.enc.yaml` | `unsealKey`, 32 random bytes as base64 | Secret `openbao-unseal` in `openbao` |

Terraform reads them with ephemeral `sops_file` resources and writes them
with write-only attributes, so neither the values nor their hashes reach the
state. The cost is that Terraform can't see when a value changed. To change
one, edit the file with `sops`, raise the Secret's `data_wo_revision` or
`binary_data_wo_revision`, and apply. The seal key needs one extra step
first, which the comment in `openbao.tf` describes. Keep a second copy of
the seal key outside this repository. Without it, nobody can read OpenBao's
data, including you.

**OpenBao holds everything else.** External Secrets copies values into
Kubernetes Secrets. Each namespace has its own SecretStore named `openbao`,
which logs in as that namespace's `openbao-reader` ServiceAccount. The
matching role in OpenBao allows reads only under that namespace's path, so
one namespace can't read another's secrets. ExternalSecrets read OpenBao
again every hour. While OpenBao is down, each Secret keeps its last synced
value. Gitea and Valkey read their secrets when they start, so after a
rotation, run `kubectl rollout restart` on the consumer.

## Namespaces and products

`modules/product-namespace` creates each namespace with:

- Pod Security labels. It enforces `baseline` by default and warns on
  `restricted`.
- A LimitRange that gives containers without requests 50m CPU and 64Mi, and a
  256Mi memory limit.
- A ResourceQuota, when `quota` is set.
- A default-deny ingress policy, unless `default_deny` is false. Each
  product adds its own allow policies.
- The `openbao-reader` ServiceAccount, when `openbao_reader` is true.

The namespace has `prevent_destroy` set, because deleting a namespace deletes
every PVC, Secret and database in it.

To add a product:

1. Add a `module "<name>_namespace"` block in `namespaces.tf`, with
   `gateway`, `trust_internal_ca` and `openbao_reader` set to true and a
   quota.
2. Add the name to `products` in `terraform/openbao` and apply there. That
   creates the product's policy and auth role.
3. Create `charts/<name>-extras` with the SecretStore, the ExternalSecrets,
   any certificates from `internal-ca`, and the network policies.
   `charts/gitea-extras` is the model.
4. Install the app with an HTTPRoute whose parent is Gateway `internal` in
   namespace `gateway`, section `https`. The DNS wildcard already points every
   name under `internal.touchgrass.software` at the Gateway. A Service with
   its own LoadBalancer address needs its own DNS record.
5. Once the product runs, check whether it passes `restricted`, then set
   `pod_security = "restricted"`. The comment in `namespaces.tf` has the
   dry-run command.

## TLS

Two CAs sign everything: the internal root and Let's Encrypt.

The ClusterIssuer `internal-ca` signs with `touchgrass-internal-root`, a
self-signed root valid for ten years. trust-manager copies the root into a
ConfigMap named `internal-ca-bundle`, key `ca.crt`, in every namespace
labelled `trust.touchgrass.software/internal-ca=true`. OpenBao, PostgreSQL
and Valkey serve certificates from this CA, and only cluster workloads
connect to them directly.

Let's Encrypt signs only the Gateway's wildcard certificate. The ClusterIssuers
`letsencrypt-staging` and `letsencrypt-prod` solve DNS-01 through the Porkbun
webhook, and only for names under `internal.touchgrass.software`. The
webhook reads the API key from the `porkbun-api-credentials` Secret, which
External Secrets copies from OpenBao. To test a change against staging
first, set `issuer` in `charts/gateway/values.yaml` to `letsencrypt-staging`.

## Gateway

Cilium runs the Gateway named `internal` in namespace `gateway` at
192.168.30.240. It terminates TLS with the wildcard certificate and accepts
HTTPRoutes from namespaces labelled `gateway.touchgrass.software/internal=true`.
Port 80 redirects to HTTPS.

LoadBalancer addresses come from the `lan` pool, 192.168.30.240 to .247. Give
every LoadBalancer Service its own address. Cilium picks one node per Service
to answer ARP, so two Services on one address can get two different nodes,
and the router's ARP entry then flips between them. Gitea SSH uses .241.

## OpenBao

Three servers replicate with raft. The static seal reads its key from the
`openbao-unseal` Secret, so pods unseal on their own after a restart or a
drain. The listener serves a certificate from `internal-ca`, and the audit
log goes to stdout. The Gateway routes `bao.internal.touchgrass.software` to
the active server and verifies the server's certificate against the internal
CA.

The StatefulSet uses the `OnDelete` update strategy, so a chart or image
change touches no running pod. Roll the pods yourself:

1. Delete each standby pod in turn, and wait for it to be Ready.
2. Run `bao operator step-down` against the active pod.
3. Delete the old active pod.

Finish the roll before any node maintenance. A drain also restarts pods onto
the pending template, in no set order.

The CronJob `openbao-snapshot` saves a raft snapshot at 02:30 every day to
the PVC `openbao-snapshots` and keeps 14 days. The snapshot holds encrypted
data, so a restore with `bao operator raft snapshot restore` needs the same
seal key. The PVC sits on the same Ceph pool as OpenBao, so these snapshots
protect against mistakes, not against losing Ceph.

## PostgreSQL

CloudNativePG runs each cluster that `charts/postgres` describes: two
instances that never share a node and prefer different Proxmox hosts, a
server certificate from `internal-ca`, and a PgBouncer pooler in session
mode. PostgreSQL rejects connections without TLS, and the pooler requires TLS
from its clients. A client connects to `<release>-pooler` with the password
from the Secret `<release>-app`, `sslmode=verify-full`, and the CA from
`internal-ca-bundle`.

The ScheduledBackup `<release>-daily` takes a cold volume snapshot of the
replica at 01:00 every day. The CronJob `<release>-backup-pruner` runs at
01:30. It deletes the scheduled Backups older than seven days and keeps the
newest completed one whatever its age. It never deletes a Backup you took by
hand. To restore, create a new Cluster from a snapshot, as described in
<https://cloudnative-pg.io/documentation/current/recovery/#recovery-from-volumesnapshot-objects>.
Like OpenBao's snapshots, these sit on the same Ceph pool as the data.

Before each node drain, the Ansible role waits until every cluster has all
its instances Ready. CloudNativePG moves the primary to a replica before the
drain evicts it.

## Valkey and Gitea

Valkey runs as one server with an append-only file on a retained volume. It
serves TLS only, with a certificate from `internal-ca`, and picks up a
renewed certificate within an hour. Its two users come from OpenBao: `gitea`
has every data command, and `default` has only the commands the metrics
exporter sends. Only Gitea's pods may connect.

Gitea runs the rootless image on a 50Gi retained volume. HTTPS goes through
the Gateway as `git.internal.touchgrass.software`, and SSH through its own
LoadBalancer address as `ssh.internal.touchgrass.software`. It reaches
PostgreSQL through the pooler and keeps its cache, sessions, queues and locks
in Valkey. The admin password comes from OpenBao:

```sh
bao kv get -field=password kv/apps/gitea/admin
```

Gitea sets the password only when it creates the account. After a rotation
in OpenBao, change it in Gitea too with `gitea admin user change-password`.
`app.ini` on the volume holds the generated `INTERNAL_TOKEN` and
`SECRET_KEY`, which encrypts two-factor secrets. Nothing backs up that
volume yet.

## Verify

```sh
cmctl check api
kubectl get certificate -A
kubectl get secretstore,externalsecret -A
kubectl -n openbao exec openbao-0 -- bao status
kubectl -n gitea get cluster gitea-pg
curl -s -o /dev/null -w '%{http_code}\n' https://git.internal.touchgrass.software/api/healthz
```

Expect every Certificate Ready, every ExternalSecret SecretSynced, OpenBao
unsealed, the cluster "in healthy state", and the health check 200.

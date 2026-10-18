# terraform-openbao

Configures OpenBao itself: the KV mount, the auth methods, the policies and
roles, and the secrets that Terraform generates. OpenBao runs on the cluster
through [terraform/kube](../kube/README.md). This root is separate because
its provider needs a running OpenBao to plan against.

No OpenBao provider exists, so this root uses `hashicorp/vault`. OpenBao
forked Vault 1.14 and keeps its API.

## Prerequisites

- Terraform 1.16 and the `bao` CLI
- An initialized OpenBao, reachable at `https://bao.internal.touchgrass.software`
- An account with the `admin` policy

## Log in

```sh
export VAULT_ADDR=https://bao.internal.touchgrass.software
bao login -method=userpass username=<name>
```

The `bao` CLI reads `VAULT_ADDR` when `BAO_ADDR` is unset, and `bao login`
stores the token in `~/.vault-token`, where the provider also looks. Leave
`VAULT_CACERT` unset, because the Gateway serves a Let's Encrypt
certificate. The provider creates a child token for each run, so the
account's policy needs `update` on `auth/token/create`. The `admin` policy
has it.

## Run

```sh
cd terraform/openbao
terraform init
terraform plan
terraform apply
```

## Layout

| File | Manages |
|---|---|
| `providers.tf` | The vault and random providers. The vault provider reads `VAULT_ADDR`, `VAULT_TOKEN` and `VAULT_CACERT` from the environment |
| `kv.tf` | The KV version 2 mount at `kv` |
| `auth.tf` | The `kubernetes` auth method, which checks ServiceAccount tokens through the TokenReview API, and the `userpass` mount |
| `policies.tf` | The `admin` policy, and the `snapshot` policy and role for the raft snapshot CronJob |
| `products.tf` | One policy and one Kubernetes auth role per product namespace, plus the pair for cert-manager |
| `generated-secrets.tf` | The secrets Terraform generates for Gitea |
| `variables.tf` | `products`, the product namespaces, and `gitea_admin_username` |

## Policies and roles

| Role | Bound ServiceAccount | May read | Token TTL |
|---|---|---|---|
| `ns-<product>` | `openbao-reader` in that namespace | `kv/data/apps/<product>/*` | 15 minutes |
| `ns-cert-manager` | `openbao-reader` in `cert-manager` | `kv/data/platform/cert-manager/*` | 15 minutes |
| `snapshot` | `openbao-snapshot` in `openbao` | `sys/storage/raft/snapshot` | 15 minutes |

Every role accepts only tokens issued for the audience `openbao`. The
SecretStores in `terraform/kube` request their tokens with that audience, and
the snapshot CronJob mounts a projected token with it.

The `admin` policy allows every capability on every path, including `sudo`.
It is for people, never for a workload.

## Secrets

| Path | Keys | Source |
|---|---|---|
| `kv/platform/cert-manager/porkbun` | `api-key`, `secret-key` | You type them in |
| `kv/apps/gitea/admin` | `username`, `password` | Terraform generates the password |
| `kv/apps/gitea/valkey` | `default`, `gitea` | Terraform generates both |
| `kv/apps/gitea/metrics` | `token` | Terraform generates it |

To read a value:

```sh
bao kv get -field=password kv/apps/gitea/admin
```

### Generated secrets

Terraform generates each value with an ephemeral `random_password` and
writes it with `data_json_wo`, so neither the value nor its hash reaches the
state. Terraform therefore can't see when a value changed in OpenBao. To
rotate one, raise its `data_json_wo_version` and apply. Then restart the
consumer, because Gitea and Valkey read their secrets when they start. The
Gitea admin password is the exception. Gitea keeps its own copy, so change
it there too with `gitea admin user change-password`.

The passwords use no special characters, so they are safe inside a
`rediss://` URL.

### Secrets you type in

`bao` reads standard input once per command, so the second value goes in
with `patch`. `printf %s` keeps the trailing newline out of the value.

```sh
read -rs PB_API; printf %s "$PB_API" | bao kv put   kv/platform/cert-manager/porkbun api-key=-
read -rs PB_SEC; printf %s "$PB_SEC" | bao kv patch kv/platform/cert-manager/porkbun secret-key=-
unset PB_API PB_SEC
```

Create the Porkbun key with the `dns` scope and `touchgrass.software` as its
only domain. Don't add an IP allow-list. A changed WAN address would silently
stop renewals.

## Add a product

1. Create the namespace in `terraform/kube` with `openbao_reader = true`.
2. Add the name to `products` in `variables.tf` and apply. That creates the
   `ns-<product>` policy and role.
3. Store or generate the product's secrets under `kv/apps/<product>/`.
   Generated values follow the pattern in `generated-secrets.tf`.
4. Point the product's SecretStore at role `ns-<product>`.

## Accounts for people

Terraform creates the `userpass` mount but no users, because `userpass`
needs a password at creation. To create one:

```sh
read -rs PW; printf %s "$PW" | bao write auth/userpass/users/<name> token_policies=admin password=-; unset PW
```

## Initialize a new OpenBao

Only a new cluster needs these steps. The static seal means the shares from
`init` are recovery keys, not unseal keys. They regenerate a root token, and
nothing else needs them.

1. Export three PGP public keys as base64, outside the repository:
   `gpg --export <id> | base64 -w0 > k1.b64`. ASCII-armored keys don't work.
2. Get the internal root CA:
   `kubectl -n cert-manager get secret touchgrass-internal-root -o jsonpath='{.data.ca\.crt}' | base64 -d > root.crt`.
3. Port-forward to the first pod, because the active Service has no
   endpoints before initialization:
   `kubectl -n openbao port-forward pod/openbao-0 8200:8200`.
4. Initialize:

   ```sh
   BAO_ADDR=https://127.0.0.1:8200 BAO_CACERT=root.crt bao operator init \
     -recovery-shares=3 -recovery-threshold=2 \
     -recovery-pgp-keys=k1.b64,k2.b64,k3.b64 -root-token-pgp-key=k1.b64
   ```

5. Store the three encrypted shares in three different places. None of them
   go in git.
6. Check that all three pods joined: `bao operator raft list-peers`.
7. Apply this root once with the root token, through a port-forward to
   `svc/openbao-active`, with `VAULT_ADDR=https://127.0.0.1:8200` and
   `VAULT_CACERT` set to the internal root.
8. Create your account as described above, log in with it, and revoke the
   root token: `bao token revoke <root>`.

Later applies go through the Gateway, as described under "Log in".

If you lose every admin account, regenerate a root token with
`bao operator generate-root` and two of the recovery shares.

## Backups

The CronJob in `terraform/kube/charts/openbao-extras` saves a raft snapshot
every day. A restore needs the same seal key, which lives in
`terraform/kube/secrets/openbao.enc.yaml`.

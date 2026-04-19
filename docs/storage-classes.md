# Storage Classes Policy

Canonical storage classes for this homelab:

| StorageClass | Backend | Intended use |
|---|---|---|
| `longhorn-2replicas` | Longhorn | Critical state (databases, durable app state) |
| `nfs-ssd` | NFS SSD | Shared storage with lower latency |
| `nfs-hdd` | NFS HDD | Bulk data, artifacts, large media |
| `local-path` | Node local disk | Ephemeral or non-critical workloads |

Notes:
- `longhorn-2replicas` is the default class for critical persistent data.
- For media libraries, a static NFS claim (`shared-media-pvc`) is used for `/volume2/media`.

## Deprecated aliases

Do not use these in new manifests:

| Deprecated name | Use instead |
|---|---|
| `nfs-ssd-fast` | `nfs-ssd` |
| `nfs-hdd-bulk` | `nfs-hdd` |
| `fast-ssd-critical` | `longhorn-2replicas` |
| `nfs-media-direct` | static PVC `shared-media-pvc` |

## Rollout rules

- New workloads must use only canonical names.
- Existing PVCs using old names are migrated in controlled waves (no big-bang migration).
- Do not change `storageClassName` in place for existing PVCs; create a new PVC and migrate data.

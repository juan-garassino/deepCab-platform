# Module: `gke`

**Optional, gated behind `var.enabled = false` (default).** Cloud Run handles
all current workloads; GKE is here for when learning K8s on the deepCab stack
becomes the next milestone.

## What it provisions (when enabled)

- One **regional** GKE Standard cluster (`deepcab-gke-${env}`)
- Workload Identity enabled (`${project}.svc.id.goog`)
- Private nodes, public endpoint with `0.0.0.0/0` authorized networks (tighten in prod)
- One separately-managed `default-pool` node pool with autoscaling (`e2-standard-2`, 1-3 nodes)
- Shielded VMs (secure boot + integrity monitoring)
- Deletion protection enabled when `env == "prod"`

## Required when enabled

- `network` + `subnet` from the `vpc` module
- `runtime_sa_email` from the `wif` module (attached to nodes)

## Inputs

See `variables.tf`. Notable:

| Name | Default |
|---|---|
| `enabled` | `false` |
| `release_channel` | `REGULAR` |
| `node_machine_type` | `e2-standard-2` |
| `min_node_count` / `max_node_count` | `1` / `3` |
| `enable_workload_identity` | `true` |

## Outputs

| Name | Description |
|---|---|
| `cluster_name` | Cluster short name. |
| `cluster_endpoint` | Sensitive — control plane URL. |
| `cluster_ca_certificate` | Sensitive — base64-encoded CA cert. |
| `location` | Region. |

The `cluster_endpoint` + `cluster_ca_certificate` outputs are what `gcloud container clusters get-credentials` would produce. Use them to wire a kubeconfig in CI when deploying via `kustomize`.

# Module: `vpc`

Optional VPC + Cloud NAT + private services connection. Gated by `var.enabled`
so dev (which uses public-IP Cloud SQL) skips it entirely.

## Provisions (when `enabled = true`)

- One regional VPC network (`deepcab-vpc`)
- One regional subnet (CIDR via `var.subnet_cidr`)
- A reserved global address + `service_networking_connection` for private services
  (Cloud SQL private IP, Memorystore, etc.)
- Optional Cloud NAT (`var.enable_nat`) for outbound internet from private nodes

## Inputs

| Name | Type | Default |
|---|---|---|
| `enabled` | `bool` | `true` |
| `project_id` | `string` | — |
| `region` | `string` | — |
| `env` | `string` | — |
| `network_name` | `string` | `"deepcab-vpc"` |
| `subnet_cidr` | `string` | `"10.20.0.0/20"` |
| `private_services_cidr` | `string` | `"10.30.0.0/16"` |
| `enable_nat` | `bool` | `true` |

## Outputs

| Name | Description |
|---|---|
| `enabled` | Whether the module is active. |
| `network_id` / `network_self_link` | VPC handles. |
| `subnet_id` | Primary subnet ID. |
| `private_services_connection` | ID of the service-networking connection — pass to `cloud_sql`. |

## When to disable

- **dev**: usually `enabled = false` — uses public-IP Cloud SQL with authorized networks
- **staging / prod**: `enabled = true` — private IP everywhere

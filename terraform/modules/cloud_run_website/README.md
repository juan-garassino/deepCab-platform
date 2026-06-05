# `cloud_run_website`

Cloud Run service for the **deepCab static SPA** (Vite + React build served by
nginx). One service per env. Shape is owned here; image is swapped by
`003-deepCab-website/.github/workflows/deploy-cloud-run.yml` on each `v*` tag.

## Cross-repo contract

| Owner | Owns |
| --- | --- |
| This module (`002`) | service spec — CPU, memory, scale, IAM, ingress, probes |
| `003-deepCab-website` CI | container image only — `gcloud run services update --image=...` |

`lifecycle.ignore_changes` covers `containers[0].image` so the next TF plan
does not revert what CI just pushed.

## Inputs (key)

| Name | Default | Notes |
| --- | --- | --- |
| `service_name` | `deepcab-website` | Must match what 003 CI calls in `gcloud run services update` |
| `image` | — (required) | Initial image. Subsequent images come from 003 CI |
| `container_port` | `80` | nginx |
| `min_instances` | `0` | dev keeps it cold; staging/prod warm |
| `allow_unauthenticated` | `true` | Static site, public |

## Bootstrap

On first apply the service starts with whatever `image` you pass. A safe
placeholder is `us-docker.pkg.dev/cloudrun/container/hello`. After 003 pushes
its first real image and the deploy workflow runs, traffic flips automatically.

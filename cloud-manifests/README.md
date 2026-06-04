# cloud-manifests/

Raw YAML manifests originally maintained in `001-deepCab-api/infra/gcp/`.

They are **preserved here as reference material**: useful for diff comparison against
the Terraform modules under `../terraform/modules/`, and as a paper trail of how
the deepCab GCP stack was first stood up before the migration to IaC.

## Status: deprecated / reference only

These manifests are no longer the source of truth. Going forward:

| Concern | Owner |
|---|---|
| Service shape (CPU/memory/scale/env vars/IAM) | `../terraform/modules/cloud_run/` |
| Retrain job shape | `../terraform/modules/cloud_run_job/` |
| Schedule | `../terraform/modules/scheduler/` |
| Workload Identity Federation | `../terraform/modules/wif/` |
| GKE cluster (optional) | `../terraform/modules/gke/` |

The 001 repo workflows now perform **image-only updates** (`gcloud run services update --image=...`)
and never `replace` a service spec from YAML. The service spec lives in Terraform.

## Why keep them?

1. **Diff comparison** — when iterating on Terraform modules it is helpful to look
   at the exact `gcloud` invocations / Knative shapes that the old bootstrap scripts
   produced, then check that the TF resource matches.
2. **Onboarding** — readers who know YAML and `gcloud` can map back from TF to
   familiar primitives.
3. **Disaster recovery** — if for some reason the TF state is unavailable, these
   manifests + the `bootstrap.sh` scripts are enough to manually re-create the
   stack from scratch.

## Layout

```
cloud-manifests/
├── cloud-run/service.yaml                 # Knative Service spec — supersedes TF cloud_run module
├── cloud-run-jobs/retrain-job.yaml        # Cloud Run Job spec      — supersedes TF cloud_run_job module
├── scheduler/{retrain-schedule.yaml,bootstrap.sh}  # supersedes TF scheduler module
├── gke/{base/,overlays/prod/}             # kustomize tree         — supersedes TF gke module
└── workload-identity/{README.md,bootstrap.sh}      # supersedes TF wif module
```

If you change something here for documentation purposes, **also update the
corresponding TF module** — these files no longer drive any deployment.

# Architecture

## Cross-repo split

```
┌────────────────────────────────────────────┐         ┌────────────────────────────────────────────┐
│ 001-deepCab-api                            │         │ 002-deepCab-platform   (THIS REPO)         │
│ ─────────────────                          │         │ ───────────────────────                    │
│ Owns: Dockerfile, source code, image build │   gcloud│ Owns: GCP shape (Terraform)                │
│                                            │ run     │       - Artifact Registry repo             │
│ CI:                                        │ services│       - Cloud Run service spec             │
│   build → push to Artifact Registry        │ update  │       - Cloud Run Job spec                 │
│   gcloud run services update --image=…  ───┼────────▶│       - Cloud Scheduler                    │
│   gcloud run jobs update --image=…         │         │       - Cloud SQL                          │
│                                            │         │       - GCS buckets                        │
│ Local: docker-compose, pytest              │         │       - Secret Manager containers          │
│                                            │         │       - WIF Pool + Provider + 4 SAs        │
│                                            │         │       - VPC, DNS, GKE (gated)              │
│                                            │         │ CI: terraform plan (PR) + apply (main)     │
└────────────────────────────────────────────┘         └────────────────────────────────────────────┘
```

The 001 repo's CI pipeline is **image-only updates**. It never replaces a Cloud
Run service spec from YAML, never creates IAM bindings, never provisions GCS
buckets. That work is all in Terraform here in 002.

## Why split?

1. **Different blast radius** — touching app code shouldn't be able to corrupt cloud shape.
2. **Different change rate** — app changes ship multiple times per day; cloud shape
   changes once a week or less.
3. **Different reviewer set** — app PRs need a backend reviewer; platform PRs
   need an SRE/platform reviewer who reads TF plans.
4. **Different secret scope** — the deployer SA used by 001 has narrow roles
   (run.developer + artifactregistry.writer); the terraform SA used by 002 has
   broad admin roles. Keeping them in separate repos limits the attack surface
   of either compromise.

## Data flow

```
┌──────────────┐    POST /predict     ┌──────────────────┐
│  client      │ ───────────────────▶│  Cloud Run        │
└──────────────┘                     │  deepcab-api      │
                                     │  (env vars +      │
                                     │   secret mounts)  │
                                     └─────┬────────┬────┘
                                           │        │
                          model load       │        │ mlflow track
                                           ▼        ▼
                                ┌──────────┐  ┌───────────────────┐
                                │  GCS     │  │  Cloud SQL        │
                                │  models  │  │  Postgres (mlflow)│
                                └──────────┘  └───────────────────┘

   Cloud Scheduler (02:00 UTC)
        │ POST /apis/run.googleapis.com/.../jobs/deepcab-retrain:run
        ▼
   Cloud Run Job  ───▶ trains model ───▶ writes to gs://${models_bucket}
                                  └────▶ logs run to MLflow (Cloud SQL)
```

## CI/CD flow

```
┌─────────────────────┐
│ Developer opens PR  │
│ to 002 (terraform)  │
└─────────┬───────────┘
          │ paths: terraform/**
          ▼
┌─────────────────────────────────┐
│ platform-plan.yml               │
│   matrix [dev, staging, prod]   │
│   → terraform init + plan       │
│   → post plan as PR comment     │
└─────────┬───────────────────────┘
          │ merge to main
          ▼
┌─────────────────────────────────┐
│ platform-apply.yml              │
│   apply-dev      (env: dev)     │
│     ↓ (manual approval)         │
│   apply-staging  (env: staging) │
│     ↓ (manual approval)         │
│   apply-prod     (env: prod)    │
│   → Slack notify                │
└─────────────────────────────────┘
```

## Bootstrap dependency graph (one-time per env)

```
manual: create gs://deepcab-tfstate-${env}   (chicken-and-egg)
    ↓
terraform init -backend=gcs
    ↓
terraform apply  (provisions: wif → gar → storage → secrets → vpc → cloud_sql → cloud_run + cloud_run_job → scheduler)
    ↓
manual: populate secrets via `gcloud secrets versions add …`
    ↓
manual: push first v0.1.0 tag in 001 → image lands in GAR
    ↓
terraform apply (Cloud Run picks up real image; idempotent re-run)
    ↓
manual: hit Cloud Run URL → done
```

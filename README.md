# deepCab-platform

GCP infrastructure-as-code for the deepCab learning project. Real Terraform, real CI,
multi-env (dev / staging / prod). Sibling repo to [`deepCab`](https://github.com/juan-garassino/deepCab)
(the API). The split:

| Repo | Owns |
|---|---|
| `deepCab` | source code + Dockerfile + image build + `gcloud run services update --image=...` |
| `deepCab-platform` *(this repo)* | every GCP resource — service shape, IAM, networking, storage, secrets, scheduler, … |

The static landing page (`index.html`, `CNAME`, `images/`, `script.js`, `style.css`)
is also published from this repo via GitHub Pages, but it is **not** the focus.
Platform content lives under `terraform/`, `cloud-manifests/`, `docs/`, `.github/`.

---

## What's here

```
.
├── index.html, CNAME, images/, script.js, style.css   # GitHub Pages landing
│
├── terraform/                  # Layered Terraform (modules + per-env composition)
│   ├── modules/                #   13 reusable modules
│   ├── envs/{dev,staging,prod} #   per-env wiring + tfvars
│   └── README.md
│
├── cloud-manifests/            # Legacy YAML preserved for reference / diff
│   ├── cloud-run/
│   ├── cloud-run-jobs/
│   ├── scheduler/
│   ├── gke/
│   └── workload-identity/
│
├── .github/workflows/
│   ├── platform-plan.yml       # PR → `terraform plan` per env → PR comment
│   └── platform-apply.yml      # main → apply dev → staging → prod (gated)
│
├── docs/
│   ├── ARCHITECTURE.md         # diagrams, cross-repo split, data flow
│   ├── ENVIRONMENTS.md         # per-env table (sizes, URLs, who can deploy)
│   ├── COSTS.md                # monthly cost back-of-napkin per env
│   └── RUNBOOK.md              # bootstrap a new env end-to-end
│
└── Makefile                    # env-scoped wrappers (plan / apply / fmt / validate / lint)
```

## 5-minute quickstart

Prerequisites: `terraform` + `gcloud` installed; you own a GCP project and a billing account.

```bash
# 1. Clone the repo
git clone https://github.com/juan-garassino/deepCab-platform.git
cd deepCab-platform

# 2. Local sanity (no GCP access needed)
make fmt              # terraform fmt -recursive
make validate         # init -backend=false + validate, per env

# 3. Bootstrap your first env (full walkthrough in docs/RUNBOOK.md)
ENV=dev
gcloud projects create deepcab-${ENV}                                # one-time
gcloud storage buckets create gs://deepcab-tfstate-${ENV}            # one-time, chicken-and-egg
./cloud-manifests/workload-identity/bootstrap.sh                     # one-time WIF bootstrap

# Edit terraform/envs/${ENV}/terraform.tfvars — fill in project_id + project_number
make ENV=${ENV} plan
make ENV=${ENV} apply

# 4. Populate secrets (TF declares containers, NOT values)
echo -n "https://hooks.slack.com/..." | gcloud secrets versions add slack-webhook-url --data-file=-
echo -n "sk-..."                       | gcloud secrets versions add openai-api-key   --data-file=-

# 5. Trigger the first image build from 001-deepCab-api (tag a release)

# 6. Hit it
URL=$(make ENV=${ENV} -s output | grep api_service_url | awk -F\" '{print $2}')
curl -fsS ${URL}/healthz
```

## Layered Terraform — how it composes

```
envs/dev/main.tf   ──┐
envs/staging/.../   ─┼──>   modules/{gar,storage,wif,secret_manager,cloud_sql,
envs/prod/.../     ──┘                vpc,cloud_run,cloud_run_website,cloud_run_job,
                                      scheduler,gke,dns,iam}
```

Each `envs/<env>/` composes the same set of modules with env-specific knobs.
There is no DRY tax — repetition makes diffs obvious during code review.

See `terraform/README.md` for the module reference table and `docs/ARCHITECTURE.md`
for the dependency graph.

## How the cross-repo split works

```
┌──────────────────────────┐
│ deepCab (001) — API repo │
│                          │
│  push v0.1.0 tag         │
│       │                  │
│       ▼                  │
│  docker build + push     │   ┌────────────────────────────────────┐
│  to GAR                  │   │ deepCab-platform (002) — THIS REPO │
│       │                  │   │                                    │
│       ▼                  │   │  TF defines the Cloud Run service  │
│  gcloud run services     │   │  spec (CPU/mem/scale/env/IAM)      │
│  update --image=…        │◀──┤  TF defines the GAR repo, IAM, ... │
│       │                  │   │                                    │
│       ▼                  │   │  Image updates from 001 do NOT     │
│  service rolls forward   │   │  trigger TF drift                  │
└──────────────────────────┘   │  (`lifecycle.ignore_changes`)      │
                               └────────────────────────────────────┘
```

Concretely: `terraform/modules/cloud_run/main.tf` has

```hcl
lifecycle {
  ignore_changes = [
    template[0].containers[0].image,
    client,
    client_version,
  ]
}
```

so TF owns the spec and 001 owns the image, with no fight.

## CI workflows

| Workflow | Trigger | Effect |
|---|---|---|
| `platform-plan.yml` | PR touching `terraform/**` | Matrix over [dev, staging, prod] — `terraform plan` → PR comment |
| `platform-apply.yml` | push to `main` touching `terraform/**` (or manual) | Sequential apply dev → staging → prod with `environment:` approval gates + Slack notify |

Both auth via Workload Identity Federation (zero JSON keys).

## Local development

The Terraform tree assumes you have `terraform >= 1.5` and a Google Cloud SDK
authenticated as a project owner. For everything else (running the API,
docker-compose, MLflow locally) you want the **001 repo**, not this one.

## Pointers

- `docs/RUNBOOK.md` — bootstrap a new env, rotate secrets, recover from drift
- `docs/ARCHITECTURE.md` — diagrams + dependency graph + data flow
- `docs/ENVIRONMENTS.md` — per-env table (sizes, URLs, deploy permissions)
- `docs/COSTS.md` — back-of-napkin monthly cost estimates
- `terraform/README.md` — module reference

## License

Same as the parent project: MIT (or as specified in the API repo).

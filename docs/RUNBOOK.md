# Runbook

Operational playbook for the deepCab platform. Read this end-to-end before
your first apply.

---

## 0. Prerequisites

On your laptop:

```bash
brew install terraform google-cloud-sdk
gcloud auth login
gcloud auth application-default login
```

You should have **billing-account owner** access on the GCP org that will host
the deepCab projects, and **admin** access on the GitHub repos `deepCab` and
`deepCab-platform`.

---

## 1. Bootstrap a new environment

### 1.1 Create the GCP project

```bash
ENV=dev   # or staging / prod
gcloud projects create deepcab-${ENV} --name="deepCab ${ENV}"
gcloud beta billing projects link deepcab-${ENV} \
  --billing-account=$BILLING_ACCOUNT     # 0X0X0X-0X0X0X-0X0X0X
gcloud config set project deepcab-${ENV}
```

Capture the project number — you need it for `terraform.tfvars`:

```bash
gcloud projects describe deepcab-${ENV} --format='value(projectNumber)'
```

### 1.2 Create the Terraform state bucket (chicken-and-egg)

```bash
gcloud storage buckets create gs://deepcab-tfstate-${ENV} \
  --project=deepcab-${ENV} \
  --location=us-central1 \
  --uniform-bucket-level-access
gcloud storage buckets update gs://deepcab-tfstate-${ENV} --versioning
```

> The bucket name **must** match the literal in `terraform/envs/${ENV}/backend.tf`.

### 1.3 Bootstrap APIs + WIF manually (one-time, breaks the second chicken-and-egg)

Terraform can manage the rest, but to run `terraform apply` from CI via WIF
you first need WIF itself. Run the existing imperative bootstrap once:

```bash
export PROJECT=deepcab-${ENV}
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT --format='value(projectNumber)')
export GH_OWNER=juan-garassino
export GH_REPO=deepCab-platform     # bootstrap WIF for THIS repo first
export REGION=us-central1
./cloud-manifests/workload-identity/bootstrap.sh
```

Then create the `deepcab-terraform` SA with broad-but-bounded roles so it can
run `terraform apply` from CI:

```bash
gcloud iam service-accounts create deepcab-terraform \
  --project=$PROJECT \
  --display-name="deepCab platform terraform CI"

for ROLE in roles/editor roles/iam.securityAdmin roles/resourcemanager.projectIamAdmin; do
  gcloud projects add-iam-policy-binding $PROJECT \
    --member="serviceAccount:deepcab-terraform@$PROJECT.iam.gserviceaccount.com" \
    --role=$ROLE --condition=None >/dev/null
done

gcloud iam service-accounts add-iam-policy-binding \
  deepcab-terraform@$PROJECT.iam.gserviceaccount.com \
  --project=$PROJECT \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/$GH_OWNER/deepCab-platform"
```

> After the first successful `terraform apply` the **TF-managed** `wif` module
> replaces all of these bindings. The bootstrap is just enough to let TF take over.

### 1.4 Set GitHub variables for this env

```bash
ENV_UPPER=$(echo $ENV | tr '[:lower:]' '[:upper:]')

gh variable set GCP_PROJECT_${ENV_UPPER}         --body "deepcab-${ENV}"
gh variable set GCP_PROJECT_NUMBER_${ENV_UPPER}  --body "$PROJECT_NUMBER"
gh variable set GCP_REGION_${ENV_UPPER}          --body "us-central1"
gh variable set GCP_WIF_PROVIDER_${ENV_UPPER}    --body "projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
gh variable set GCP_TERRAFORM_SA_${ENV_UPPER}    --body "deepcab-terraform@deepcab-${ENV}.iam.gserviceaccount.com"
gh variable set GCP_DEPLOYER_SA_${ENV_UPPER}     --body "deepcab-deployer@deepcab-${ENV}.iam.gserviceaccount.com"

gh secret set SLACK_WEBHOOK_URL                  # paste the URL when prompted
```

Also configure each env in repo Settings → Environments → Required reviewers.

### 1.5 Edit the env's tfvars

Edit `terraform/envs/${ENV}/terraform.tfvars`:

- `project_id` = `deepcab-${ENV}`
- `project_number` = the value from 1.1
- `gh_owner` / `gh_api_repo` / `gh_platform_repo` if defaults don't match

Commit + push (these are not secrets).

### 1.6 First apply

```bash
make ENV=${ENV} plan
make ENV=${ENV} apply
```

This provisions: WIF (full TF-managed replacement), GAR, GCS, Cloud SQL,
Cloud Run + Job (with the `gcr.io/cloudrun/hello` placeholder image),
Cloud Scheduler. ~5-10 minutes.

### 1.7 Populate secrets

```bash
gcloud config set project deepcab-${ENV}

# Slack
echo -n "https://hooks.slack.com/..."                 | gcloud secrets versions add slack-webhook-url  --data-file=-
# OpenAI key (for the agent)
echo -n "sk-..."                                       | gcloud secrets versions add openai-api-key    --data-file=-
# Internal API key (X-API-Key for /train and /agent/improve)
openssl rand -hex 32 | tr -d '\n'                      | gcloud secrets versions add deepcab-api-key   --data-file=-
# MLflow DB password (rotate from the TF-generated one)
openssl rand -base64 32 | tr -d '=\n'                  | gcloud secrets versions add mlflow-db-password --data-file=-
```

After rotating the DB password in Secret Manager, also reset it on the Cloud
SQL user (TF holds the original value but Secret Manager is the runtime source):

```bash
gcloud sql users set-password mlflow \
  --instance=deepcab-mlflow-${ENV} \
  --password=$(gcloud secrets versions access latest --secret=mlflow-db-password)
```

### 1.8 First image lands

Trigger the 001 image build (typically by tagging `v0.1.0`):

```bash
cd ../001-deepCab-api
git tag v0.1.0
git push origin v0.1.0
```

The 001 `release.yml` workflow builds + pushes to GAR, then runs
`gcloud run services update --image=...` to swap the placeholder image for the
real one. TF's `lifecycle.ignore_changes` keeps the next `terraform plan` from
reverting that image change.

### 1.9 Smoke test

```bash
URL=$(cd ../002-deepCab-platform/terraform/envs/${ENV} && terraform output -raw api_service_url)
curl -fsS ${URL}/healthz
curl -fsS ${URL}/version
```

---

## 2. Secret rotation

```bash
gcloud secrets versions add slack-webhook-url --data-file=- <<< "https://hooks.slack.com/NEW"
# Cloud Run picks up the new value on next cold start. Force a restart:
gcloud run services update deepcab-api --region=us-central1 --update-env-vars=ROTATE=$(date +%s)
```

For `mlflow-db-password` rotation: see step 1.7.

---

## 3. Destroying an env

```bash
make ENV=dev destroy
```

Cloud SQL has `deletion_protection = true` in staging/prod. To destroy a
production-like env you must first:

```bash
cd terraform/envs/<env>
terraform apply -var='deletion_protection=false'   # update tfvars and re-apply
make ENV=<env> destroy
```

The `tfstate` bucket has `force_destroy = false` and survives `terraform destroy`
on purpose — delete it manually if you really mean it.

---

## 4. Drift recovery

If someone clicks in the Cloud Console and changes a service spec:

```bash
make ENV=<env> plan       # shows the drift
make ENV=<env> apply      # reconciles to TF
```

If the change should be preserved, copy it into the TF code instead.

---

## 5. Common failure modes

| Error | Cause | Fix |
|---|---|---|
| `Backend initialization required` | tfstate bucket missing | Run step 1.2 |
| `Permission 'iam.serviceAccounts.getAccessToken' denied` | WIF binding missing | Re-run step 1.3 |
| `Error 409: artifact registry 'deepcab' already exists` | Previous bootstrap-script artifact | `terraform import module.gar.google_artifact_registry_repository.deepcab projects/.../locations/.../repositories/deepcab` |
| Cloud Run revision stuck in `Provisioning` | Bad image | `gcloud run revisions list` + roll back |
| `cloud-sql-proxy unauthorized` | Runtime SA missing `roles/cloudsql.client` | Already in `wif` defaults — re-apply if missing |

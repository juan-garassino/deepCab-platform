#!/usr/bin/env bash
# One-shot GCP bootstrap: create project + link billing + state bucket + WIF SA.
# Wraps everything in docs/RUNBOOK.md section 1 (create project through "ready for TF").
#
# Idempotent. Re-running after a successful run is safe (each step checks first).
#
# Pre-reqs:
#   - gcloud CLI authed as a user with project-creator + billing-account-user roles
#   - `gcloud auth login` AND `gcloud auth application-default login` already done
#
# Required env:
#   BILLING_ACCOUNT      e.g. 0X0X0X-0X0X0X-0X0X0X  (get from `gcloud billing accounts list`)
#
# Optional env:
#   PROJECT_ID           default: deepcab-<YYMMDD> (must be globally unique)
#   REGION               default: us-central1
#   ENV                  default: dev      (also creates the state bucket gs://deepcab-tfstate-<env>)
#   GH_OWNER             default: juan-garassino
#   GH_PLATFORM_REPO     default: deepCab-platform
#
# Output: prints PROJECT_ID, PROJECT_NUMBER, WIF_PROVIDER, DEPLOYER_SA, TERRAFORM_SA
# at the end — paste those into scripts/gh-vars.env before `make sync_gh`.

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-deepcab-$(date +%y%m%d)}"
REGION="${REGION:-us-central1}"
ENV_NAME="${ENV:-dev}"
GH_OWNER="${GH_OWNER:-juan-garassino}"
GH_PLATFORM_REPO="${GH_PLATFORM_REPO:-deepCab-platform}"

if [[ -z "${BILLING_ACCOUNT:-}" ]]; then
  echo "ERROR: BILLING_ACCOUNT not set. Run:" >&2
  echo "  gcloud billing accounts list" >&2
  echo "  export BILLING_ACCOUNT=0X0X0X-0X0X0X-0X0X0X" >&2
  echo "  $0" >&2
  exit 1
fi

echo "==> Project:     $PROJECT_ID"
echo "==> Billing:     $BILLING_ACCOUNT"
echo "==> Region:      $REGION"
echo "==> Env:         $ENV_NAME"
echo "==> GH owner:    $GH_OWNER"
echo

# ---------------------------------------------------------------------------
# 1. Create project (idempotent)
# ---------------------------------------------------------------------------
echo "==> [1/6] Creating project (if missing)..."
if gcloud projects describe "$PROJECT_ID" &>/dev/null; then
  echo "    project $PROJECT_ID already exists — skipping create"
else
  gcloud projects create "$PROJECT_ID" --name="deepCab $ENV_NAME"
fi

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
echo "    project number: $PROJECT_NUMBER"

# ---------------------------------------------------------------------------
# 2. Link billing
# ---------------------------------------------------------------------------
echo
echo "==> [2/6] Linking billing account..."
current=$(gcloud beta billing projects describe "$PROJECT_ID" --format='value(billingAccountName)' 2>/dev/null || true)
if [[ -n "$current" && "$current" == *"$BILLING_ACCOUNT"* ]]; then
  echo "    already linked to $BILLING_ACCOUNT — skipping"
else
  gcloud beta billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT"
fi

# ---------------------------------------------------------------------------
# 3. Enable required APIs
# ---------------------------------------------------------------------------
echo
echo "==> [3/6] Enabling required APIs (this can take 1-2 min)..."
gcloud services enable \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  artifactregistry.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  storage.googleapis.com \
  secretmanager.googleapis.com \
  cloudscheduler.googleapis.com \
  sqladmin.googleapis.com \
  compute.googleapis.com \
  serviceusage.googleapis.com \
  cloudbilling.googleapis.com \
  --project="$PROJECT_ID"

# ---------------------------------------------------------------------------
# 4. State bucket
# ---------------------------------------------------------------------------
echo
echo "==> [4/6] Creating Terraform state bucket..."
BUCKET="deepcab-tfstate-${ENV_NAME}"
if gcloud storage buckets describe "gs://${BUCKET}" --project="$PROJECT_ID" &>/dev/null; then
  echo "    gs://${BUCKET} already exists — skipping create"
else
  gcloud storage buckets create "gs://${BUCKET}" \
    --project="$PROJECT_ID" \
    --location="$REGION" \
    --uniform-bucket-level-access
  gcloud storage buckets update "gs://${BUCKET}" --versioning
fi

# ---------------------------------------------------------------------------
# 5. WIF pool + provider + terraform SA (so CI can run `terraform apply`)
# ---------------------------------------------------------------------------
echo
echo "==> [5/6] Bootstrapping WIF pool + provider + terraform SA..."
POOL_ID="github-pool"
PROVIDER_ID="github-provider"
TF_SA="deepcab-terraform"
TF_SA_EMAIL="${TF_SA}@${PROJECT_ID}.iam.gserviceaccount.com"
DEPLOYER_SA="deepcab-deployer"
DEPLOYER_SA_EMAIL="${DEPLOYER_SA}@${PROJECT_ID}.iam.gserviceaccount.com"

if ! gcloud iam workload-identity-pools describe "$POOL_ID" --location=global --project="$PROJECT_ID" &>/dev/null; then
  gcloud iam workload-identity-pools create "$POOL_ID" \
    --location=global --display-name="GitHub Actions Pool" --project="$PROJECT_ID"
else
  echo "    pool $POOL_ID already exists — skipping"
fi

if ! gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
       --workload-identity-pool="$POOL_ID" --location=global --project="$PROJECT_ID" &>/dev/null; then
  gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
    --workload-identity-pool="$POOL_ID" \
    --location=global \
    --display-name="GitHub Actions" \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner,attribute.ref=assertion.ref" \
    --attribute-condition="assertion.repository_owner == '${GH_OWNER}'" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --project="$PROJECT_ID"
else
  echo "    provider $PROVIDER_ID already exists — skipping"
fi

WIF_PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}"

# Terraform SA — what 002's platform-apply.yml impersonates
if ! gcloud iam service-accounts describe "$TF_SA_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
  gcloud iam service-accounts create "$TF_SA" \
    --project="$PROJECT_ID" --display-name="deepCab platform terraform CI"
  # IAM is eventually consistent — wait for the SA to be visible before binding.
  for i in 1 2 3 4 5 6; do
    if gcloud iam service-accounts describe "$TF_SA_EMAIL" --project="$PROJECT_ID" &>/dev/null; then break; fi
    echo "    waiting for IAM propagation ($i/6)..."
    sleep 5
  done
else
  echo "    sa $TF_SA already exists — skipping create"
fi

for role in roles/editor roles/iam.securityAdmin roles/resourcemanager.projectIamAdmin; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${TF_SA_EMAIL}" --role="$role" --condition=None --quiet >/dev/null
done

gcloud iam service-accounts add-iam-policy-binding "$TF_SA_EMAIL" \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.repository/${GH_OWNER}/${GH_PLATFORM_REPO}" \
  --project="$PROJECT_ID" --quiet >/dev/null

echo "    terraform SA bound to ${GH_OWNER}/${GH_PLATFORM_REPO}"

# ---------------------------------------------------------------------------
# 6. Print everything you need for the dotenv files
# ---------------------------------------------------------------------------
echo
echo "==> [6/6] Bootstrap complete."
echo
echo "Paste these into scripts/gh-vars.env (shared across all 3 repos):"
echo "  GCP_PROJECT=$PROJECT_ID"
echo "  GCP_PROJECT_NUMBER=$PROJECT_NUMBER"
echo "  GCP_REGION=$REGION"
echo "  GCP_WIF_PROVIDER=$WIF_PROVIDER"
echo "  GCP_DEPLOYER_SA=$DEPLOYER_SA_EMAIL"
echo
echo "Paste these into scripts/gh-vars.platform.env (platform repo only):"
echo "  GCP_WIF_PROVIDER_${ENV_NAME^^}=$WIF_PROVIDER"
echo "  GCP_TERRAFORM_SA_${ENV_NAME^^}=$TF_SA_EMAIL"
echo
echo "Next:"
echo "  1. cp scripts/gh-vars.env.example scripts/gh-vars.env (then edit)"
echo "  2. cp scripts/gh-secrets.env.example scripts/gh-secrets.env (then edit)"
echo "  3. cp scripts/gh-vars.platform.env.example scripts/gh-vars.platform.env (then edit)"
echo "  4. make sync_gh"
echo "  5. cd terraform/envs/${ENV_NAME} && terraform init && terraform apply"
echo "     (the apply creates the rest: deployer SA, runtime SA, scheduler SA,"
echo "      Cloud Run service+job+website, Cloud SQL, GCS buckets, secrets, etc.)"

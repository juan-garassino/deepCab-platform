# Workload Identity Federation: replace `001/infra/gcp/workload-identity/bootstrap.sh`.
#
# Provisions:
#   * 1 Workload Identity Pool ("github-pool")
#   * 1 OIDC Provider in that pool ("github-provider"), restricted to the configured GH owner
#   * 4 Service Accounts:
#       - deepcab-deployer    : impersonated by 001's image-build/deploy CI
#       - deepcab-runtime     : attached to Cloud Run services + Cloud Run Jobs
#       - deepcab-scheduler   : invokes the retrain Job from Cloud Scheduler
#       - deepcab-terraform   : impersonated by THIS platform repo's plan/apply CI
#   * Project-level IAM bindings per SA role list
#   * Two workload-identity-user bindings:
#       - GH repo (var.gh_owner/var.gh_repo)            -> deployer SA
#       - GH repo (var.gh_owner/var.platform_gh_repo)   -> terraform SA
#   * Deployer SA gets serviceAccountUser on runtime SA so it can deploy services
#     whose `serviceAccountName` is the runtime SA.

# ----------------------------------------------------------------------------
# Required APIs
# ----------------------------------------------------------------------------

locals {
  required_services = toset([
    "iamcredentials.googleapis.com",
    "iam.googleapis.com",
    "sts.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "run.googleapis.com",
    "container.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "sqladmin.googleapis.com",
    "compute.googleapis.com",
  ])
}

resource "google_project_service" "enabled" {
  for_each = local.required_services
  project  = var.project_id
  service  = each.value

  disable_on_destroy = false
}

# ----------------------------------------------------------------------------
# Workload Identity Pool + GitHub OIDC provider
# ----------------------------------------------------------------------------

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions Pool"
  description               = "Federates GitHub Actions OIDC tokens with deepCab service accounts."

  depends_on = [google_project_service.enabled]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "GitHub Actions"
  description                        = "Accepts OIDC tokens issued to github.com/${var.gh_owner}/*"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }

  # Hard floor: only the configured GH owner can mint tokens against this provider.
  attribute_condition = "assertion.repository_owner == \"${var.gh_owner}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# ----------------------------------------------------------------------------
# Service accounts
# ----------------------------------------------------------------------------

resource "google_service_account" "deployer" {
  project      = var.project_id
  account_id   = var.deployer_sa_id
  display_name = "deepCab GH Actions deployer"
  description  = "Impersonated by the 001 image-build / deploy workflows."

  depends_on = [google_project_service.enabled]
}

resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = var.runtime_sa_id
  display_name = "deepCab runtime SA"
  description  = "Attached to Cloud Run services / Jobs / GKE pods at runtime."

  depends_on = [google_project_service.enabled]
}

resource "google_service_account" "scheduler" {
  project      = var.project_id
  account_id   = var.scheduler_sa_id
  display_name = "deepCab Cloud Scheduler invoker"
  description  = "Used by Cloud Scheduler to invoke the retrain Job."

  depends_on = [google_project_service.enabled]
}

resource "google_service_account" "terraform" {
  project      = var.project_id
  account_id   = var.terraform_sa_id
  display_name = "deepCab platform terraform CI"
  description  = "Impersonated by the 002 platform repo's plan/apply workflows."

  depends_on = [google_project_service.enabled]
}

# ----------------------------------------------------------------------------
# Project-level IAM bindings (one google_project_iam_member per (sa, role))
# ----------------------------------------------------------------------------

locals {
  deployer_bindings = {
    for role in var.deployer_project_roles : role => role
  }
  runtime_bindings = {
    for role in var.runtime_project_roles : role => role
  }
  terraform_bindings = {
    for role in var.terraform_project_roles : role => role
  }
}

resource "google_project_iam_member" "deployer" {
  for_each = local.deployer_bindings
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_project_iam_member" "runtime" {
  for_each = local.runtime_bindings
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_project_iam_member" "terraform" {
  for_each = local.terraform_bindings
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.terraform.email}"
}

# scheduler SA only needs run.invoker (granted on the Job in the cloud_run_job module).

# ----------------------------------------------------------------------------
# Workload-identity-user bindings (GH repo -> SA)
# ----------------------------------------------------------------------------

# 001-deepCab-api repo can impersonate the deployer SA.
resource "google_service_account_iam_member" "gh_api_to_deployer" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/attribute.repository/${var.gh_owner}/${var.gh_repo}"
}

# 002-deepCab-platform repo can impersonate the terraform SA.
resource "google_service_account_iam_member" "gh_platform_to_terraform" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/attribute.repository/${var.gh_owner}/${var.platform_gh_repo}"
}

# ----------------------------------------------------------------------------
# Cross-SA impersonation
# ----------------------------------------------------------------------------

# Deployer SA needs serviceAccountUser on the runtime SA so it can deploy Cloud Run
# services whose serviceAccountName == runtime SA.
resource "google_service_account_iam_member" "deployer_uses_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployer.email}"
}

# Terraform SA likewise — when TF applies a Cloud Run service it sets serviceAccountName.
resource "google_service_account_iam_member" "terraform_uses_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_service_account_iam_member" "terraform_uses_scheduler" {
  service_account_id = google_service_account.scheduler.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.terraform.email}"
}

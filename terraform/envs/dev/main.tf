# ----------------------------------------------------------------------------
# deepCab — DEV environment composition
#
# Thin composition: per-env shape lives in ../_shared/env_config.tf.
# This file wires module inputs from `local.cfg` (the env slice) plus a few
# env-local concerns (showcase_mode toggle, dev-only Cloud SQL activation).
#
# Budget target: ~$0-15/mo idle.
# ----------------------------------------------------------------------------

locals {
  env = "dev"

  common_labels = {
    env       = local.env
    managed   = "terraform"
    component = "deepcab-platform"
  }
}

module "env_config" {
  source = "../_shared"
  env    = local.env
}

locals {
  cfg = module.env_config.cfg
}

module "gar" {
  source     = "../../modules/gar"
  project_id = var.project_id
  region     = var.region
  labels     = local.common_labels
}

module "storage" {
  source        = "../../modules/storage"
  project_id    = var.project_id
  region        = var.region
  env           = local.env
  force_destroy = local.cfg.storage.force_destroy
  labels        = local.common_labels
}

module "wif" {
  source           = "../../modules/wif"
  project_id       = var.project_id
  project_number   = var.project_number
  gh_owner         = var.gh_owner
  gh_repo          = var.gh_api_repo
  platform_gh_repo = var.gh_platform_repo
  website_gh_repo  = var.gh_website_repo
  labels           = local.common_labels
}

module "secrets" {
  source           = "../../modules/secret_manager"
  project_id       = var.project_id
  region           = var.region
  env              = local.env
  runtime_sa_email = module.wif.runtime_sa_email
  labels           = local.common_labels
}

module "vpc" {
  source     = "../../modules/vpc"
  project_id = var.project_id
  region     = var.region
  env        = local.env
  enabled    = local.cfg.vpc.enabled
}

module "cloud_sql" {
  source     = "../../modules/cloud_sql"
  project_id = var.project_id
  region     = var.region
  env        = local.env

  tier                = local.cfg.cloud_sql.tier
  disk_size_gb        = local.cfg.cloud_sql.disk_size_gb
  deletion_protection = local.cfg.cloud_sql.deletion_protection
  use_private_ip      = local.cfg.cloud_sql.use_private_ip
  backup_enabled      = local.cfg.cloud_sql.backup_enabled
  authorized_networks = local.cfg.cloud_sql.authorized_networks

  # Env-local: showcase_mode flips the instance running/stopped to save $.
  activation_policy = var.showcase_mode ? "ALWAYS" : "NEVER"

  labels = local.common_labels
}

module "cloud_run" {
  source     = "../../modules/cloud_run"
  project_id = var.project_id
  region     = var.region
  env        = local.env

  image                 = var.api_image
  service_account_email = module.wif.runtime_sa_email

  cpu                   = local.cfg.cloud_run_api.cpu
  memory                = local.cfg.cloud_run_api.memory
  min_instances         = local.cfg.cloud_run_api.min_instances
  max_instances         = local.cfg.cloud_run_api.max_instances
  container_concurrency = local.cfg.cloud_run_api.container_concurrency
  timeout_seconds       = local.cfg.cloud_run_api.timeout_seconds
  allow_unauthenticated = true

  env_vars = {
    APP_ENV             = local.env
    MLFLOW_TRACKING_URI = module.cloud_run_mlflow.service_url
    MODEL_TARGET        = "gcs"
    GCP_PROJECT         = var.project_id
    REGISTRY_GCS_BUCKET = module.storage.models_bucket
  }

  secret_env_vars = {
    OPENAI_API_KEY     = "openai-api-key"
    DEEPCAB_API_KEY    = "deepcab-api-key"
    SLACK_WEBHOOK_URL  = "slack-webhook-url"
    MLFLOW_DB_PASSWORD = "mlflow-db-password"
  }

  labels = local.common_labels

  depends_on = [
    module.secrets,
    module.gar,
  ]
}

# Auto-populate the mlflow-db-password secret with the TF-generated password.
# Other secrets (openai-api-key, deepcab-api-key, slack-webhook-url) are
# user-supplied — push values manually after apply via `gcloud secrets versions add`.
resource "google_secret_manager_secret_version" "mlflow_db_password" {
  secret      = "projects/${var.project_id}/secrets/mlflow-db-password"
  secret_data = module.cloud_sql.user_passwords["mlflow"]

  depends_on = [
    module.secrets,
    module.cloud_sql,
  ]
}

# Cloud Run service — MLflow tracking server.
# Uses the GAR-mirrored MLflow image (ghcr.io is rejected by Cloud Run).
# To refresh after a new MLflow release:
#   gcloud builds submit --config=cloud-manifests/mlflow/mirror.yaml --no-source
module "cloud_run_mlflow" {
  source     = "../../modules/cloud_run_mlflow"
  project_id = var.project_id
  region     = var.region
  env        = local.env

  service_account_email = module.wif.runtime_sa_email
  cloudsql_instance     = module.cloud_sql.connection_name
  artifacts_bucket      = module.storage.mlflow_artifacts_bucket

  image         = "us-central1-docker.pkg.dev/deepcab-dev/deepcab/mlflow:v2.16.2"
  cpu           = local.cfg.cloud_run_mlflow.cpu
  memory        = local.cfg.cloud_run_mlflow.memory
  min_instances = local.cfg.cloud_run_mlflow.min_instances
  max_instances = local.cfg.cloud_run_mlflow.max_instances

  labels = local.common_labels

  depends_on = [module.cloud_sql, module.secrets, module.storage]
}

# Uptime Kuma needs read+write on its gcsfuse-mounted state bucket
# (writes SQLite, error.log, uploads). Runtime SA only has objectViewer
# project-wide; grant objectAdmin on this one bucket explicitly.
resource "google_storage_bucket_iam_member" "status_bucket_admin" {
  bucket = module.storage.status_state_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${module.wif.runtime_sa_email}"
}

# Same for MLflow artifacts bucket (MLflow writes run artifacts there).
resource "google_storage_bucket_iam_member" "mlflow_artifacts_admin" {
  bucket = module.storage.mlflow_artifacts_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${module.wif.runtime_sa_email}"
}

# Uptime Kuma status page (statuspage.io look).
module "cloud_run_status" {
  source     = "../../modules/cloud_run_status"
  project_id = var.project_id
  region     = var.region
  env        = local.env

  service_account_email = module.wif.runtime_sa_email
  state_bucket          = module.storage.status_state_bucket

  # Showcase flips min_instances on so the status page stays warm.
  min_instances = var.showcase_mode ? 1 : local.cfg.cloud_run_status.min_instances
  max_instances = local.cfg.cloud_run_status.max_instances

  labels = local.common_labels

  depends_on = [module.storage]
}

# Static SPA (Vite+React+nginx).
module "cloud_run_website" {
  source     = "../../modules/cloud_run_website"
  project_id = var.project_id
  region     = var.region
  env        = local.env

  image                 = var.website_image
  service_account_email = module.wif.runtime_sa_email

  cpu                   = local.cfg.cloud_run_website.cpu
  memory                = local.cfg.cloud_run_website.memory
  min_instances         = local.cfg.cloud_run_website.min_instances
  max_instances         = local.cfg.cloud_run_website.max_instances
  container_concurrency = local.cfg.cloud_run_website.container_concurrency
  allow_unauthenticated = true

  labels = local.common_labels

  depends_on = [module.gar]
}

module "cloud_run_job" {
  source     = "../../modules/cloud_run_job"
  project_id = var.project_id
  region     = var.region
  env        = local.env

  image                 = var.retrain_image
  service_account_email = module.wif.runtime_sa_email
  scheduler_sa_email    = module.wif.scheduler_sa_email

  cpu                  = local.cfg.cloud_run_job.cpu
  memory               = local.cfg.cloud_run_job.memory
  task_timeout_seconds = local.cfg.cloud_run_job.task_timeout_seconds

  args = [
    "-m",
    "deepCab.training.train",
    "backend=tf_mlp",
    "data=${local.cfg.cloud_run_job.data_size}",
  ]

  env_vars = {
    APP_ENV             = local.env
    MLFLOW_TRACKING_URI = module.cloud_run_mlflow.service_url
    MODEL_TARGET        = "gcs"
    GCP_PROJECT         = var.project_id
    REGISTRY_GCS_BUCKET = module.storage.models_bucket
  }

  secret_env_vars = {
    MLFLOW_DB_PASSWORD = "mlflow-db-password"
  }

  labels = local.common_labels

  depends_on = [module.secrets]
}

module "scheduler" {
  source     = "../../modules/scheduler"
  project_id = var.project_id
  region     = var.region
  env        = local.env

  target_uri            = module.cloud_run_job.execute_uri
  service_account_email = module.wif.scheduler_sa_email
  paused                = local.cfg.scheduler.paused
}

module "dns" {
  source     = "../../modules/dns"
  project_id = var.project_id
  env        = local.env
  enabled    = local.cfg.dns.enabled
}

module "gke" {
  source     = "../../modules/gke"
  project_id = var.project_id
  region     = var.region
  env        = local.env
  enabled    = local.cfg.gke.enabled
}

module "iam" {
  source     = "../../modules/iam"
  project_id = var.project_id
  env        = local.env
}

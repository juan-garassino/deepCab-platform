# ----------------------------------------------------------------------------
# deepCab — DEV environment composition
#
# Smallest tier everywhere. No VPC (public-IP Cloud SQL). No DNS. No GKE.
# Budget target: ~$5-15/mo idle.
# ----------------------------------------------------------------------------

locals {
  env = "dev"

  common_labels = {
    env       = local.env
    managed   = "terraform"
    component = "deepcab-platform"
  }
}

# 1. Artifact Registry (must exist before Cloud Run can reference images)
module "gar" {
  source     = "../../modules/gar"
  project_id = var.project_id
  region     = var.region
  labels     = local.common_labels
}

# 2. Storage buckets (mlflow artifacts, models, tfstate)
module "storage" {
  source     = "../../modules/storage"
  project_id = var.project_id
  region     = var.region
  env        = local.env

  # dev: allow destroy with objects present so iteration is painless
  force_destroy = true

  labels = local.common_labels
}

# 3. WIF + service accounts
module "wif" {
  source           = "../../modules/wif"
  project_id       = var.project_id
  project_number   = var.project_number
  gh_owner         = var.gh_owner
  gh_repo          = var.gh_api_repo
  platform_gh_repo = var.gh_platform_repo

  labels = local.common_labels
}

# 4. Secret Manager
module "secrets" {
  source           = "../../modules/secret_manager"
  project_id       = var.project_id
  region           = var.region
  env              = local.env
  runtime_sa_email = module.wif.runtime_sa_email

  labels = local.common_labels
}

# 5. VPC disabled in dev — Cloud SQL uses public IP with our office network only.
module "vpc" {
  source     = "../../modules/vpc"
  project_id = var.project_id
  region     = var.region
  env        = local.env
  enabled    = false
}

# 6. Cloud SQL — smallest tier, public IP (dev only)
module "cloud_sql" {
  source     = "../../modules/cloud_sql"
  project_id = var.project_id
  region     = var.region
  env        = local.env

  tier                = "db-f1-micro"
  deletion_protection = false
  use_private_ip      = false

  authorized_networks = [
    {
      name  = "world-readonly-temp"
      value = "0.0.0.0/0"
    },
  ]

  labels = local.common_labels
}

# 7. Cloud Run service — minimal scale
module "cloud_run" {
  source     = "../../modules/cloud_run"
  project_id = var.project_id
  region     = var.region
  env        = local.env

  image                 = var.api_image
  service_account_email = module.wif.runtime_sa_email

  cpu                   = "1"
  memory                = "512Mi"
  min_instances         = 0
  max_instances         = 2
  container_concurrency = 40
  allow_unauthenticated = true

  env_vars = {
    APP_ENV             = "dev"
    PORT                = "8000"
    MLFLOW_TRACKING_URI = var.mlflow_tracking_uri
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

# 8. Cloud Run Job (retrain)
module "cloud_run_job" {
  source     = "../../modules/cloud_run_job"
  project_id = var.project_id
  region     = var.region
  env        = local.env

  image                 = var.retrain_image
  service_account_email = module.wif.runtime_sa_email
  scheduler_sa_email    = module.wif.scheduler_sa_email

  cpu                  = "2"
  memory               = "4Gi"
  task_timeout_seconds = 1800

  args = [
    "-m",
    "deepCab.training.train",
    "backend=tf_mlp",
    "data=1k",
  ]

  env_vars = {
    APP_ENV             = "dev"
    MLFLOW_TRACKING_URI = var.mlflow_tracking_uri
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

# 9. Cloud Scheduler (paused in dev — fires manually only)
module "scheduler" {
  source     = "../../modules/scheduler"
  project_id = var.project_id
  region     = var.region
  env        = local.env

  target_uri            = module.cloud_run_job.execute_uri
  service_account_email = module.wif.scheduler_sa_email
  paused                = true
}

# 10. DNS disabled in dev
module "dns" {
  source     = "../../modules/dns"
  project_id = var.project_id
  env        = local.env
  enabled    = false
}

# 11. GKE disabled in dev
module "gke" {
  source     = "../../modules/gke"
  project_id = var.project_id
  region     = var.region
  env        = local.env
  enabled    = false
}

# 12. Cross-cutting IAM (no budget in dev)
module "iam" {
  source     = "../../modules/iam"
  project_id = var.project_id
  env        = local.env
}

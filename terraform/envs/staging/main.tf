# ----------------------------------------------------------------------------
# deepCab — STAGING environment composition
#
# Thin composition: per-env shape lives in ../_shared/env_config.tf.
# Mid-tier. Private-IP Cloud SQL via VPC. DNS optional. No GKE.
# Budget target: ~$20-40/mo.
# ----------------------------------------------------------------------------

locals {
  env = "staging"

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
  source                = "../../modules/vpc"
  project_id            = var.project_id
  region                = var.region
  env                   = local.env
  enabled               = local.cfg.vpc.enabled
  subnet_cidr           = local.cfg.vpc.subnet_cidr
  private_services_cidr = local.cfg.vpc.private_services_cidr
  enable_nat            = local.cfg.vpc.enable_nat
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
  private_network     = module.vpc.network_self_link

  labels = local.common_labels

  depends_on = [module.vpc]
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

  cloudsql_instances = [module.cloud_sql.connection_name]

  env_vars = {
    APP_ENV             = local.env
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

  depends_on = [module.secrets, module.gar]
}

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

  cloudsql_instances = [module.cloud_sql.connection_name]

  env_vars = {
    APP_ENV             = local.env
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

  # cfg.dns.enabled marks "this env may run DNS"; the operator-supplied
  # var.dns_zone_name being non-empty actually turns it on.
  enabled     = local.cfg.dns.enabled && var.dns_zone_name != ""
  zone_name   = var.dns_zone_name
  dns_name    = var.dns_name
  create_zone = false

  records = var.dns_zone_name == "" ? {} : {
    "api.staging" = {
      type    = "CNAME"
      ttl     = 300
      rrdatas = ["ghs.googlehosted.com."]
    }
  }
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

project_id     = "deepcab-prod"
project_number = "000000000000"
region         = "us-central1"

gh_owner         = "juan-garassino"
gh_api_repo      = "deepCab"
gh_platform_repo = "deepCab-platform"

api_image     = "us-docker.pkg.dev/cloudrun/container/hello"
retrain_image = "us-docker.pkg.dev/cloudrun/container/hello"

mlflow_tracking_uri = "https://mlflow.deepcab.com"

# Enable when you own the deepcab.com zone in this project.
dns_zone_name = ""
dns_name      = ""

# Toggle to spin up the GKE cluster (default off — Cloud Run handles prod).
enable_gke = false

# Set these to activate the $200/mo budget alert.
budget_alert_email = ""
budget_amount_usd  = 200
billing_account    = ""

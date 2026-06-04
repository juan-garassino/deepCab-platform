project_id     = "deepcab-staging"
project_number = "000000000000"
region         = "us-central1"

gh_owner         = "juan-garassino"
gh_api_repo      = "deepCab"
gh_platform_repo = "deepCab-platform"

api_image     = "us-docker.pkg.dev/cloudrun/container/hello"
retrain_image = "us-docker.pkg.dev/cloudrun/container/hello"

mlflow_tracking_uri = "https://mlflow.staging.deepcab.com"

# Set these once you own a DNS zone in this project to enable api.staging.deepcab.com.
dns_zone_name = ""
dns_name      = ""

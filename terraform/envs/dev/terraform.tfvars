# dev environment values.
#
# Replace `project_id` + `project_number` with your real dev project before
# `terraform plan`. `gcloud projects describe <project> --format='value(projectNumber)'`
# prints the number.

project_id     = "deepcab-dev"
project_number = "929003378637"
region         = "us-central1"

gh_owner         = "juan-garassino"
gh_api_repo      = "deepCab"
gh_platform_repo = "deepCab-platform"

# Bootstrap images. On first apply Cloud Run needs *some* image to start with;
# the hello-world container ships from Google's public registry. Once 001's
# image-build workflow pushes the real image, `gcloud run services update --image=...`
# swaps it in and `lifecycle.ignore_changes` keeps TF from reverting.
api_image     = "us-docker.pkg.dev/cloudrun/container/hello"
retrain_image = "us-docker.pkg.dev/cloudrun/container/hello"

mlflow_tracking_uri = "http://mlflow.dev.deepcab.local:5000"

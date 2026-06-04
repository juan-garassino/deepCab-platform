# Artifact Registry repo holding all deepCab Docker images.
# The 001-deepCab-api repo's image-build workflow pushes here; the 002 platform
# repo references the resulting URLs in the cloud_run / cloud_run_job modules.

resource "google_artifact_registry_repository" "deepcab" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repo_id
  description   = var.description
  format        = "DOCKER"
  labels        = var.labels

  # Keep only a sane number of images / versions per env to avoid the unbounded
  # GAR storage cost that bites every team eventually.
  cleanup_policies {
    id     = "keep-tagged-recent"
    action = "KEEP"
    most_recent_versions {
      package_name_prefixes = ["api", "retrain"]
      keep_count            = 10
    }
  }

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s" # 7 days
    }
  }
}

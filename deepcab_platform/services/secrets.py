"""SecretsService — rotate a Secret Manager secret + bounce Cloud Run revisions.

Cloud Run binds secret env vars at revision creation time. Pushing a new
version of `openai-api-key` does NOT update the running api — you need to
trigger a new revision. This service does both: pushes the new version
*and* fires `gcloud run services update --update-secrets=...` (a no-op-ish
spec change that creates a fresh revision picking up `:latest`).
"""

from __future__ import annotations

from dataclasses import dataclass

from deepcab_platform.providers.gcloud import GcloudProvider


@dataclass
class SecretsService:
    gcloud: GcloudProvider

    # Default secret → consuming Cloud Run services. Tests can override.
    DEFAULT_SECRET_CONSUMERS: dict[str, list[str]] = None  # type: ignore[assignment]

    def __post_init__(self) -> None:
        if self.DEFAULT_SECRET_CONSUMERS is None:
            object.__setattr__(self, "DEFAULT_SECRET_CONSUMERS", {
                "openai-api-key": ["deepcab-api"],
                "deepcab-api-key": ["deepcab-api"],
                "slack-webhook-url": ["deepcab-api"],
                "mlflow-db-password": ["deepcab-api", "deepcab-mlflow"],
                # kuma-admin-password is read by the seeder, not the kuma service itself.
            })

    def rotate(
        self,
        secret_id: str,
        value: str,
        *,
        project_id: str,
        region: str = "us-central1",
        services: list[str] | None = None,
    ) -> dict:
        new_version = self._add_version(secret_id, value, project_id)
        targets = services if services is not None else self.DEFAULT_SECRET_CONSUMERS.get(secret_id, [])
        bumped: list[str] = []
        for service in targets:
            self._bump_service(service, secret_id, project_id, region)
            bumped.append(service)
        return {"secret": secret_id, "new_version": new_version, "services_bumped": bumped}

    def _add_version(self, secret_id: str, value: str, project_id: str) -> str:
        # Pipe the value through stdin via subprocess (the GcloudProvider doesn't expose stdin yet;
        # use the file-data flag with a temp value via shell would leak — instead use --data-file=- and
        # pass via a here-doc-style env. For now: write to a tempfile and pass.).
        import tempfile
        with tempfile.NamedTemporaryFile("w", delete=False) as f:
            f.write(value)
            path = f.name
        try:
            out = self.gcloud.run([
                "secrets", "versions", "add", secret_id,
                f"--data-file={path}", f"--project={project_id}",
                "--format=value(name)",
            ])
            return out.strip()
        finally:
            import os
            try:
                os.unlink(path)
            except OSError:
                pass

    def _bump_service(self, service: str, secret_id: str, project_id: str, region: str) -> None:
        # Touching `update-secrets` with the same `secret:latest` ref creates a new revision
        # that re-reads the secret at startup. The env-var name is derived from the secret id
        # (uppercased, dashes → underscores) — matches our convention in cloud_run_service.
        env_var = secret_id.upper().replace("-", "_")
        self.gcloud.run([
            "run", "services", "update", service,
            f"--region={region}", f"--project={project_id}",
            f"--update-secrets={env_var}={secret_id}:latest",
            "--quiet",
        ])

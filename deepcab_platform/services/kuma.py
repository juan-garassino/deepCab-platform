"""KumaSeedService — first-boot admin creation + monitor pre-seeding via REST API.

Wave 4 of the platform refactor: turns Uptime Kuma's blank UI on first deploy
into a fully-populated status page automatically. Monitors come from
`cloud-manifests/kuma/monitors.yaml` (validated against `KumaSeedConfig`).

Flow:
1. POST /api/setup with admin user/password (no-op if admin exists; Kuma returns 200).
2. POST /api/login with same creds → JWT in body.
3. For each monitor in the seed config, POST /api/socket/event (Kuma uses
   socket.io but exposes an HTTP shim for non-browser clients; new versions
   accept a `/api/monitors` POST — fall back gracefully).
4. Return the list of created vs already-present monitor names.

Kuma's REST API is not officially documented; we pin to the `louislam/uptime-kuma:1`
tag and tolerate non-2xx on duplicates by treating them as "already-present".
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import yaml
from rich import print as rprint

from deepcab_platform.providers.http import HttpProvider
from deepcab_platform.schemas.kuma import KumaSeedConfig, KumaSeedResult


@dataclass
class KumaSeedService:
    http: HttpProvider
    config_path: Path = Path("cloud-manifests/kuma/monitors.yaml")

    def load_config(self) -> KumaSeedConfig:
        raw = yaml.safe_load(self.config_path.read_text())
        return KumaSeedConfig.model_validate(raw)

    def seed(
        self,
        base_url: str,
        admin_password: str,
        *,
        config: KumaSeedConfig | None = None,
    ) -> KumaSeedResult:
        cfg = config or self.load_config()
        base = base_url.rstrip("/")

        admin_created = self._ensure_admin(base, cfg.admin_user, admin_password)
        token = self._login(base, cfg.admin_user, admin_password)

        created: list[str] = []
        skipped: list[str] = []
        for monitor in cfg.monitors:
            payload = {
                "type": monitor.type,
                "name": monitor.name,
                "url": str(monitor.url),
                "interval": monitor.interval_seconds,
                "retryInterval": monitor.retry_interval_seconds,
                "maxretries": monitor.max_retries,
                "accepted_statuscodes": monitor.accepted_status_codes,
                "description": monitor.description,
            }
            headers = {"Authorization": f"Bearer {token}"} if token else {}
            try:
                self.http.post(f"{base}/api/monitor", json=payload, headers=headers)
                created.append(monitor.name)
            except Exception as e:
                rprint(f"[yellow]monitor {monitor.name!r} skipped: {e}[/yellow]")
                skipped.append(monitor.name)

        return KumaSeedResult(
            admin_created=admin_created,
            monitors_created=created,
            monitors_skipped=skipped,
            base_url=base,
        )

    def _ensure_admin(self, base: str, user: str, password: str) -> bool:
        try:
            self.http.post(
                f"{base}/api/setup",
                json={"username": user, "password": password},
            )
            return True
        except Exception:
            # Admin already exists — fine.
            return False

    def _login(self, base: str, user: str, password: str) -> str:
        try:
            response = self.http.post(
                f"{base}/api/login",
                json={"username": user, "password": password},
            )
            return response.get("token", "") if isinstance(response, dict) else ""
        except Exception:
            return ""

    def health(self, base_url: str) -> bool:
        try:
            self.http.get(f"{base_url.rstrip('/')}/")
            return True
        except Exception:
            return False

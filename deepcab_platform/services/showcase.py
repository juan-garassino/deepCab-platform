"""ShowcaseService — flip the env up (Cloud SQL ALWAYS, Kuma min=1) or down ($0 idle).

Delegates to `TerraformService.run_action(APPLY)` with the `showcase_mode`
TF variable toggled.
"""

from __future__ import annotations

from dataclasses import dataclass

from deepcab_platform.schemas.enums import PlatformEnv, ShowcaseMode, TerraformAction
from deepcab_platform.services.terraform import TerraformService


@dataclass
class ShowcaseService:
    terraform_service: TerraformService

    def set_mode(self, env: PlatformEnv, mode: ShowcaseMode) -> str:
        showcase_var = "true" if mode == ShowcaseMode.UP else "false"
        return self.terraform_service.run_action(
            TerraformAction.APPLY,
            env,
            auto_approve=True,
            extra_args=[f"-var=showcase_mode={showcase_var}"],
        )

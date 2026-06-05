"""`deepcab-platform tf <action>` — thin terraform wrapper scoped to envs/<env>/."""

from __future__ import annotations

import typer
from rich import print as rprint

from deepcab_platform.deps import get_terraform_service
from deepcab_platform.schemas.enums import PlatformEnv, ProviderMode, TerraformAction

tf_app = typer.Typer(help="Terraform plan/apply/destroy/output for a target env.", no_args_is_help=True)


def _run(action: TerraformAction, env: PlatformEnv, auto_approve: bool, dry_run: bool) -> None:
    mode = ProviderMode.DRY_RUN if dry_run else ProviderMode.REAL
    out = get_terraform_service(mode).run_action(action, env, auto_approve=auto_approve)
    rprint(out)


@tf_app.command("plan")
def plan(env: PlatformEnv = typer.Option(PlatformEnv.DEV, "--env", "-e"),
         dry_run: bool = typer.Option(False, "--dry-run")) -> None:
    _run(TerraformAction.PLAN, env, auto_approve=False, dry_run=dry_run)


@tf_app.command("apply")
def apply(env: PlatformEnv = typer.Option(PlatformEnv.DEV, "--env", "-e"),
          auto_approve: bool = typer.Option(False, "--auto-approve", "-y"),
          dry_run: bool = typer.Option(False, "--dry-run")) -> None:
    _run(TerraformAction.APPLY, env, auto_approve=auto_approve, dry_run=dry_run)


@tf_app.command("destroy")
def destroy(env: PlatformEnv = typer.Option(PlatformEnv.DEV, "--env", "-e"),
            auto_approve: bool = typer.Option(False, "--auto-approve", "-y"),
            dry_run: bool = typer.Option(False, "--dry-run")) -> None:
    _run(TerraformAction.DESTROY, env, auto_approve=auto_approve, dry_run=dry_run)


@tf_app.command("output")
def output(env: PlatformEnv = typer.Option(PlatformEnv.DEV, "--env", "-e")) -> None:
    _run(TerraformAction.OUTPUT, env, auto_approve=False, dry_run=False)


@tf_app.command("validate")
def validate(env: PlatformEnv = typer.Option(PlatformEnv.DEV, "--env", "-e")) -> None:
    _run(TerraformAction.VALIDATE, env, auto_approve=False, dry_run=False)

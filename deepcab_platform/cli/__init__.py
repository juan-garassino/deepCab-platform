"""Typer app aggregator. `deepcab-platform <subcommand>` lands here."""

from __future__ import annotations

import typer

from deepcab_platform.cli.bootstrap import bootstrap_cmd
from deepcab_platform.cli.kuma import kuma_app
from deepcab_platform.cli.mlflow import mlflow_app
from deepcab_platform.cli.secrets import secrets_app
from deepcab_platform.cli.showcase import showcase_app
from deepcab_platform.cli.status import status_cmd
from deepcab_platform.cli.sync_gh import sync_gh_cmd
from deepcab_platform.cli.tf import tf_app

app = typer.Typer(
    name="deepcab-platform",
    help="deepCab platform CLI — bootstrap, sync-gh, mlflow, showcase, kuma, tf, status.",
    no_args_is_help=True,
    add_completion=False,
)

# Single-command subcommands
app.command("bootstrap")(bootstrap_cmd)
app.command("sync-gh")(sync_gh_cmd)
app.command("status")(status_cmd)

# Multi-command sub-apps
app.add_typer(mlflow_app, name="mlflow")
app.add_typer(showcase_app, name="showcase")
app.add_typer(kuma_app, name="kuma")
app.add_typer(tf_app, name="tf")
app.add_typer(secrets_app, name="secrets")

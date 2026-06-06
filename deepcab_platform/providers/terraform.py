"""`terraform` CLI provider — Protocol + Real + DryRun impls."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from typing import Protocol, runtime_checkable

from rich import print as rprint


@runtime_checkable
class TerraformProvider(Protocol):
    """Abstracts `terraform`. workdir scopes the command to an env directory."""

    def run(self, args: list[str], *, workdir: str, check: bool = True) -> str: ...


@dataclass
class RealTerraformProvider:
    binary: str = "terraform"

    def run(self, args: list[str], *, workdir: str, check: bool = True) -> str:
        if shutil.which(self.binary) is None:
            raise RuntimeError(f"`{self.binary}` not found on PATH")
        env = os.environ.copy()
        env.setdefault("TF_IN_AUTOMATION", "1")
        env.setdefault("TF_INPUT", "0")
        result = subprocess.run(
            [self.binary, *args],
            check=False,  # we handle the error ourselves so stderr surfaces
            cwd=workdir,
            capture_output=True,
            text=True,
            env=env,
        )
        if result.returncode != 0:
            if result.stdout:
                sys.stdout.write(result.stdout)
            if result.stderr:
                sys.stderr.write(result.stderr)
            if check:
                raise subprocess.CalledProcessError(
                    result.returncode,
                    [self.binary, *args],
                    output=result.stdout,
                    stderr=result.stderr,
                )
        return result.stdout


@dataclass
class DryRunTerraformProvider:
    def run(self, args: list[str], *, workdir: str, check: bool = True) -> str:
        rprint(
            f"[dim]\\[dry-run terraform][/dim] [cyan](cd {workdir} && terraform "
            f"{' '.join(args)})[/cyan]"
        )
        return ""

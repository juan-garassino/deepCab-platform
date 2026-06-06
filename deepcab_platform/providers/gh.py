"""`gh` CLI provider — Protocol + Real + DryRun impls."""

from __future__ import annotations

import shutil
import subprocess
import sys
from dataclasses import dataclass
from typing import Protocol, runtime_checkable

from rich import print as rprint


@runtime_checkable
class GhProvider(Protocol):
    """Abstracts the `gh` CLI. Returns stdout; raises on non-zero by default."""

    def run(self, args: list[str], *, check: bool = True, input_text: str | None = None) -> str: ...


@dataclass
class RealGhProvider:
    binary: str = "gh"

    def run(self, args: list[str], *, check: bool = True, input_text: str | None = None) -> str:
        if shutil.which(self.binary) is None:
            raise RuntimeError(f"`{self.binary}` not found on PATH")
        result = subprocess.run(
            [self.binary, *args],
            check=False,
            capture_output=True,
            text=True,
            input=input_text,
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
class DryRunGhProvider:
    def run(self, args: list[str], *, check: bool = True, input_text: str | None = None) -> str:
        suffix = f"  (stdin: {input_text[:40]!r}…)" if input_text else ""
        rprint(f"[dim]\\[dry-run gh][/dim] [cyan]gh {' '.join(args)}[/cyan]{suffix}")
        return ""

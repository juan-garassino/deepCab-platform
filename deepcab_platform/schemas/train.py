"""Pydantic models for `deepcab-platform train-on-vm`.

The training VM is provisioned ad-hoc, runs `python -m deepCab.training.train`
inside our `deepcab/api` image, uploads the run artifacts to GCS, logs the
run to MLflow, and self-destructs. Inputs are Pydantic-validated so a typo
in `--backend` or `--data` fails before the gcloud call.
"""

from __future__ import annotations

from pydantic import BaseModel, Field

from deepcab_platform.schemas.enums import BackendKind, DataSize, GpuType, PlatformEnv


class TrainOnVmInputs(BaseModel):
    """User-supplied inputs to `TrainOnVmService.launch()`."""

    model_config = {"extra": "forbid"}

    env: PlatformEnv = PlatformEnv.DEV
    backend: BackendKind = BackendKind.TORCH_MLP
    data: DataSize = DataSize.S100K
    machine_type: str = "n1-standard-4"
    zone: str = "us-central1-a"
    gpu: GpuType = GpuType.T4
    spot: bool = True
    max_runtime: str = "6h"  # GCP `--max-run-duration` value
    auto_delete: bool = True
    image_tag: str = "v1.0"
    tail: bool = False  # stream serial console after create


class TrainOnVmResult(BaseModel):
    """What `launch()` returns. Goes back to the CLI for rendering."""

    model_config = {"extra": "forbid"}

    instance_name: str
    zone: str
    project_id: str
    image: str
    machine_type: str
    gpu: GpuType
    spot: bool
    serial_console_url: str
    monitoring_url: str
    estimated_cost_per_hour: float = Field(ge=0)

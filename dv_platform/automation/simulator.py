"""Simulator execution stage for scenario-level regressions."""

from __future__ import annotations

import subprocess
import time
from pathlib import Path

from .compile import CompileArtifact
from .models import SimulationResult, resolve_project_root
from .parser import parse_log


class SimulatorRunner:
    """Run already compiled simulations and persist their raw logs."""

    def __init__(self, artifact: CompileArtifact, log_dir: Path | None = None) -> None:
        self.artifact = artifact
        self.project_root = resolve_project_root()
        self.log_dir = log_dir or self.project_root / "sim" / "dv_platform" / "log"
        self.waveform_dir = self.project_root / "sim" / "uart_fifo_sim"
        self.log_dir.mkdir(parents=True, exist_ok=True)
        self.waveform_dir.mkdir(parents=True, exist_ok=True)

    def run_case(self, case_name: str, regression_id: str) -> SimulationResult:
        """Execute one case, save a complete log, and parse its test outcome."""

        log_path = self.log_dir / f"{regression_id}_{case_name}.log"
        waveform_path = self.waveform_dir / f"{regression_id}_{case_name}.vcd"
        if self.artifact.execution_mode == "uvm":
            command = ["bash", str(self.artifact.executable), case_name, "--vcd", str(waveform_path)]
        else:
            command = ["vvp", str(self.artifact.executable), f"+TEST={case_name}", f"+VCD={waveform_path}"]
        started = time.monotonic()
        completed = subprocess.run(command, cwd=self.project_root, text=True, capture_output=True, check=False)
        duration_seconds = time.monotonic() - started
        log_path.write_text(completed.stdout + completed.stderr, encoding="utf-8")
        return parse_log(
            case_name=case_name,
            log_path=log_path,
            duration_seconds=duration_seconds,
            simulator=self.artifact.simulator,
            exit_code=completed.returncode,
        )

"""Compilation stage for UART FIFO verification runs."""

from __future__ import annotations

import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

from .models import resolve_project_root


@dataclass(frozen=True)
class CompileArtifact:
    """The runner and simulator selected for a regression run."""

    simulator: str
    executable: Path
    execution_mode: Literal["legacy", "uvm"]


class CompileError(RuntimeError):
    """Raised when the simulator cannot compile the selected verification entry."""


def available_simulator(preferred: str = "auto") -> str:
    """Choose a supported execution mode from the tools available on PATH."""

    if preferred not in {"auto", "legacy", "uvm"}:
        raise ValueError("simulator must be one of: auto, legacy, uvm")
    if preferred == "legacy":
        if not shutil.which("iverilog"):
            raise CompileError("Icarus Verilog (iverilog) is required for legacy mode.")
        return "iverilog-legacy"
    if preferred == "uvm":
        for command, label in (("vcs", "vcs-uvm"), ("xrun", "xcelium-uvm"), ("vsim", "questa-uvm")):
            if shutil.which(command):
                return label
        raise CompileError("No UVM 1.2 simulator found (VCS, Xcelium, or Questa/ModelSim).")
    for command, label in (("vcs", "vcs-uvm"), ("xrun", "xcelium-uvm"), ("vsim", "questa-uvm")):
        if shutil.which(command):
            return label
    if shutil.which("iverilog"):
        return "iverilog-legacy"
    raise CompileError("No supported simulator found. Install Icarus or a UVM 1.2 simulator.")


def compile_testbench(simulator_mode: str = "auto", build_dir: Path | None = None) -> CompileArtifact:
    """Prepare the selected verification runner.

    The legacy testbench is compiled once for a structured regression. Commercial
    simulators execute the project's canonical ``run.sh`` UVM flow for each case.
    """

    project_root = resolve_project_root()
    selected = available_simulator(simulator_mode)
    output_dir = build_dir or project_root / "sim" / "dv_platform" / "build"
    output_dir.mkdir(parents=True, exist_ok=True)

    if selected != "iverilog-legacy":
        run_script = project_root / "run.sh"
        if not run_script.is_file():
            raise CompileError("The UVM runner './run.sh' is missing.")
        return CompileArtifact(simulator=selected, executable=run_script, execution_mode="uvm")

    executable = output_dir / "uart_fifo_legacy.out"
    command = [
        "iverilog",
        "-g2012",
        "-I",
        "tb",
        "-o",
        str(executable),
        "tb/tb_top_loop_test.v",
        "rtl/top_looptest.v",
        "rtl/uart_fifo.v",
        "rtl/uart.v",
        "rtl/fifo.v",
    ]
    completed = subprocess.run(command, cwd=project_root, text=True, capture_output=True, check=False)
    if completed.returncode != 0:
        message = (completed.stdout + completed.stderr).strip()
        raise CompileError(message or "Icarus compilation failed.")
    return CompileArtifact(simulator=selected, executable=executable, execution_mode="legacy")

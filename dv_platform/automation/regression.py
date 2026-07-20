"""CLI entry point orchestrating compile, simulation, parsing, and reporting."""

from __future__ import annotations

import argparse
import sys
import uuid
from pathlib import Path

from .compile import CompileError, compile_testbench
from .models import RegressionReport, TestCaseDefinition, resolve_project_root, utc_now
from .report import render_summary, write_report
from .simulator import SimulatorRunner


TEST_CASES: tuple[TestCaseDefinition, ...] = (
    TestCaseDefinition("single", "Single-byte A5 UART loopback.", "DV Platform", 1),
    TestCaseDefinition("multi", "Ordered 11/22/33/44 UART loopback.", "DV Platform", 4),
    TestCaseDefinition("stream", "Twenty-byte incrementing UART loopback.", "DV Platform", 20),
    TestCaseDefinition("fifo", "Standalone FIFO full/empty boundary behavior.", "DV Platform", 0),
    TestCaseDefinition("reset", "UART loopback recovery after reset.", "DV Platform", 1),
)
CASE_BY_NAME = {case.name: case for case in TEST_CASES}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="UART FIFO structured regression runner")
    parser.add_argument("--cases", nargs="+", default=["all"], choices=["all", *CASE_BY_NAME])
    parser.add_argument("--simulator", default="auto", choices=["auto", "legacy", "uvm"])
    parser.add_argument("--report-dir", type=Path, default=resolve_project_root() / "sim" / "dv_platform" / "report")
    parser.add_argument("--log-dir", type=Path, default=resolve_project_root() / "sim" / "dv_platform" / "log")
    parser.add_argument("--regression-id", default=None)
    return parser.parse_args()


def selected_case_names(requested: list[str]) -> list[str]:
    """Expand all while preserving the declared verification-plan ordering."""

    if "all" in requested:
        return [case.name for case in TEST_CASES]
    return requested


def main() -> int:
    args = parse_args()
    regression_id = args.regression_id or f"reg-{uuid.uuid4().hex[:12]}"
    started_at = utc_now()
    try:
        artifact = compile_testbench(args.simulator)
    except CompileError as exc:
        print(f"Regression setup failed: {exc}", file=sys.stderr)
        return 2

    runner = SimulatorRunner(artifact, args.log_dir)
    results = [runner.run_case(case_name, regression_id) for case_name in selected_case_names(args.cases)]
    status = "passed" if all(result.status == "passed" for result in results) else "failed"
    report = RegressionReport(
        regression_id=regression_id,
        started_at=started_at,
        finished_at=utc_now(),
        simulator=artifact.simulator,
        status=status,
        results=results,
    )
    report_path = write_report(report, args.report_dir)
    print(render_summary(report, report_path))
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())

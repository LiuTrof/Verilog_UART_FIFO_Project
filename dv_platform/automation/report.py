"""Regression report persistence and concise terminal rendering."""

from __future__ import annotations

import json
from pathlib import Path

from .models import RegressionReport


def write_report(report: RegressionReport, report_dir: Path) -> Path:
    """Persist one immutable report in a machine-readable JSON format."""

    report_dir.mkdir(parents=True, exist_ok=True)
    path = report_dir / f"{report.regression_id}.json"
    path.write_text(json.dumps(report.to_dict(), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return path


def render_summary(report: RegressionReport, report_path: Path) -> str:
    """Return the compact console summary used by CI and local developers."""

    lines = [
        f"Regression {report.regression_id}: {report.status.upper()}",
        f"Simulator: {report.simulator}",
        f"Cases: {report.passed_cases}/{report.total_cases} passed",
    ]
    for result in report.results:
        lines.append(
            f"  {result.case_name:<6} {result.status.upper():<6} "
            f"{result.duration_seconds:>6.3f}s checks={result.checked_bytes if result.checked_bytes is not None else '-'}"
        )
    lines.append(f"Report: {report_path}")
    return "\n".join(lines)

"""Typed regression domain models shared by the automation commands."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal


CaseStatus = Literal["passed", "failed", "error", "skipped"]


@dataclass(frozen=True)
class TestCaseDefinition:
    """A runnable verification scenario and its ownership metadata."""

    name: str
    description: str
    owner: str
    expected_checks: int


@dataclass(frozen=True)
class SimulationResult:
    """Normalized outcome of one simulator invocation."""

    case_name: str
    status: CaseStatus
    duration_seconds: float
    simulator: str
    log_path: str
    checked_bytes: int | None
    error_count: int | None
    pending_bytes: int | None
    failure_reason: str | None

    def to_dict(self) -> dict[str, object]:
        return asdict(self)


@dataclass(frozen=True)
class RegressionReport:
    """A complete, JSON-serializable regression report."""

    regression_id: str
    started_at: str
    finished_at: str
    simulator: str
    status: Literal["passed", "failed"]
    results: list[SimulationResult]

    @property
    def total_cases(self) -> int:
        return len(self.results)

    @property
    def passed_cases(self) -> int:
        return sum(result.status == "passed" for result in self.results)

    def to_dict(self) -> dict[str, object]:
        return {
            "regression_id": self.regression_id,
            "started_at": self.started_at,
            "finished_at": self.finished_at,
            "simulator": self.simulator,
            "status": self.status,
            "summary": {
                "total_cases": self.total_cases,
                "passed_cases": self.passed_cases,
                "failed_cases": self.total_cases - self.passed_cases,
                "pass_rate": round(self.passed_cases / self.total_cases * 100, 2)
                if self.total_cases
                else 0.0,
            },
            "results": [result.to_dict() for result in self.results],
        }


def utc_now() -> str:
    """Return a stable ISO-8601 timestamp suitable for reports and the API."""

    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def resolve_project_root() -> Path:
    """Find the repository root from this module without relying on CWD."""

    return Path(__file__).resolve().parents[2]

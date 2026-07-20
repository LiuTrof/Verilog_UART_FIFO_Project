"""Domain entities for the verification platform service layer."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Project:
    id: int
    name: str
    description: str
    version: str
    created_at: str


@dataclass(frozen=True)
class TestCase:
    id: int
    project_id: int
    name: str
    description: str
    owner: str
    expected_checks: int
    status: str
    result: str


@dataclass(frozen=True)
class Regression:
    id: str
    project_id: int
    simulator: str
    status: str
    started_at: str
    finished_at: str | None
    total_cases: int
    passed_cases: int
    report_path: str | None


@dataclass(frozen=True)
class Simulation:
    id: int
    regression_id: str
    testcase_id: int
    status: str
    runtime_seconds: float
    checked_bytes: int | None
    error_count: int | None
    pending_bytes: int | None
    log_path: str
    failure_reason: str | None
    testcase_name: str | None = None

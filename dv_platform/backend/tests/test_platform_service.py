"""Focused service-level regression tests using an isolated SQLite database."""

from __future__ import annotations

import json
from pathlib import Path

from dv_platform.backend.app.model.entities import Regression, Simulation
from dv_platform.backend.app.service.platform_service import PlatformService


def test_bootstrap_creates_project_and_verification_plan(tmp_path: Path) -> None:
    service = PlatformService(tmp_path / "platform.db")

    project = service.bootstrap()
    testcases = service.list_testcases(project.id)

    assert project.name == "UART FIFO Verification"
    assert [case.name for case in testcases] == ["single", "multi", "stream", "fifo", "reset"]


def test_dashboard_reflects_seeded_project(tmp_path: Path) -> None:
    service = PlatformService(tmp_path / "platform.db")
    project = service.bootstrap()

    dashboard = service.dashboard(project.id)

    assert dashboard["total_testcases"] == 5
    assert dashboard["pass_rate"] == 0.0
    assert dashboard["coverage"]["source"] is None


def test_regression_progress_exposes_completed_case_before_run_finishes(tmp_path: Path) -> None:
    service = PlatformService(tmp_path / "platform.db")
    project = service.bootstrap()
    testcase = service.list_testcases(project.id)[0]
    regression = Regression(
        id="reg-live-progress",
        project_id=project.id,
        simulator="iverilog-legacy",
        status="queued",
        started_at="2026-01-01T00:00:00+00:00",
        finished_at=None,
        total_cases=2,
        passed_cases=0,
        report_path=None,
    )
    service.repository.create_regression(regression)
    service.repository.create_simulation(
        Simulation(
            id=0,
            regression_id=regression.id,
            testcase_id=testcase.id,
            status="passed",
            runtime_seconds=0.2,
            checked_bytes=1,
            error_count=0,
            pending_bytes=0,
            log_path="/tmp/reg-live-progress_single.log",
            failure_reason=None,
        )
    )
    service.repository.update_regression_progress(regression.id, passed_cases=1)

    progress = service.get_regression(regression.id)
    simulations = service.list_simulations(regression.id)

    assert progress.status == "queued"
    assert (progress.passed_cases, progress.total_cases) == (1, 2)
    assert simulations[0].testcase_name == "single"


def test_regression_history_returns_all_runs_by_default(tmp_path: Path) -> None:
    service = PlatformService(tmp_path / "platform.db")
    project = service.bootstrap()
    for index in range(21):
        service.repository.create_regression(
            Regression(
                id=f"reg-history-{index}",
                project_id=project.id,
                simulator="iverilog-legacy",
                status="passed",
                started_at=f"2026-01-01T00:00:{index:02d}+00:00",
                finished_at=f"2026-01-01T00:01:{index:02d}+00:00",
                total_cases=1,
                passed_cases=1,
                report_path=f"/tmp/reg-history-{index}.json",
            )
        )

    assert len(service.list_regressions(project.id)) == 21


def test_queued_regression_is_resumed_with_a_valid_simulator_mode(tmp_path: Path, monkeypatch) -> None:
    service = PlatformService(tmp_path / "platform.db")
    project = service.bootstrap()
    regression = Regression(
        id="reg-resume-legacy",
        project_id=project.id,
        simulator="iverilog-legacy",
        status="queued",
        started_at="2026-01-01T00:00:00+00:00",
        finished_at=None,
        total_cases=5,
        passed_cases=3,
        report_path=None,
        requested_cases=json.dumps(["single", "multi", "stream", "fifo", "reset"]),
    )
    service.repository.create_regression(regression)
    resumed: list[tuple[str, int, list[str], str]] = []
    monkeypatch.setattr(service, "_start_worker", lambda *args: resumed.append(args))

    service.resume_queued_regressions()

    assert resumed == [
        ("reg-resume-legacy", project.id, ["single", "multi", "stream", "fifo", "reset"], "legacy")
    ]


def test_queued_legacy_regression_without_saved_selection_remains_recoverable(
    tmp_path: Path, monkeypatch
) -> None:
    service = PlatformService(tmp_path / "platform.db")
    project = service.bootstrap()
    regression = Regression(
        id="reg-resume-compatibility",
        project_id=project.id,
        simulator="iverilog-legacy",
        status="queued",
        started_at="2026-01-01T00:00:00+00:00",
        finished_at=None,
        total_cases=5,
        passed_cases=3,
        report_path=None,
    )
    service.repository.create_regression(regression)
    resumed: list[tuple[str, int, list[str], str]] = []
    monkeypatch.setattr(service, "_start_worker", lambda *args: resumed.append(args))

    service.resume_queued_regressions()

    assert resumed == [
        ("reg-resume-compatibility", project.id, ["single", "multi", "stream", "fifo", "reset"], "legacy")
    ]

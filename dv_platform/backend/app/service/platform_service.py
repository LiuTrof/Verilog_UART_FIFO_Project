"""Application service coordinates validation, persistence, and regression execution."""

from __future__ import annotations

import json
import threading
import uuid
from pathlib import Path
from typing import Iterator

from dv_platform.automation.compile import CompileError, available_simulator, compile_testbench
from dv_platform.automation.models import RegressionReport, resolve_project_root, utc_now
from dv_platform.automation.report import write_report
from dv_platform.automation.regression import CASE_BY_NAME, TEST_CASES
from dv_platform.automation.simulator import SimulatorRunner
from dv_platform.backend.app.model.entities import Project, Regression, Simulation, TestCase
from dv_platform.backend.app.repository.database import initialize
from dv_platform.backend.app.repository.platform_repository import PlatformRepository


class NotFoundError(LookupError):
    """Requested platform resource does not exist."""


class ConflictError(ValueError):
    """A requested resource conflicts with the current state."""


class PlatformService:
    """Use-case layer for the Chip Verification Engineering Platform."""

    def __init__(self, database_path: Path | None = None) -> None:
        initialize(database_path)
        self.repository = PlatformRepository(database_path)
        self._runs: dict[str, threading.Thread] = {}
        self._run_lock = threading.Lock()
        self._progress_condition = threading.Condition()
        self._progress_versions: dict[str, int] = {}

    def bootstrap(self) -> Project:
        """Create the UART FIFO project and add any missing verification-plan cases."""

        existing = self.repository.list_projects()
        if existing:
            project = existing[0]
        else:
            project = self.repository.create_project(
                name="UART FIFO Verification",
                description="UART RX -> FIFO -> loopback -> UART TX module-level verification platform.",
                version="main",
                created_at=utc_now(),
            )
        for case in TEST_CASES:
            if not self.repository.get_testcase_by_name(project.id, case.name):
                self.repository.create_testcase(
                    project.id, case.name, case.description, case.owner, case.expected_checks
                )
        return project

    def list_projects(self) -> list[Project]:
        return self.repository.list_projects()

    def create_project(self, name: str, description: str, version: str) -> Project:
        try:
            return self.repository.create_project(name, description, version, utc_now())
        except Exception as exc:
            if "UNIQUE" in str(exc).upper():
                raise ConflictError(f"Project '{name}' already exists.") from exc
            raise

    def _project(self, project_id: int) -> Project:
        project = self.repository.get_project(project_id)
        if not project:
            raise NotFoundError(f"Project {project_id} was not found.")
        return project

    def list_testcases(self, project_id: int) -> list[TestCase]:
        self._project(project_id)
        return self.repository.list_testcases(project_id)

    def create_testcase(
        self, project_id: int, name: str, description: str, owner: str, expected_checks: int
    ) -> TestCase:
        self._project(project_id)
        if self.repository.get_testcase_by_name(project_id, name):
            raise ConflictError(f"Testcase '{name}' already exists in project {project_id}.")
        return self.repository.create_testcase(project_id, name, description, owner, expected_checks)

    def start_regression(self, project_id: int, requested_cases: list[str], simulator: str) -> Regression:
        self._project(project_id)
        if not requested_cases:
            raise ValueError("At least one testcase must be selected.")
        if "all" in requested_cases:
            case_names = [case.name for case in TEST_CASES]
        else:
            case_names = list(dict.fromkeys(requested_cases))
        unavailable = [name for name in case_names if name not in CASE_BY_NAME]
        if unavailable:
            raise ValueError(f"Unsupported testcase(s): {', '.join(unavailable)}.")
        resolved_simulator = available_simulator(simulator)
        regression_id = f"reg-{uuid.uuid4().hex[:12]}"
        regression = Regression(
            id=regression_id,
            project_id=project_id,
            simulator=resolved_simulator,
            status="queued",
            started_at=utc_now(),
            finished_at=None,
            total_cases=len(case_names),
            passed_cases=0,
            report_path=None,
            requested_cases=json.dumps(case_names),
        )
        self.repository.create_regression(regression)
        self._start_worker(regression_id, project_id, case_names, simulator)
        return regression

    def resume_queued_regressions(self) -> None:
        """Resume durable queued work after a dev reload or API process restart."""

        for regression in self.repository.list_queued_regressions():
            case_names = self._requested_case_names(regression)
            if not case_names:
                self._fail_interrupted_regression(regression, "Missing persisted testcase selection for queued regression.")
                continue
            self._start_worker(
                regression.id,
                regression.project_id,
                case_names,
                self._resume_simulator_mode(regression.simulator),
            )

    def _requested_case_names(self, regression: Regression) -> list[str]:
        if regression.requested_cases:
            try:
                case_names = json.loads(regression.requested_cases)
            except json.JSONDecodeError:
                return []
            if isinstance(case_names, list) and all(isinstance(name, str) and name in CASE_BY_NAME for name in case_names):
                return case_names
            return []
        # Compatibility for queued runs created before requested_cases was persisted.
        return [case.name for case in TEST_CASES] if regression.total_cases == len(TEST_CASES) else []

    @staticmethod
    def _resume_simulator_mode(simulator: str) -> str:
        """Map the persisted simulator label back to a compile selection mode."""

        if simulator == "iverilog-legacy":
            return "legacy"
        if simulator.endswith("-uvm"):
            return "uvm"
        return "auto"

    def _start_worker(self, regression_id: str, project_id: int, case_names: list[str], simulator: str) -> None:
        with self._run_lock:
            existing = self._runs.get(regression_id)
            if existing and existing.is_alive():
                return
            worker = threading.Thread(
                target=self._execute_regression,
                args=(regression_id, project_id, case_names, simulator),
                daemon=True,
                name=f"dv-{regression_id}",
            )
            self._runs[regression_id] = worker
        with self._progress_condition:
            self._progress_versions.setdefault(regression_id, 0)
        worker.start()

    def _fail_interrupted_regression(self, regression: Regression, reason: str) -> None:
        log_path = resolve_project_root() / "sim" / "dv_platform" / "log" / f"{regression.id}_resume.log"
        log_path.parent.mkdir(parents=True, exist_ok=True)
        log_path.write_text(reason + "\n", encoding="utf-8")
        self.repository.finish_regression(
            regression.id, "failed", utc_now(), regression.total_cases, regression.passed_cases, str(log_path)
        )
        self._publish_progress(regression.id)

    def _publish_progress(self, regression_id: str) -> None:
        """Wake the single live-progress stream after a durable state change."""

        with self._progress_condition:
            self._progress_versions[regression_id] = self._progress_versions.get(regression_id, 0) + 1
            self._progress_condition.notify_all()

    def _execute_regression(self, regression_id: str, project_id: int, case_names: list[str], simulator: str) -> None:
        """Run outside the HTTP request and persist every individual simulation outcome."""

        try:
            artifact = compile_testbench(simulator)
            runner = SimulatorRunner(artifact)
            existing = {simulation.testcase_name: simulation for simulation in self.repository.list_simulations(regression_id)}
            results = []
            passed_cases = sum(simulation.status == "passed" for simulation in existing.values())
            for case_name in case_names:
                if case_name in existing:
                    results.append(self._simulation_result(existing[case_name], artifact.simulator))
                    continue
                result = runner.run_case(case_name, regression_id)
                results.append(result)
                if result.status == "passed":
                    passed_cases += 1
                testcase = self.repository.get_testcase_by_name(project_id, result.case_name)
                if testcase:
                    self.repository.create_simulation(
                        Simulation(
                            id=0,
                            regression_id=regression_id,
                            testcase_id=testcase.id,
                            status=result.status,
                            runtime_seconds=result.duration_seconds,
                            checked_bytes=result.checked_bytes,
                            error_count=result.error_count,
                            pending_bytes=result.pending_bytes,
                            log_path=result.log_path,
                            failure_reason=result.failure_reason,
                        )
                    )
                    self.repository.update_testcase_result(project_id, result.case_name, "ready", result.status)
                # Persist the case before executing the next one so the selected run can render live progress.
                self.repository.update_regression_progress(regression_id, passed_cases)
                self._publish_progress(regression_id)
            status = "passed" if all(result.status == "passed" for result in results) else "failed"
            report = RegressionReport(
                regression_id=regression_id,
                started_at=self.repository.get_regression(regression_id).started_at,  # type: ignore[union-attr]
                finished_at=utc_now(),
                simulator=artifact.simulator,
                status=status,
                results=results,
            )
            report_path = write_report(report, resolve_project_root() / "sim" / "dv_platform" / "report")
            self.repository.finish_regression(
                regression_id, status, report.finished_at, report.total_cases, report.passed_cases, str(report_path)
            )
            self._publish_progress(regression_id)
            # Legacy runs report functional self-checking only; commercial coverage import remains explicit.
            self.repository.write_coverage(regression_id, "not_collected", (None, None, None, None))
        except (CompileError, OSError, RuntimeError, ValueError) as exc:
            log_path = resolve_project_root() / "sim" / "dv_platform" / "log" / f"{regression_id}_setup.log"
            log_path.parent.mkdir(parents=True, exist_ok=True)
            log_path.write_text(str(exc) + "\n", encoding="utf-8")
            regression = self.repository.get_regression(regression_id)
            self.repository.finish_regression(
                regression_id,
                "failed",
                utc_now(),
                regression.total_cases if regression else 0,
                regression.passed_cases if regression else 0,
                str(log_path),
            )
            self._publish_progress(regression_id)
        finally:
            with self._run_lock:
                self._runs.pop(regression_id, None)

    @staticmethod
    def _simulation_result(simulation: Simulation, simulator: str):
        """Convert a persisted case result back into report data when resuming a regression."""

        from dv_platform.automation.models import SimulationResult

        return SimulationResult(
            case_name=simulation.testcase_name or Path(simulation.log_path).stem.rsplit("_", 1)[-1],
            status=simulation.status,  # type: ignore[arg-type]
            duration_seconds=simulation.runtime_seconds,
            simulator=simulator,
            log_path=simulation.log_path,
            checked_bytes=simulation.checked_bytes,
            error_count=simulation.error_count,
            pending_bytes=simulation.pending_bytes,
            failure_reason=simulation.failure_reason,
        )

    def list_regressions(self, project_id: int) -> list[Regression]:
        self._project(project_id)
        return self.repository.list_regressions(project_id)

    def get_regression(self, regression_id: str) -> Regression:
        regression = self.repository.get_regression(regression_id)
        if not regression:
            raise NotFoundError(f"Regression '{regression_id}' was not found.")
        return regression

    def list_simulations(self, regression_id: str) -> list[Simulation]:
        self.get_regression(regression_id)
        return self.repository.list_simulations(regression_id)

    def regression_progress(self, regression_id: str) -> tuple[Regression, list[Simulation]]:
        """Read one consistent UI snapshot after a progress notification."""

        return self.get_regression(regression_id), self.repository.list_simulations(regression_id)

    def stream_regression_progress(self, regression_id: str) -> Iterator[tuple[int, Regression, list[Simulation]]]:
        """Yield the initial state and every subsequent persisted testcase result."""

        observed_version = -1
        while True:
            with self._progress_condition:
                self._progress_condition.wait_for(
                    lambda: self._progress_versions.get(regression_id, 0) > observed_version,
                    timeout=15,
                )
                next_version = self._progress_versions.get(regression_id, 0)
            if next_version == observed_version:
                # Keep the connection alive without turning an idle interval into a duplicate update.
                yield next_version, self.get_regression(regression_id), []
                continue
            observed_version = next_version
            regression, simulations = self.regression_progress(regression_id)
            yield observed_version, regression, simulations
            if regression.status != "queued":
                return

    def dashboard(self, project_id: int) -> dict[str, object]:
        project = self._project(project_id)
        cases = self.repository.list_testcases(project_id)
        passed = sum(case.result == "passed" for case in cases)
        failed = sum(case.result == "failed" for case in cases)
        regressions = self.repository.list_regressions(project_id, limit=1)
        coverage = self.repository.latest_coverage(project_id) or {
            "line_coverage": None,
            "branch_coverage": None,
            "fsm_coverage": None,
            "functional_coverage": None,
            "source": None,
        }
        return {
            "project": project,
            "total_testcases": len(cases),
            "passed_testcases": passed,
            "pass_rate": round(passed / len(cases) * 100, 2) if cases else 0.0,
            "failed_testcases": failed,
            "latest_regression": regressions[0] if regressions else None,
            "coverage": coverage,
        }

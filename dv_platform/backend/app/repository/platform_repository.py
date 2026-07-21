"""Repository layer keeping SQL out of API controllers and services."""

from __future__ import annotations

import sqlite3
from pathlib import Path

from dv_platform.backend.app.model.entities import Project, Regression, Simulation, TestCase
from dv_platform.backend.app.repository.database import connect


class PlatformRepository:
    """Persistence operations for projects, testcases, regressions, and simulations."""

    def __init__(self, database_path: Path | None = None) -> None:
        self.database_path = database_path

    def _connection(self) -> sqlite3.Connection:
        return connect(self.database_path)

    @staticmethod
    def _project(row: sqlite3.Row) -> Project:
        return Project(**dict(row))

    @staticmethod
    def _testcase(row: sqlite3.Row) -> TestCase:
        return TestCase(**dict(row))

    @staticmethod
    def _regression(row: sqlite3.Row) -> Regression:
        return Regression(**dict(row))

    @staticmethod
    def _simulation(row: sqlite3.Row) -> Simulation:
        return Simulation(**dict(row))

    def list_projects(self) -> list[Project]:
        with self._connection() as connection:
            rows = connection.execute("SELECT * FROM projects ORDER BY id").fetchall()
        return [self._project(row) for row in rows]

    def get_project(self, project_id: int) -> Project | None:
        with self._connection() as connection:
            row = connection.execute("SELECT * FROM projects WHERE id = ?", (project_id,)).fetchone()
        return self._project(row) if row else None

    def create_project(self, name: str, description: str, version: str, created_at: str) -> Project:
        with self._connection() as connection:
            cursor = connection.execute(
                "INSERT INTO projects(name, description, version, created_at) VALUES (?, ?, ?, ?)",
                (name, description, version, created_at),
            )
            row = connection.execute("SELECT * FROM projects WHERE id = ?", (cursor.lastrowid,)).fetchone()
        return self._project(row)

    def list_testcases(self, project_id: int) -> list[TestCase]:
        with self._connection() as connection:
            rows = connection.execute(
                "SELECT * FROM testcases WHERE project_id = ? ORDER BY id", (project_id,)
            ).fetchall()
        return [self._testcase(row) for row in rows]

    def get_testcase_by_name(self, project_id: int, name: str) -> TestCase | None:
        with self._connection() as connection:
            row = connection.execute(
                "SELECT * FROM testcases WHERE project_id = ? AND name = ?", (project_id, name)
            ).fetchone()
        return self._testcase(row) if row else None

    def create_testcase(
        self, project_id: int, name: str, description: str, owner: str, expected_checks: int
    ) -> TestCase:
        with self._connection() as connection:
            cursor = connection.execute(
                """INSERT INTO testcases(project_id, name, description, owner, expected_checks, status, result)
                   VALUES (?, ?, ?, ?, ?, 'ready', 'not_run')""",
                (project_id, name, description, owner, expected_checks),
            )
            row = connection.execute("SELECT * FROM testcases WHERE id = ?", (cursor.lastrowid,)).fetchone()
        return self._testcase(row)

    def update_testcase_result(self, project_id: int, name: str, status: str, result: str) -> None:
        with self._connection() as connection:
            connection.execute(
                "UPDATE testcases SET status = ?, result = ? WHERE project_id = ? AND name = ?",
                (status, result, project_id, name),
            )

    def create_regression(self, regression: Regression) -> None:
        with self._connection() as connection:
            connection.execute(
                """INSERT INTO regressions(id, project_id, simulator, status, started_at, finished_at,
                   total_cases, passed_cases, report_path, requested_cases)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    regression.id,
                    regression.project_id,
                    regression.simulator,
                    regression.status,
                    regression.started_at,
                    regression.finished_at,
                    regression.total_cases,
                    regression.passed_cases,
                    regression.report_path,
                    regression.requested_cases,
                ),
            )

    def finish_regression(
        self, regression_id: str, status: str, finished_at: str, total_cases: int, passed_cases: int, report_path: str
    ) -> None:
        with self._connection() as connection:
            connection.execute(
                """UPDATE regressions SET status = ?, finished_at = ?, total_cases = ?, passed_cases = ?, report_path = ?
                   WHERE id = ?""",
                (status, finished_at, total_cases, passed_cases, report_path, regression_id),
            )

    def list_regressions(self, project_id: int, limit: int | None = None) -> list[Regression]:
        with self._connection() as connection:
            if limit is None:
                rows = connection.execute(
                    "SELECT * FROM regressions WHERE project_id = ? ORDER BY started_at DESC", (project_id,)
                ).fetchall()
            else:
                rows = connection.execute(
                    "SELECT * FROM regressions WHERE project_id = ? ORDER BY started_at DESC LIMIT ?", (project_id, limit)
                ).fetchall()
        return [self._regression(row) for row in rows]

    def get_regression(self, regression_id: str) -> Regression | None:
        with self._connection() as connection:
            row = connection.execute("SELECT * FROM regressions WHERE id = ?", (regression_id,)).fetchone()
        return self._regression(row) if row else None

    def list_queued_regressions(self) -> list[Regression]:
        with self._connection() as connection:
            rows = connection.execute(
                "SELECT * FROM regressions WHERE status = 'queued' ORDER BY started_at"
            ).fetchall()
        return [self._regression(row) for row in rows]

    def create_simulation(self, simulation: Simulation) -> None:
        with self._connection() as connection:
            connection.execute(
                """INSERT INTO simulations(regression_id, testcase_id, status, runtime_seconds, checked_bytes,
                   error_count, pending_bytes, log_path, failure_reason)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    simulation.regression_id,
                    simulation.testcase_id,
                    simulation.status,
                    simulation.runtime_seconds,
                    simulation.checked_bytes,
                    simulation.error_count,
                    simulation.pending_bytes,
                    simulation.log_path,
                    simulation.failure_reason,
                ),
            )

    def list_simulations(self, regression_id: str) -> list[Simulation]:
        with self._connection() as connection:
            rows = connection.execute(
                """SELECT simulations.*, testcases.name AS testcase_name
                   FROM simulations JOIN testcases ON testcases.id = simulations.testcase_id
                   WHERE simulations.regression_id = ? ORDER BY simulations.id""",
                (regression_id,),
            ).fetchall()
        return [self._simulation(row) for row in rows]

    def update_regression_progress(self, regression_id: str, passed_cases: int) -> None:
        with self._connection() as connection:
            connection.execute(
                "UPDATE regressions SET passed_cases = ? WHERE id = ?", (passed_cases, regression_id)
            )

    def write_coverage(self, regression_id: str, source: str, values: tuple[float | None, ...]) -> None:
        with self._connection() as connection:
            connection.execute(
                """INSERT INTO coverage_snapshots(regression_id, line_coverage, branch_coverage, fsm_coverage,
                   functional_coverage, source) VALUES (?, ?, ?, ?, ?, ?)""",
                (regression_id, *values, source),
            )

    def latest_coverage(self, project_id: int) -> dict[str, float | None] | None:
        with self._connection() as connection:
            row = connection.execute(
                """SELECT c.line_coverage, c.branch_coverage, c.fsm_coverage, c.functional_coverage, c.source
                   FROM coverage_snapshots c JOIN regressions r ON c.regression_id = r.id
                   WHERE r.project_id = ? ORDER BY c.id DESC LIMIT 1""",
                (project_id,),
            ).fetchone()
        return dict(row) if row else None

"""SQLite connection and schema lifecycle for a self-contained platform instance."""

from __future__ import annotations

import sqlite3
from pathlib import Path

from dv_platform.automation.models import resolve_project_root


SCHEMA = """
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS projects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    version TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS testcases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    owner TEXT NOT NULL,
    expected_checks INTEGER NOT NULL,
    status TEXT NOT NULL,
    result TEXT NOT NULL,
    UNIQUE(project_id, name)
);

CREATE TABLE IF NOT EXISTS regressions (
    id TEXT PRIMARY KEY,
    project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    simulator TEXT NOT NULL,
    status TEXT NOT NULL,
    started_at TEXT NOT NULL,
    finished_at TEXT,
    total_cases INTEGER NOT NULL DEFAULT 0,
    passed_cases INTEGER NOT NULL DEFAULT 0,
    report_path TEXT
);

CREATE TABLE IF NOT EXISTS simulations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    regression_id TEXT NOT NULL REFERENCES regressions(id) ON DELETE CASCADE,
    testcase_id INTEGER NOT NULL REFERENCES testcases(id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    runtime_seconds REAL NOT NULL,
    checked_bytes INTEGER,
    error_count INTEGER,
    pending_bytes INTEGER,
    log_path TEXT NOT NULL,
    failure_reason TEXT
);

CREATE TABLE IF NOT EXISTS coverage_snapshots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    regression_id TEXT NOT NULL REFERENCES regressions(id) ON DELETE CASCADE,
    line_coverage REAL,
    branch_coverage REAL,
    fsm_coverage REAL,
    functional_coverage REAL,
    source TEXT NOT NULL
);
"""


def default_database_path() -> Path:
    """Store platform data under sim so it remains clearly generated/project-local."""

    return resolve_project_root() / "sim" / "dv_platform" / "platform.db"


def connect(database_path: Path | None = None) -> sqlite3.Connection:
    """Open a row-addressable SQLite connection with foreign-key enforcement."""

    path = database_path or default_database_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(path)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    return connection


def initialize(database_path: Path | None = None) -> None:
    """Create missing tables. This operation is intentionally idempotent."""

    with connect(database_path) as connection:
        connection.executescript(SCHEMA)

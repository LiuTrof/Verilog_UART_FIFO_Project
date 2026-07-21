"""Strict API payload schemas; FastAPI will generate the OpenAPI contract from these."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class ProjectCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    description: str = Field(min_length=2, max_length=1000)
    version: str = Field(default="main", min_length=1, max_length=64)


class ProjectResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str
    version: str
    created_at: str


class TestCaseCreate(BaseModel):
    name: str = Field(min_length=1, max_length=64, pattern=r"^[a-z0-9_-]+$")
    description: str = Field(min_length=2, max_length=1000)
    owner: str = Field(default="DV Platform", min_length=2, max_length=120)
    expected_checks: int = Field(default=0, ge=0)


class TestCaseResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    project_id: int
    name: str
    description: str
    owner: str
    expected_checks: int
    status: str
    result: str


class RegressionStart(BaseModel):
    cases: list[str] = Field(default_factory=lambda: ["all"], min_length=1)
    simulator: Literal["auto", "legacy", "uvm"] = "auto"


class RegressionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    project_id: int
    simulator: str
    status: str
    started_at: str
    finished_at: str | None
    total_cases: int
    passed_cases: int
    report_path: str | None


class SimulationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

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


class RegressionProgressResponse(BaseModel):
    regression: RegressionResponse
    simulations: list[SimulationResponse]


class CoverageResponse(BaseModel):
    line_coverage: float | None
    branch_coverage: float | None
    fsm_coverage: float | None
    functional_coverage: float | None
    source: str | None


class DashboardResponse(BaseModel):
    project: ProjectResponse
    total_testcases: int
    passed_testcases: int
    pass_rate: float
    failed_testcases: int
    latest_regression: RegressionResponse | None
    coverage: CoverageResponse

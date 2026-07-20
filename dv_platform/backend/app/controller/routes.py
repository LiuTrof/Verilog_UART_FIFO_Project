"""Thin HTTP controller layer for the verification-platform API."""

from __future__ import annotations

import json
import tempfile
from pathlib import Path
from typing import Iterator

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import StreamingResponse

from dv_platform.automation.compile import CompileError
from dv_platform.backend.app.schema.api import (
    DashboardResponse,
    ProjectCreate,
    ProjectResponse,
    RegressionResponse,
    RegressionStart,
    RegressionProgressResponse,
    SimulationResponse,
    TestCaseCreate,
    TestCaseResponse,
)
from dv_platform.backend.app.service.platform_service import ConflictError, NotFoundError, PlatformService
from dv_platform.backend.app.service.waveform_service import WaveformNotFoundError, WaveformService


router = APIRouter(prefix="/api/v1", tags=["verification-platform"])


def get_service() -> PlatformService:
    """Resolve the application-scoped service stored by the app factory."""

    from dv_platform.backend.app.main import service

    return service


def get_waveform_service() -> WaveformService:
    return WaveformService()


def _not_found(error: NotFoundError) -> HTTPException:
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(error))


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "chip-dv-platform"}


@router.get("/projects", response_model=list[ProjectResponse])
def list_projects(platform: PlatformService = Depends(get_service)) -> list[ProjectResponse]:
    return [ProjectResponse.model_validate(project) for project in platform.list_projects()]


@router.post("/projects", response_model=ProjectResponse, status_code=status.HTTP_201_CREATED)
def create_project(payload: ProjectCreate, platform: PlatformService = Depends(get_service)) -> ProjectResponse:
    try:
        return ProjectResponse.model_validate(platform.create_project(**payload.model_dump()))
    except ConflictError as error:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(error)) from error


@router.get("/projects/{project_id}/dashboard", response_model=DashboardResponse)
def dashboard(project_id: int, platform: PlatformService = Depends(get_service)) -> DashboardResponse:
    try:
        return DashboardResponse.model_validate(platform.dashboard(project_id))
    except NotFoundError as error:
        raise _not_found(error) from error


@router.get("/projects/{project_id}/testcases", response_model=list[TestCaseResponse])
def list_testcases(project_id: int, platform: PlatformService = Depends(get_service)) -> list[TestCaseResponse]:
    try:
        return [TestCaseResponse.model_validate(case) for case in platform.list_testcases(project_id)]
    except NotFoundError as error:
        raise _not_found(error) from error


@router.post(
    "/projects/{project_id}/testcases",
    response_model=TestCaseResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_testcase(
    project_id: int, payload: TestCaseCreate, platform: PlatformService = Depends(get_service)
) -> TestCaseResponse:
    try:
        return TestCaseResponse.model_validate(platform.create_testcase(project_id, **payload.model_dump()))
    except NotFoundError as error:
        raise _not_found(error) from error
    except ConflictError as error:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(error)) from error


@router.get("/projects/{project_id}/regressions", response_model=list[RegressionResponse])
def list_regressions(project_id: int, platform: PlatformService = Depends(get_service)) -> list[RegressionResponse]:
    try:
        return [RegressionResponse.model_validate(run) for run in platform.list_regressions(project_id)]
    except NotFoundError as error:
        raise _not_found(error) from error


@router.post(
    "/projects/{project_id}/regressions",
    response_model=RegressionResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
def start_regression(
    project_id: int, payload: RegressionStart, platform: PlatformService = Depends(get_service)
) -> RegressionResponse:
    try:
        return RegressionResponse.model_validate(platform.start_regression(project_id, payload.cases, payload.simulator))
    except NotFoundError as error:
        raise _not_found(error) from error
    except CompileError as error:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(error)) from error
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(error)) from error


@router.get("/regressions/{regression_id}", response_model=RegressionResponse)
def get_regression(regression_id: str, platform: PlatformService = Depends(get_service)) -> RegressionResponse:
    try:
        return RegressionResponse.model_validate(platform.get_regression(regression_id))
    except NotFoundError as error:
        raise _not_found(error) from error


@router.get("/regressions/{regression_id}/simulations", response_model=list[SimulationResponse])
def list_simulations(regression_id: str, platform: PlatformService = Depends(get_service)) -> list[SimulationResponse]:
    try:
        return [SimulationResponse.model_validate(item) for item in platform.list_simulations(regression_id)]
    except NotFoundError as error:
        raise _not_found(error) from error


@router.get("/regressions/{regression_id}/progress", response_model=RegressionProgressResponse)
def regression_progress(
    regression_id: str, platform: PlatformService = Depends(get_service)
) -> RegressionProgressResponse:
    try:
        regression = platform.get_regression(regression_id)
        simulations = platform.list_simulations(regression_id)
        return RegressionProgressResponse(
            regression=RegressionResponse.model_validate(regression),
            simulations=[SimulationResponse.model_validate(item) for item in simulations],
        )
    except NotFoundError as error:
        raise _not_found(error) from error


@router.get("/regressions/{regression_id}/events")
def regression_events(regression_id: str, platform: PlatformService = Depends(get_service)) -> StreamingResponse:
    """Push one snapshot per completed testcase without browser polling."""

    try:
        platform.get_regression(regression_id)
    except NotFoundError as error:
        raise _not_found(error) from error

    def event_stream() -> Iterator[str]:
        for version, regression, simulations in platform.stream_regression_progress(regression_id):
            if not simulations and version != 0 and regression.status == "queued":
                yield ": keepalive\n\n"
                continue
            payload = RegressionProgressResponse(
                regression=RegressionResponse.model_validate(regression),
                simulations=[SimulationResponse.model_validate(item) for item in simulations],
            ).model_dump(mode="json")
            yield f"id: {version}\ndata: {json.dumps(payload)}\n\n"

    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@router.get("/projects/{project_id}/waveforms")
def list_waveforms(project_id: int, platform: PlatformService = Depends(get_service)) -> list[dict[str, object]]:
    try:
        platform.dashboard(project_id)
    except NotFoundError as error:
        raise _not_found(error) from error
    return [summary.__dict__ for summary in WaveformService().list_waveforms()]


@router.get("/projects/{project_id}/waveforms/{name}")
def inspect_waveform(
    project_id: int,
    name: str,
    search: str = "",
    platform: PlatformService = Depends(get_service),
    waveforms: WaveformService = Depends(get_waveform_service),
) -> dict[str, object]:
    try:
        platform.dashboard(project_id)
        return waveforms.inspect(name, search)
    except NotFoundError as error:
        raise _not_found(error) from error
    except WaveformNotFoundError as error:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Waveform '{error}' was not found.") from error


@router.post("/projects/{project_id}/waveforms", status_code=status.HTTP_201_CREATED)
async def upload_waveform(
    project_id: int,
    file: UploadFile = File(...),
    platform: PlatformService = Depends(get_service),
    waveforms: WaveformService = Depends(get_waveform_service),
) -> dict[str, object]:
    try:
        platform.dashboard(project_id)
    except NotFoundError as error:
        raise _not_found(error) from error
    if not file.filename or not file.filename.lower().endswith(".vcd"):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Only .vcd waveform files are accepted.")
    with tempfile.NamedTemporaryFile(delete=False, suffix=".vcd") as temporary:
        temporary.write(await file.read())
        temporary_path = Path(temporary.name)
    try:
        return waveforms.import_vcd(temporary_path, file.filename).__dict__
    finally:
        temporary_path.unlink(missing_ok=True)

"""FastAPI composition root for the Chip Verification Engineering Platform."""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from dv_platform.backend.app.controller.routes import router
from dv_platform.backend.app.service.platform_service import PlatformService


service = PlatformService()


def create_app() -> FastAPI:
    """Build the API application and initialize the default UART FIFO project."""

    app = FastAPI(
        title="Chip Verification Engineering Platform API",
        version="1.0.0",
        description="Project, testcase, regression, log, and coverage management for UART FIFO DV.",
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"],
        allow_credentials=False,
        allow_methods=["GET", "POST"],
        allow_headers=["Content-Type"],
    )
    app.include_router(router)

    @app.on_event("startup")
    def initialize_platform() -> None:
        service.bootstrap()
        service.resume_queued_regressions()

    return app


app = create_app()

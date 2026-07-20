"""Parse simulator text logs into structured verification results."""

from __future__ import annotations

import re
from pathlib import Path

from .models import SimulationResult


_CHECKED_PATTERNS = (
    re.compile(r"已检查字节数\s*:\s*(\d+)"),
    re.compile(r"CHECKED BYTE\s*:\s*(\d+)"),
    re.compile(r"checked=(\d+)", re.IGNORECASE),
)
_PENDING_PATTERNS = (
    re.compile(r"未匹配预期数\s*:\s*(\d+)"),
    re.compile(r"PENDING BYTE\s*:\s*(\d+)"),
    re.compile(r"pending=(\d+)", re.IGNORECASE),
)
_ERROR_PATTERNS = (
    re.compile(r"当前错误数\s*:\s*(\d+)"),
    re.compile(r"ERROR\s*:\s*(\d+)"),
    re.compile(r"errors=(\d+)", re.IGNORECASE),
)


def _last_value(patterns: tuple[re.Pattern[str], ...], content: str) -> int | None:
    """Return the last matching counter because logs can include several scenarios."""

    values: list[int] = []
    for pattern in patterns:
        values.extend(int(match.group(1)) for match in pattern.finditer(content))
    return values[-1] if values else None


def parse_log(
    *,
    case_name: str,
    log_path: Path,
    duration_seconds: float,
    simulator: str,
    exit_code: int,
) -> SimulationResult:
    """Turn one simulation log and process status into a canonical result."""

    content = log_path.read_text(encoding="utf-8", errors="replace")
    checked = _last_value(_CHECKED_PATTERNS, content)
    pending = _last_value(_PENDING_PATTERNS, content)
    errors = _last_value(_ERROR_PATTERNS, content)
    passed = exit_code == 0 and "TEST PASS" in content and (errors in {None, 0})
    reason: str | None = None
    if not passed:
        reason = "Simulator returned a non-zero status." if exit_code else "PASS marker or error counters are invalid."
        for line in content.splitlines():
            if "[FAIL]" in line or "UVM_ERROR" in line or "UVM_FATAL" in line:
                reason = line.strip()
                break
    return SimulationResult(
        case_name=case_name,
        status="passed" if passed else "failed",
        duration_seconds=round(duration_seconds, 3),
        simulator=simulator,
        log_path=str(log_path),
        checked_bytes=checked,
        error_count=errors,
        pending_bytes=pending,
        failure_reason=reason,
    )

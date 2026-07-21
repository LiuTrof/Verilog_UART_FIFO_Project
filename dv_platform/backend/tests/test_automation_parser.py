"""Tests for log normalization, especially the project-local Chinese scoreboard format."""

from __future__ import annotations

from pathlib import Path

from dv_platform.automation.parser import parse_log


def test_parser_recognizes_passing_chinese_scoreboard_log(tmp_path: Path) -> None:
    log = tmp_path / "single.log"
    log.write_text(
        "已检查字节数 : 1\n未匹配预期数 : 0\n当前错误数   : 0\n结果         : TEST PASS\n",
        encoding="utf-8",
    )

    result = parse_log(
        case_name="single", log_path=log, duration_seconds=0.1, simulator="iverilog-legacy", exit_code=0
    )

    assert result.status == "passed"
    assert result.checked_bytes == 1
    assert result.error_count == 0

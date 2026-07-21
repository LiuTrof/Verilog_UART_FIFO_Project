"""Tests for bounded VCD indexing used by the waveform workbench."""

from __future__ import annotations

from pathlib import Path

from dv_platform.backend.app.service.waveform_service import WaveformService


def test_signal_index_stops_after_vcd_declaration_header(tmp_path: Path) -> None:
    waveform = tmp_path / "header_only.vcd"
    waveform.write_text(
        """$timescale 1 ns $end
$scope module tb $end
$var wire 1 ! clk $end
$upscope $end
$enddefinitions $end
#0
$var wire 1 ? must_not_be_indexed $end
""",
        encoding="utf-8",
    )

    service = WaveformService(tmp_path)
    details = service.inspect(waveform.name)

    assert details["signal_count"] == 1
    assert details["matched_signals"] == [{"name": "tb.clk", "identifier": "!", "width": 1}]
    assert details["end_time"] == 0
    assert details["timescale"] == "1 ns"


def test_imported_vcd_is_listed_and_inspectable(tmp_path: Path) -> None:
    source = tmp_path / "source.vcd"
    source.write_text("$scope module dut $end\n$var wire 8 ! data $end\n$enddefinitions $end\n", encoding="utf-8")
    service = WaveformService(tmp_path / "managed")

    imported = service.import_vcd(source, "uart_capture.vcd")

    assert imported.name == "uart_capture.vcd"
    assert imported.signal_count == 1
    assert imported.timescale is None
    assert service.inspect(imported.name)["matched_signals"][0]["name"] == "dut.data"

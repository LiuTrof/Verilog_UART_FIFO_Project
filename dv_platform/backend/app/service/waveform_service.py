"""VCD discovery, import, and signal indexing for waveform analysis workflows."""

from __future__ import annotations

import re
import shutil
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from dv_platform.automation.models import resolve_project_root


_VCD_VARIABLE = re.compile(r"\$var\s+\S+\s+(\d+)\s+(\S+)\s+([^\s$]+)")


@dataclass(frozen=True)
class WaveformSummary:
    name: str
    size_bytes: int
    modified_at: str
    signal_count: int


class WaveformNotFoundError(FileNotFoundError):
    """Raised for a VCD name outside the managed waveform directory."""


class WaveformService:
    """Manage project-local VCD files without allowing arbitrary path traversal."""

    def __init__(self, waveform_dir: Path | None = None) -> None:
        self.waveform_dir = waveform_dir or resolve_project_root() / "sim" / "uart_fifo_sim"
        self.waveform_dir.mkdir(parents=True, exist_ok=True)

    def _path(self, name: str) -> Path:
        path = self.waveform_dir / Path(name).name
        if path.suffix.lower() != ".vcd" or not path.is_file():
            raise WaveformNotFoundError(name)
        return path

    @staticmethod
    def _signals(path: Path) -> list[dict[str, object]]:
        signals: list[dict[str, object]] = []
        scope: list[str] = []
        with path.open("r", encoding="utf-8", errors="replace") as source:
            for line in source:
                tokens = line.split()
                if not tokens:
                    continue
                if tokens[0] == "$scope" and len(tokens) >= 3:
                    scope.append(tokens[2])
                elif tokens[0] == "$upscope" and scope:
                    scope.pop()
                else:
                    match = _VCD_VARIABLE.match(line)
                    if match:
                        width, identifier, signal_name = match.groups()
                        signals.append(
                            {
                                "name": ".".join([*scope, signal_name]),
                                "identifier": identifier,
                                "width": int(width),
                            }
                        )
        return signals

    def list_waveforms(self) -> list[WaveformSummary]:
        """Return all imported/generated VCDs with header-derived signal counts."""

        waveforms: list[WaveformSummary] = []
        for path in sorted(self.waveform_dir.glob("*.vcd"), key=lambda item: item.stat().st_mtime, reverse=True):
            stat = path.stat()
            waveforms.append(
                WaveformSummary(
                    name=path.name,
                    size_bytes=stat.st_size,
                    modified_at=datetime.fromtimestamp(stat.st_mtime).astimezone().isoformat(timespec="seconds"),
                    signal_count=len(self._signals(path)),
                )
            )
        return waveforms

    def inspect(self, name: str, search: str = "") -> dict[str, object]:
        """Index VCD declarations and return matching signals plus a small source preview."""

        path = self._path(name)
        query = search.casefold().strip()
        signals = self._signals(path)
        matching = [signal for signal in signals if not query or query in str(signal["name"]).casefold()]
        preview = path.read_text(encoding="utf-8", errors="replace")[:1200]
        return {
            "name": path.name,
            "signal_count": len(signals),
            "matched_signals": matching[:200],
            "query": search,
            "preview": preview,
        }

    def import_vcd(self, source_path: Path, filename: str) -> WaveformSummary:
        """Import a VCD written by an upload endpoint into the managed wave directory."""

        target = self.waveform_dir / f"{Path(filename).stem}.vcd"
        shutil.copyfile(source_path, target)
        stat = target.stat()
        return WaveformSummary(
            name=target.name,
            size_bytes=stat.st_size,
            modified_at=datetime.fromtimestamp(stat.st_mtime).astimezone().isoformat(timespec="seconds"),
            signal_count=len(self._signals(target)),
        )

# Chip Verification Engineering Platform

`dv_platform/` turns the existing UART FIFO verification project into a usable engineering
workbench. It deliberately keeps the RTL and the standard UVM 1.2 entry untouched while
adding automation, durable results, an API, and a TypeScript dashboard.

## Why this exists

The users are DV engineers and verification leads who need a repeatable answer to four
questions: which scenarios ran, what failed, where is the log or waveform, and what remains
uncovered. The platform connects those operational concerns to the existing UART/FIFO DUT
without replacing the testbench's independent Driver, Monitor, Scoreboard, or checker.

## Architecture

```text
RTL / UVM core                 Automation                     Platform service                 Workbench
rtl/ + tb/uvm/      ->   compile -> simulate -> parse   ->   FastAPI + SQLite API   ->   React + TypeScript
                         JSON report + raw logs               projects / cases / runs             dashboard / VCD index
```

| Layer | Implementation | Responsibility |
| --- | --- | --- |
| Verification core | `rtl/`, `tb/uvm/` | UART/FIFO behavior, UVM Driver/Monitor/Scoreboard/checker. |
| Automation | `dv_platform/automation/` | Compile, invoke simulator, parse logs, write JSON reports. |
| Service | `dv_platform/backend/app/` | FastAPI controller/service/repository/model layers and SQLite history. |
| Workbench | `dv_platform/frontend/` | Dashboard, testcase management, regression details, waveform signal index. |

## Simulator policy

`./run.sh` remains the standard UVM 1.2 command. It requires VCS, Xcelium, or Questa/ModelSim
with UVM configured. The platform's `auto` runner selects one of those UVM simulators first and
calls the same `run.sh` entry for each selected testcase. When no UVM simulator is available, it
falls back to the project-local Icarus self-checking compatibility testbench. This does not claim
to execute UVM under Icarus; the generated record is clearly labeled `iverilog-legacy`.

```bash
# Existing standard UVM entry, once a UVM 1.2 simulator is installed.
./run.sh all

# Structured, current-machine-compatible regression.
python3 -m dv_platform.automation --cases all

# One fast smoke scenario.
python3 -m dv_platform.automation --cases fifo
```

Artifacts are written below `sim/dv_platform/`:

- `build/`: compiled local compatibility executable
- `log/`: raw scenario logs
- `report/`: immutable JSON regression reports
- `platform.db`: SQLite project and execution history

Platform-triggered smoke and medium-length scenarios emit compact VCDs to `sim/uart_fifo_sim/`
using the regression identifier. The 64-byte and 128-byte deep-stream scenarios retain their
raw logs and JSON reports without a VCD, preventing a 100 MHz clock trace from creating
multi-gigabyte waveform files. The waveform page discovers generated VCDs automatically, so a
frontend run can be traced from its database record through the raw log and JSON report to the
corresponding signals.

Coverage values are intentionally `not_collected` for Icarus. The platform does not present
invented line, branch, FSM, or functional coverage. A commercial simulator coverage export can
be imported as the next integration step.

## Run the workbench

Use two terminals from the repository root.

For a Chinese step-by-step guide covering how to open a local terminal, start all services,
verify health, run regressions, and resolve port conflicts, see
[LOCAL_RUN_GUIDE.md](LOCAL_RUN_GUIDE.md).

```bash
python3 -m venv .venv
.venv/bin/pip install -r dv_platform/backend/requirements.txt
.venv/bin/uvicorn dv_platform.backend.app.main:app --reload --port 8000
```

```bash
cd dv_platform/frontend
export PATH="$HOME/.nvm/versions/node/v22.22.0/bin:$PATH"  # Only needed if an older node comes first on PATH.
npm ci
npm run dev
```

Open `http://127.0.0.1:5173`. The API contract is available at
`http://127.0.0.1:8000/docs`.

## API surface

| Endpoint | Purpose |
| --- | --- |
| `GET /api/v1/projects` | List DV projects. |
| `GET /api/v1/projects/{id}/dashboard` | Project metrics and coverage status. |
| `GET/POST /api/v1/projects/{id}/testcases` | Testcase management. |
| `GET/POST /api/v1/projects/{id}/regressions` | History and asynchronous regression start. |
| `GET /api/v1/regressions/{id}/simulations` | Per-scenario results and log location. |
| `GET/POST /api/v1/projects/{id}/waveforms` | VCD catalog and import. |
| `GET /api/v1/projects/{id}/waveforms/{name}` | Signal index and filtered VCD header. |

## Frontend request policy

The workbench avoids global background refreshes. Initial load reads only the project overview
and regression list. Testcase and waveform catalogs load only when their corresponding page is
opened, then remain cached for the session. Selecting a VCD fetches its declaration index once;
signal search is filtered in the browser rather than re-parsing the VCD on every keystroke.

Only a `queued` regression is polled, and only while the Regression Center is open and the
browser tab is visible. The poll targets that one regression record with bounded exponential
backoff (5, 10, 20, then 30 seconds); leaving the page or hiding the tab cancels the pending
request. The progress response includes the run and all cases that have completed so far; each
case is persisted before the next begins, so the report-path area shows scenario outcomes as they
arrive. Once it reaches a terminal state, the platform does one overview refresh and stops
polling. The Regression Center refresh button remains the explicit path for users who need an
immediate state refresh.

## Quality gates

```bash
.venv/bin/pytest -q
cd dv_platform/frontend && npm run build
```

The automated tests use a temporary SQLite database. They verify project bootstrap, testcase
seeding, dashboard behavior, and parsing of the project's Chinese scoreboard format.

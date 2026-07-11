# GTKWave Scenario Views

This folder contains five GTKWave save files (`.gtkw`). Each save file opens its
own scenario VCD and automatically loads only the signals needed for that
scenario. The DUT RTL is not modified.

Use `./run.sh <scenario> --wave` or the launcher below. The selected simulation
is rerun first so its VCD always matches the current testbench structure.

## Open a Scenario

In GTKWave, select **File -> Read Save File** and choose one of these files:

| Save file | Scenario |
| --- | --- |
| `01_single_byte_loopback.gtkw` | One-byte UART loopback: `A5` |
| `02_multi_byte_loopback.gtkw` | UART loopback: `11 22 33 44` |
| `03_stream_loopback.gtkw` | 20-byte stream: `00` through `13` |
| `04_fifo_boundary.gtkw` | FIFO writes to full, then reads to empty |
| `05_reset_recovery.gtkw` | Reset followed by another `A5` loopback |

Each view starts at time zero because every scenario now has an independent VCD.

## Signals Shown

Each view deliberately contains only the signals needed to judge its scenario:

| View | Signals used to judge the scenario |
| --- | --- |
| Single byte | `rx`, `tx`, RX/TX done pulses, `driver_data`, `monitor_data` |
| Multi byte | `rx`, `tx`, RX/TX done pulses, `driver_data`, `monitor_data` |
| Stream | `rx`, `tx`, `driver_data`, `monitor_data` |
| FIFO boundary | FIFO reset, write/read enables, `full`, `empty`, write data |
| Reset recovery | `reset`, `rx`, `tx`, RX/TX done pulses, `driver_data`, `monitor_data` |

Signals that do not directly support a scenario's pass criteria are intentionally
excluded to keep the waveform focused.

## Switching Views

GTKWave's **File -> Read Save File** appends the new view's signals to the
currently displayed signals. To replace the current view inside the same tab,
first click the signal-name pane, then use **Edit -> Highlight All** followed by
**Edit -> Delete**. After the list is empty, use **File -> Read Save File** to
load the next scenario.

For a clean, one-command launch that reruns one scenario and opens exactly its
matching view, use the included launcher from the project root:

```bash
./gtkwave_views/open_view.sh 1
./gtkwave_views/open_view.sh 2
./gtkwave_views/open_view.sh 3
./gtkwave_views/open_view.sh 4
./gtkwave_views/open_view.sh 5
```

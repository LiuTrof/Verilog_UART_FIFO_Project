# GTKWave Scenario Views

This folder contains five GTKWave save files (`.gtkw`). Each save file opens the
project waveform and automatically loads only the essential signals for one
test scenario. The RTL and testbench files are not modified.

Before opening a view, run `./build.sh` from the project root so the VCD waveform
is regenerated at `sim/uart_fifo_sim/tb_top_loop_test.vcd`.

## Open a Scenario

In GTKWave, select **File -> Read Save File** and choose one of these files:

| Save file | Scenario |
| --- | --- |
| `01_single_byte_loopback.gtkw` | One-byte UART loopback: `A5` |
| `02_multi_byte_loopback.gtkw` | UART loopback: `11 22 33 44` |
| `03_stream_loopback.gtkw` | 20-byte stream: `00` through `13` |
| `04_fifo_boundary.gtkw` | FIFO writes to full, then reads to empty |
| `05_reset_recovery.gtkw` | Reset followed by another `A5` loopback |

You can also double-click a `.gtkw` file in Finder when GTKWave is associated
with the extension, or run it from the project root:

```bash
gtkwave --save gtkwave_views/01_single_byte_loopback.gtkw
```

Each view also starts at the approximate simulation time for that test case.

## Switching Views

GTKWave's **File -> Read Save File** appends the new view's signals to the
currently displayed signals. To replace the current view inside the same tab,
first click the signal-name pane, then use **Edit -> Highlight All** followed by
**Edit -> Delete**. After the list is empty, use **File -> Read Save File** to
load the next scenario.

For a clean, one-command launch that always opens exactly one scenario view in
a new GTKWave window, use the included launcher from the project root:

```bash
./gtkwave_views/open_view.sh 1
./gtkwave_views/open_view.sh 2
./gtkwave_views/open_view.sh 3
./gtkwave_views/open_view.sh 4
./gtkwave_views/open_view.sh 5
```

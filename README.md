# PP16 â€” Tandy 1000 HX editor project

Current working build: **M9 with native Save/Open, basic shape tools, bucket
fill and selection/clipboard editing**, with the M10 sprite-focused interface
cleanup underway,
retaining the PIXELplus-style layout and the accepted faster canvas/pointer
baseline. The 64x64 packed image is editable with one-level undo and can be
saved as a native `.P16` file.

Current M10-start build: **69,122-byte EXE**, with **64,902 code bytes** and
4,112 initialized-data bytes. It remains within the 64 KB small-model code
segment (634 bytes of production code headroom). Shared file-read and byte-comparison
code recovered 291 bytes before adding native `.CLP` save/load, for 361 bytes
of net code growth. Range/overflow checks and verified saves remain enabled.
The current checkpoint uses
FPC `-O1 -Os`, a packed 3x5 font table, shared line/border/clipboard-transform
routines, shared shape rasterizers, incremental shape previews, packed-row
image-preview drawing, and packed-row clipboard copy for aligned selections. the nonfunctional single-image number and
information panels. See the optimization checkpoint in
[MILESTONES.md](docs/MILESTONES.md).
The current M6 build includes the save/restart fix for DOSBox profiles with
long filenames enabled; PP16 consistently uses DOS 8.3 file operations.

- **Brush** (top row, fourth icon): left-click or drag to paint square strokes.
- **Eraser** (bottom row, first icon): left-drag with the background color.
- **Circle, Square, Line** (bottom row, second through fourth icons): drag with
  the foreground color. Circle starts at its centre; Square starts at its first
  corner. Their live canvas outline previews the result before release. Each
  completed shape is one undoable action; Escape cancels it.
- **Size selector** (below the tool icons): use its - / + buttons to choose a
  shared 1–5 px square brush for Brush, Eraser, Circle, Square and Line.
- **Bucket Fill** (top row, third icon): left-click a connected area to replace
  it with the foreground color. It is four-connected, respects color borders,
  and is one undoable action.
- **Select** (top row, first icon): drag an inclusive rectangle; hold **Ctrl**
  while dragging to constrain it to a square. Right-click the button to toggle
  an ellipse selector; Ctrl-drag then constrains it to a circle. Both shapes use
  the same one-screen-pixel alternating light/dark-grey marquee. Ellipse Copy,
  Cut and Paste affect only pixels inside the oval; included black pixels remain
  opaque. **Ctrl+C** copies it; **Ctrl+X** copies then clears it to the
  background color as one undoable action. **Ctrl+V** opens a shape-matched
  floating Paste outline centered in the view: move it with the mouse or arrows,
  then left-click or press Enter to commit; Escape cancels. Paste clips at the
  image edge and is one undoable action.
  **Edit > Paste Behind** restricts a paste to destination pixels matching the currently selected background color; it is a persistent, checked toggle and applies when the floating clip is placed.
- **Clipboard** (top row, second icon) or its right-hand panel: begin placement
  of the current clipboard image. The panel shows the clipboard at actual size
  and its dimensions. Its right-side mirror, rotate and scale buttons are always
  visible; they take effect once a clipboard image exists. The Select label
  shows the current selection dimensions.
- **Right-click/drag on the canvas**: sample foreground color with any tool.
- **Left/right palette click**: foreground/background color; **Tab** swaps them.
- **1 / 2 / 4 / 8**: zoom; **arrows**: pan one pixel; **Shift+arrows**: pan
  half the visible view. **F4**: grid; **F1**: help.
- **On-screen pan arrows**: left-click for half a view, right-click for one pixel.
- **Click/drag in the image preview**: center the view there; dragging past its
  edges clamps to the image. Escape ends the drag at the current view without
  changing the image or its undo history.
- **Backspace**, **Edit > Undo**, or the **UNDO** label: undo the last completed
  stroke or Clear. Undo consumes its snapshot; it does not toggle redo.
- **Escape during a stroke**: restore the image from before that stroke and
  wait for button release. The preceding completed action's undo is preserved.
- **Action > Clear / Clear to Colour**: fill with black / foreground color.
  **Alt+C** also clears to black. Clear is undoable.
- **File > New**: start a blank black image. **File > Exit** or Escape exits.
  If there are unsaved changes, choose **Cancel** or **Discard**. Cancel is the
  default; Tab changes the choice and Enter accepts it. Escape cancels the prompt.
- **Ctrl+S / File > Save**: save the current image; an unnamed image gets a
  filename dialog. **Ctrl+Shift+S / Save As**: choose a new filename.
- **Save As `NAME.CLP`**: save the current clipboard, including its dimensions
  and rectangle/ellipse shape. The document filename, unsaved edits and undo stay intact.
- **Ctrl+O / File > Open**: choose a `.P16` image or `.CLP` clipboard. Loading a
  clip preserves the open image and view; use Ctrl+V or the clipboard tools to
  place it. Selecting a `.P16` while the image is dirty offers Cancel or Discard.
  Failed reads preserve the current image and clipboard.
- Filename dialogs list both formats, accept DOS 8.3 names in the current
  directory and add `.P16` when the extension is omitted.
  Type a name, or choose a listed file. Tab changes fields; arrows/Page Up/Down
  navigate the list; Enter accepts and Escape cancels. Save As replacement
  requires confirmation and defaults to Cancel.
- Replaced files are retained under `TRASH\YYYYMMDD\Snnnn` with their original
  names. Temporary files from failed saves stay there too.

Changes update the canvas and actual-size preview. The title and UNSAVED label
show that image pixels changed. PP16 deliberately omits image-wide special
effects: frame-to-frame continuity belongs to future animation-aware tools.

DOSBox-X's integrated DOS supplies the mouse driver; no upload/install is
needed. An actual DOS boot or the physical HX needs its own compatible driver.
The user's PicoMEM provides EMS/XMS too; these are optional future resources.
The baseline still requires only conventional memory.

From this folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build-pp16.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\check-pp16.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run-pp16.ps1
```

With **PP16_DEV opened as the VS Code workspace**, Ctrl+Shift+B builds PP16.
The `PP16: Build and run editor` task opens a visible emulator.
The existing watch-log task follows `obj/monitor.log`. PP16 checks keep separate
reports under `obj/pp16-*`, preserving previous runs. The default check uses
3,000 cycles/ms to finish quickly; the interactive profile uses 750.
Pass `-UndoOnly -Cycles 750` for focused M5 checks or `-FileOnly -Cycles 750`
for M6, or `-ClipOnly -Cycles 750` for focused M9 checks. Tests now live in separate DOS harnesses under `obj/checks`, built by
`build-checks.ps1`; focused clipboard UI, file, and ellipse harnesses keep test
code separate from the editor's 64 KB code segment. The production EXE no longer embeds `/TEST`, `/PERF`,
`/UNDOTEST` or the legacy demos; the check script selects the correct harness.

`out/PP16.EXE` is the current program; `out/M9.EXE` preserves the accepted
optimized M9 checkpoint; `out/M4.EXE` preserves the previous
drawing checkpoint; `out/M1.EXE` preserves the passing M1
checkpoint and `out/HXTEST.EXE` preserves the original smoke test. On the HX,
copy PP16.EXE and run `PP16` with a mouse driver already loaded. No GRAFIX TSR
or ADJMEM command is required: PP16 reserves the needed portion of the video
page through DOS, or accepts an existing 32 KiB reservation. It refuses to
overwrite an existing allocation. `out/M1.EXE` retains the keyboard-only demo.

See [design/evidence](docs/M0-DESIGN.md), [milestone results](docs/MILESTONES.md),
[credits](docs/CREDITS.md), and the [M4 drawing preview](docs/screenshots/M4-drawing.png).
Physical HX, actual DOS 3.3, and hands-on interface acceptance remain separate
from automated emulator results.
See [M5 behavior and checks](docs/M5-UNDO.md) for undo and discard semantics.
The [interface redraw checkpoint](docs/UI-REDRAW.md) describes popup restoration,
targeted control updates, preview-outline updates, and the video-page options.
Run `check-pp16.ps1 -PerfOnly -Cycles 750` for UI timings and exact framebuffer
comparison against full redraws.
The [canvas and pointer checkpoint](docs/UI-RESPONSE.md) covers packed canvas
redraws, coordinate updates and faster navigation. `-ResponseOnly -Cycles 750`
runs its focused checks and pointer benchmark; these checks also run in the full suite.
See [M6 behavior and validation](docs/M6-FILES.md), [M7 shapes](docs/M7-SHAPES.md),
[M8 fill and clipboard design](docs/M8-FILL-CLIPBOARD-DESIGN.md) and the
[M9 selection and clipboard](docs/M9-CLIPBOARD.md) and the [native format specification](docs/P16-FORMAT.md). Legacy `.PUT` import and
variable-size editing remain separate milestones.

## Original HXTEST baseline

Target: Tandy 1000HX with NEC V20, 640 KB conventional RAM, PicoMEM disks,
and DOS 3.3. The build uses FPC 3.2.2's i8086 cross-compiler, 8086 runtime
libraries, and the small memory model. The output is a 16-bit DOS MZ EXE.

## In VS Code

Open this `PP16_DEV` folder as the workspace. Its settings configure the
installed FreePascal Toolkit extension to use the local cross-compiler.

- **Terminal > Run Task > Tandy: Build 16-bit DOS (FPC Toolkit)**: build HXTEST.
- **Terminal > Run Task > Tandy: Build and run in DOSBox-X**: build and open
  the DOSBox-X executable bundled with the installed VSCode DOSBox extension.
- **Terminal > Run Task > Tandy: Watch assistant build and test log**: follow
  the output produced by the assistant's build/check scripts.

The run task leaves DOSBox-X open. Type `HXTEST` to repeat the test after a
rebuild, or `exit` to close it. The EXE and its test files are in `out`.
Generated test reports are hidden in Explorer; `out\HXTEST.EXE` remains visible.
Build and test logs are written to `obj\monitor.log`, also hidden in Explorer.
Use the watch task above to follow the log without adding files to the project root.

For cleanup, move unnecessary files into dated subfolders of `trash` instead of
deleting them. The automated check preserves previous `DEFAULT.TXT` and
`RESULT.TXT` there before writing fresh results. Emptying `trash` requires an
explicit request.

The assistant can edit these files and invoke the compiler/emulator directly.
The VS Code task definitions are prepared; their execution through the editor
UI has not been independently verified.

## Command line

From this directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\run.ps1
```

For an automated run that records `out\RESULT.TXT` and checks its success marker:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\check.ps1
```

The PowerShell execution-policy option applies only to that process.

## Verified result

`HXTEST.EXE` reports a two-byte Integer, calculates 8! = 40320 using a DWord,
and writes and reads `HXTEST.TXT`. The automated 8086-profile run completed with
`ALL TESTS PASSED`. The test uses integer arithmetic and requires no 8087.

The extension's DOSBox-X 0.83.18 reports DOS 5.00 by default. This profile runs
`VER SET 3 30` before the test, so the program reports DOS 3.30. This changes
the reported version; it does not boot Microsoft's DOS 3.3 kernel. Actual DOS
3.3 compatibility still needs verification on your Tandy, or with a DOS 3.3
boot image you supply.

The emulator uses Tandy video, an 8086 CPU, 640 KB RAM, no FPU, and no EMS/XMS/UMB.
PP16 uses the user-selected fixed 750-cycle setting in `config/pp16.conf`.
This is a preferred interactive speed, not a measured V20 clock equivalent.
This DOSBox-X version labels its 8086 CPU emulation experimental. PicoMEM's
hardware and your exact Tandy BIOS are not emulated by this test.

## Observed FPC runtime limitation

With this prebuilt FPC 3.2.2 8086-small runtime and overflow checking enabled,
the signed LongInt factorial test raised runtime error 215 at 5040 * 8, despite
the result fitting in LongInt. Explicitly converting both operands to LongInt
did not resolve it; the same executable also failed with DOSBox-X's 386 CPU.
The assembly calls `fpc_mul_longint_checkoverflow` for the operation.

The smoke test now uses unsigned DWord for the nonnegative factorial. Range and
overflow checks remain enabled. This avoids the observed signed multiplication
problem; it does not establish that the signed runtime helper is fixed. Test
signed checked arithmetic separately before relying on it in an application.

## On the Tandy

Copy `out\HXTEST.EXE` to a writable DOS directory and run `HXTEST`. It creates
or replaces `HXTEST.TXT` in its current directory. Keep DOS filenames within 8.3.

## Tools

The cross-compiler and 8086-small libraries were extracted locally from the
[official FPC Windows-to-i8086 package](https://www.freepascal.org/down/i8086/msdos-hungary.html)
using [innoextract](https://constexpr.org/innoextract/). The installer was not run.
Your Windows FPC installation remains the original host installation. The working
cross-compiler is under `tools\fpc-i8086` and is excluded from Git. Downloaded
installers and the temporary extraction utility were removed after setup.

[DOSBox VER documentation](https://www.dosbox.com/wiki/VER) describes the reported
version command. FPC Toolkit's installed documentation describes the `fpc` task
type and `fpctoolkit.env.PP` setting used here.



M3 layout and behavior are documented in [M3-INTERFACE.md](docs/M3-INTERFACE.md).
`out/M2.EXE` preserves the accepted mouse checkpoint; `PP16 /M2` also runs it.

The M3 Utilities dropdown described in the historical layout material has been
removed from the current editor. Its toolbar position is now Clipboard; the
retained M3 screenshot is archival only.

[M4 behavior and tests](docs/M4-DRAWING.md). `out/M3.EXE` preserves the passing layout build.

# Medium-model setup and compatibility baseline - 2026-10-23

Version 1.1 now defaults to Medium for gradient/dither development; its current
behavior and measurements are in [GRADIENT-DITHER.md](GRADIENT-DITHER.md).
The measurements below record the successful pre-gradient compatibility
trial. The frozen 1.0 distribution is still Small and has not been rebuilt.

The pre-gradient editor compiled and passed its full DOSBox-X regression with
FPC's `-WmMedium` memory model on branch `v1.1`, using a separate build target
while Small remained the default at that checkpoint.

## What changed

`pp16-medium.cfg` keeps the existing DOS/8086 and `-O1 -Os` settings, selects
Medium, and uses separate runtime units, object files and output directories.
The build, check and interactive launch scripts accept `-MemoryModel Medium`;
omitting that argument now selects Medium. The medium executable and toolbar
atlas live in `out/medium/`.

The program and test-launcher exit hooks now use FPC's model-dependent
`CodePointer` instead of `NearCsPointer`. Their saved `ExitProc` pointers must
retain the code segment in Medium. Startup text identifies the selected model.
No drawing, file-format, gradient or video-assembler changes were needed.

Medium allows code to span multiple segments, removing the single 64 KiB
total-code ceiling. Individual code segments remain limited to 64 KiB. Data
is still near data with a 64 KiB group, including the stack and near heap;
this does not create additional data space. The editor still requires only
conventional memory, with no EMS, XMS or overlay manager.

## Runtime setup

The bundled compiler is FPC 3.2.2. Its installed Pascal units initially covered
only Small, although it includes the Medium startup object `prt0m.o`. Build
matching Medium `System`, `Strings` and `Dos` units before building the editor.
The helper checks compiler/source version numbers and keeps compiler output
in `obj/medium-rtl-build.log`. Other RTL units are not built by this recipe.

On this machine, the matching sources were extracted from the existing local
`E:\Projects\FPC` repository's `release_3_2_2` tag, commit
`0d122c49534b480be9284c21bd60b53d99904346`, without changing that checkout.
The current FPC development sources are a different version and must not be
substituted for these release sources.

To stage that same source tree from a local FPC Git checkout, run from PP16_DEV:

```powershell
New-Item -ItemType Directory -Force -Path obj,tools/fpc-src-3.2.2 | Out-Null
git -C E:/Projects/FPC archive --format=tar --output=E:/Projects/PP16_DEV/obj/fpc-3.2.2-rtl.tar release_3_2_2 rtl compiler/version.pas
tar -xf obj/fpc-3.2.2-rtl.tar -C tools/fpc-src-3.2.2
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\config\build-medium-rtl.ps1
```

Adjust the checkout/archive paths for another machine. Alternatively stage
the matching release's `rtl` directory and `compiler/version.pas` in
`tools/fpc-src-3.2.2`. Pass `-SourceRoot` to the helper for a different source
location. Sources and generated runtime units stay under ignored `tools/`;
they are build prerequisites, not additions to the end-user installation.
The stock runtime emits warnings in existing upstream stubs; compilation
completed successfully and their full output is retained in the log.

## Build, check and run

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build-pp16.ps1 -MemoryModel Medium
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\check-pp16.ps1 -MemoryModel Medium -Cycles 3000
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run-pp16.ps1 -MemoryModel Medium
```

The last command opens the editor for interactive review. Automated checks
use hidden DOSBox-X instances and disposable drives under `obj/pp16-medium-*`.
The independent `MEMINFO` DOS-arena diagnostic continues to use its original
Small build; the editor, production launch driver and editor harnesses use
Medium. `hx8086.cfg` is unchanged.

## Measured results

| Measurement | Small / release 1.0 | Medium trial |
| --- | ---: | ---: |
| Linked code bytes | 64,532 | 67,804 |
| Initialized data bytes | 4,384 | 4,456 |
| Data group including 8 KiB stack | 57,728 | 57,872 |
| Startup near heap (`MemAvail`) | 7,810 | 7,662 |
| EXE bytes on disk | 69,026 | 78,378 |

Code grew by 3,272 bytes (about 5.1%). The linker map shows code spread across
segments rather than one 64 KiB segment. The largest logical unit's code is
`TUI_TEXT`, 22,321 bytes. Available conventional RAM and individual segment
sizes remain relevant; Medium's addressing range is not a usable RAM budget.

Medium executable SHA-256:
`6f17f9fca2697dfbc06fccdf2fe1d77bb6c8d310c80326a0f8d1a806baf2ee73`.

Validation completed:

- Medium runtime and production editor built successfully.
- Focused clipboard UI, 39,244 ellipse assertions, clipboard file checks and
  exact DOS memory restoration passed in
  `obj/pp16-medium-20261023-023323-85e779`.
- Full regression passed at 3,000 cycles/ms in
  `obj/pp16-medium-20261023-023447-68d547`: video/mouse, canvas/view, drawing,
  Clear/Clear to Colour, undo/cancel, clipboard, file UI, native/clipboard
  files and recovery, missing mouse, unsupported video, production Save/Open,
  and exact DOS arena restoration.
- All nine full-regression framebuffer dumps equal the accepted Small run
  `obj/pp16-20261022-231640-28f570` byte for byte.
- Rebuilding the default Small editor after the pointer change produced a
  byte-identical copy of the frozen 1.0 executable. The distribution ZIP's
  SHA-256 remains
  `33092bc0e7592b4cd6a32a78b2b912cbcc7ca226f1ce2472db59db6bd302ee99`.

The UI performance run passed at 750 cycles/ms in
`obj/pp16-medium-20261023-023754-2e1a03`. All ten incremental frames equal
their full redraws and the fresh Small comparison run
`obj/pp16-20261023-022522-db327a` byte for byte. The existing comparison tool
reported these BIOS tick counts (about 55 ms per tick):

| UI case | Small | Medium |
| --- | ---: | ---: |
| File open/close twice | 7 | 7 |
| Switch six menus | 13 | 14 |
| Menu choice (legacy utility-labelled fixture) | 1 | 1 |
| Help open/close | 9 | 10 |
| Cancel dirty Exit | 17 | 18 |
| Change/swap colours | 2 | 2 |
| Select four tools | 5 | 4 |
| Zoom/pan | 17 | 17 |
| Open File | 3 | 4 |
| Open dirty Exit | 6 | 6 |

Every case differs by at most one tick. These coarse measurements support
similar UI performance in this emulator configuration; they do not establish
an exact slowdown percentage or hardware timing. The comparison includes
the separately built Medium runtime as well as changed code addressing.

These are pre-gradient DOSBox-X results, not physical Tandy 1000HX measurements.
Interactive acceptance and a physical HX run remain outstanding before a
Medium release. See the current gradient record linked above for later work.

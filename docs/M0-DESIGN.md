# PP16 reference audit and design â€” 2026-09-19

PP16 is a new 8086 real-mode DOS application, not a port of missing editor
source. M1 was the initial authorized checkpoint; the user subsequently
requested M2 mouse interaction before GUI design. No M3 GUI or drawing tools
are implemented in this pass.

## Evidence and limitations

- Read the staged brief, archive inspection, PP256 help/manual, GRAF PointC,
  GetPoint, Set 320, page routines, TSR entry, and ADJMEM source.
- PP256's editor/filter source is absent. Help documents the menu/status bars,
  tool/palette panel, zoom grid and image selector. F4 toggles grid, F7 opens
  animation; Backspace undo uses the original STORE snapshot workflow.
  These are **documentation findings**, not interactive observations.
- Launched PP.EXE in installed DOSBox-X 0.83.18 using `config/refvga.conf`
  (SVGA, 386, 10,000 cycles/ms), on a copy at `obj/refpp`.
- Native capture failed with `SetIsBorderRequired ... 0x 80004002`.
  Accessibility sees only the DOSBox shell. Mouse-menu automation failed
  with `coordinate input geometry is unavailable`; the screenshot shortcut
  was rejected due to intervening user input. No captured reference screen,
  measured editor resolution, sprite loading, drawing/undo, F7 or SD
  observation is claimed. Those observations remain pending.
- Original sources and assets remain intact. See CREDITS.md for notices.

## Backend and memory decisions

- Application-owned Pascal renderer; no GRAFIX TSR, timer hook or old TP OBJ.
  Selected GRAF addressing/nibble/page algorithms translated into TVIDEO.PAS.
  Keep this readable Pascal implementation as the reference for future ASM
  optimizations. No unmeasured ASM optimization or ABI claim in M1.
- Mode 09h, 320x200, 16 hardware color indices; BIOS default identity palette.
  B800 window, `(y AND 3)*8192 + (y DIV 4)*160 + (x DIV 2)`;
  even pixel high nibble. Inclusive clipped rectangles; reversed ranges empty.
- Port 3DF=F6 selects banks 6/7 for CPU and display, the highest 32 KiB of
  the 640 KiB HX memory layout (98000..9FFFF). Only this hardware/memory
  configuration is accepted initially. No page flipping.
- A targeted ADJMEM probe **confirmed** default BDA available=624 KiB and
  installed=640 KiB. `ADJMEM -16` changed available to 608 and DOS arena end
  from 9C 00 to 9800 paragraphs. `+16` restored both. Raw evidence is recorded
  separately. ADJMEM is therefore a valid existing reservation mechanism;
  it is not missing functionality.
- PP16 instead checks the MCB chain and takes an ordinary DOS last-fit
  allocation covering the unprotected part of that page (normally 16 KiB).
  It restores the previous allocation strategy immediately, validates the
  returned address/owner/extent, and keeps the allocation until text mode is
  restored. DOS frees it at exit; the cleanup hook also explicitly releases it.
  BIOS memory size is never patched. A live conflicting allocation causes
  refusal. An existing DOS/BDA reservation of at least 32 KiB is accepted
  without claiming ownership or releasing it.
- The guard precedes mode setting or framebuffer writes. No allocation
  protection is inferred merely from entering graphics or using B800.
- Full physical HX and actual DOS 3.3 validation remain pending. `VER SET`
  changes DOSBox's reported version only. Fixed emulator cycles are not V20
  timing measurements. FPU/EMS/XMS/UMB remain disabled in baseline tests.

## Future editor layout and storage

- Keep document pixels separate from video/cursor pixels. Start with 64x64,
  packed 4bpp, 2048 bytes, row stride `(width+1) DIV 2`. Odd-width unused low
  nibble must be zero. Use checked DWord sizes; avoid the recorded signed
  multiplication runtime bug.
- Planned boundaries: TVIDEO/VMEM, TMOUSE/TCURSOR, then document, view,
  tool transactions, UI, file I/O. Avoid building a general widget framework.
- Fit a compact 16-color selector, zoom canvas, actual-size preview, controls
  and status into 320x200. Help-inspired workflow; exact panel layout awaits
  mouse checkpoint review. Mouse drags belong to the control where they began;
  palette/dialog clicks must not leak into canvas strokes. Mouse input is
  tested independently before committing to the GUI geometry.
- Document coordinates remain square integer pixels. GRAF's aspect ratio 6:5
  describes 320x200 on a 4:3 display; any corrected preview is a separate view.
- One per-action undo snapshot, no original STORE dependency. Full 320x200
  image+undo =64,000 bytes, which cannot coexist with runtime/stack/UI inside
  this near-data segment. Verify segmented storage or bounded undo before M9.
- User clarified that PicoMEM on the actual HX provides both EMS and XMS.
  They are **available optional capabilities**, not absent hardware. Retain
  conventional-memory operation; later evaluate actual driver versions, APIs
  and capacity for undo, clipboard and image collections. Do not silently
  introduce an EMS/XMS requirement or assume those drivers are loaded.
- Future `.P16` files: versioned explicit little-endian fields, packed pixels,
  checked lengths, failure-safe load and temporary-save replacement. Format
  specification and implementation belong to M6, not this renderer/input pass.

## Reused build/run commands

From `E:\Projects\PP16_DEV`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build-pp16.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\check-pp16.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run-pp16.ps1
```

Original HXTEST scripts/configuration and executable are retained. The M1
passing executable is also retained as `out/M1.EXE`. Build/test output goes
to `obj/monitor.log`; each PP16 check has a separate `obj/pp16-*` DOS drive.
No installation work or general toolchain smoke-test rerun was needed.



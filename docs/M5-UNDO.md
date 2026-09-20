# M5 - undo, cancellation, Clear and New/Exit protection

One completed brush/eraser stroke is one action, including any canvas
exit/re-entry segments. Backspace, Edit > Undo or the UNDO label restores its
previous pixels and dirty flag. Undo consumes its snapshot; there is no redo.
The label/menu is disabled when no snapshot is available or a stroke is active.

Escape during a stroke cancels it, restores the pre-stroke document and dirty
flag, and blocks painting until all buttons are released. The previous completed
action's undo survives. Sampling, palette/view changes and strokes that write
only the existing color do not replace undo. Sampling cancellation ends color
selection; it does not undo a foreground-color choice.

Action > Clear (Alt+C) fills with black. Clear to Colour fills with the foreground
color. Each is one undoable action; an already-uniform fill preserves undo.
File > New creates a blank black 64x64 document and resets view and undo.
Foreground/background and tool selection are retained. A new untouched blank
document is clean; drawing makes it dirty. Startup still shows the demo fixture.

New and Exit prompt on a dirty document. Cancel is selected initially. Tab or
Left/Right changes the choice; Enter accepts it; Escape cancels. Clicking the
named buttons works too. Outside clicks, right clicks and covered menu/palette
clicks do nothing. A click that dismisses the prompt cannot start a stroke.
Cancel retains pixels and undo; Discard is explicit permission to lose them.
Saving is M6, so the prompt states that saving is not yet available.

## Storage and repainting

Two packed 2048-byte snapshots are added: previous completed action and pending
stroke. Pending capture occurs on the first actual pixel change. This preserves
the old undo across canceled/no-change strokes without allocation during input.
Both live in conventional near data; no EMS/XMS or screen backbuffer is used.
Commit copies pending to undo, cancellation restores pending, undo restores the
completed snapshot. Restoration marks all document rows for repaint; normal
drawing retains the existing changed-row rendering. Full UI draws consume those
rows, preventing a subsequent repaint from drawing over a modal dialog.

Build: 64,648-byte EXE, 53,363 code bytes, 11,174 initialized data bytes,
8,192-byte stack, and 37,006 bytes of initial near heap on `/UNDOTEST`.

## Verification

`PP16 /UNDOTEST` exercises the same pointer, keyboard and menu dispatch as the
interactive editor. It checks whole-stroke restoration of every pixel, dirty
state, consumed undo, two successive actions, erasing, no-change strokes,
sampling/view preservation, cancellation and retained prior undo, canvas and
preview restoration, held-button blocking, both Clear commands, keyboard Clear,
clean/dirty New and Exit, default Cancel, explicit Discard, modal isolation and
click consumption. It leaves a dirty Exit prompt in `M5FRAME.BIN` for inspection.

The existing M1-M4, missing-mouse, unsupported-video and exact DOS-memory-chain
restoration checks remain part of `check-pp16.ps1`. Real HX/DOS 3.3 results remain
separate from emulator checks. M4.EXE is retained; the next milestone is M6 save/open.

`check-pp16.ps1 -UndoOnly -Cycles 750` runs M5 and the memory-chain comparison
at the interactive speed without repeating the exhaustive view-coordinate sweep.
The runner allows more time at lower cycle settings. An initial full 750-cycle
attempt hit the old 180-second limit during M3, before M5 ran; that attempt is
retained as an incomplete run, not a pass.

The full M1-M5 suite passed at 3,000 cycles/ms in
`obj/pp16-20260919-220410-d721dc`, including exact DOS memory-chain restoration.
The M4 drawing fixture repainted 46 cells in 2 BIOS ticks in this build;
this coarse emulator timing is not a physical-HX speed measurement.
Pixel assertions passed for both the [drawing frame](screenshots/M5-drawing.png)
and [confirmation dialog](screenshots/M5-confirm.png). These PNGs render DOS
video-memory dumps, not captured emulator windows. The dialog was visually
inspected for legibility, complete borders and Cancel's default focus.

Focused M5 checks also passed at 750 cycles/ms in
`obj/pp16-20260919-221131-ab1418`, including exact memory-chain restoration.
See [M5 test reports](M5-TESTS.txt). Interactive M5 acceptance on the user's
mouse and physical HX/DOS 3.3 validation remain pending.

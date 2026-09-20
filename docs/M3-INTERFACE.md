# M3: PIXELplus-style layout

The user supplied the main window, all six expanded menus and the Open Image
File dialog. These are visual references supplied by the user, not screens
captured through automation. Native window capture remains unavailable.

The 320x200 implementation preserves the three-column layout, blue menu and
status bars, green title, beveled tools, grid/zoom controls, separate preview,
image-number strip and information panel. The palette becomes a usable 4x4
matrix of the 16 Tandy colors. BIOS 8x8 text serves the menus; an original
3x5 font fits the small labels. No reference artwork is embedded.

All menu groups follow the screenshots, including separators and shortcut
hints. Unimplemented entries are gray and cannot change the image. File Exit,
View Grid and Help work; shortcuts on gray entries describe planned reference
behavior and are not active. Keys 1/2/4/8 zoom; arrows pan; F4 toggles the
grid; F1 opens help. Escape closes a menu before exiting the application.
A menu dismissal consumes its click. Controls act on a new press, so holding
a button while moving onto a palette/tool does not select it.

Canvas content is x=85..212, y=29..156; the border is excluded from hit tests.
Coordinates undergo one integer zoom division plus the clamped pan origin.
Zoom preserves the center where possible. At 1x, the area outside the 64x64
document is gray and is not a document hit. The 1:1 preview outlines the
viewed region without touching document memory.

The original 64x64 sunset fixture occupies 2048 packed bytes. Its storage API
exposes readback only at this checkpoint. Foreground/background and tool
selection affect UI state only. View changes redraw the canvas; pointer
motion updates only the cursor and changed coordinate text.

PP256's .PUT files store BASIC BLOAD image records, possibly multiple images.
Its Save As default does not determine PP16's native format: retain .P16 for
PP16 saves and reserve .PUT for explicit future import/export. The supplied
file-dialog screenshot establishes blue inset panels, highlighted selection,
scroll arrows, and OK/Cancel buttons. The file browser belongs to M6.

Validation includes M1/M2 regression checks and every 128x128 viewport
position at 1x/2x/4x/8x and both pan extremes; border/outside-document
rejection; palette/tool/zoom/menu-dismissal dispatch; and unchanged document
checksum. Preview PNGs are rendered from DOS video memory, not host screenshots.
Automated runs use 3,000 cycles/ms; interactive launch retains 300.

The user accepted M2's appearance and behavior before M3 began. M3 hands-on
review and physical HX/actual DOS3.3 checks remain pending. Next is M4 pencil,
erase and eyedropper. Undo and save/open remain M5 and M6. HXTEST and M1/M2
executables remain available. PicoMEM EMS/XMS is optional future capacity;
the baseline requires only conventional memory.

Final build: 48,546-byte EXE; measured near heap 46,582 bytes on /UITEST.
All automated checks passed; see M3-TESTS.txt.

## Corrected toolbar and Utilities selector

User correction: left-to-right, top-to-bottom the tools are Cut, Utilities,
Bucket Fill, Brush, Eraser, Circle, Square, Line. The icons and labels now
follow that order. Utilities corresponds to the Special Effects Brush in
PP256.HLP (H067). Selecting it shows the current effect in the selector
below the tool icons. Clicking that name opens the blue dropdown.

The fourteen entries, in reference order, are BRIGHT, DARK, TINT, FUR, MIX,
SOFT, UNZAG, HOLLOW, TILE, XOR, GREY, SWEEP, SWAP, EDGE. Default is SOFT.
Click an entry, or drag from the selector and release on an entry. Releasing
on the original header leaves a click-open menu. Clicking the current header
or outside cancels; dragging outside and releasing cancels. Dismissal consumes
the click and cannot select a covered palette color. Hovering an entry shows
its help-based description in the footer. Action > Effect follows the chosen
name, but remains disabled: choosing an effect is UI state, not applying it.

The source says BRIGHT/DARK/TINT/FUR/MIX have independent strengths of 1..100,
configured with a right-click on the selector. That dialog and all effect
algorithms are deferred. Brightness/gray/antialias effects require deliberate
16-color mappings, not arithmetic on palette indices. XOR operates on color
indices; TILE needs a clipboard; SWAP replaces current with secondary color.
No image data or strength settings are changed by this checkpoint.

Tests cover click-open/release, click selection, drag selection, outside-drag
cancellation, header cancellation, dismissal over the palette, all hover rows,
and the unchanged document checksum. See M3-TESTS.txt and the rendered
[Utilities dropdown](screenshots/M3-utilities.png).

The toolbar now uses original 14x14 pixel glyphs: scissors, crossed wrench and
screwdriver, pouring bucket, paintbrush with ferrule and broad bristles,
slanted pink eraser, outlined circle, outlined square, and diagonal line.
The selected-tool name and yellow selection border remain visible. Current
build: 51,954-byte EXE, 43,067 code bytes and 8,784 initialized data bytes.
The Utilities selector and icon changes passed the M1/M2/M3 automated checks.

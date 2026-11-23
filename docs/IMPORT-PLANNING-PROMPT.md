# PP16 planning prompt: PCX and PP256 import

Work in `E:\Projects\PP16_DEV`. Prepare an evidence-based research and
implementation plan for importing prepared indexed images into PP16 and
converting them to its fixed Tandy 16-color palette. Conversion quality is the
user's main concern: preserve color, shading, outlines, and small details.

**Authorization and working agreement**

This is a planning request, not authorization to implement the importer.

- At the start of a new session, give a visible recommendation in this form:
  `Suggested setting: <model or class> / <reasoning effort> - <reason>.`
  Wait for the user to say `proceed` before taking further action. Do not
  repeat a recommendation/approval gate already satisfied for this task.
- Once authorized to plan, use targeted read-only inspection and primary-source
  research. Do not edit files, run project code, build, test, generate comparison
  images, install dependencies, or launch applications during this phase.
- Return the plan in chat. Identify the next bounded action, give its model
  recommendation, and wait for explicit authorization before executing it.
  Approval of a design alone does not authorize implementation.
- Preserve existing user work. Do not commit, push, publish, repackage the
  release, or change DOSBox settings. Do not delegate to other agents without
  an explicit request.

**Agreed feature scope**

- Run the importer inside PP16 on the Tandy. A separate DOS importer callable
  from PP16 is a fallback only if a measured resource problem justifies it.
- Add `Import...` under the File menu.
- Initial formats: indexed PCX and PIXELplus 256 `.PUT` image files. Start the
  PCX proposal with the standard 8-bit, single-plane indexed variant, including
  images using fewer than 256 colors. State this supported profile explicitly;
  identify the cost of supporting older 1/4-bit PCX variants separately.
- Use the PCX palette and the PP256 associated `.APF` or a supplied `.PAL`.
  Do not silently substitute an arbitrary palette when one is missing.
- The user prepares image dimensions and reduces arbitrary source formats to
  256 colors or fewer externally. Do not add resizing or cropping controls.
  Plan clear rejection of oversized selected images. Propose a simple placement
  and padding policy for images smaller than the fixed 64x64 document.
- PP256 `.PUT` may contain multiple images. Propose a minimal way to choose
  one image without adding animation or a multi-document editor.
- Convert to literal Tandy palette indexes, retaining native `.P16`/`.CLP`
  compatibility. Import should be one undoable action. Cancellation or failure
  must preserve the document, dirty state, filename, previous undo, clipboard,
  and active paint settings. Explain successful import and subsequent Save
  behavior, including how the source file is protected from overwriting.
- BMP, PNG, JPEG, true-color PCX, a universal converter, and changes to the
  existing gradient controls are outside the initial scope.

**Inspect the current project before proposing changes**

Read applicable `AGENTS.md` files, `README.md`, relevant current entries in
`docs/MILESTONES.md`, `docs/PP16 CODING AGENT RULES.md`,
`docs/MEDIUM-MODEL.md`, and `docs/GRADIENT-DITHER.md`.

Inspect only the necessary parts of `src/TFILES.PAS`, `src/TDOC.PAS`,
`src/TPAINT.PAS`, `src/TUI.PAS`, `src/TCLIP.PAS`, video/palette references,
and the existing build/check scripts and focused test conventions. Inspect Git
status and preserve unrelated changes. The frozen 1.0 distribution in
`dist/PP16V10/` and `dist/PP16V10.ZIP` must remain untouched.

The current development line uses FPC 3.2.2, DOS real mode, 8086-compatible
instructions, and the Medium memory model. Medium allows multiple code
segments but keeps a shared 64 KiB near-data group, including stack and heap.
Do not assume a floating-point coprocessor, EMS, XMS, or a different memory
model. Original Tandy 1000HX compatibility remains the target.

The documented gradient-build checkpoint records 70,882 linked code bytes,
58,896 bytes in the data group including an 8 KiB stack, and 6,650 startup
near-heap bytes. These are recorded measurements, not a fresh live baseline;
check their relevance against current artifacts and identify any measurements
that must wait for an authorized build. Do not run a build just to plan.

`TDOC.DocReplace` currently resets undo and dirty state. Do not assume the
native Open path provides the required import transaction. `TFILES` already
has a packed staging buffer; investigate safe reuse before proposing another
permanent full-image allocation. Identify stack use as well as globals/heap.

**Research and compare conversion methods**

Use the actual PP16 palette, including its brown entry. The output palette is
fixed; this is not a task to generate an optimized arbitrary 16-color palette.
Previously discussed simulated-shade counts describe idealized spatial RGB
averages, not independently addressable colors or guaranteed visual matches.

Compare at least these candidates in the proposed quality study:

1. Nearest solid palette color as a baseline.
2. Palette-aware ordered dithering, starting with Joel Yliluoma's
   arbitrary-palette positional dithering work.
3. An established error-diffusion method, such as serpentine Floyd-Steinberg.

Research gamma-aware mixing and perceptual color error. Explain target-display
assumptions and the cost of each approach on an 8086 without a coprocessor.
Consider penalties for harsh endpoint contrast and unnecessary pattern noise.
Do not choose a pair merely because its two endpoints are individually nearest
to the source color, and do not select a winner solely by raw RGB error.

The painting tool's 10% increments are a UI choice, not an importer requirement.
Assess finer internal proportions and alternative patterns. The existing 10x10
rank tile is a candidate to evaluate, not a quality requirement. Consider its
partial-tile behavior and the loss of fine detail at 64x64.

Distinguish computations that can be cached once for each source palette entry
from those that depend on neighboring pixels. A pair/ratio plan can be cached;
error-diffusion decisions depend on accumulated error and cannot generally be
replaced by one fixed output recipe per source index.

Recommend adaptation of proven methods before inventing a hybrid. Any custom
method should address a demonstrated shortcoming. Review licensing before
proposing reuse of implementation code. Mark untested quality and performance
claims as hypotheses.

Primary starting points:

- [ZSoft technical reference](https://techheap.packetizer.com/compression/graphics/pcxfmt.html),
  preserved in a mirror.
- [Joel Yliluoma's dithering research](https://bisqwit.iki.fi/story/howto/dither/jy/).
- Local PP256 references: `references/pp256/PP256.DOC` and
  `references/pp256/USERSUBS.BAS`, especially `InitImageData`,
  `MakeImageIndex`, `InitPaletteData`, and `ChangePalette`.

**Plan decoding and resource use**

Use separate format readers feeding one conversion core. Prefer bounded
scanline processing and packed 4-bit output over a full indexed source image
in near memory. A host-side research prototype may be proposed for comparison,
but the shipping importer must work inside PP16 without a host converter.

For PCX, account for header validation, padded `BytesPerLine`, RLE limits,
truncated data, and the trailing 256-entry RGB palette. Enforce file/row bounds
before accepting a decoded image. Treat palette RGB values as 0..255.

For PP256, verify the 7-byte BLOAD wrapper, image descriptors, width stored in
bits, height, record alignment, and multiple records against the local source
and samples. Its `.APF`/`.PAL` reference uses 256 four-byte entries containing
VGA DAC channel values; do not interpret it as a PCX 768-byte palette.
Verify packing and normalize the 0..63 channels consistently. Include palette
lookup in the PP256 directory layout and DOS 8.3 filename/path constraints.

Estimate persistent data, temporary buffers, worst simultaneous memory use,
stack depth, largest code segment, and worst-case conversion work for each
candidate. Address fixed-point rounding, accumulator ranges, overflow, and
clamping. Keep conversion independent of the active gradient globals; importing
must not rebuild/change the user's selected paint per pixel.

Decode and convert fully before committing the image. Propose the smallest
coherent document API change needed for one undoable import. Preserve packed
rendering and the working Clear/Clear to Colour paths. If a separate importer
becomes necessary, account for the resident editor sharing conventional RAM
with its child process; do not assume a second executable creates more RAM.

**Define proportionate validation for a later authorized phase**

- Compare representative prepared sprites, gradients, grayscale ramps,
  saturated colors, skin tones, and photographic examples. Include outlines,
  single-pixel features, flat fills, and artwork using exact Tandy colors.
- Present outputs at actual size and integer magnification. Assess brightness,
  hue, banding, texture, and edge/detail preservation alongside appropriate
  numeric metrics. Use unfiltered pixels for reproducible comparisons; treat
  CRT/shader appearance as additional display evidence.
- Require unchanged output for an image already using the exact target colors,
  valid palette indexes, deterministic conversion, and palette-order invariance
  when RGB values and pixels are otherwise unchanged.
- Include malformed/truncated PCX, RLE boundary cases, padded rows, bad PUT
  descriptors/lengths, odd-sized records, missing palettes, multi-image PUT,
  unsupported dimensions, cancellation, I/O failure, and undo/state preservation.
- Verify identical decoded content and palettes give identical conversion
  across both formats. Test File-menu dispatch and update affected menu-row
  fixtures. Exercise native Save/Open and literal clipboard behavior.
- After implementation authorization, follow project validation requirements:
  meaningful focused checks first, a Medium production build, then
  `check-pp16.ps1 -Cycles 3000` and `git diff --check` before completion.
  Plan memory-restoration checks and measured import timings. Distinguish
  DOSBox-X results, user visual acceptance, and physical-HX verification.
  Do not execute these checks during planning.

**Required planning response**

Return a concise current-code assessment, sourced algorithm comparison,
resource budget with assumptions, recommended initial method and alternatives,
minimal File > Import flow, proposed module/API changes, and staged acceptance
criteria. Separate user decisions from choices that can be resolved by research.

Put the conversion-quality comparison before full format/UI integration in the
proposed sequence. Name a specific next bounded study or prototype, state its
expected outputs and model recommendation, and stop for user authorization.
Do not claim that this prompt, a completed plan, or the user's agreement with an
idea authorizes running that study or implementing the importer.

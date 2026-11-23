# PP16 CODING AGENT RULES

TARGET

- Tandy 1000 HX / NEC V20
- 8086-compatible instructions only
- DOS real mode
- FPC 3.2.2 i8086 cross compiler
- Medium memory model for v1.1 gradient development; release 1.0 is Small.
  Runtime setup and the compatibility baseline are in docs/MEDIUM-MODEL.md.
- 320x200 Tandy 16-color Mode 09h
- Physical HX compatibility is the final authority

PROJECT STATE

- Read README.md first.
- Read docs/MILESTONES.md before beginning substantial work.
- Current completed milestone: M8.
- Do not redesign completed milestones unless explicitly instructed.

IMPLEMENTATION

- Work one milestone/subtask at a time.
- Preserve existing behavior unless the milestone explicitly changes it.
- Prefer simple 8086-friendly implementations.
- Do not introduce 286/386 instructions.
- Do not introduce EMS/XMS requirements without explicit approval.
- Do not create a general-purpose widget framework.
- Respect DOS 8.3 filenames.

VALIDATION

- Build after meaningful changes.
- Run the appropriate focused test first.
- Run regression tests before declaring a milestone complete.
- Emulator success does not equal physical-HX verification.
- Do not claim untested behavior as verified.

DOCUMENTATION

- Record architectural decisions in the appropriate docs file.
- Update docs/MILESTONES.md when a milestone changes status.
- Preserve old checkpoints where the existing project convention requires it.

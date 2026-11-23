# PP16 ready-to-run distributions

## PP16 1.0 - 23 October 2026

- **Download/package:** [PP16V10.ZIP](PP16V10.ZIP), 60,315 bytes.
- **Unpacked installer folder:** [PP16V10/](PP16V10/).
- **Start here:** [README.TXT](PP16V10/README.TXT).
- **Quick controls:** [HELP.TXT](PP16V10/HELP.TXT).
- **Complete manual:** [PP16.DOC](PP16V10/PP16.DOC).
- **Per-file SHA-256 checksums:** [MANIFEST.TXT](PP16V10/MANIFEST.TXT).

Extract the ZIP into a single directory, change into that directory at a DOS
prompt, and run `INSTALL`. The default destination is `C:\PP16`.
`INSTALL D:\PP16` selects another full DOS 8.3 path; its drive and parent
directory must already exist. The installer uses standard DOS batch commands
and refuses to replace any existing package file. It neither deletes artwork
nor changes the system startup files or PATH.

The package has ten flat, DOS 8.3-named files: the installer; the editor and
required toolbar atlas; the user manual, readme and quick help; author/reference
credits; the Free Pascal runtime exception and accompanying license; and the
checksum manifest. There are no compiler tools, source files, test programs,
emulator binaries, sample artwork or previous checkpoints in the package.
The two runtime files are `PP16.EXE` and `PP16UI.P16`; preserve the supplied
documentation and notices when redistributing the complete package.

The ZIP's SHA-256 is:

```text
33092bc0e7592b4cd6a32a78b2b912cbcc7ca226f1ce2472db59db6bd302ee99
```

### Release provenance and validation

The application source checkpoint is
`15fc96b0ac5975aee6c5bcd3a18996184ae2fe7e` (packed Clear actions). The
69,026-byte executable is identical to the image accepted by the complete
DOSBox-X regression at 3,000 fixed cycles/ms in
`obj/pp16-20261022-231640-28f570`. The toolbar asset is identical too.
The package does not rebuild or modify that accepted executable.

Executable SHA-256:

```text
98d05b69be9d9b8f1687419a9bf65f5b7ea12e886ab6fbbc2e539b7a8c86e256
```

Installation was exercised in an isolated DOSBox-X drive, using the 8086/Tandy,
640 KiB, no-EMS/XMS baseline with long filenames disabled. Checks covered:

- Default and alternate destinations, with every installed payload byte checked.
- Refusal to overwrite an installed editor or existing documentation.
- Preservation of unrelated artwork in an existing destination directory.
- Missing payload files, invocation from the wrong working directory, and a
  non-directory destination, without replacing protected files.
- Save and Open through the actual installed production editor, producing a
  valid 2,068-byte native `.P16` image.
- ZIP membership, per-file checksums, DOS 8.3 names, ASCII/CRLF documentation,
  and verbatim copies of the supplied runtime notices.

Local inputs and results are retained under
`obj/dist-1.0-20261023-5aa6eba2/`, including `RUNTEST.BAT` and `RESULTS.TXT`.
Nested DOSBox batch output redirection was incomplete across `CALL`/`GOTO`, so
installer outcomes were verified through destination bytes and failure-state
fixtures; the installed editor's Save/Open reports were captured separately.
Actual DOS 3.3 and physical-HX validation remain separate from emulator results.

The release remains small-model 8086 code: 64,532 code bytes, 1,004 bytes of
code-segment headroom, and 7,810 reported initial near-heap bytes. Gradient
dither painting and any memory-model migration are future version 1.1 work.

The frozen payload is stored byte-for-byte in Git through `.gitattributes`,
so normal Git checkouts preserve its DOS line endings and manifest checksums.

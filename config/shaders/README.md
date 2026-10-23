# CRT-Geom for the interactive DOSBox-X profile

`crt-geom.glsl` is an unmodified copy of the shader from
[tyrells/dosbox-svn-shaders](https://github.com/tyrells/dosbox-svn-shaders/blob/bcb2ee79e81b6fd1002591ba423e0bf0dad40e8c/crt/crt-geom.glsl),
revision `bcb2ee79e81b6fd1002591ba423e0bf0dad40e8c`.

Copyright (C) 2010-2012 cgwg, Themaister and DOLLS. The shader is licensed
under GNU GPL version 2 or later; its original notice is preserved in the
source. [COPYING.txt](COPYING.txt) contains the GPL version 2 text.

SHA-256: `6789d93f20de0bab3d3d4c4c6f8d4068ed3a50b15c55da4321854f391decb194`.

`config/pp16.conf` selects this local shader with OpenGL nearest-neighbour
output (`openglnb`), aspect correction and the Normal 4x scaler. The upstream
[usage guide](https://github.com/tyrells/dosbox-svn-shaders#readme) specifies
`openglnb` for CRT-Geom. This host-side display asset is not part of the DOS
editor executable or the frozen 1.0 installation payload.

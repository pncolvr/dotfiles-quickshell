All nine fragment shader presets from [CAVA 1.0.0](https://github.com/karlstav/cava/tree/1.0.0/output/shaders)
are retained unmodified in `upstream/`, under the included upstream MIT license.

`build.py` ports their GLSL interface to Qt Quick: audio bands come from a small
GPU texture, uniform values come from QML, the coordinate system is adjusted,
and black backgrounds become transparent to preserve the media card artwork.
The original shader drawing algorithms remain in place. Matching vertex and
fragment bundles target GLSL 150/330 and GLSL ES 300, plus HLSL and Metal. Spectrogram uses the
previous rendered frame as its history texture.

Rebuild the generated sources and tracked shader bundles after editing the port:

```sh
python3 src/theme/shaders/cava/build.py
```

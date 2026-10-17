#!/usr/bin/env python3
"""Adapt CAVA 1.0.0 fragment shaders to Qt Quick's uniform/texture interface."""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parent
header = '''#version 450
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 qt_FragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 foreground;
    vec3 u_resolution;
    float shader_time;
    int bars_count;
    int bar_width;
    int bar_spacing;
    float band_blend;
};
layout(binding = 1) uniform sampler2D audioData;
layout(binding = 2) uniform sampler2D inputTexture;
#define fg_color foreground.rgb
const vec3 bg_color = vec3(0.0);
const int gradient_count = 0;
const vec3 gradient_colors[8] = vec3[8](
    vec3(0), vec3(0), vec3(0), vec3(0),
    vec3(0), vec3(0), vec3(0), vec3(0));
vec2 fragCoord;
vec4 fragColor;
float cavaBand(int index) {
    vec2 levels = texture(audioData, vec2((float(clamp(index, 0, bars_count - 1)) + 0.5) / float(bars_count), 0.5)).rg;
    return mix(levels.r, levels.g, band_blend);
}
'''
footer = '''
void main() {
    fragCoord = vec2(qt_TexCoord0.x, 1.0 - qt_TexCoord0.y);
    fragColor = vec4(0.0);
    cavaMain();
    vec3 color = clamp(fragColor.rgb, 0.0, 1.0);
    // Preserve the card artwork: black shader background becomes transparent.
    float alpha = max(color.r, max(color.g, color.b));
    qt_FragColor = vec4(color, alpha) * qt_Opacity;
}
'''
for source in sorted((root / 'upstream').glob('*.frag')):
    body = source.read_text()
    body = re.sub(r'^#version.*\n', '', body, flags=re.M)
    body = re.sub(r'^(?:in|out|uniform)\s+[^;]+;[^\n]*\n', '', body, flags=re.M)
    body = body.replace('void main()', 'void cavaMain()')
    body = re.sub(r'\bbars\[([^\]]+)\]', r'cavaBand(int(\1))', body)
    # Qt's texture coordinates start at the top, unlike the original SDL shader.
    body = body.replace('texture(inputTexture, offsetCoord)',
                        'texture(inputTexture, vec2(offsetCoord.x, 1.0 - offsetCoord.y))')
    target = root / source.name
    target.write_text('// Generated from CAVA 1.0.0; see README.md and LICENSE.\n' + header + body + footer)
    subprocess.run(['/usr/lib/qt6/bin/qsb', '--glsl', '300 es,150,330', '--hlsl', '50',
                    '--msl', '12', '-o', str(target) + '.qsb', str(target)], check=True)

# Match the fragment bundles' modern GLSL variants rather than Qt's legacy default vertex shader.
vertex = root / 'pass_through.vert'
uniforms = header[header.index('layout(std140'):header.index('layout(binding = 1)')]
vertex.write_text('''#version 450
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;
''' + uniforms + '''
void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = qt_Matrix * qt_Vertex;
}
''')
subprocess.run(['/usr/lib/qt6/bin/qsb', '--glsl', '300 es,150,330', '--hlsl', '50',
                '--msl', '12', '-o', str(vertex) + '.qsb', str(vertex)], check=True)

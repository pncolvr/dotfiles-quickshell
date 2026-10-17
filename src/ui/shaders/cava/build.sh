#!/usr/bin/env bash
# Adapt CAVA 1.0.0 shaders to Qt Quick's uniform/texture interface.
set -euo pipefail
shader_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
header=$(cat <<'GLSL'
#version 450
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
GLSL
)
compile() {
    /usr/lib/qt6/bin/qsb --glsl '300 es,150,330' --hlsl 50 --msl 12 -o "$1.qsb" "$1"
}
for source in "$shader_dir"/upstream/*.frag; do
    target="$shader_dir/${source##*/}"
    {
        printf '// Generated from CAVA 1.0.0; see README.md and LICENSE.\n%s\n' "$header"
        sed -E '
            /^#version/d
            /^(in|out|uniform)[[:space:]]+[^;]+;/d
            s/void main\(\)/void cavaMain()/g
            s/\bbars\[([^]]+)\]/cavaBand(int(\1))/g
            s/texture\(inputTexture, offsetCoord\)/texture(inputTexture, vec2(offsetCoord.x, 1.0 - offsetCoord.y))/g
        ' "$source"
        cat <<'GLSL'

void main() {
    fragCoord = vec2(qt_TexCoord0.x, 1.0 - qt_TexCoord0.y);
    fragColor = vec4(0.0);
    cavaMain();
    vec3 color = clamp(fragColor.rgb, 0.0, 1.0);
    // Preserve the card artwork: black shader background becomes transparent.
    float alpha = max(color.r, max(color.g, color.b));
    qt_FragColor = vec4(color, alpha) * qt_Opacity;
}
GLSL
    } > "$target"
    compile "$target"
done
# Match the fragments' modern GLSL variants, rather than Qt's legacy vertex shader.
vertex="$shader_dir/pass_through.vert"
{
    cat <<'GLSL'
#version 450
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;
GLSL
    sed -n '/^layout(std140/,/^layout(binding = 1)/{ /^layout(binding = 1)/!p; }' <<< "$header"
    cat <<'GLSL'

void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = qt_Matrix * qt_Vertex;
}
GLSL
} > "$vertex"
compile "$vertex"

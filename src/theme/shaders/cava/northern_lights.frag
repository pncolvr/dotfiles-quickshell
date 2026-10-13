// Generated from CAVA 1.0.0; see README.md and LICENSE.
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


// bar values. defaults to left channels first (low to high), then right (high to low).



//colors, configurable in cava config file

void cavaMain()
{
    // find which bar to use based on where we are on the x axis
    int bar = int(bars_count * fragCoord.x);

    float bar_y = 1.0 - abs((fragCoord.y - 0.5)) * 2.0;
    float y = (cavaBand(int(bar))) * bar_y;

    float bar_x = (fragCoord.x - float(bar) / float(bars_count)) * bars_count;
    float bar_r = 1.0 - abs((bar_x - 0.5)) * 2;

    bar_r = bar_r * bar_r * 2;

    // set color
    fragColor.r = fg_color.x * y * bar_r;
    fragColor.g = fg_color.y * y * bar_r;
    fragColor.b = fg_color.z * y * bar_r;
}

void main() {
    fragCoord = vec2(qt_TexCoord0.x, 1.0 - qt_TexCoord0.y);
    fragColor = vec4(0.0);
    cavaMain();
    vec3 color = clamp(fragColor.rgb, 0.0, 1.0);
    // Preserve the card artwork: black shader background becomes transparent.
    float alpha = max(color.r, max(color.g, color.b));
    qt_FragColor = vec4(color, alpha) * qt_Opacity;
}

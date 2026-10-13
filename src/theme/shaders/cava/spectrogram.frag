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
    return texture(audioData, vec2((float(clamp(index, 0, bars_count - 1)) + 0.5) / float(bars_count), 0.5)).r;
}


// bar values. defaults to left channels first (low to high), then right (high
// to low).



// colors, configurable in cava config file (r,g,b) (0.0 - 1.0)



vec3 normalize_C(float y, vec3 col_1, vec3 col_2, float y_min, float y_max) {
    // create color based on fraction of this color and next color
    float yr = (y - y_min) / (y_max - y_min);
    return col_1 * (1.0 - yr) + col_2 * yr;
}

void cavaMain() {
    // find which bar to use based on where we are on the y axis
    int bar = int(bars_count * fragCoord.y);
    float y = cavaBand(int(bar));
    float band_size = 1.0 / float(bars_count);
    float current_band_min = bar * band_size;
    float current_band_max = (bar + 1) * band_size;

    int hist_length = 512;
    float win_size = 1.0 / hist_length;

    if (fragCoord.x > 1.0 - win_size) {

        if (fragCoord.y > current_band_min && fragCoord.y < current_band_max) {

            fragColor = vec4(fg_color * y, 1.0);
        }
    } else {
        vec2 offsetCoord = fragCoord;
        offsetCoord.x += float(win_size);
        fragColor = texture(inputTexture, vec2(offsetCoord.x, 1.0 - offsetCoord.y));
    }
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

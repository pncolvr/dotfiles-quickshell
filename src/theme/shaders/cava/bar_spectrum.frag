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



// colors, configurable in cava config file (r,g,b) (0.0 - 1.0)




vec3 normalize_C(float y, vec3 col_1, vec3 col_2, float y_min, float y_max) {
    // create color based on fraction of this color and next color
    float yr = (y - y_min) / (y_max - y_min);
    return col_1 * (1.0 - yr) + col_2 * yr;
}

void cavaMain() {
    // find which bar to use based on where we are on the x axis
    float x = u_resolution.x * fragCoord.x;
    int bar = int(bars_count * fragCoord.x);

    // calculate a bar size
    float bar_size = u_resolution.x / bars_count;

    // the y coordinate and bar values are the same
    float y = cavaBand(int(bar));

    // make sure there is a thin line at bottom
    if (y * u_resolution.y < 1.0) {
        y = 1.0 / u_resolution.y;
    }

    // draw the bar up to current height
    if (y > fragCoord.y) {
        // make some space between bars basen on settings
        if (x > (bar + 1) * (bar_size)-bar_spacing) {
            fragColor = vec4(bg_color, 1.0);
        } else {
            if (gradient_count == 0) {
                fragColor = vec4(fg_color, 1.0);
            } else {
                // find which color in the configured gradient we are at
                int color = int((gradient_count - 1) * fragCoord.y);

                // find where on y this and next color is supposed to be
                float y_min = color / (gradient_count - 1.0);
                float y_max = (color + 1.0) / (gradient_count - 1.0);

                // make color
                fragColor = vec4(normalize_C(fragCoord.y, gradient_colors[color],
                                             gradient_colors[color + 1], y_min, y_max),
                                 1.0);
            }
        }
    } else {
        fragColor = vec4(bg_color, 1.0);
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

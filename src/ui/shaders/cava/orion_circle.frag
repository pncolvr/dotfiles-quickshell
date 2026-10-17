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
// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 rezky_nightky <with.rezky@gmail.com>

// Static Orion (non-rotating)








vec3 normalize_C(float y, vec3 col_1, vec3 col_2, float y_min, float y_max) {
    const float EPS = 0.0001;
    float yr = (y - y_min) / max(y_max - y_min, EPS);
    yr = clamp(yr, 0.0, 1.0);
    return col_1 * (1.0 - yr) + col_2 * yr;
}

void cavaMain() {
    vec2 p = fragCoord - vec2(0.5);
    p.x *= u_resolution.x / u_resolution.y;

    float base_radius = 0.35;
    float max_len = 0.15;
    float pad = 2.0 / u_resolution.y;
    float min_r = max(base_radius - pad, 0.0);
    float max_r = base_radius + max_len + pad;

    float r2 = dot(p, p);
    if (r2 < min_r * min_r || r2 > max_r * max_r) {
        fragColor = vec4(bg_color, 1.0);
        return;
    }

    float r = sqrt(r2);

    float theta = atan(p.y, p.x);

    float pi = radians(180.0);
    float tau = pi * 2.0;

    float a = (theta + pi) / tau;
    a = fract(a);

    int bc = min(bars_count, 512);
    if (bc <= 0) {
        fragColor = vec4(bg_color, 1.0);
        return;
    }

    float cell = a * float(bc);
    int bar = int(floor(cell));
    bar = clamp(bar, 0, bc - 1);
    int bar_next = bar + 1;
    if (bar_next >= bc) {
        bar_next = 0;
    }
    float f = fract(cell);

    float fill = float(bar_width) / max(float(bar_width + bar_spacing), 1.0);
    float angular = abs(f - 0.5);
    float px = max(length(dFdx(p)), length(dFdy(p)));
    float df = 0.35 * (float(bc) * px) / (tau * max(r, px));
    float gap_half = (1.0 - fill) * 0.5;
    float eps = 1.0 / (float(bc) * 2048.0);
    float gap_cap = max(gap_half - eps, 0.0);
    float df_cap = min(gap_cap, fill * 0.15);
    df = min(df, max(df_cap, 1e-6));
    float angular_alpha = 1.0 - smoothstep(fill * 0.5 - df, fill * 0.5 + df, angular);
    angular_alpha *= step(angular, fill * 0.5 + df);
    angular_alpha *= step(0.01, angular_alpha);

    float y0 = clamp(cavaBand(int(bar)), 0.0, 1.0);
    float y1 = clamp(cavaBand(int(bar_next)), 0.0, 1.0);
    float y = mix(y0, y1, f);

    float amp = y * (1.0 + 0.8 * (1.0 - y));

    float min_len = 1.0 / u_resolution.y;
    float max_len_cap = max(max_len - min_len, min_len);
    float len = min(max(amp * max_len, min_len), max_len_cap);
    float act = smoothstep(0.0, min_len / max_len, amp);

    float dr = clamp(px, min_len, 2.0 * min_len);
    float inner = smoothstep(base_radius - dr, base_radius + dr, r);
    float outer = 1.0 - smoothstep(base_radius + len - dr, base_radius + len + dr, r);
    float radial_alpha = inner * outer * act;
    float outer_cap = 1.0 - smoothstep(base_radius + max_len - dr, base_radius + max_len + dr, r);
    radial_alpha *= outer_cap;

    float alpha = angular_alpha * radial_alpha;
    alpha *= step(0.0035, alpha);

    if (alpha == 0.0) {
        fragColor = vec4(bg_color, 1.0);
        return;
    }

    vec3 col;
    if (gradient_count == 0) {
        col = fg_color;
    } else {
        if (gradient_count == 1) {
            col = gradient_colors[0];
        } else {
            int color = int(floor((gradient_count - 1) * amp));
            color = clamp(color, 0, gradient_count - 2);
            float y_min = float(color) / (gradient_count - 1.0);
            float y_max = float(color + 1) / (gradient_count - 1.0);
            col =
                normalize_C(amp, gradient_colors[color], gradient_colors[color + 1], y_min, y_max);
        }
    }

    fragColor = vec4(mix(bg_color, col, alpha), 1.0);
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

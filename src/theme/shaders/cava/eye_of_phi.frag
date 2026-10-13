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

// this shader was stolen from shadertoy user ChunderFPV

#define SCALE 8.0
#define PI radians(180.0)
#define TAU (PI * 2.0)
#define CS(a) vec2(cos(a), sin(a))
#define PT(u, r) smoothstep(0.0, r, r - length(u))





// colors, configurable in cava config file (r,g,b) (0.0 - 1.0)


// gradient map ( color, equation, time, width, shadow, reciprocal )
vec3 gm(vec3 c, float n, float t, float w, float d, bool i) {
  float g = min(abs(n), 1.0 / abs(n));
  float s = abs(sin(n * PI - t));
  if (i)
    s = min(s, abs(sin(PI / n + t)));
  return (1.0 - pow(abs(s), w)) * c * pow(g, d) * 6.0;
}

// denominator spiral, use 1/n for numerator
// ( screen xy, spiral exponent, decimal, line width, hardness, rotation )
float ds(vec2 u, float e, float n, float w, float h, float ro) {
  float ur = length(u);          // unit radius
  float sr = pow(ur, e);         // spiral radius
  float a = round(sr) * n * TAU; // arc
  vec2 xy = CS(a + ro) * ur;     // xy coords
  float l = PT(u - xy, w);       // line
  float s = mod(sr + 0.5, 1.0);  // gradient smooth
  s = min(s, 1.0 - s);           // darken filter
  return l * s * h;
}

void cavaMain() {
  float t = shader_time / PI * 2.0;
  vec4 m = vec4(0, 0, 0, 0);                 // iMouse;
  m.xy = m.xy * 2.0 / u_resolution.xy - 1.0; // ±1x, ±1y
  if (m.z > 0.0)
    t += m.y * SCALE; // move time with mouse y
  float z = (m.z > 0.0) ? pow(1.0 - abs(m.y), sign(m.y)) : 1.0; // zoom (+)
  float e = (m.z > 0.0) ? pow(1.0 - abs(m.x), -sign(m.x))
                        : 1.0;                   // screen exponent (+)
  float se = (m.z > 0.0) ? e * -sign(m.y) : 1.0; // spiral exponent
  vec3 bg = vec3(0);                             // black background

  float aa = 3.0; // anti-aliasing

  for (float j = 0.0; j < aa; j++)
    for (float k = 0.0; k < aa; k++) {
      vec3 c = vec3(0);
      vec2 o = vec2(j, k) / aa;
      vec2 uv = (fragCoord * u_resolution.xy - 0.5 * u_resolution.xy + o) /
                u_resolution.y * SCALE * z; // apply cartesian, scale and zoom
      if (m.z > 0.0)
        uv =
            exp(log(abs(uv)) * e) * sign(uv); // warp screen space with exponent

      float px = length(fwidth(uv)); // pixel width
      float x = uv.x;                // every pixel on x
      float y = uv.y;                // every pixel on y
      float l = length(uv);          // hypot of xy: sqrt(x*x+y*y)

      float mc = (x * x + y * y - 1.0) / y;  // metallic circle at xy
      float g = min(abs(mc), 1.0 / abs(mc)); // gradient
      vec3 gold = vec3(1.0, 0.6, 0.0) * g * l;
      vec3 blue = vec3(0.3, 0.5, 0.9) * (1.0 - g);
      vec3 rgb = max(gold, blue);

      float w = 0.1;                                      // line width
      float d = 0.4;                                      // shadow depth
      c = max(c, gm(rgb, mc, -t, w * cavaBand(int(0)), d, false)); // metallic
      c = max(c, gm(rgb, abs(y / x) * sign(y), -t, w * cavaBand(int(1)), d,
                    false)); // tangent
      c = max(c, gm(rgb, (x * x) / (y * y) * sign(y), -t, w * cavaBand(int(2)), d,
                    false)); // sqrt cotangent
      c = max(c, gm(rgb, (x * x) + (y * y), t, w * cavaBand(int(3)), d,
                    true)); // sqrt circles

      c += rgb * ds(uv, se, t / TAU, px * 2.0 * cavaBand(int(4)), 2.0, 0.0); // spiral 1a
      c += rgb * ds(uv, se, t / TAU, px * 2.0 * cavaBand(int(5)), 2.0, PI);  // spiral 1b
      c +=
          rgb * ds(uv, -se, t / TAU, px * 2.0 * cavaBand(int(6)), 2.0, 0.0); // spiral 2a
      c += rgb * ds(uv, -se, t / TAU, px * 2.0 * cavaBand(int(7)), 2.0, PI); // spiral 2b
      c = max(c, 0.0); // clear negative color

      c += pow(max(1.0 - l, 0.0), 3.0 / z); // center glow

      if (m.z > 0.0) // display grid on click
      {
        vec2 xyg = abs(fract(uv + 0.5) - 0.5) / px; // xy grid
        c.gb += 0.2 * (1.0 - min(min(xyg.x, xyg.y), 1.0));
      }
      bg += c;
    }
  bg /= aa * aa;
  bg *= sqrt(bg) * 1.5;

  fragColor = vec4(bg, 1.0);
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

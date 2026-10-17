#version 450
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 baseColor;
    vec4 pulseColor;
    float phase;
};
layout(binding = 1) uniform sampler2D source;
void main() {
    float coverage = texture(source, qt_TexCoord0).a;
    float blend = 0.5 - 0.5 * cos(6.28318530718 * phase);
    fragColor = mix(baseColor, pulseColor, blend) * coverage * qt_Opacity;
}

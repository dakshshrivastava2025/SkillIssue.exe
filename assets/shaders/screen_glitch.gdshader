shader_type canvas_item;

uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float chromatic_aberration : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    
    if (glitch_intensity > 0.01) {
        float noise = random(vec2(floor(uv.y * 30.0), floor(TIME * 20.0)));
        if (noise < glitch_intensity * 0.4) {
            uv.x += (random(vec2(TIME, uv.y)) - 0.5) * 0.06 * glitch_intensity;
        }
    }
    
    float shift = (chromatic_aberration + (glitch_intensity * 0.02));
    float r = texture(screen_texture, uv + vec2(shift, 0.0)).r;
    float g = texture(screen_texture, uv).g;
    float b = texture(screen_texture, uv - vec2(shift, 0.0)).b;
    
    COLOR = vec4(r, g, b, 1.0);
}

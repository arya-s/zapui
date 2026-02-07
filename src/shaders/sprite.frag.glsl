#version 330 core

in vec2 v_tex_coord;
in vec4 v_color;
in vec4 v_content_mask;
in vec2 v_pixel_position;

uniform sampler2D u_texture;
uniform int u_mono;  // 1 for monochrome (text), 0 for polychrome (images)

out vec4 frag_color;

void main() {
    // Content mask clipping
    if (v_content_mask.z > 0.0 && v_content_mask.w > 0.0) {
        vec2 mask_min = v_content_mask.xy;
        vec2 mask_max = mask_min + v_content_mask.zw;
        if (v_pixel_position.x < mask_min.x || v_pixel_position.x > mask_max.x ||
            v_pixel_position.y < mask_min.y || v_pixel_position.y > mask_max.y) {
            discard;
        }
    }
    
    vec4 tex_color = texture(u_texture, v_tex_coord);
    
    if (u_mono == 1) {
        // Monochrome: use red channel as alpha, apply tint color
        float alpha = tex_color.r * v_color.a;
        if (alpha < 0.001) {
            discard;
        }
        frag_color = vec4(v_color.rgb, alpha);
    } else {
        // Polychrome: use texture color directly
        if (tex_color.a < 0.001) {
            discard;
        }
        frag_color = tex_color;
    }
}

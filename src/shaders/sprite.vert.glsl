#version 330 core

// Per-vertex attributes (unit quad)
layout(location = 0) in vec2 a_position;  // 0,0 to 1,1

// Per-instance attributes
layout(location = 1) in vec4 a_bounds;       // x, y, width, height (screen position)
layout(location = 2) in vec4 a_tex_bounds;   // u, v, width, height (texture coordinates)
layout(location = 3) in vec4 a_color;        // RGBA (tint for mono, ignored for poly)
layout(location = 4) in vec4 a_content_mask; // x, y, width, height

uniform vec2 u_viewport_size;

out vec2 v_tex_coord;
out vec4 v_color;
out vec4 v_content_mask;
out vec2 v_pixel_position;

void main() {
    vec2 quad_pos = a_bounds.xy;
    vec2 quad_size = a_bounds.zw;
    
    // Calculate vertex position in pixels
    vec2 pixel_pos = quad_pos + a_position * quad_size;
    
    // Convert to clip space (-1 to 1)
    vec2 clip_pos = (pixel_pos / u_viewport_size) * 2.0 - 1.0;
    clip_pos.y = -clip_pos.y;  // Flip Y (top-left origin)
    
    gl_Position = vec4(clip_pos, 0.0, 1.0);
    
    // Texture coordinates
    vec2 tex_pos = a_tex_bounds.xy;
    vec2 tex_size = a_tex_bounds.zw;
    v_tex_coord = tex_pos + a_position * tex_size;
    
    v_color = a_color;
    v_content_mask = a_content_mask;
    v_pixel_position = pixel_pos;
}

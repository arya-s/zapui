#version 330 core

// Per-vertex attributes (unit quad)
layout(location = 0) in vec2 a_position;  // 0,0 to 1,1

// Per-instance attributes
layout(location = 1) in vec4 a_bounds;        // x, y, width, height
layout(location = 2) in vec4 a_corner_radii;  // TL, TR, BR, BL
layout(location = 3) in float a_blur_radius;
layout(location = 4) in vec4 a_color;         // RGBA
layout(location = 5) in vec4 a_content_mask;  // x, y, width, height

uniform vec2 u_viewport_size;

out vec2 v_position;
out vec2 v_quad_size;
out vec4 v_corner_radii;
out float v_blur_radius;
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
    
    v_position = a_position;
    v_quad_size = quad_size;
    v_corner_radii = a_corner_radii;
    v_blur_radius = a_blur_radius;
    v_color = a_color;
    v_content_mask = a_content_mask;
    v_pixel_position = pixel_pos;
}

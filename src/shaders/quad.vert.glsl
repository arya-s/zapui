#version 330 core

// Per-vertex attributes (unit quad)
layout(location = 0) in vec2 a_position;  // 0,0 to 1,1

// Per-instance attributes
layout(location = 1) in vec4 a_bounds;           // x, y, width, height
layout(location = 2) in vec4 a_background_color; // RGBA
layout(location = 3) in vec4 a_border_color;     // RGBA
layout(location = 4) in vec4 a_border_widths;    // top, right, bottom, left
layout(location = 5) in vec4 a_corner_radii;     // TL, TR, BR, BL
layout(location = 6) in vec4 a_content_mask;     // x, y, width, height (0,0,0,0 = no mask)
layout(location = 7) in vec4 a_border_style;     // x = style (0 = solid, 1 = dashed), yzw = unused

uniform vec2 u_viewport_size;

out vec2 v_position;        // Position within the quad (0-1)
out vec2 v_quad_size;       // Size of the quad in pixels
out vec4 v_background_color;
out vec4 v_border_color;
out vec4 v_border_widths;
out vec4 v_corner_radii;
out vec4 v_content_mask;
out vec2 v_pixel_position;  // Absolute pixel position
flat out float v_border_style;  // 0 = solid, 1 = dashed

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
    v_background_color = a_background_color;
    v_border_color = a_border_color;
    v_border_widths = a_border_widths;
    v_corner_radii = a_corner_radii;
    v_content_mask = a_content_mask;
    v_pixel_position = pixel_pos;
    v_border_style = a_border_style.x;
}

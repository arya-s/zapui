#version 330 core

in vec2 v_position;
in vec2 v_quad_size;
in vec4 v_background_color;
in vec4 v_border_color;
in vec4 v_border_widths;
in vec4 v_corner_radii;
in vec4 v_content_mask;
in vec2 v_pixel_position;
flat in float v_border_style;  // 0 = solid, 1 = dashed

out vec4 frag_color;

// Signed distance function for a rounded box
// p: position relative to box center
// b: box half-size
// r: corner radius (one value per corner: TL, TR, BR, BL)
float roundedBoxSDF(vec2 p, vec2 b, vec4 r) {
    // Select corner radius based on which quadrant we're in
    vec2 rr;
    if (p.x > 0.0) {
        rr = (p.y > 0.0) ? r.zw : r.yw;  // BR or TR
    } else {
        rr = (p.y > 0.0) ? r.xw : r.xy;  // BL or TL
    }
    float radius = (p.x > 0.0) ? 
        ((p.y > 0.0) ? r.z : r.y) :  // BR or TR
        ((p.y > 0.0) ? r.w : r.x);   // BL or TL
    
    vec2 q = abs(p) - b + radius;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

void main() {
    // Position in pixels relative to quad top-left
    vec2 local_pos = v_position * v_quad_size;
    
    // Position relative to quad center
    vec2 center_pos = local_pos - v_quad_size * 0.5;
    vec2 half_size = v_quad_size * 0.5;
    
    // Corner radii (TL, TR, BR, BL)
    vec4 radii = v_corner_radii;
    
    // Clamp radii to half the minimum dimension
    float max_radius = min(half_size.x, half_size.y);
    radii = min(radii, vec4(max_radius));
    
    // Calculate SDF for outer edge
    float dist = roundedBoxSDF(center_pos, half_size, radii);
    
    // Anti-aliasing: smooth edge over ~1 pixel
    float aa = fwidth(dist);
    float outer_alpha = 1.0 - smoothstep(-aa, aa, dist);
    
    // Border handling
    vec4 bw = v_border_widths;  // top, right, bottom, left
    float border_top = bw.x;
    float border_right = bw.y;
    float border_bottom = bw.z;
    float border_left = bw.w;
    
    // Calculate inner box for border
    vec2 inner_half_size = half_size - vec2(
        (border_left + border_right) * 0.5,
        (border_top + border_bottom) * 0.5
    );
    vec2 inner_offset = vec2(
        (border_left - border_right) * 0.5,
        (border_top - border_bottom) * 0.5
    );
    
    // Adjust inner radii
    float avg_border = (border_top + border_right + border_bottom + border_left) * 0.25;
    vec4 inner_radii = max(radii - vec4(avg_border), vec4(0.0));
    
    // SDF for inner edge (border inside)
    float inner_dist = roundedBoxSDF(center_pos - inner_offset, max(inner_half_size, vec2(0.0)), inner_radii);
    float inner_alpha = 1.0 - smoothstep(-aa, aa, inner_dist);
    
    // Determine if we're in border or fill area
    float border_factor = outer_alpha * (1.0 - inner_alpha);
    float fill_factor = outer_alpha * inner_alpha;
    
    // Handle dashed border style (matching GPUI's approach)
    if (v_border_style > 0.5 && border_factor > 0.0) {
        // GPUI uses: (2 * border_width) dash, (1 * border_width) gap
        float avg_border_width = (bw.x + bw.y + bw.z + bw.w) * 0.25;
        avg_border_width = max(avg_border_width, 1.0);
        
        float dash_length = 2.0 * avg_border_width;
        float gap_length = 1.0 * avg_border_width;
        float pattern_length = dash_length + gap_length;
        
        // Calculate position along perimeter
        // For each edge, we track x or y position
        vec2 abs_center = abs(center_pos);
        
        float perimeter_pos;
        
        // Determine which edge we're on and calculate position
        // Top edge: y near -half_size.y
        // Right edge: x near half_size.x  
        // Bottom edge: y near half_size.y
        // Left edge: x near -half_size.x
        
        float edge_threshold_x = half_size.x - avg_border_width * 2.0;
        float edge_threshold_y = half_size.y - avg_border_width * 2.0;
        
        if (center_pos.y < -edge_threshold_y) {
            // Top edge - use x position
            perimeter_pos = local_pos.x;
        } else if (center_pos.x > edge_threshold_x) {
            // Right edge - use y position
            perimeter_pos = local_pos.y + v_quad_size.x;
        } else if (center_pos.y > edge_threshold_y) {
            // Bottom edge - use x position (reversed)
            perimeter_pos = (v_quad_size.x - local_pos.x) + v_quad_size.x + v_quad_size.y;
        } else if (center_pos.x < -edge_threshold_x) {
            // Left edge - use y position (reversed)
            perimeter_pos = (v_quad_size.y - local_pos.y) + 2.0 * v_quad_size.x + v_quad_size.y;
        } else {
            // Corner region - use angle
            float angle = atan(center_pos.y, center_pos.x);
            float perimeter = 2.0 * (v_quad_size.x + v_quad_size.y);
            perimeter_pos = (angle + 3.14159) / (2.0 * 3.14159) * perimeter;
        }
        
        // Apply dash pattern with slight anti-aliasing
        float pattern_phase = mod(perimeter_pos, pattern_length);
        // Use step for crisp dashes (GPUI-style)
        float dash_alpha = step(pattern_phase, dash_length);
        
        border_factor *= dash_alpha;
    }
    
    // Mix colors
    vec4 bg_color = v_background_color;
    vec4 bd_color = v_border_color;
    
    vec4 final_color = bg_color * fill_factor + bd_color * border_factor;
    final_color.a = outer_alpha * max(bg_color.a * fill_factor + bd_color.a * border_factor, 
                                       step(0.001, fill_factor) * bg_color.a + step(0.001, border_factor) * bd_color.a);
    
    // Content mask clipping
    if (v_content_mask.z > 0.0 && v_content_mask.w > 0.0) {
        vec2 mask_min = v_content_mask.xy;
        vec2 mask_max = mask_min + v_content_mask.zw;
        if (v_pixel_position.x < mask_min.x || v_pixel_position.x > mask_max.x ||
            v_pixel_position.y < mask_min.y || v_pixel_position.y > mask_max.y) {
            discard;
        }
    }
    
    if (final_color.a < 0.001) {
        discard;
    }
    
    frag_color = final_color;
}

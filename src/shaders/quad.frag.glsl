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
    
    // Border handling - pick nearest border width like GPUI
    vec4 bw = v_border_widths;  // top, right, bottom, left
    vec2 border = vec2(
        center_pos.x < 0.0 ? bw.w : bw.y,  // left or right
        center_pos.y < 0.0 ? bw.x : bw.z   // top or bottom
    );
    
    // Pick the corner radius for this quadrant
    float corner_radius;
    if (center_pos.x < 0.0) {
        corner_radius = (center_pos.y < 0.0) ? radii.x : radii.w;  // TL or BL
    } else {
        corner_radius = (center_pos.y < 0.0) ? radii.y : radii.z;  // TR or BR
    }
    
    // Vector from corner of quad bounds to point (mirrored to bottom-right quadrant)
    vec2 corner_to_point = abs(center_pos) - half_size;
    
    // Vector from point to center of rounded corner's circle
    vec2 corner_center_to_point = corner_to_point + corner_radius;
    
    // Inner edge calculation like GPUI
    float antialias_threshold = 0.5;
    vec2 reduced_border = vec2(
        border.x == 0.0 ? -antialias_threshold : border.x,
        border.y == 0.0 ? -antialias_threshold : border.y
    );
    
    vec2 straight_border_inner_corner_to_point = corner_to_point + reduced_border;
    
    // Calculate inner SDF like GPUI
    float inner_dist;
    if (corner_center_to_point.x <= 0.0 || corner_center_to_point.y <= 0.0) {
        // Straight border region
        inner_dist = -max(straight_border_inner_corner_to_point.x, straight_border_inner_corner_to_point.y);
    } else if (straight_border_inner_corner_to_point.x > 0.0 || straight_border_inner_corner_to_point.y > 0.0) {
        // Beyond inner straight border
        inner_dist = -1.0;
    } else if (reduced_border.x == reduced_border.y) {
        // Circular inner edge
        inner_dist = -(dist + reduced_border.x);
    } else {
        // Elliptical inner edge (simplified)
        vec2 ellipse_radii = max(vec2(0.0), vec2(corner_radius) - reduced_border);
        vec2 p = corner_center_to_point / max(ellipse_radii, vec2(0.001));
        inner_dist = (length(p) - 1.0) * min(ellipse_radii.x, ellipse_radii.y);
    }
    
    // border_sdf: negative when inside the border region
    float border_sdf = max(inner_dist, dist);
    
    // Colors
    vec4 bg_color = v_background_color;
    vec4 bd_color = v_border_color;
    
    // Handle dashed border style (matching GPUI's approach)
    // Only process if we're in the border region (border_sdf < threshold)
    if (v_border_style > 0.5 && border_sdf < antialias_threshold) {
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
        
        // Apply dash pattern
        float pattern_phase = mod(perimeter_pos, pattern_length);
        float dash_alpha_val = step(pattern_phase, dash_length);
        
        // Modulate border alpha for dashing (like GPUI)
        bd_color.a *= dash_alpha_val;
    }
    
    // Start with background color
    vec4 final_color = bg_color;
    
    // Only blend border if we're in the border region
    if (border_sdf < antialias_threshold) {
        // GPUI-style blending using "over" operator:
        // over(below, above) where below=background, above=border
        float blended_alpha = bd_color.a + bg_color.a * (1.0 - bd_color.a);
        vec3 blended_rgb = (blended_alpha > 0.001) 
            ? (bd_color.rgb * bd_color.a + bg_color.rgb * bg_color.a * (1.0 - bd_color.a)) / blended_alpha
            : bg_color.rgb;
        vec4 blended = vec4(blended_rgb, blended_alpha);
        
        // GPUI: mix(background, blended, saturate(threshold - inner_sdf))
        // inner_dist is negative in border, positive in fill (like GPUI's inner_sdf)
        float border_blend = clamp(antialias_threshold - inner_dist, 0.0, 1.0);
        final_color = mix(bg_color, blended, border_blend);
    }
    
    // Apply outer edge antialiasing using SDF (like GPUI)
    // GPUI: blend_color(color, saturate(threshold - outer_sdf))
    float outer_blend = clamp(antialias_threshold - dist, 0.0, 1.0);
    final_color.a *= outer_blend;
    
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

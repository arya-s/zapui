#version 330 core

in vec2 v_position;
in vec2 v_quad_size;
in vec4 v_corner_radii;
in float v_blur_radius;
in vec4 v_color;
in vec4 v_content_mask;
in vec2 v_pixel_position;

out vec4 frag_color;

// Signed distance function for a rounded box
float roundedBoxSDF(vec2 p, vec2 b, vec4 r) {
    float radius = (p.x > 0.0) ? 
        ((p.y > 0.0) ? r.z : r.y) :
        ((p.y > 0.0) ? r.w : r.x);
    
    vec2 q = abs(p) - b + radius;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

// Approximate Gaussian blur using the error function approximation
// This gives a smooth shadow falloff
float shadowAlpha(float dist, float blur) {
    if (blur < 0.001) {
        return dist < 0.0 ? 1.0 : 0.0;
    }
    // Approximate erf for Gaussian shadow
    // erf(x) ≈ tanh(sqrt(pi) * x) for fast approximation
    float x = dist / (blur * 0.5);
    return 0.5 - 0.5 * tanh(x * 1.7724538509);  // sqrt(pi) ≈ 1.7724538509
}

void main() {
    // The bounds already include the blur expansion
    // We need to find the "inner" box that casts the shadow
    float blur = v_blur_radius;
    vec2 inner_size = v_quad_size - vec2(blur * 2.0);
    
    // Position relative to quad center
    vec2 local_pos = v_position * v_quad_size;
    vec2 center_pos = local_pos - v_quad_size * 0.5;
    vec2 half_size = inner_size * 0.5;
    
    // Corner radii
    vec4 radii = v_corner_radii;
    float max_radius = min(half_size.x, half_size.y);
    radii = min(radii, vec4(max(max_radius, 0.0)));
    
    // Calculate distance to the shadow-casting box
    float dist = roundedBoxSDF(center_pos, max(half_size, vec2(0.0)), radii);
    
    // Calculate shadow alpha with Gaussian falloff
    float alpha = shadowAlpha(dist, blur) * v_color.a;
    
    // Content mask clipping
    if (v_content_mask.z > 0.0 && v_content_mask.w > 0.0) {
        vec2 mask_min = v_content_mask.xy;
        vec2 mask_max = mask_min + v_content_mask.zw;
        if (v_pixel_position.x < mask_min.x || v_pixel_position.x > mask_max.x ||
            v_pixel_position.y < mask_min.y || v_pixel_position.y > mask_max.y) {
            discard;
        }
    }
    
    if (alpha < 0.001) {
        discard;
    }
    
    frag_color = vec4(v_color.rgb, alpha);
}

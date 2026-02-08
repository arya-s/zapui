// Quad shader for D3D11
// Renders rounded rectangles with borders using SDF

// Constants
cbuffer GlobalParams : register(b0) {
    float2 viewport_size;
    float2 _padding;
};

// Per-instance data (structured buffer)
struct QuadInstance {
    float4 bounds;           // x, y, width, height
    float4 background_color; // RGBA
    float4 border_color;     // RGBA  
    float4 border_widths;    // top, right, bottom, left
    float4 corner_radii;     // TL, TR, BR, BL
    float4 content_mask;     // x, y, width, height (0,0,0,0 = no mask)
    float4 border_style;     // x = style (0 = solid, 1 = dashed)
};

StructuredBuffer<QuadInstance> instances : register(t0);

// Vertex shader input (unit quad: 0,0 to 1,1)
struct VSInput {
    float2 position : POSITION;
    uint instanceID : SV_InstanceID;
};

// Vertex shader output / Pixel shader input
struct PSInput {
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
    float2 quad_size : TEXCOORD1;
    float2 pixel_position : TEXCOORD2;
    nointerpolation float4 background_color : COLOR0;
    nointerpolation float4 border_color : COLOR1;
    nointerpolation float4 border_widths : TEXCOORD3;
    nointerpolation float4 corner_radii : TEXCOORD4;
    nointerpolation float4 content_mask : TEXCOORD5;
    nointerpolation float border_style : TEXCOORD6;
};

// Vertex Shader
PSInput VSMain(VSInput input) {
    PSInput output;
    
    QuadInstance inst = instances[input.instanceID];
    
    float2 quad_pos = inst.bounds.xy;
    float2 quad_size = inst.bounds.zw;
    
    // Calculate vertex position in pixels
    float2 pixel_pos = quad_pos + input.position * quad_size;
    
    // Convert to clip space (-1 to 1)
    float2 clip_pos = (pixel_pos / viewport_size) * 2.0 - 1.0;
    clip_pos.y = -clip_pos.y;  // Flip Y (top-left origin)
    
    output.position = float4(clip_pos, 0.0, 1.0);
    output.uv = input.position;
    output.quad_size = quad_size;
    output.pixel_position = pixel_pos;
    output.background_color = inst.background_color;
    output.border_color = inst.border_color;
    output.border_widths = inst.border_widths;
    output.corner_radii = inst.corner_radii;
    output.content_mask = inst.content_mask;
    output.border_style = inst.border_style.x;
    
    return output;
}

// Signed distance function for a rounded box
float roundedBoxSDF(float2 p, float2 b, float4 r) {
    float radius;
    if (p.x > 0.0) {
        radius = (p.y > 0.0) ? r.z : r.y;  // BR or TR
    } else {
        radius = (p.y > 0.0) ? r.w : r.x;  // BL or TL
    }
    
    float2 q = abs(p) - b + radius;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

// Pixel Shader
float4 PSMain(PSInput input) : SV_TARGET {
    // Position in pixels relative to quad top-left
    float2 local_pos = input.uv * input.quad_size;
    
    // Position relative to quad center
    float2 center_pos = local_pos - input.quad_size * 0.5;
    float2 half_size = input.quad_size * 0.5;
    
    // Corner radii
    float4 radii = input.corner_radii;
    float max_radius = min(half_size.x, half_size.y);
    radii = min(radii, float4(max_radius, max_radius, max_radius, max_radius));
    
    // Calculate SDF for outer edge
    float dist = roundedBoxSDF(center_pos, half_size, radii);
    
    // Anti-aliasing
    float aa = 0.5; // fwidth approximation
    float outer_alpha = 1.0 - smoothstep(-aa, aa, dist);
    
    // Border handling
    float4 bw = input.border_widths;
    float2 border = float2(
        center_pos.x < 0.0 ? bw.w : bw.y,
        center_pos.y < 0.0 ? bw.x : bw.z
    );
    
    float corner_radius;
    if (center_pos.x < 0.0) {
        corner_radius = (center_pos.y < 0.0) ? radii.x : radii.w;
    } else {
        corner_radius = (center_pos.y < 0.0) ? radii.y : radii.z;
    }
    
    float2 corner_to_point = abs(center_pos) - half_size;
    float2 corner_center_to_point = corner_to_point + corner_radius;
    
    float antialias_threshold = 0.5;
    float2 reduced_border = float2(
        border.x == 0.0 ? -antialias_threshold : border.x,
        border.y == 0.0 ? -antialias_threshold : border.y
    );
    
    float2 straight_border_inner_corner_to_point = corner_to_point + reduced_border;
    
    float inner_dist;
    if (corner_center_to_point.x <= 0.0 || corner_center_to_point.y <= 0.0) {
        inner_dist = -max(straight_border_inner_corner_to_point.x, straight_border_inner_corner_to_point.y);
    } else if (straight_border_inner_corner_to_point.x > 0.0 || straight_border_inner_corner_to_point.y > 0.0) {
        inner_dist = -1.0;
    } else if (reduced_border.x == reduced_border.y) {
        inner_dist = -(dist + reduced_border.x);
    } else {
        float2 ellipse_radii = max(float2(0.0, 0.0), float2(corner_radius, corner_radius) - reduced_border);
        float2 p = corner_center_to_point / max(ellipse_radii, float2(0.001, 0.001));
        inner_dist = (length(p) - 1.0) * min(ellipse_radii.x, ellipse_radii.y);
    }
    
    float border_sdf = max(inner_dist, dist);
    
    float4 bg_color = input.background_color;
    float4 bd_color = input.border_color;
    
    // Dashed border (simplified)
    if (input.border_style > 0.5 && border_sdf < antialias_threshold) {
        float avg_border_width = (bw.x + bw.y + bw.z + bw.w) * 0.25;
        avg_border_width = max(avg_border_width, 1.0);
        
        float dash_length = 2.0 * avg_border_width;
        float gap_length = 1.0 * avg_border_width;
        float pattern_length = dash_length + gap_length;
        
        float perimeter_pos = local_pos.x + local_pos.y;
        float pattern_phase = fmod(perimeter_pos, pattern_length);
        float dash_alpha_val = step(pattern_phase, dash_length);
        
        bd_color.a *= dash_alpha_val;
    }
    
    float4 final_color = bg_color;
    
    if (border_sdf < antialias_threshold) {
        float blended_alpha = bd_color.a + bg_color.a * (1.0 - bd_color.a);
        float3 blended_rgb = (blended_alpha > 0.001) 
            ? (bd_color.rgb * bd_color.a + bg_color.rgb * bg_color.a * (1.0 - bd_color.a)) / blended_alpha
            : bg_color.rgb;
        float4 blended = float4(blended_rgb, blended_alpha);
        
        float border_blend = saturate(antialias_threshold - inner_dist);
        final_color = lerp(bg_color, blended, border_blend);
    }
    
    float outer_blend = saturate(antialias_threshold - dist);
    final_color.a *= outer_blend;
    
    // Content mask
    if (input.content_mask.z > 0.0 && input.content_mask.w > 0.0) {
        float2 mask_min = input.content_mask.xy;
        float2 mask_max = mask_min + input.content_mask.zw;
        if (input.pixel_position.x < mask_min.x || input.pixel_position.x > mask_max.x ||
            input.pixel_position.y < mask_min.y || input.pixel_position.y > mask_max.y) {
            discard;
        }
    }
    
    if (final_color.a < 0.001) {
        discard;
    }
    
    return final_color;
}

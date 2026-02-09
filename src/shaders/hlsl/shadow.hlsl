// Shadow shader for D3D11
// Based on GPUI's shadow implementation - Gaussian blur using analytical integration

// Constants
cbuffer GlobalParams : register(b0) {
    float2 viewport_size;
    float2 _padding;
};

// Per-instance data (structured buffer)
struct ShadowInstance {
    float4 bounds;           // x, y, width, height
    float4 corner_radii;     // TL, TR, BR, BL
    float4 color;            // RGBA
    float blur_radius;
    float3 _padding2;
};

StructuredBuffer<ShadowInstance> instances : register(t0);

static const float M_PI = 3.14159265358979323846;

// Vertex shader input (unit quad: 0,0 to 1,1)
struct VSInput {
    float2 position : POSITION;
    uint instanceID : SV_InstanceID;
};

// Vertex shader output / Pixel shader input
struct PSInput {
    float4 position : SV_POSITION;
    float2 pixel_position : TEXCOORD0;
    nointerpolation float4 color : COLOR0;
    nointerpolation uint shadow_id : TEXCOORD1;
};

// Vertex Shader
PSInput VSMain(VSInput input) {
    PSInput output;
    
    ShadowInstance inst = instances[input.instanceID];
    
    // Expand bounds by blur margin
    float margin = 3.0 * inst.blur_radius;
    float2 expanded_origin = inst.bounds.xy - margin;
    float2 expanded_size = inst.bounds.zw + 2.0 * margin;
    
    // Calculate vertex position in pixels
    float2 pixel_pos = expanded_origin + input.position * expanded_size;
    
    // Convert to clip space (-1 to 1)
    float2 clip_pos = (pixel_pos / viewport_size) * 2.0 - 1.0;
    clip_pos.y = -clip_pos.y;  // Flip Y (top-left origin)
    
    output.position = float4(clip_pos, 0.0, 1.0);
    output.pixel_position = pixel_pos;
    output.color = inst.color;
    output.shadow_id = input.instanceID;
    
    return output;
}

// Standard Gaussian function for weighting samples
float gaussian(float x, float sigma) {
    return exp(-(x * x) / (2.0 * sigma * sigma)) / (sqrt(2.0 * M_PI) * sigma);
}

// Approximate error function for Gaussian integral
float2 erf_approx(float2 v) {
    float2 s = sign(v);
    float2 a = abs(v);
    float2 r1 = 1.0 + (0.278393 + (0.230389 + (0.000972 + 0.078108 * a) * a) * a) * a;
    float2 r2 = r1 * r1;
    return s - s / (r2 * r2);
}

// Blur along X axis using analytical integration
float blur_along_x(float x, float y, float sigma, float corner, float2 half_size) {
    float delta = min(half_size.y - corner - abs(y), 0.0);
    float curved = half_size.x - corner + sqrt(max(0.0, corner * corner - delta * delta));
    float2 integral = 0.5 + 0.5 * erf_approx((x + float2(-curved, curved)) * (sqrt(0.5) / sigma));
    return integral.y - integral.x;
}

// Select corner radius based on quadrant
float pick_corner_radius(float2 center_to_point, float4 radii) {
    if (center_to_point.x < 0.0) {
        return (center_to_point.y < 0.0) ? radii.x : radii.w;  // TL or BL
    } else {
        return (center_to_point.y < 0.0) ? radii.y : radii.z;  // TR or BR
    }
}

// Pixel Shader
float4 PSMain(PSInput input) : SV_TARGET {
    ShadowInstance shadow = instances[input.shadow_id];
    
    float2 half_size = shadow.bounds.zw / 2.0;
    float2 center = shadow.bounds.xy + half_size;
    float2 center_to_point = input.pixel_position - center;
    
    float corner_radius = pick_corner_radius(center_to_point, shadow.corner_radii);
    float blur = shadow.blur_radius;
    
    // Handle zero blur case - sharp shadow using SDF
    if (blur < 0.001) {
        float dist;
        float min_half = min(half_size.x, half_size.y);
        
        if (corner_radius >= min_half) {
            // Circle or pill shape - use circle SDF
            dist = length(center_to_point) - min_half;
        } else {
            // Rounded rectangle SDF
            float2 q = abs(center_to_point) - half_size + corner_radius;
            dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner_radius;
        }
        
        // Smooth edge with 1px antialiasing
        float alpha = saturate(-dist) * input.color.a;
        return float4(input.color.rgb, alpha);
    }
    
    // DEBUG: Step through blur_along_x calculation
    float x = center_to_point.x;
    float y = center_to_point.y;
    float sigma = blur;
    float corner = corner_radius;
    
    // The signal is only non-zero in a limited range, so don't waste samples
    float low = center_to_point.y - half_size.y;
    float high = center_to_point.y + half_size.y;
    float start_y = clamp(-3.0 * blur, low, high);
    float end_y = clamp(3.0 * blur, low, high);
    
    // Accumulate samples (we can get away with surprisingly few samples)
    float step_size = (end_y - start_y) / 4.0;
    float y_sample = start_y + step_size * 0.5;
    float alpha = 0.0;
    
    [unroll]
    for (int i = 0; i < 4; i++) {
        float blur_x = blur_along_x(center_to_point.x, center_to_point.y - y_sample, blur, corner_radius, half_size);
        alpha += blur_x * gaussian(y_sample, blur) * step_size;
        y_sample += step_size;
    }
    
    alpha *= input.color.a;
    
    return float4(input.color.rgb, alpha);
}

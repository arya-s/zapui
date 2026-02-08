// Sprite shader for D3D11
// Renders textured quads for text glyphs (monochrome) and images (polychrome)

// Constants
cbuffer GlobalParams : register(b0) {
    float2 viewport_size;
    int is_mono;  // 1 = monochrome (text), 0 = polychrome (images)
    float _padding;
};

// Per-instance data
struct SpriteInstance {
    float4 bounds;      // x, y, width, height (screen pixels)
    float4 uv_bounds;   // x, y, width, height (0-1 in texture)
    float4 color;       // RGBA tint (for mono) or ignored (for poly)
    float4 content_mask; // x, y, width, height (0,0,0,0 = no mask)
};

StructuredBuffer<SpriteInstance> instances : register(t0);
Texture2D sprite_texture : register(t1);
SamplerState sprite_sampler : register(s0);

// Vertex shader input
struct VSInput {
    float2 position : POSITION;
    uint instanceID : SV_InstanceID;
};

// Vertex shader output / Pixel shader input
struct PSInput {
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
    float2 pixel_position : TEXCOORD1;
    nointerpolation float4 color : COLOR0;
    nointerpolation float4 content_mask : TEXCOORD2;
};

// Vertex Shader
PSInput VSMain(VSInput input) {
    PSInput output;
    
    SpriteInstance inst = instances[input.instanceID];
    
    float2 quad_pos = inst.bounds.xy;
    float2 quad_size = inst.bounds.zw;
    
    // Calculate vertex position in pixels
    float2 pixel_pos = quad_pos + input.position * quad_size;
    
    // Convert to clip space (-1 to 1)
    float2 clip_pos = (pixel_pos / viewport_size) * 2.0 - 1.0;
    clip_pos.y = -clip_pos.y;  // Flip Y (top-left origin)
    
    output.position = float4(clip_pos, 0.0, 1.0);
    
    // Calculate UV coordinates
    float2 uv_pos = inst.uv_bounds.xy;
    float2 uv_size = inst.uv_bounds.zw;
    output.uv = uv_pos + input.position * uv_size;
    
    output.pixel_position = pixel_pos;
    output.color = inst.color;
    output.content_mask = inst.content_mask;
    
    return output;
}

// Pixel Shader
float4 PSMain(PSInput input) : SV_TARGET {
    // Sample texture
    float4 tex_color = sprite_texture.Sample(sprite_sampler, input.uv);
    
    float4 final_color;
    
    if (is_mono != 0) {
        // Monochrome mode (text glyphs)
        // Texture is grayscale alpha mask, tint with color
        final_color = float4(input.color.rgb, input.color.a * tex_color.r);
    } else {
        // Polychrome mode (images)
        // Use texture color directly
        final_color = tex_color;
    }
    
    // Content mask clipping
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

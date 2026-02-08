//! DirectX 11 Renderer
//!
//! Native Windows renderer using Direct3D 11.

const std = @import("std");
pub const win32 = @import("win32");

pub const d3d11 = win32.graphics.direct3d11;
const d3d = win32.graphics.direct3d;
const dxgi = win32.graphics.dxgi;
const fxc = win32.graphics.direct3d.fxc;
const foundation = win32.foundation;

const ID3DBlob = d3d.ID3DBlob;

const HWND = foundation.HWND;
const HRESULT = foundation.HRESULT;
pub const S_OK = foundation.S_OK;

const Allocator = std.mem.Allocator;

// Scene integration
const scene_mod = @import("../scene.zig");
const Scene = scene_mod.Scene;
const color_mod = @import("../color.zig");
const Hsla = color_mod.Hsla;

// Helper to release COM objects
fn release(comptime T: type, obj: *T) void {
    _ = obj.IUnknown.vtable.Release(&obj.IUnknown);
}

// Quad instance data (matches HLSL struct)
pub const QuadInstance = extern struct {
    bounds: [4]f32,           // x, y, width, height
    background_color: [4]f32, // RGBA
    border_color: [4]f32,     // RGBA  
    border_widths: [4]f32,    // top, right, bottom, left
    corner_radii: [4]f32,     // TL, TR, BR, BL
    content_mask: [4]f32,     // x, y, width, height
    border_style: [4]f32,     // x = style (0 = solid, 1 = dashed)
};

// Sprite instance data (matches HLSL struct)
pub const SpriteInstance = extern struct {
    bounds: [4]f32,       // x, y, width, height (screen pixels)
    uv_bounds: [4]f32,    // x, y, width, height (0-1 in texture)
    color: [4]f32,        // RGBA tint
    content_mask: [4]f32, // x, y, width, height (0,0,0,0 = no mask)
};

// Global params constant buffer for quads
const GlobalParams = extern struct {
    viewport_size: [2]f32,
    _padding: [2]f32,
};

// Global params constant buffer for sprites
const SpriteGlobalParams = extern struct {
    viewport_size: [2]f32,
    is_mono: i32,
    _padding: f32,
};

pub const D3D11Renderer = struct {
    allocator: Allocator,
    device: *d3d11.ID3D11Device,
    context: *d3d11.ID3D11DeviceContext,
    swap_chain: *dxgi.IDXGISwapChain,
    render_target_view: ?*d3d11.ID3D11RenderTargetView,

    // Shader resources
    vertex_shader: ?*d3d11.ID3D11VertexShader,
    pixel_shader: ?*d3d11.ID3D11PixelShader,
    input_layout: ?*d3d11.ID3D11InputLayout,
    
    // Buffers
    vertex_buffer: ?*d3d11.ID3D11Buffer,
    instance_buffer: ?*d3d11.ID3D11Buffer,
    constant_buffer: ?*d3d11.ID3D11Buffer,
    instance_srv: ?*d3d11.ID3D11ShaderResourceView,
    
    // Blend state
    blend_state: ?*d3d11.ID3D11BlendState,
    rasterizer_state: ?*d3d11.ID3D11RasterizerState,
    
    // Sprite shader resources
    sprite_vertex_shader: ?*d3d11.ID3D11VertexShader,
    sprite_pixel_shader: ?*d3d11.ID3D11PixelShader,
    sprite_instance_buffer: ?*d3d11.ID3D11Buffer,
    sprite_instance_srv: ?*d3d11.ID3D11ShaderResourceView,
    sprite_constant_buffer: ?*d3d11.ID3D11Buffer,
    sprite_sampler: ?*d3d11.ID3D11SamplerState,

    width: u32,
    height: u32,
    
    // Instance buffer capacity
    max_instances: u32,
    
    pub fn init(allocator: Allocator, hwnd: HWND, width: u32, height: u32) !D3D11Renderer {
        // Describe swap chain
        var swap_chain_desc = std.mem.zeroes(dxgi.DXGI_SWAP_CHAIN_DESC);
        swap_chain_desc.BufferDesc.Width = width;
        swap_chain_desc.BufferDesc.Height = height;
        swap_chain_desc.BufferDesc.RefreshRate.Numerator = 60;
        swap_chain_desc.BufferDesc.RefreshRate.Denominator = 1;
        swap_chain_desc.BufferDesc.Format = .B8G8R8A8_UNORM;
        swap_chain_desc.SampleDesc.Count = 1;
        swap_chain_desc.SampleDesc.Quality = 0;
        swap_chain_desc.BufferUsage = dxgi.DXGI_USAGE_RENDER_TARGET_OUTPUT;
        swap_chain_desc.BufferCount = 2;
        swap_chain_desc.OutputWindow = hwnd;
        swap_chain_desc.Windowed = 1;
        swap_chain_desc.SwapEffect = .DISCARD;

        const feature_levels = [_]d3d.D3D_FEATURE_LEVEL{
            .@"11_1",
            .@"11_0",
            .@"10_1",
            .@"10_0",
        };

        var device: *d3d11.ID3D11Device = undefined;
        var context: *d3d11.ID3D11DeviceContext = undefined;
        var swap_chain: *dxgi.IDXGISwapChain = undefined;
        var feature_level: d3d.D3D_FEATURE_LEVEL = undefined;

        const hr = d3d11.D3D11CreateDeviceAndSwapChain(
            null,
            .HARDWARE,
            null,
            .{},
            &feature_levels,
            feature_levels.len,
            d3d11.D3D11_SDK_VERSION,
            &swap_chain_desc,
            @ptrCast(&swap_chain),
            @ptrCast(&device),
            &feature_level,
            @ptrCast(&context),
        );

        if (hr != S_OK) {
            std.debug.print("D3D11CreateDeviceAndSwapChain failed: 0x{x}\n", .{@as(u32, @bitCast(hr))});
            return error.D3D11CreateDeviceFailed;
        }

        var self = D3D11Renderer{
            .allocator = allocator,
            .device = device,
            .context = context,
            .swap_chain = swap_chain,
            .render_target_view = null,
            .vertex_shader = null,
            .pixel_shader = null,
            .input_layout = null,
            .vertex_buffer = null,
            .instance_buffer = null,
            .constant_buffer = null,
            .instance_srv = null,
            .blend_state = null,
            .rasterizer_state = null,
            .sprite_vertex_shader = null,
            .sprite_pixel_shader = null,
            .sprite_instance_buffer = null,
            .sprite_instance_srv = null,
            .sprite_constant_buffer = null,
            .sprite_sampler = null,
            .width = width,
            .height = height,
            .max_instances = 4096,
        };

        try self.createRenderTargetView();
        try self.createShaders();
        try self.createBuffers();
        try self.createStates();

        std.debug.print("D3D11 initialized: {}x{}, feature level: {}\n", .{ width, height, @intFromEnum(feature_level) });

        return self;
    }

    fn createRenderTargetView(self: *D3D11Renderer) !void {
        var back_buffer: *d3d11.ID3D11Texture2D = undefined;
        const hr1 = self.swap_chain.vtable.GetBuffer(
            self.swap_chain,
            0,
            d3d11.IID_ID3D11Texture2D,
            @ptrCast(&back_buffer),
        );
        if (hr1 != S_OK) return error.GetBufferFailed;
        defer release(d3d11.ID3D11Texture2D, back_buffer);

        var rtv: *d3d11.ID3D11RenderTargetView = undefined;
        const hr2 = self.device.vtable.CreateRenderTargetView(
            self.device,
            @ptrCast(back_buffer),
            null,
            @ptrCast(&rtv),
        );
        if (hr2 != S_OK) return error.CreateRenderTargetViewFailed;

        self.render_target_view = rtv;
    }

    fn createShaders(self: *D3D11Renderer) !void {
        const shader_source = @embedFile("../shaders/hlsl/quad.hlsl");
        
        // Compile vertex shader
        var vs_blob: *ID3DBlob = undefined;
        var vs_errors: ?*ID3DBlob = null;
        
        const vs_hr = fxc.D3DCompile(
            shader_source.ptr,
            shader_source.len,
            null, // source name
            null, // defines
            null, // includes
            "VSMain",
            "vs_5_0",
            0, // flags
            0, // effect flags
            @ptrCast(&vs_blob),
            @ptrCast(&vs_errors),
        );
        
        if (vs_hr != S_OK) {
            if (vs_errors) |errs| {
                const msg: [*:0]const u8 = @ptrCast(errs.vtable.GetBufferPointer(errs));
                std.debug.print("VS compile error: {s}\n", .{msg});
                release(ID3DBlob, errs);
            }
            return error.ShaderCompileFailed;
        }
        defer release(ID3DBlob, vs_blob);
        
        // Compile pixel shader
        var ps_blob: *ID3DBlob = undefined;
        var ps_errors: ?*ID3DBlob = null;
        
        const ps_hr = fxc.D3DCompile(
            shader_source.ptr,
            shader_source.len,
            null,
            null,
            null,
            "PSMain",
            "ps_5_0",
            0,
            0,
            @ptrCast(&ps_blob),
            @ptrCast(&ps_errors),
        );
        
        if (ps_hr != S_OK) {
            if (ps_errors) |errs| {
                const msg: [*:0]const u8 = @ptrCast(errs.vtable.GetBufferPointer(errs));
                std.debug.print("PS compile error: {s}\n", .{msg});
                release(ID3DBlob, errs);
            }
            return error.ShaderCompileFailed;
        }
        defer release(ID3DBlob, ps_blob);
        
        // Create vertex shader
        const vs_ptr: [*]const u8 = @ptrCast(vs_blob.vtable.GetBufferPointer(vs_blob));
        const vs_size = vs_blob.vtable.GetBufferSize(vs_blob);
        
        var vs: *d3d11.ID3D11VertexShader = undefined;
        const vs_create_hr = self.device.vtable.CreateVertexShader(
            self.device,
            vs_ptr,
            vs_size,
            null,
            @ptrCast(&vs),
        );
        if (vs_create_hr != S_OK) return error.CreateVertexShaderFailed;
        self.vertex_shader = vs;
        
        // Create pixel shader
        const ps_ptr: [*]const u8 = @ptrCast(ps_blob.vtable.GetBufferPointer(ps_blob));
        const ps_size = ps_blob.vtable.GetBufferSize(ps_blob);
        
        var ps: *d3d11.ID3D11PixelShader = undefined;
        const ps_create_hr = self.device.vtable.CreatePixelShader(
            self.device,
            ps_ptr,
            ps_size,
            null,
            @ptrCast(&ps),
        );
        if (ps_create_hr != S_OK) return error.CreatePixelShaderFailed;
        self.pixel_shader = ps;
        
        // Create input layout
        const input_desc = [_]d3d11.D3D11_INPUT_ELEMENT_DESC{
            .{
                .SemanticName = "POSITION",
                .SemanticIndex = 0,
                .Format = .R32G32_FLOAT,
                .InputSlot = 0,
                .AlignedByteOffset = 0,
                .InputSlotClass = .VERTEX_DATA,
                .InstanceDataStepRate = 0,
            },
        };
        
        var layout: *d3d11.ID3D11InputLayout = undefined;
        const layout_hr = self.device.vtable.CreateInputLayout(
            self.device,
            &input_desc,
            input_desc.len,
            vs_ptr,
            vs_size,
            @ptrCast(&layout),
        );
        if (layout_hr != S_OK) return error.CreateInputLayoutFailed;
        self.input_layout = layout;
        
        // Create sprite shaders
        try self.createSpriteShaders();
    }
    
    fn createSpriteShaders(self: *D3D11Renderer) !void {
        const sprite_source = @embedFile("../shaders/hlsl/sprite.hlsl");
        
        // Compile vertex shader
        var vs_blob: *ID3DBlob = undefined;
        var vs_errors: ?*ID3DBlob = null;
        
        const vs_hr = fxc.D3DCompile(
            sprite_source.ptr,
            sprite_source.len,
            null,
            null,
            null,
            "VSMain",
            "vs_5_0",
            0,
            0,
            @ptrCast(&vs_blob),
            @ptrCast(&vs_errors),
        );
        
        if (vs_hr != S_OK) {
            if (vs_errors) |errs| {
                const msg: [*:0]const u8 = @ptrCast(errs.vtable.GetBufferPointer(errs));
                std.debug.print("Sprite VS compile error: {s}\n", .{msg});
                release(ID3DBlob, errs);
            }
            return error.ShaderCompileFailed;
        }
        defer release(ID3DBlob, vs_blob);
        
        // Compile pixel shader
        var ps_blob: *ID3DBlob = undefined;
        var ps_errors: ?*ID3DBlob = null;
        
        const ps_hr = fxc.D3DCompile(
            sprite_source.ptr,
            sprite_source.len,
            null,
            null,
            null,
            "PSMain",
            "ps_5_0",
            0,
            0,
            @ptrCast(&ps_blob),
            @ptrCast(&ps_errors),
        );
        
        if (ps_hr != S_OK) {
            if (ps_errors) |errs| {
                const msg: [*:0]const u8 = @ptrCast(errs.vtable.GetBufferPointer(errs));
                std.debug.print("Sprite PS compile error: {s}\n", .{msg});
                release(ID3DBlob, errs);
            }
            return error.ShaderCompileFailed;
        }
        defer release(ID3DBlob, ps_blob);
        
        // Create vertex shader
        const vs_ptr: [*]const u8 = @ptrCast(vs_blob.vtable.GetBufferPointer(vs_blob));
        const vs_size = vs_blob.vtable.GetBufferSize(vs_blob);
        
        var vs: *d3d11.ID3D11VertexShader = undefined;
        const vs_create_hr = self.device.vtable.CreateVertexShader(
            self.device,
            vs_ptr,
            vs_size,
            null,
            @ptrCast(&vs),
        );
        if (vs_create_hr != S_OK) return error.CreateVertexShaderFailed;
        self.sprite_vertex_shader = vs;
        
        // Create pixel shader
        const ps_ptr: [*]const u8 = @ptrCast(ps_blob.vtable.GetBufferPointer(ps_blob));
        const ps_size = ps_blob.vtable.GetBufferSize(ps_blob);
        
        var ps: *d3d11.ID3D11PixelShader = undefined;
        const ps_create_hr = self.device.vtable.CreatePixelShader(
            self.device,
            ps_ptr,
            ps_size,
            null,
            @ptrCast(&ps),
        );
        if (ps_create_hr != S_OK) return error.CreatePixelShaderFailed;
        self.sprite_pixel_shader = ps;
    }

    fn createBuffers(self: *D3D11Renderer) !void {
        // Unit quad vertices (two triangles)
        const vertices = [_]f32{
            0.0, 0.0, // TL
            1.0, 0.0, // TR
            0.0, 1.0, // BL
            1.0, 0.0, // TR
            1.0, 1.0, // BR
            0.0, 1.0, // BL
        };
        
        var vb_desc = std.mem.zeroes(d3d11.D3D11_BUFFER_DESC);
        vb_desc.ByteWidth = @sizeOf(@TypeOf(vertices));
        vb_desc.Usage = .DEFAULT;
        vb_desc.BindFlags = .{ .VERTEX_BUFFER = 1 };
        
        var vb_data = d3d11.D3D11_SUBRESOURCE_DATA{
            .pSysMem = &vertices,
            .SysMemPitch = 0,
            .SysMemSlicePitch = 0,
        };
        
        var vb: *d3d11.ID3D11Buffer = undefined;
        const vb_hr = self.device.vtable.CreateBuffer(self.device, &vb_desc, &vb_data, @ptrCast(&vb));
        if (vb_hr != S_OK) return error.CreateVertexBufferFailed;
        self.vertex_buffer = vb;
        
        // Instance buffer (dynamic)
        var ib_desc = std.mem.zeroes(d3d11.D3D11_BUFFER_DESC);
        ib_desc.ByteWidth = @sizeOf(QuadInstance) * self.max_instances;
        ib_desc.Usage = .DYNAMIC;
        ib_desc.BindFlags = .{ .SHADER_RESOURCE = 1 };
        ib_desc.CPUAccessFlags = .{ .WRITE = 1 };
        ib_desc.MiscFlags = .{ .BUFFER_STRUCTURED = 1 };
        ib_desc.StructureByteStride = @sizeOf(QuadInstance);
        
        var ib: *d3d11.ID3D11Buffer = undefined;
        const ib_hr = self.device.vtable.CreateBuffer(self.device, &ib_desc, null, @ptrCast(&ib));
        if (ib_hr != S_OK) return error.CreateInstanceBufferFailed;
        self.instance_buffer = ib;
        
        // Create SRV for instance buffer
        var srv_desc = std.mem.zeroes(d3d11.D3D11_SHADER_RESOURCE_VIEW_DESC);
        srv_desc.Format = .UNKNOWN;
        srv_desc.ViewDimension = ._SRV_DIMENSION_BUFFER;
        srv_desc.Anonymous.Buffer.Anonymous1.FirstElement = 0;
        srv_desc.Anonymous.Buffer.Anonymous2.NumElements = self.max_instances;
        
        var srv: *d3d11.ID3D11ShaderResourceView = undefined;
        const srv_hr = self.device.vtable.CreateShaderResourceView(self.device, @ptrCast(ib), &srv_desc, @ptrCast(&srv));
        if (srv_hr != S_OK) return error.CreateSRVFailed;
        self.instance_srv = srv;
        
        // Constant buffer
        var cb_desc = std.mem.zeroes(d3d11.D3D11_BUFFER_DESC);
        cb_desc.ByteWidth = @sizeOf(GlobalParams);
        cb_desc.Usage = .DYNAMIC;
        cb_desc.BindFlags = .{ .CONSTANT_BUFFER = 1 };
        cb_desc.CPUAccessFlags = .{ .WRITE = 1 };
        
        var cb: *d3d11.ID3D11Buffer = undefined;
        const cb_hr = self.device.vtable.CreateBuffer(self.device, &cb_desc, null, @ptrCast(&cb));
        if (cb_hr != S_OK) return error.CreateConstantBufferFailed;
        self.constant_buffer = cb;
        
        // Sprite instance buffer (StructuredBuffer)
        var sib_desc = std.mem.zeroes(d3d11.D3D11_BUFFER_DESC);
        sib_desc.ByteWidth = self.max_instances * @sizeOf(SpriteInstance);
        sib_desc.Usage = .DYNAMIC;
        sib_desc.BindFlags = .{ .SHADER_RESOURCE = 1 };
        sib_desc.CPUAccessFlags = .{ .WRITE = 1 };
        sib_desc.MiscFlags = .{ .BUFFER_STRUCTURED = 1 };
        sib_desc.StructureByteStride = @sizeOf(SpriteInstance);
        
        var sib: *d3d11.ID3D11Buffer = undefined;
        const sib_hr = self.device.vtable.CreateBuffer(self.device, &sib_desc, null, @ptrCast(&sib));
        if (sib_hr != S_OK) return error.CreateSpriteInstanceBufferFailed;
        self.sprite_instance_buffer = sib;
        
        // Create SRV for sprite instance buffer
        var ssrv_desc = std.mem.zeroes(d3d11.D3D11_SHADER_RESOURCE_VIEW_DESC);
        ssrv_desc.Format = .UNKNOWN;
        ssrv_desc.ViewDimension = ._SRV_DIMENSION_BUFFER;
        ssrv_desc.Anonymous.Buffer.Anonymous1.FirstElement = 0;
        ssrv_desc.Anonymous.Buffer.Anonymous2.NumElements = self.max_instances;
        
        var ssrv: *d3d11.ID3D11ShaderResourceView = undefined;
        const ssrv_hr = self.device.vtable.CreateShaderResourceView(self.device, @ptrCast(sib), &ssrv_desc, @ptrCast(&ssrv));
        if (ssrv_hr != S_OK) return error.CreateSpriteSRVFailed;
        self.sprite_instance_srv = ssrv;
        
        // Sprite constant buffer
        var scb_desc = std.mem.zeroes(d3d11.D3D11_BUFFER_DESC);
        scb_desc.ByteWidth = @sizeOf(SpriteGlobalParams);
        scb_desc.Usage = .DYNAMIC;
        scb_desc.BindFlags = .{ .CONSTANT_BUFFER = 1 };
        scb_desc.CPUAccessFlags = .{ .WRITE = 1 };
        
        var scb: *d3d11.ID3D11Buffer = undefined;
        const scb_hr = self.device.vtable.CreateBuffer(self.device, &scb_desc, null, @ptrCast(&scb));
        if (scb_hr != S_OK) return error.CreateSpriteConstantBufferFailed;
        self.sprite_constant_buffer = scb;
    }
    
    fn createStates(self: *D3D11Renderer) !void {
        // Blend state for alpha blending
        var blend_desc = std.mem.zeroes(d3d11.D3D11_BLEND_DESC);
        blend_desc.RenderTarget[0].BlendEnable = 1;
        blend_desc.RenderTarget[0].SrcBlend = .SRC_ALPHA;
        blend_desc.RenderTarget[0].DestBlend = .INV_SRC_ALPHA;
        blend_desc.RenderTarget[0].BlendOp = .ADD;
        blend_desc.RenderTarget[0].SrcBlendAlpha = .ONE;
        blend_desc.RenderTarget[0].DestBlendAlpha = .INV_SRC_ALPHA;
        blend_desc.RenderTarget[0].BlendOpAlpha = .ADD;
        blend_desc.RenderTarget[0].RenderTargetWriteMask = 0x0F;
        
        var blend_state: *d3d11.ID3D11BlendState = undefined;
        const bs_hr = self.device.vtable.CreateBlendState(self.device, &blend_desc, @ptrCast(&blend_state));
        if (bs_hr != S_OK) return error.CreateBlendStateFailed;
        self.blend_state = blend_state;
        
        // Rasterizer state
        var rast_desc = std.mem.zeroes(d3d11.D3D11_RASTERIZER_DESC);
        rast_desc.FillMode = .SOLID;
        rast_desc.CullMode = .NONE;
        rast_desc.DepthClipEnable = 1;
        
        var rast_state: *d3d11.ID3D11RasterizerState = undefined;
        const rs_hr = self.device.vtable.CreateRasterizerState(self.device, &rast_desc, @ptrCast(&rast_state));
        if (rs_hr != S_OK) return error.CreateRasterizerStateFailed;
        self.rasterizer_state = rast_state;
        
        // Sampler state for sprite textures
        var sampler_desc = std.mem.zeroes(d3d11.D3D11_SAMPLER_DESC);
        sampler_desc.Filter = .MIN_MAG_MIP_LINEAR;
        sampler_desc.AddressU = .CLAMP;
        sampler_desc.AddressV = .CLAMP;
        sampler_desc.AddressW = .CLAMP;
        sampler_desc.MaxAnisotropy = 1;
        sampler_desc.ComparisonFunc = .NEVER;
        sampler_desc.MinLOD = 0;
        sampler_desc.MaxLOD = 3.402823466e+38; // D3D11_FLOAT32_MAX
        
        var sampler: *d3d11.ID3D11SamplerState = undefined;
        const ss_hr = self.device.vtable.CreateSamplerState(self.device, &sampler_desc, @ptrCast(&sampler));
        if (ss_hr != S_OK) return error.CreateSamplerStateFailed;
        self.sprite_sampler = sampler;
    }

    pub fn deinit(self: *D3D11Renderer) void {
        // Sprite resources
        if (self.sprite_sampler) |s| release(d3d11.ID3D11SamplerState, s);
        if (self.sprite_constant_buffer) |b| release(d3d11.ID3D11Buffer, b);
        if (self.sprite_instance_srv) |s| release(d3d11.ID3D11ShaderResourceView, s);
        if (self.sprite_instance_buffer) |b| release(d3d11.ID3D11Buffer, b);
        if (self.sprite_pixel_shader) |s| release(d3d11.ID3D11PixelShader, s);
        if (self.sprite_vertex_shader) |s| release(d3d11.ID3D11VertexShader, s);
        
        // Quad resources
        if (self.rasterizer_state) |s| release(d3d11.ID3D11RasterizerState, s);
        if (self.blend_state) |s| release(d3d11.ID3D11BlendState, s);
        if (self.constant_buffer) |b| release(d3d11.ID3D11Buffer, b);
        if (self.instance_srv) |s| release(d3d11.ID3D11ShaderResourceView, s);
        if (self.instance_buffer) |b| release(d3d11.ID3D11Buffer, b);
        if (self.vertex_buffer) |b| release(d3d11.ID3D11Buffer, b);
        if (self.input_layout) |l| release(d3d11.ID3D11InputLayout, l);
        if (self.pixel_shader) |s| release(d3d11.ID3D11PixelShader, s);
        if (self.vertex_shader) |s| release(d3d11.ID3D11VertexShader, s);
        if (self.render_target_view) |rtv| release(d3d11.ID3D11RenderTargetView, rtv);
        release(dxgi.IDXGISwapChain, self.swap_chain);
        release(d3d11.ID3D11DeviceContext, self.context);
        release(d3d11.ID3D11Device, self.device);
    }

    pub fn resize(self: *D3D11Renderer, width: u32, height: u32) !void {
        if (width == 0 or height == 0) return;

        self.width = width;
        self.height = height;

        if (self.render_target_view) |rtv| {
            release(d3d11.ID3D11RenderTargetView, rtv);
            self.render_target_view = null;
        }

        self.context.vtable.OMSetRenderTargets(self.context, 0, null, null);

        const hr = self.swap_chain.vtable.ResizeBuffers(
            self.swap_chain,
            0,
            width,
            height,
            .UNKNOWN,
            0,
        );
        if (hr != S_OK) return error.ResizeBuffersFailed;

        try self.createRenderTargetView();
    }

    pub fn clear(self: *D3D11Renderer, r: f32, g: f32, b: f32, a: f32) void {
        const rtv = self.render_target_view orelse return;
        const clear_color = [4]f32{ r, g, b, a };
        self.context.vtable.ClearRenderTargetView(self.context, rtv, @ptrCast(&clear_color));
    }

    pub fn beginFrame(self: *D3D11Renderer) void {
        const rtv = self.render_target_view orelse return;

        var rtvs = [1]?*d3d11.ID3D11RenderTargetView{rtv};
        self.context.vtable.OMSetRenderTargets(self.context, 1, @ptrCast(&rtvs), null);

        const viewport = d3d11.D3D11_VIEWPORT{
            .TopLeftX = 0,
            .TopLeftY = 0,
            .Width = @floatFromInt(self.width),
            .Height = @floatFromInt(self.height),
            .MinDepth = 0,
            .MaxDepth = 1,
        };
        self.context.vtable.RSSetViewports(self.context, 1, @ptrCast(&viewport));
        
        // Update constant buffer
        if (self.constant_buffer) |cb| {
            var mapped: d3d11.D3D11_MAPPED_SUBRESOURCE = undefined;
            const map_hr = self.context.vtable.Map(self.context, @ptrCast(cb), 0, .WRITE_DISCARD, 0, &mapped);
            if (map_hr == S_OK) {
                const params: *GlobalParams = @ptrCast(@alignCast(mapped.pData));
                params.viewport_size = .{ @floatFromInt(self.width), @floatFromInt(self.height) };
                params._padding = .{ 0, 0 };
                self.context.vtable.Unmap(self.context, @ptrCast(cb), 0);
            }
        }
        
        // Set pipeline state
        if (self.blend_state) |bs| {
            self.context.vtable.OMSetBlendState(self.context, bs, null, 0xFFFFFFFF);
        }
        if (self.rasterizer_state) |rs| {
            self.context.vtable.RSSetState(self.context, rs);
        }
    }
    
    pub fn drawQuads(self: *D3D11Renderer, instances: []const QuadInstance) void {
        if (instances.len == 0) return;
        if (instances.len > self.max_instances) {
            std.debug.print("Too many instances: {} > {}\n", .{ instances.len, self.max_instances });
            return;
        }
        
        const ib = self.instance_buffer orelse return;
        const vb = self.vertex_buffer orelse return;
        const vs = self.vertex_shader orelse return;
        const ps = self.pixel_shader orelse return;
        const layout = self.input_layout orelse return;
        const cb = self.constant_buffer orelse return;
        const srv = self.instance_srv orelse return;
        
        // Update instance buffer
        var mapped: d3d11.D3D11_MAPPED_SUBRESOURCE = undefined;
        const map_hr = self.context.vtable.Map(self.context, @ptrCast(ib), 0, .WRITE_DISCARD, 0, &mapped);
        if (map_hr != S_OK) return;
        
        const dest: [*]QuadInstance = @ptrCast(@alignCast(mapped.pData));
        @memcpy(dest[0..instances.len], instances);
        self.context.vtable.Unmap(self.context, @ptrCast(ib), 0);
        
        // Set shaders
        self.context.vtable.VSSetShader(self.context, vs, null, 0);
        self.context.vtable.PSSetShader(self.context, ps, null, 0);
        
        // Set input layout
        self.context.vtable.IASetInputLayout(self.context, layout);
        
        // Set vertex buffer
        const stride: u32 = 8; // 2 floats
        const offset: u32 = 0;
        var vbs = [1]?*d3d11.ID3D11Buffer{vb};
        self.context.vtable.IASetVertexBuffers(self.context, 0, 1, @ptrCast(&vbs), @ptrCast(&stride), @ptrCast(&offset));
        
        // Set primitive topology
        self.context.vtable.IASetPrimitiveTopology(self.context, ._PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        
        // Set constant buffer
        var cbs = [1]?*d3d11.ID3D11Buffer{cb};
        self.context.vtable.VSSetConstantBuffers(self.context, 0, 1, @ptrCast(&cbs));
        
        // Set instance SRV
        var srvs = [1]?*d3d11.ID3D11ShaderResourceView{srv};
        self.context.vtable.VSSetShaderResources(self.context, 0, 1, @ptrCast(&srvs));
        
        // Draw instanced
        self.context.vtable.DrawInstanced(self.context, 6, @intCast(instances.len), 0, 0);
    }
    
    /// Draw sprites (text glyphs or images)
    /// texture_srv: The texture to sample from (glyph atlas or image atlas)
    /// is_mono: true for monochrome text, false for color images
    pub fn drawSprites(
        self: *D3D11Renderer,
        instances: []const SpriteInstance,
        texture_srv: *d3d11.ID3D11ShaderResourceView,
        is_mono: bool,
    ) void {
        if (instances.len == 0) return;
        
        const vs = self.sprite_vertex_shader orelse return;
        const ps = self.sprite_pixel_shader orelse return;
        const vb = self.vertex_buffer orelse return;
        const sib = self.sprite_instance_buffer orelse return;
        const srv = self.sprite_instance_srv orelse return;
        const cb = self.sprite_constant_buffer orelse return;
        const sampler = self.sprite_sampler orelse return;
        const layout = self.input_layout orelse return;
        
        // Upload instance data
        var mapped: d3d11.D3D11_MAPPED_SUBRESOURCE = undefined;
        const map_hr = self.context.vtable.Map(self.context, @ptrCast(sib), 0, .WRITE_DISCARD, 0, &mapped);
        if (map_hr != S_OK) return;
        
        const dest: [*]SpriteInstance = @ptrCast(@alignCast(mapped.pData));
        @memcpy(dest[0..instances.len], instances);
        self.context.vtable.Unmap(self.context, @ptrCast(sib), 0);
        
        // Update constant buffer
        var cb_mapped: d3d11.D3D11_MAPPED_SUBRESOURCE = undefined;
        const cb_map_hr = self.context.vtable.Map(self.context, @ptrCast(cb), 0, .WRITE_DISCARD, 0, &cb_mapped);
        if (cb_map_hr != S_OK) return;
        
        const params: *SpriteGlobalParams = @ptrCast(@alignCast(cb_mapped.pData));
        params.* = .{
            .viewport_size = .{ @floatFromInt(self.width), @floatFromInt(self.height) },
            .is_mono = if (is_mono) 1 else 0,
            ._padding = 0,
        };
        self.context.vtable.Unmap(self.context, @ptrCast(cb), 0);
        
        // Set shaders
        self.context.vtable.VSSetShader(self.context, vs, null, 0);
        self.context.vtable.PSSetShader(self.context, ps, null, 0);
        
        // Set input layout and vertex buffer (same quad as quads)
        self.context.vtable.IASetInputLayout(self.context, layout);
        var vbs = [1]?*d3d11.ID3D11Buffer{vb};
        var strides = [1]u32{@sizeOf(f32) * 2};
        var offsets = [1]u32{0};
        self.context.vtable.IASetVertexBuffers(self.context, 0, 1, @ptrCast(&vbs), &strides, &offsets);
        self.context.vtable.IASetPrimitiveTopology(self.context, ._PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        
        // Set blend state
        if (self.blend_state) |bs| {
            const blend_factor = [4]f32{ 0, 0, 0, 0 };
            self.context.vtable.OMSetBlendState(self.context, bs, @ptrCast(&blend_factor), 0xFFFFFFFF);
        }
        
        // Set constant buffer
        var cbs = [1]?*d3d11.ID3D11Buffer{cb};
        self.context.vtable.VSSetConstantBuffers(self.context, 0, 1, @ptrCast(&cbs));
        self.context.vtable.PSSetConstantBuffers(self.context, 0, 1, @ptrCast(&cbs));
        
        // Set instance SRV (slot 0 for instances)
        var inst_srvs = [1]?*d3d11.ID3D11ShaderResourceView{srv};
        self.context.vtable.VSSetShaderResources(self.context, 0, 1, @ptrCast(&inst_srvs));
        
        // Set texture SRV (slot 1 for texture)
        var tex_srvs = [1]?*d3d11.ID3D11ShaderResourceView{texture_srv};
        self.context.vtable.PSSetShaderResources(self.context, 1, 1, @ptrCast(&tex_srvs));
        
        // Set sampler
        var samplers = [1]?*d3d11.ID3D11SamplerState{sampler};
        self.context.vtable.PSSetSamplers(self.context, 0, 1, @ptrCast(&samplers));
        
        // Draw instanced
        self.context.vtable.DrawInstanced(self.context, 6, @intCast(instances.len), 0, 0);
    }

    pub fn present(self: *D3D11Renderer, vsync: bool) void {
        const sync_interval: u32 = if (vsync) 1 else 0;
        _ = self.swap_chain.vtable.Present(self.swap_chain, sync_interval, 0);
    }

    // ========================================================================
    // Scene Integration
    // ========================================================================

    /// Draw a scene containing quads, shadows, and sprites
    pub fn drawScene(self: *D3D11Renderer, scene: *const Scene) void {
        // Draw shadows first (behind everything)
        const shadows = scene.getShadows();
        if (shadows.len > 0) {
            // TODO: Implement shadow rendering for D3D11
            // For now, shadows are skipped
        }

        // Draw quads
        const quads = scene.getQuads();
        if (quads.len > 0) {
            var instances: [256]QuadInstance = undefined;
            const count = @min(quads.len, 256);
            
            for (quads[0..count], 0..) |q, i| {
                instances[i] = sceneQuadToInstance(q);
            }
            
            self.drawQuads(instances[0..count]);
        }

        // Note: Sprites (text) require a texture atlas.
        // Use D3D11TextRenderer for text rendering instead.
    }

    /// Convert a scene Quad to a D3D11 QuadInstance
    fn sceneQuadToInstance(q: scene_mod.Quad) QuadInstance {
        const bg_color = if (q.background) |bg| switch (bg) {
            .solid => |c| hslaToRgba(c),
        } else [4]f32{ 0, 0, 0, 0 };

        const border_color = if (q.border_color) |c| hslaToRgba(c) else [4]f32{ 0, 0, 0, 0 };

        const mask = if (q.content_mask) |m| [4]f32{ m.origin.x, m.origin.y, m.size.width, m.size.height } else [4]f32{ 0, 0, 0, 0 };

        return .{
            .bounds = .{ q.bounds.origin.x, q.bounds.origin.y, q.bounds.size.width, q.bounds.size.height },
            .background_color = bg_color,
            .border_color = border_color,
            .border_widths = .{ q.border_widths.top, q.border_widths.right, q.border_widths.bottom, q.border_widths.left },
            .corner_radii = .{ q.corner_radii.top_left, q.corner_radii.top_right, q.corner_radii.bottom_right, q.corner_radii.bottom_left },
            .content_mask = mask,
            .border_style = .{ if (q.border_style == .dashed) 1.0 else 0.0, 0, 0, 0 },
        };
    }

    /// Convert HSLA color to RGBA float array
    fn hslaToRgba(hsla: Hsla) [4]f32 {
        const rgb = hsla.toRgba();
        return .{ rgb.r, rgb.g, rgb.b, rgb.a };
    }
};

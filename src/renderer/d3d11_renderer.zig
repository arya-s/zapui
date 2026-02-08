//! DirectX 11 Renderer
//!
//! Native Windows renderer using Direct3D 11.

const std = @import("std");
const win32 = @import("win32");

const d3d11 = win32.graphics.direct3d11;
const d3d = win32.graphics.direct3d;
const dxgi = win32.graphics.dxgi;
const fxc = win32.graphics.direct3d.fxc;
const foundation = win32.foundation;

const ID3DBlob = d3d.ID3DBlob;

const HWND = foundation.HWND;
const HRESULT = foundation.HRESULT;
const S_OK = foundation.S_OK;

const Allocator = std.mem.Allocator;

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

// Global params constant buffer
const GlobalParams = extern struct {
    viewport_size: [2]f32,
    _padding: [2]f32,
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
    }

    pub fn deinit(self: *D3D11Renderer) void {
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

    pub fn present(self: *D3D11Renderer, vsync: bool) void {
        const sync_interval: u32 = if (vsync) 1 else 0;
        _ = self.swap_chain.vtable.Present(self.swap_chain, sync_interval, 0);
    }
};

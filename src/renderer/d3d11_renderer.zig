//! DirectX 11 Renderer
//!
//! Native Windows renderer using Direct3D 11.

const std = @import("std");
const win32 = @import("win32");

const d3d11 = win32.graphics.direct3d11;
const d3d = win32.graphics.direct3d;
const dxgi = win32.graphics.dxgi;
const foundation = win32.foundation;
const com = win32.system.com;

const HWND = foundation.HWND;
const HRESULT = foundation.HRESULT;
const S_OK = foundation.S_OK;

const Allocator = std.mem.Allocator;

// Helper to release COM objects
fn release(comptime T: type, obj: *T) void {
    _ = obj.IUnknown.vtable.Release(&obj.IUnknown);
}

pub const D3D11Renderer = struct {
    allocator: Allocator,
    device: *d3d11.ID3D11Device,
    context: *d3d11.ID3D11DeviceContext,
    swap_chain: *dxgi.IDXGISwapChain,
    render_target_view: ?*d3d11.ID3D11RenderTargetView,

    width: u32,
    height: u32,

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
        swap_chain_desc.Windowed = 1; // TRUE
        swap_chain_desc.SwapEffect = .DISCARD;

        // Feature levels to try
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

        // Create device and swap chain
        const hr = d3d11.D3D11CreateDeviceAndSwapChain(
            null, // adapter
            .HARDWARE,
            null, // software module
            .{}, // flags
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
            .width = width,
            .height = height,
        };

        // Create render target view
        try self.createRenderTargetView();

        std.debug.print("D3D11 initialized: {}x{}, feature level: {}\n", .{ width, height, @intFromEnum(feature_level) });

        return self;
    }

    fn createRenderTargetView(self: *D3D11Renderer) !void {
        // Get back buffer
        var back_buffer: *d3d11.ID3D11Texture2D = undefined;
        const hr1 = self.swap_chain.vtable.GetBuffer(
            self.swap_chain,
            0,
            d3d11.IID_ID3D11Texture2D,
            @ptrCast(&back_buffer),
        );
        if (hr1 != S_OK) {
            std.debug.print("GetBuffer failed: 0x{x}\n", .{@as(u32, @bitCast(hr1))});
            return error.GetBufferFailed;
        }
        defer release(d3d11.ID3D11Texture2D, back_buffer);

        // Create render target view
        var rtv: *d3d11.ID3D11RenderTargetView = undefined;
        const hr2 = self.device.vtable.CreateRenderTargetView(
            self.device,
            @ptrCast(back_buffer),
            null,
            @ptrCast(&rtv),
        );
        if (hr2 != S_OK) {
            std.debug.print("CreateRenderTargetView failed: 0x{x}\n", .{@as(u32, @bitCast(hr2))});
            return error.CreateRenderTargetViewFailed;
        }

        self.render_target_view = rtv;
    }

    pub fn deinit(self: *D3D11Renderer) void {
        if (self.render_target_view) |rtv| {
            release(d3d11.ID3D11RenderTargetView, rtv);
        }
        release(dxgi.IDXGISwapChain, self.swap_chain);
        release(d3d11.ID3D11DeviceContext, self.context);
        release(d3d11.ID3D11Device, self.device);
    }

    pub fn resize(self: *D3D11Renderer, width: u32, height: u32) !void {
        if (width == 0 or height == 0) return;

        self.width = width;
        self.height = height;

        // Release render target view
        if (self.render_target_view) |rtv| {
            release(d3d11.ID3D11RenderTargetView, rtv);
            self.render_target_view = null;
        }

        // Unbind render target
        self.context.vtable.OMSetRenderTargets(self.context, 0, null, null);

        // Resize buffers
        const hr = self.swap_chain.vtable.ResizeBuffers(
            self.swap_chain,
            0, // preserve buffer count
            width,
            height,
            .UNKNOWN, // preserve format
            0,
        );
        if (hr != S_OK) {
            std.debug.print("ResizeBuffers failed: 0x{x}\n", .{@as(u32, @bitCast(hr))});
            return error.ResizeBuffersFailed;
        }

        // Recreate render target view
        try self.createRenderTargetView();
    }

    pub fn clear(self: *D3D11Renderer, r: f32, g: f32, b: f32, a: f32) void {
        const rtv = self.render_target_view orelse return;

        const clear_color = [4]f32{ r, g, b, a };
        self.context.vtable.ClearRenderTargetView(self.context, rtv, @ptrCast(&clear_color));
    }

    pub fn beginFrame(self: *D3D11Renderer) void {
        const rtv = self.render_target_view orelse return;

        // Set render target
        var rtvs = [1]?*d3d11.ID3D11RenderTargetView{rtv};
        self.context.vtable.OMSetRenderTargets(self.context, 1, @ptrCast(&rtvs), null);

        // Set viewport
        const viewport = d3d11.D3D11_VIEWPORT{
            .TopLeftX = 0,
            .TopLeftY = 0,
            .Width = @floatFromInt(self.width),
            .Height = @floatFromInt(self.height),
            .MinDepth = 0,
            .MaxDepth = 1,
        };
        self.context.vtable.RSSetViewports(self.context, 1, @ptrCast(&viewport));
    }

    pub fn present(self: *D3D11Renderer, vsync: bool) void {
        const sync_interval: u32 = if (vsync) 1 else 0;
        _ = self.swap_chain.vtable.Present(self.swap_chain, sync_interval, 0);
    }
};

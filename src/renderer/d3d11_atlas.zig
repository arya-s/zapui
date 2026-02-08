//! D3D11 GPU-backed texture atlas with lazy synchronization.
//!
//! Wraps a CPU-side Atlas and manages a D3D11 texture that is
//! automatically re-uploaded when the atlas data changes.

const std = @import("std");
const win32 = @import("win32");
const atlas_mod = @import("atlas.zig");

const d3d11 = win32.graphics.direct3d11;
const dxgi = win32.graphics.dxgi;
const foundation = win32.foundation;

const S_OK = foundation.S_OK;
const Allocator = std.mem.Allocator;

const Atlas = atlas_mod.Atlas;
const Format = atlas_mod.Format;

// Helper to release COM objects
fn release(comptime T: type, obj: *T) void {
    _ = obj.IUnknown.vtable.Release(&obj.IUnknown);
}

pub const D3D11Atlas = struct {
    /// CPU-side atlas data
    atlas: Atlas,
    /// D3D11 texture
    texture: ?*d3d11.ID3D11Texture2D,
    /// Shader resource view for sampling
    srv: ?*d3d11.ID3D11ShaderResourceView,
    /// D3D11 device reference (for texture updates)
    device: *d3d11.ID3D11Device,
    /// D3D11 context reference (for texture updates)
    context: *d3d11.ID3D11DeviceContext,
    /// Last synced modification counter
    last_synced: usize,

    pub fn init(
        allocator: Allocator,
        device: *d3d11.ID3D11Device,
        context: *d3d11.ID3D11DeviceContext,
        size: u32,
        format: Format,
    ) !D3D11Atlas {
        var cpu_atlas = try Atlas.init(allocator, size, format);
        errdefer cpu_atlas.deinit();

        // Create D3D11 texture
        var tex_desc = std.mem.zeroes(d3d11.D3D11_TEXTURE2D_DESC);
        tex_desc.Width = size;
        tex_desc.Height = size;
        tex_desc.MipLevels = 1;
        tex_desc.ArraySize = 1;
        tex_desc.Format = if (format == .grayscale) .R8_UNORM else .B8G8R8A8_UNORM;
        tex_desc.SampleDesc.Count = 1;
        tex_desc.Usage = .DEFAULT;
        tex_desc.BindFlags = .{ .SHADER_RESOURCE = 1 };

        var texture: *d3d11.ID3D11Texture2D = undefined;
        const tex_hr = device.vtable.CreateTexture2D(device, &tex_desc, null, @ptrCast(&texture));
        if (tex_hr != S_OK) return error.CreateTextureFailed;
        errdefer release(d3d11.ID3D11Texture2D, texture);

        // Create SRV
        var srv_desc = std.mem.zeroes(d3d11.D3D11_SHADER_RESOURCE_VIEW_DESC);
        srv_desc.Format = tex_desc.Format;
        srv_desc.ViewDimension = ._DIMENSION_TEXTURE2D;
        srv_desc.Anonymous.Texture2D.MostDetailedMip = 0;
        srv_desc.Anonymous.Texture2D.MipLevels = 1;

        var srv: *d3d11.ID3D11ShaderResourceView = undefined;
        const srv_hr = device.vtable.CreateShaderResourceView(device, @ptrCast(texture), &srv_desc, @ptrCast(&srv));
        if (srv_hr != S_OK) return error.CreateSRVFailed;

        return .{
            .atlas = cpu_atlas,
            .texture = texture,
            .srv = srv,
            .device = device,
            .context = context,
            .last_synced = 0, // Force initial sync
        };
    }

    pub fn deinit(self: *D3D11Atlas) void {
        if (self.srv) |srv| {
            release(d3d11.ID3D11ShaderResourceView, srv);
            self.srv = null;
        }
        if (self.texture) |tex| {
            release(d3d11.ID3D11Texture2D, tex);
            self.texture = null;
        }
        self.atlas.deinit();
    }

    /// Sync the CPU atlas to the GPU texture if modified.
    /// Call this before rendering.
    pub fn sync(self: *D3D11Atlas) void {
        const current = self.atlas.getModified();
        if (current == self.last_synced) return;

        const texture = self.texture orelse return;

        // Upload entire texture (D3D11 UpdateSubresource)
        const row_pitch: u32 = self.atlas.size * self.atlas.format.depth();
        
        const box = d3d11.D3D11_BOX{
            .left = 0,
            .top = 0,
            .front = 0,
            .right = self.atlas.size,
            .bottom = self.atlas.size,
            .back = 1,
        };
        
        self.context.vtable.UpdateSubresource(
            self.context,
            @ptrCast(texture),
            0,
            &box,
            self.atlas.data.ptr,
            row_pitch,
            0,
        );

        self.last_synced = current;
    }

    /// Bind the texture to a shader slot
    pub fn bind(self: *D3D11Atlas, slot: u32) void {
        self.sync();
        
        const srv = self.srv orelse return;
        var srvs = [1]?*d3d11.ID3D11ShaderResourceView{srv};
        self.context.vtable.PSSetShaderResources(self.context, slot, 1, @ptrCast(&srvs));
    }

    /// Get the underlying CPU atlas for allocation
    pub fn getCpuAtlas(self: *D3D11Atlas) *Atlas {
        return &self.atlas;
    }
};

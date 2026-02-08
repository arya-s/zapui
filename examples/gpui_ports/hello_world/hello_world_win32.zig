//! Hello World - Native Win32 + DirectX 11 version
//!
//! This is the same hello_world example but using native Win32 windowing
//! and D3D11 rendering with actual text using FreeType.

const std = @import("std");
const zapui = @import("zapui");
const freetype = @import("freetype");

const d3d11 = zapui.renderer.d3d11_renderer.d3d11;
const S_OK = zapui.renderer.d3d11_renderer.S_OK;

// Use Win32 platform
const win32_platform = zapui.platform.Win32Backend;
const D3D11Renderer = zapui.renderer.d3d11_renderer.D3D11Renderer;
const QuadInstance = zapui.renderer.d3d11_renderer.QuadInstance;
const SpriteInstance = zapui.renderer.d3d11_renderer.SpriteInstance;

fn release(comptime T: type, obj: *T) void {
    _ = obj.IUnknown.vtable.Release(&obj.IUnknown);
}

// Embedded font
const font_data = @embedFile("LiberationSans-Regular.ttf");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Initialize FreeType
    const ft_lib = freetype.Library.init() catch {
        std.debug.print("Failed to initialize FreeType\n", .{});
        return error.FreeTypeInitFailed;
    };
    defer ft_lib.deinit();
    
    // Load font
    const face = ft_lib.initMemoryFace(font_data, 0) catch {
        std.debug.print("Failed to load font\n", .{});
        return error.FontLoadFailed;
    };
    defer face.deinit();
    
    // Set font size
    face.setPixelSizes(0, 24) catch {
        std.debug.print("Failed to set font size\n", .{});
        return error.FontSizeFailed;
    };

    // Initialize Win32 platform
    var plat = try win32_platform.init();
    defer plat.deinit();

    // Create window
    const window = try win32_platform.createWindow(&plat, .{
        .width = 500,
        .height = 500,
        .title = "Hello World - ZapUI (Win32 + D3D11)",
    });
    defer window.destroy();

    std.debug.print("Hello World - ZapUI (Win32 + D3D11)\n", .{});
    std.debug.print("Press ESC or close window to exit\n", .{});

    // Initialize D3D11 renderer
    var renderer = D3D11Renderer.init(allocator, window.hwnd.?, 500, 500) catch |err| {
        std.debug.print("Failed to initialize D3D11: {}\n", .{err});
        return err;
    };
    defer renderer.deinit();
    
    // Create a texture atlas for glyphs (256x256)
    const atlas_size: u32 = 256;
    var atlas_data = try allocator.alloc(u8, atlas_size * atlas_size);
    defer allocator.free(atlas_data);
    @memset(atlas_data, 0);
    
    // Render "Hello, World!" glyphs into atlas
    const text = "Hello, World!";
    var glyph_x: u32 = 2;
    const glyph_y: u32 = 2;
    
    // Store glyph info for rendering
    const GlyphInfo = struct {
        atlas_x: u32,
        atlas_y: u32,
        width: u32,
        height: u32,
        bearing_x: i32,
        bearing_y: i32,
        advance: i32,
    };
    
    var glyph_infos: [text.len]GlyphInfo = undefined;
    
    for (text, 0..) |char, i| {
        // Get glyph index
        const glyph_index = face.getCharIndex(char) orelse continue;
        
        // Load glyph
        face.loadGlyph(glyph_index, .{ .render = true }) catch continue;
        
        const glyph = face.handle.*.glyph;
        const bitmap = &glyph.*.bitmap;
        
        if (bitmap.width > 0 and bitmap.rows > 0) {
            // Copy glyph bitmap to atlas
            const src: [*]const u8 = @ptrCast(bitmap.buffer);
            const w = bitmap.width;
            const h = bitmap.rows;
            const pitch = @as(u32, @intCast(if (bitmap.pitch < 0) -bitmap.pitch else bitmap.pitch));
            
            for (0..h) |row| {
                const dst_row = (glyph_y + row) * atlas_size + glyph_x;
                const src_row = row * pitch;
                for (0..w) |col| {
                    atlas_data[dst_row + col] = src[src_row + col];
                }
            }
            
            glyph_infos[i] = .{
                .atlas_x = glyph_x,
                .atlas_y = glyph_y,
                .width = w,
                .height = h,
                .bearing_x = glyph.*.bitmap_left,
                .bearing_y = glyph.*.bitmap_top,
                .advance = @intCast(glyph.*.advance.x >> 6),
            };
            
            glyph_x += w + 2; // Add padding between glyphs
        } else {
            // Space or non-rendered glyph
            glyph_infos[i] = .{
                .atlas_x = 0,
                .atlas_y = 0,
                .width = 0,
                .height = 0,
                .bearing_x = 0,
                .bearing_y = 0,
                .advance = @intCast(glyph.*.advance.x >> 6),
            };
        }
    }
    
    // Create D3D11 texture for atlas
    var tex_desc = std.mem.zeroes(d3d11.D3D11_TEXTURE2D_DESC);
    tex_desc.Width = atlas_size;
    tex_desc.Height = atlas_size;
    tex_desc.MipLevels = 1;
    tex_desc.ArraySize = 1;
    tex_desc.Format = .R8_UNORM;
    tex_desc.SampleDesc.Count = 1;
    tex_desc.Usage = .DEFAULT;
    tex_desc.BindFlags = .{ .SHADER_RESOURCE = 1 };
    
    var init_data = std.mem.zeroes(d3d11.D3D11_SUBRESOURCE_DATA);
    init_data.pSysMem = atlas_data.ptr;
    init_data.SysMemPitch = atlas_size;
    
    var atlas_texture: ?*d3d11.ID3D11Texture2D = null;
    const tex_hr = renderer.device.vtable.CreateTexture2D(renderer.device, &tex_desc, &init_data, @ptrCast(&atlas_texture));
    if (tex_hr != S_OK or atlas_texture == null) {
        std.debug.print("Failed to create atlas texture\n", .{});
        return error.CreateTextureFailed;
    }
    defer if (atlas_texture) |t| release(d3d11.ID3D11Texture2D, t);
    
    // Create SRV for atlas
    var srv_desc = std.mem.zeroes(d3d11.D3D11_SHADER_RESOURCE_VIEW_DESC);
    srv_desc.Format = .R8_UNORM;
    srv_desc.ViewDimension = ._SRV_DIMENSION_TEXTURE2D;
    srv_desc.Anonymous.Texture2D.MostDetailedMip = 0;
    srv_desc.Anonymous.Texture2D.MipLevels = 1;
    
    var atlas_srv: ?*d3d11.ID3D11ShaderResourceView = null;
    const srv_hr = renderer.device.vtable.CreateShaderResourceView(renderer.device, @ptrCast(atlas_texture), &srv_desc, @ptrCast(&atlas_srv));
    if (srv_hr != S_OK or atlas_srv == null) {
        std.debug.print("Failed to create atlas SRV\n", .{});
        return error.CreateSRVFailed;
    }
    defer if (atlas_srv) |s| release(d3d11.ID3D11ShaderResourceView, s);

    // Main loop
    while (!window.shouldClose()) {
        const events = window.pollEvents();

        for (events) |event| {
            switch (event) {
                .key => |k| {
                    if (k.key == .escape and k.action == .press) {
                        return;
                    }
                },
                .resize => |r| {
                    renderer.resize(r.width, r.height) catch {};
                },
                else => {},
            }
        }

        // Render frame
        renderer.beginFrame();
        // No separate clear - the root div fills the entire window like GPUI
        renderer.clear(0.0, 0.0, 0.0, 1.0); // Black (won't be visible - root div covers all)
        
        // Root div is full window size (500x500) matching GPUI's .size(px(500))
        const container_size: f32 = 500;
        const container_x: f32 = 0;
        const container_y: f32 = 0;
        
        // Draw colored boxes like in hello_world
        // size_8 = 32px (2rem), gap_2 = 8px (0.5rem)
        const box_size: f32 = 32;
        const gap: f32 = 8;
        const total_width = 6 * box_size + 5 * gap;
        const boxes_x = container_x + (container_size - total_width) / 2;
        const boxes_y = container_y + container_size / 2 + 20;
        
        var quads: [7]QuadInstance = undefined;
        
        // Main container
        quads[0] = .{
            .bounds = .{ container_x, container_y, container_size, container_size },
            .background_color = .{ 0.31, 0.31, 0.31, 1.0 }, // rgb(0x505050)
            .border_color = .{ 0.0, 0.0, 1.0, 1.0 }, // blue
            .border_widths = .{ 1, 1, 1, 1 },
            .corner_radii = .{ 0, 0, 0, 0 },
            .content_mask = .{ 0, 0, 0, 0 },
            .border_style = .{ 0, 0, 0, 0 },
        };
        
        // Red box
        quads[1] = .{
            .bounds = .{ boxes_x + 0 * (box_size + gap), boxes_y, box_size, box_size },
            .background_color = .{ 1.0, 0.0, 0.0, 1.0 },
            .border_color = .{ 1.0, 1.0, 1.0, 1.0 },
            .border_widths = .{ 1, 1, 1, 1 },
            .corner_radii = .{ 4, 4, 4, 4 },
            .content_mask = .{ 0, 0, 0, 0 },
            .border_style = .{ 1, 0, 0, 0 }, // dashed
        };
        
        // Green box
        quads[2] = .{
            .bounds = .{ boxes_x + 1 * (box_size + gap), boxes_y, box_size, box_size },
            .background_color = .{ 0.0, 0.5, 0.0, 1.0 }, // GPUI green
            .border_color = .{ 1.0, 1.0, 1.0, 1.0 },
            .border_widths = .{ 1, 1, 1, 1 },
            .corner_radii = .{ 4, 4, 4, 4 },
            .content_mask = .{ 0, 0, 0, 0 },
            .border_style = .{ 1, 0, 0, 0 },
        };
        
        // Blue box
        quads[3] = .{
            .bounds = .{ boxes_x + 2 * (box_size + gap), boxes_y, box_size, box_size },
            .background_color = .{ 0.0, 0.0, 1.0, 1.0 },
            .border_color = .{ 1.0, 1.0, 1.0, 1.0 },
            .border_widths = .{ 1, 1, 1, 1 },
            .corner_radii = .{ 4, 4, 4, 4 },
            .content_mask = .{ 0, 0, 0, 0 },
            .border_style = .{ 1, 0, 0, 0 },
        };
        
        // Yellow box
        quads[4] = .{
            .bounds = .{ boxes_x + 3 * (box_size + gap), boxes_y, box_size, box_size },
            .background_color = .{ 1.0, 1.0, 0.0, 1.0 },
            .border_color = .{ 1.0, 1.0, 1.0, 1.0 },
            .border_widths = .{ 1, 1, 1, 1 },
            .corner_radii = .{ 4, 4, 4, 4 },
            .content_mask = .{ 0, 0, 0, 0 },
            .border_style = .{ 1, 0, 0, 0 },
        };
        
        // Black box
        quads[5] = .{
            .bounds = .{ boxes_x + 4 * (box_size + gap), boxes_y, box_size, box_size },
            .background_color = .{ 0.0, 0.0, 0.0, 1.0 },
            .border_color = .{ 1.0, 1.0, 1.0, 1.0 },
            .border_widths = .{ 1, 1, 1, 1 },
            .corner_radii = .{ 4, 4, 4, 4 },
            .content_mask = .{ 0, 0, 0, 0 },
            .border_style = .{ 1, 0, 0, 0 },
        };
        
        // White box
        quads[6] = .{
            .bounds = .{ boxes_x + 5 * (box_size + gap), boxes_y, box_size, box_size },
            .background_color = .{ 1.0, 1.0, 1.0, 1.0 },
            .border_color = .{ 0.0, 0.0, 0.0, 1.0 }, // black border
            .border_widths = .{ 1, 1, 1, 1 },
            .corner_radii = .{ 4, 4, 4, 4 },
            .content_mask = .{ 0, 0, 0, 0 },
            .border_style = .{ 1, 0, 0, 0 },
        };
        
        renderer.drawQuads(&quads);
        
        // Draw text using FreeType glyphs
        // Calculate text width for centering
        var text_width: f32 = 0;
        for (glyph_infos) |info| {
            text_width += @floatFromInt(info.advance);
        }
        
        const text_x = container_x + (container_size - text_width) / 2;
        const text_y = container_y + container_size / 2 - 30;
        const baseline_y = text_y + 24; // Font size
        
        var sprites: [text.len]SpriteInstance = undefined;
        var cursor_x = text_x;
        var sprite_count: usize = 0;
        
        const atlas_size_f: f32 = @floatFromInt(atlas_size);
        
        for (glyph_infos) |info| {
            if (info.width > 0 and info.height > 0) {
                const gx = cursor_x + @as(f32, @floatFromInt(info.bearing_x));
                const gy = baseline_y - @as(f32, @floatFromInt(info.bearing_y));
                
                sprites[sprite_count] = .{
                    .bounds = .{ 
                        gx, 
                        gy, 
                        @floatFromInt(info.width), 
                        @floatFromInt(info.height) 
                    },
                    .uv_bounds = .{
                        @as(f32, @floatFromInt(info.atlas_x)) / atlas_size_f,
                        @as(f32, @floatFromInt(info.atlas_y)) / atlas_size_f,
                        @as(f32, @floatFromInt(info.width)) / atlas_size_f,
                        @as(f32, @floatFromInt(info.height)) / atlas_size_f,
                    },
                    .color = .{ 1.0, 1.0, 1.0, 1.0 }, // White text
                    .content_mask = .{ 0, 0, 0, 0 },
                };
                sprite_count += 1;
            }
            cursor_x += @floatFromInt(info.advance);
        }
        
        if (sprite_count > 0) {
            renderer.drawSprites(sprites[0..sprite_count], atlas_srv.?, true);
        }

        renderer.present(true);
    }
}

//! Hello World - Port of GPUI's hello_world.rs example

const std = @import("std");
const zapui = @import("zapui");
const freetype = @import("freetype");

const d3d11 = zapui.renderer.d3d11_renderer.d3d11;
const D3D11Renderer = zapui.renderer.d3d11_renderer.D3D11Renderer;
const QuadInstance = zapui.renderer.d3d11_renderer.QuadInstance;
const SpriteInstance = zapui.renderer.d3d11_renderer.SpriteInstance;
const Win32 = zapui.platform.Win32Backend;

// Colors
fn rgb(hex: u24) [4]f32 {
    return .{
        @as(f32, @floatFromInt((hex >> 16) & 0xFF)) / 255.0,
        @as(f32, @floatFromInt((hex >> 8) & 0xFF)) / 255.0,
        @as(f32, @floatFromInt(hex & 0xFF)) / 255.0,
        1.0,
    };
}
// rgb(0x0000ff)
// rgb(0x505050)
const black = [4]f32{ 0, 0, 0, 1 };
const blue = [4]f32{ 0, 0, 1, 1 };
// rgb(0xffffff)
const green = [4]f32{ 0, 0.5, 0, 1 }; // gpui::green()
const red = [4]f32{ 1, 0, 0, 1 };
const white = [4]f32{ 1, 1, 1, 1 };
const yellow = [4]f32{ 1, 1, 0, 1 };

// ============================================================================
// HelloWorld
// ============================================================================

const HelloWorld = struct {
    text: []const u8,

    fn render(self: *HelloWorld, renderer: *D3D11Renderer, text_renderer: anytype) void {
        // div()
        //     .flex().flex_col().gap_3()
        //     .bg(rgb(0x505050))
        //     .size(px(500.0))
        //     .justify_center().items_center()
        //     .text_xl().text_color(rgb(0xffffff))
        //     .child(format!("Hello, {}!", &self.text))
        //     .child(div().flex().gap_2()
        //         .child(div().size_8().bg(gpui::red()).border_1().border_dashed().rounded_md().border_color(gpui::white()))
        //         .child(div().size_8().bg(gpui::green()).border_1().border_dashed().rounded_md().border_color(gpui::white()))
        //         .child(div().size_8().bg(gpui::blue()).border_1().border_dashed().rounded_md().border_color(gpui::white()))
        //         .child(div().size_8().bg(gpui::yellow()).border_1().border_dashed().rounded_md().border_color(gpui::white()))
        //         .child(div().size_8().bg(gpui::black()).border_1().border_dashed().rounded_md().border_color(gpui::white()))
        //         .child(div().size_8().bg(gpui::white()).border_1().border_dashed().rounded_md().border_color(gpui::black()))
        //     )

        const bg = rgb(0x505050);
        renderer.clear(bg[0], bg[1], bg[2], bg[3]);

        // Layout: flex_col, justify_center, items_center, gap_3
        const size_8: f32 = 32;
        const gap_2: f32 = 8;
        const gap_3: f32 = 12;
        const text_xl: f32 = 20;

        const content_h = text_xl + gap_3 + size_8;
        const y = (500 - content_h) / 2;
        const row_w = 6 * size_8 + 5 * gap_2;
        const x = (500 - row_w) / 2;

        // .child(format!("Hello, {}!", &self.text))
        var buf: [64]u8 = undefined;
        const label = std.fmt.bufPrint(&buf, "Hello, {s}!", .{self.text}) catch "Hello!";
        text_renderer.draw(renderer, label, 250, y + 16, white);

        // .child(div().flex().gap_2() ...)
        const row_y = y + text_xl + gap_3;
        const quads = [_]QuadInstance{
            quad(x + 0 * (size_8 + gap_2), row_y, size_8, red, white),
            quad(x + 1 * (size_8 + gap_2), row_y, size_8, green, white),
            quad(x + 2 * (size_8 + gap_2), row_y, size_8, blue, white),
            quad(x + 3 * (size_8 + gap_2), row_y, size_8, yellow, white),
            quad(x + 4 * (size_8 + gap_2), row_y, size_8, black, white),
            quad(x + 5 * (size_8 + gap_2), row_y, size_8, white, black),
        };
        renderer.drawQuads(&quads);
    }
};

// Helper: div().size(s).bg(bg).border_1().border_dashed().rounded_md().border_color(border)
fn quad(x: f32, y: f32, size: f32, bg: [4]f32, border: [4]f32) QuadInstance {
    return .{
        .bounds = .{ x, y, size, size },
        .background_color = bg,
        .border_color = border,
        .border_widths = .{ 1, 1, 1, 1 },
        .corner_radii = .{ 6, 6, 6, 6 },
        .border_style = .{ 1, 0, 0, 0 }, // dashed
        .content_mask = .{ 0, 0, 0, 0 },
    };
}

// ============================================================================
// Text Rendering (GPUI handles this internally)
// ============================================================================

const TextRenderer = struct {
    srv: *d3d11.ID3D11ShaderResourceView,
    glyphs: [128]Glyph,
    size: f32,

    const Glyph = struct { u: f32, v: f32, w: f32, h: f32, bx: f32, by: f32, adv: f32 };

    fn init(alloc: std.mem.Allocator, renderer: *D3D11Renderer) !TextRenderer {
        const ft = try freetype.Library.init();
        defer ft.deinit();
        const face = try ft.initMemoryFace(@embedFile("LiberationSans-Regular.ttf"), 0);
        defer face.deinit();
        try face.setPixelSizes(0, 20);

        const size: u32 = 256;
        var data = try alloc.alloc(u8, size * size);
        defer alloc.free(data);
        @memset(data, 0);

        var glyphs: [128]Glyph = undefined;
        var px: u32 = 2;
        for (32..127) |c| {
            const idx = face.getCharIndex(@intCast(c)) orelse continue;
            face.loadGlyph(idx, .{ .render = true }) catch continue;
            const g = face.handle.*.glyph;
            const bmp = &g.*.bitmap;
            if (bmp.width > 0 and bmp.rows > 0) {
                const src: [*]const u8 = @ptrCast(bmp.buffer);
                const pitch: u32 = @intCast(if (bmp.pitch < 0) -bmp.pitch else bmp.pitch);
                for (0..bmp.rows) |row| {
                    for (0..bmp.width) |col| {
                        data[(2 + row) * size + px + col] = src[row * pitch + col];
                    }
                }
            }
            const sf: f32 = @floatFromInt(size);
            glyphs[c] = .{
                .u = @as(f32, @floatFromInt(px)) / sf,
                .v = 2.0 / sf,
                .w = @as(f32, @floatFromInt(bmp.width)) / sf,
                .h = @as(f32, @floatFromInt(bmp.rows)) / sf,
                .bx = @floatFromInt(g.*.bitmap_left),
                .by = @floatFromInt(g.*.bitmap_top),
                .adv = @floatFromInt(g.*.advance.x >> 6),
            };
            px += bmp.width + 2;
        }

        var desc = std.mem.zeroes(d3d11.D3D11_TEXTURE2D_DESC);
        desc.Width = size;
        desc.Height = size;
        desc.MipLevels = 1;
        desc.ArraySize = 1;
        desc.Format = .R8_UNORM;
        desc.SampleDesc.Count = 1;
        desc.BindFlags = .{ .SHADER_RESOURCE = 1 };
        var sub = std.mem.zeroes(d3d11.D3D11_SUBRESOURCE_DATA);
        sub.pSysMem = data.ptr;
        sub.SysMemPitch = size;
        var tex: ?*d3d11.ID3D11Texture2D = null;
        _ = renderer.device.vtable.CreateTexture2D(renderer.device, &desc, &sub, @ptrCast(&tex));
        var srv_desc = std.mem.zeroes(d3d11.D3D11_SHADER_RESOURCE_VIEW_DESC);
        srv_desc.Format = .R8_UNORM;
        srv_desc.ViewDimension = ._SRV_DIMENSION_TEXTURE2D;
        srv_desc.Anonymous.Texture2D.MipLevels = 1;
        var srv: ?*d3d11.ID3D11ShaderResourceView = null;
        _ = renderer.device.vtable.CreateShaderResourceView(renderer.device, @ptrCast(tex), &srv_desc, @ptrCast(&srv));

        return .{ .srv = srv.?, .glyphs = glyphs, .size = @floatFromInt(size) };
    }

    fn draw(self: *TextRenderer, renderer: *D3D11Renderer, str: []const u8, cx: f32, baseline: f32, color: [4]f32) void {
        var w: f32 = 0;
        for (str) |c| {
            if (c < 128) w += self.glyphs[c].adv;
        }

        var sprites: [64]SpriteInstance = undefined;
        var n: usize = 0;
        var x = cx - w / 2;
        for (str) |c| {
            if (c >= 128) continue;
            const g = self.glyphs[c];
            if (g.w > 0) {
                sprites[n] = .{
                    .bounds = .{ x + g.bx, baseline - g.by, g.w * self.size, g.h * self.size },
                    .uv_bounds = .{ g.u, g.v, g.w, g.h },
                    .color = color,
                    .content_mask = .{ 0, 0, 0, 0 },
                };
                n += 1;
            }
            x += g.adv;
        }
        if (n > 0) renderer.drawSprites(sprites[0..n], self.srv, true);
    }
};

// ============================================================================
// Main
// ============================================================================

pub fn main() !void {
    var platform = try Win32.init();
    defer platform.deinit();

    const window = try Win32.createWindow(&platform, .{
        .width = 500,
        .height = 500,
        .title = "Hello World",
    });
    defer window.destroy();

    var renderer = try D3D11Renderer.init(std.heap.page_allocator, window.hwnd.?, 500, 500);
    defer renderer.deinit();

    var text_renderer = try TextRenderer.init(std.heap.page_allocator, &renderer);

    var state = HelloWorld{ .text = "World" };

    while (!window.shouldClose()) {
        for (window.pollEvents()) |e| {
            switch (e) {
                .key => |k| if (k.key == .escape) return,
                .resize => |r| renderer.resize(r.width, r.height) catch {},
                else => {},
            }
        }

        renderer.beginFrame();
        state.render(&renderer, &text_renderer);
        renderer.present(true);
    }
}

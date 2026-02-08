//! Hello World - Port of GPUI's hello_world.rs example

const std = @import("std");
const zapui = @import("zapui");

const D3D11Renderer = zapui.renderer.d3d11_renderer.D3D11Renderer;
const D3D11TextRenderer = zapui.renderer.d3d11_text.D3D11TextRenderer;
const QuadInstance = zapui.renderer.d3d11_renderer.QuadInstance;
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

    fn render(self: *HelloWorld, renderer: *D3D11Renderer, text_renderer: *D3D11TextRenderer) void {
        const bg = rgb(0x505050);
        renderer.clear(bg[0], bg[1], bg[2], bg[3]);

        // Layout
        const size_8: f32 = 32;
        const gap_2: f32 = 8;
        const gap_3: f32 = 12;
        const text_xl: f32 = 20;

        const content_h = text_xl + gap_3 + size_8;
        const y = (500 - content_h) / 2;
        const row_w = 6 * size_8 + 5 * gap_2;
        const x = (500 - row_w) / 2;

        // Text
        var buf: [64]u8 = undefined;
        const label = std.fmt.bufPrint(&buf, "Hello, {s}!", .{self.text}) catch "Hello!";
        text_renderer.drawCentered(renderer, label, 250, y + 16, white);

        // Colored boxes
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
// Main
// ============================================================================

const font_data = @embedFile("LiberationSans-Regular.ttf");

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

    var text_renderer = try D3D11TextRenderer.init(std.heap.page_allocator, &renderer, font_data, 20);
    defer text_renderer.deinit();

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

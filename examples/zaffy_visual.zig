//! Zaffy Visual Demo
//!
//! Renders a dashboard layout using Zaffy for flexbox and zapui for rendering.

const std = @import("std");
const zapui = @import("zapui");
const zaffy = zapui.zaffy;
const zglfw = @import("zglfw");

const WINDOW_WIDTH: f32 = 900;
const WINDOW_HEIGHT: f32 = 700;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize GLFW
    zglfw.init() catch {
        std.debug.print("Failed to initialize GLFW\n", .{});
        return;
    };
    defer zglfw.terminate();

    zglfw.windowHint(.context_version_major, 3);
    zglfw.windowHint(.context_version_minor, 3);
    zglfw.windowHint(.opengl_profile, .opengl_core_profile);
    zglfw.windowHint(.opengl_forward_compat, true);

    const window = zglfw.Window.create(@intFromFloat(WINDOW_WIDTH), @intFromFloat(WINDOW_HEIGHT), "Zaffy Layout Demo", null, null) catch {
        std.debug.print("Failed to create window\n", .{});
        return;
    };
    defer window.destroy();

    zglfw.makeContextCurrent(window);
    zglfw.swapInterval(1);

    // Load OpenGL functions
    zapui.renderer.gl.loadGlFunctions(zglfw.getProcAddress) catch {
        std.debug.print("Failed to load OpenGL functions\n", .{});
        return;
    };

    // Initialize renderer
    var renderer = try zapui.renderer.gl_renderer.GlRenderer.init(allocator);
    defer renderer.deinit();
    renderer.setViewport(WINDOW_WIDTH, WINDOW_HEIGHT, 1.0);

    var scene = zapui.scene.Scene.init(allocator);
    defer scene.deinit();

    // Build Zaffy layout tree - Simple 2x3 grid layout
    var tree = zaffy.Zaffy.init(allocator);
    defer tree.deinit();

    const padding: f32 = 20;
    const gap: f32 = 16;
    const header_h: f32 = 60;
    const content_h = WINDOW_HEIGHT - 2 * padding - header_h - gap;

    // Root container
    const root = try tree.newLeaf(.{
        .flex_direction = .column,
        .size = .{ .width = .{ .length = WINDOW_WIDTH }, .height = .{ .length = WINDOW_HEIGHT } },
        .padding = zaffy.Rect(zaffy.LengthPercentage).all(.{ .length = padding }),
        .gap = .{ .width = .{ .length = 0 }, .height = .{ .length = gap } },
    });

    // Header
    const header = try tree.newLeaf(.{
        .size = .{ .width = .auto, .height = .{ .length = header_h } },
    });
    try tree.appendChild(root, header);

    // Main row: sidebar + content grid
    const main_row = try tree.newLeaf(.{
        .flex_direction = .row,
        .size = .{ .width = .auto, .height = .{ .length = content_h } },
        .gap = .{ .width = .{ .length = gap }, .height = .{ .length = 0 } },
    });
    try tree.appendChild(root, main_row);

    // Sidebar - fixed width, doesn't shrink
    const sidebar = try tree.newLeaf(.{
        .flex_direction = .column,
        .size = .{ .width = .{ .length = 200 }, .height = .auto },
        .flex_shrink = 0,
        .gap = .{ .width = .{ .length = 0 }, .height = .{ .length = 10 } },
    });
    try tree.appendChild(main_row, sidebar);

    // 5 sidebar items
    var sidebar_items: [5]zaffy.NodeId = undefined;
    for (0..5) |i| {
        sidebar_items[i] = try tree.newLeaf(.{
            .size = .{ .width = .auto, .height = .{ .length = 44 } },
        });
        try tree.appendChild(sidebar, sidebar_items[i]);
    }

    // Content area - 2 rows of 3 cards each
    // The content takes remaining space after sidebar (860 - 200 - 16 gap = 644)
    const content = try tree.newLeaf(.{
        .flex_direction = .column,
        .flex_grow = 1,
        .flex_basis = .{ .length = 0 }, // Start from 0, grow to fill
        .gap = .{ .width = .{ .length = 0 }, .height = .{ .length = gap } },
    });
    try tree.appendChild(main_row, content);

    // Top row of cards
    const top_row = try tree.newLeaf(.{
        .flex_direction = .row,
        .flex_grow = 1,
        .gap = .{ .width = .{ .length = gap }, .height = .{ .length = 0 } },
    });
    try tree.appendChild(content, top_row);

    var top_cards: [3]zaffy.NodeId = undefined;
    for (0..3) |i| {
        top_cards[i] = try tree.newLeaf(.{ .flex_grow = 1 });
        try tree.appendChild(top_row, top_cards[i]);
    }

    // Bottom row of cards
    const bottom_row = try tree.newLeaf(.{
        .flex_direction = .row,
        .flex_grow = 1,
        .gap = .{ .width = .{ .length = gap }, .height = .{ .length = 0 } },
    });
    try tree.appendChild(content, bottom_row);

    var bottom_cards: [3]zaffy.NodeId = undefined;
    for (0..3) |i| {
        bottom_cards[i] = try tree.newLeaf(.{ .flex_grow = 1 });
        try tree.appendChild(bottom_row, bottom_cards[i]);
    }

    // Compute layout
    tree.computeLayoutWithSize(root, WINDOW_WIDTH, WINDOW_HEIGHT);

    std.debug.print("Zaffy Visual Demo\n", .{});
    std.debug.print("Press ESC to exit\n\n", .{});
    tree.printTree(root);

    // Colors
    const hsla = zapui.color.hsla;
    const Background = zapui.style.Background;

    const bg_color = hsla(220, 0.15, 0.10, 1.0);
    const header_color = Background{ .solid = hsla(220, 0.6, 0.35, 1.0) };
    const sidebar_color = Background{ .solid = hsla(220, 0.2, 0.18, 1.0) };
    const sidebar_item_color = Background{ .solid = hsla(220, 0.3, 0.25, 1.0) };
    const sidebar_item_hover = Background{ .solid = hsla(200, 0.5, 0.35, 1.0) };
    const card_colors = [_]Background{
        .{ .solid = hsla(340, 0.65, 0.45, 1.0) }, // Pink
        .{ .solid = hsla(200, 0.65, 0.45, 1.0) }, // Blue
        .{ .solid = hsla(150, 0.55, 0.40, 1.0) }, // Green
        .{ .solid = hsla(40, 0.70, 0.50, 1.0) },  // Orange
        .{ .solid = hsla(280, 0.50, 0.45, 1.0) }, // Purple
        .{ .solid = hsla(180, 0.50, 0.40, 1.0) }, // Teal
    };

    // Helper types
    const Bounds = zapui.geometry.Bounds(f32);
    const Point = zapui.geometry.Point(f32);
    const Size = zapui.geometry.Size(f32);
    const Corners = zapui.geometry.Corners(f32);

    // Main loop
    while (!window.shouldClose()) {
        zglfw.pollEvents();

        // Check for ESC
        if (window.getKey(.escape) == .press) {
            break;
        }

        // Get mouse position for hover effects
        const cursor_pos = window.getCursorPos();
        const mouse_x: f32 = @floatCast(cursor_pos[0]);
        const mouse_y: f32 = @floatCast(cursor_pos[1]);
        const mouse = Point.init(mouse_x, mouse_y);

        scene.clear();

        const radius: Corners = .{ .top_left = 12, .top_right = 12, .bottom_left = 12, .bottom_right = 12 };
        const small_radius: Corners = .{ .top_left = 8, .top_right = 8, .bottom_left = 8, .bottom_right = 8 };

        // Render header
        const header_layout = tree.getLayout(header);
        try scene.insertQuad(.{
            .bounds = Bounds.init(Point.init(header_layout.location.x, header_layout.location.y), Size.init(header_layout.size.width, header_layout.size.height)),
            .background = header_color,
            .corner_radii = radius,
            .order = scene.nextDrawOrder(),
        });

        // Render sidebar background
        const sidebar_layout = tree.getLayout(sidebar);
        const main_layout = tree.getLayout(main_row);
        const sidebar_abs = Bounds.init(
            Point.init(main_layout.location.x + sidebar_layout.location.x, main_layout.location.y + sidebar_layout.location.y),
            Size.init(sidebar_layout.size.width, sidebar_layout.size.height),
        );
        try scene.insertQuad(.{
            .bounds = sidebar_abs,
            .background = sidebar_color,
            .corner_radii = radius,
            .order = scene.nextDrawOrder(),
        });

        // Render sidebar items with hover
        for (sidebar_items) |item| {
            const item_layout = tree.getLayout(item);
            const item_bounds = Bounds.init(
                Point.init(sidebar_abs.origin.x + item_layout.location.x, sidebar_abs.origin.y + item_layout.location.y),
                Size.init(item_layout.size.width, item_layout.size.height),
            );
            const is_hovered = item_bounds.contains(mouse);
            try scene.insertQuad(.{
                .bounds = item_bounds,
                .background = if (is_hovered) sidebar_item_hover else sidebar_item_color,
                .corner_radii = small_radius,
                .order = scene.nextDrawOrder(),
            });
        }

        // Render content cards
        const content_layout = tree.getLayout(content);
        const content_abs_x = main_layout.location.x + content_layout.location.x;
        const content_abs_y = main_layout.location.y + content_layout.location.y;

        const top_row_layout = tree.getLayout(top_row);
        for (top_cards, 0..) |card, i| {
            const card_layout = tree.getLayout(card);
            const card_bounds = Bounds.init(
                Point.init(
                    content_abs_x + top_row_layout.location.x + card_layout.location.x,
                    content_abs_y + top_row_layout.location.y + card_layout.location.y,
                ),
                Size.init(card_layout.size.width, card_layout.size.height),
            );
            try scene.insertQuad(.{
                .bounds = card_bounds,
                .background = card_colors[i],
                .corner_radii = radius,
                .order = scene.nextDrawOrder(),
            });
        }

        const bottom_row_layout = tree.getLayout(bottom_row);
        for (bottom_cards, 0..) |card, i| {
            const card_layout = tree.getLayout(card);
            const card_bounds = Bounds.init(
                Point.init(
                    content_abs_x + bottom_row_layout.location.x + card_layout.location.x,
                    content_abs_y + bottom_row_layout.location.y + card_layout.location.y,
                ),
                Size.init(card_layout.size.width, card_layout.size.height),
            );
            try scene.insertQuad(.{
                .bounds = card_bounds,
                .background = card_colors[i + 3],
                .corner_radii = radius,
                .order = scene.nextDrawOrder(),
            });
        }

        // Render
        renderer.clear(bg_color);
        try renderer.drawScene(&scene);
        window.swapBuffers();
    }
}

//! Taffy Layout Demo
//!
//! This example demonstrates using Taffy for automatic flexbox layout.
//! Just prints the computed layout tree.

const std = @import("std");
const zapui = @import("zapui");
const taffy = zapui.taffy;

const WINDOW_WIDTH: f32 = 800;
const WINDOW_HEIGHT: f32 = 600;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Taffy Layout Demo\n", .{});
    std.debug.print("=================\n\n", .{});

    // Build layout tree with Taffy
    var tree = taffy.Taffy.init(allocator);
    defer tree.deinit();

    // Root: vertical column with padding
    const root = try tree.newLeaf(.{
        .flex_direction = .column,
        .size = .{ .width = .{ .length = WINDOW_WIDTH }, .height = .{ .length = WINDOW_HEIGHT } },
        .padding = taffy.Rect(taffy.LengthPercentage).all(.{ .length = 20 }),
        .gap = .{ .width = .{ .length = 0 }, .height = .{ .length = 16 } },
    });

    // Header bar
    const header = try tree.newLeaf(.{
        .flex_direction = .row,
        .size = .{ .width = .auto, .height = .{ .length = 60 } },
        .justify_content = .space_between,
        .align_items = .center,
        .padding = taffy.Rect(taffy.LengthPercentage).all(.{ .length = 16 }),
    });
    try tree.appendChild(root, header);

    const logo = try tree.newLeaf(.{
        .size = .{ .width = .{ .length = 120 }, .height = .{ .length = 40 } },
    });
    try tree.appendChild(header, logo);

    // Nav items container
    const nav = try tree.newLeaf(.{
        .flex_direction = .row,
        .gap = .{ .width = .{ .length = 24 }, .height = .{ .length = 0 } },
    });
    try tree.appendChild(header, nav);

    // Nav items
    var nav_items: [4]taffy.NodeId = undefined;
    for (0..4) |i| {
        nav_items[i] = try tree.newLeaf(.{
            .size = .{ .width = .{ .length = 80 }, .height = .{ .length = 32 } },
        });
        try tree.appendChild(nav, nav_items[i]);
    }

    // Main content area
    const main_content = try tree.newLeaf(.{
        .flex_direction = .row,
        .flex_grow = 1,
        .gap = .{ .width = .{ .length = 20 }, .height = .{ .length = 0 } },
    });
    try tree.appendChild(root, main_content);

    // Sidebar
    const sidebar = try tree.newLeaf(.{
        .flex_direction = .column,
        .size = .{ .width = .{ .length = 250 }, .height = .auto },
        .gap = .{ .width = .{ .length = 0 }, .height = .{ .length = 12 } },
    });
    try tree.appendChild(main_content, sidebar);

    // Sidebar items
    for (0..6) |_| {
        const sidebar_item = try tree.newLeaf(.{
            .size = .{ .width = .auto, .height = .{ .length = 44 } },
        });
        try tree.appendChild(sidebar, sidebar_item);
    }

    // Content grid
    const content = try tree.newLeaf(.{
        .flex_direction = .column,
        .flex_grow = 1,
        .gap = .{ .width = .{ .length = 0 }, .height = .{ .length = 16 } },
    });
    try tree.appendChild(main_content, content);

    // Grid rows
    for (0..3) |_| {
        const row = try tree.newLeaf(.{
            .flex_direction = .row,
            .flex_grow = 1,
            .gap = .{ .width = .{ .length = 16 }, .height = .{ .length = 0 } },
        });
        try tree.appendChild(content, row);

        // Grid cells
        for (0..3) |_| {
            const cell = try tree.newLeaf(.{
                .flex_grow = 1,
            });
            try tree.appendChild(row, cell);
        }
    }

    // Footer
    const footer = try tree.newLeaf(.{
        .flex_direction = .row,
        .size = .{ .width = .auto, .height = .{ .length = 50 } },
        .justify_content = .center,
        .align_items = .center,
    });
    try tree.appendChild(root, footer);

    const footer_text = try tree.newLeaf(.{
        .size = .{ .width = .{ .length = 200 }, .height = .{ .length = 24 } },
    });
    try tree.appendChild(footer, footer_text);

    // Compute layout
    std.debug.print("Computing layout for {d}x{d} viewport...\n\n", .{ WINDOW_WIDTH, WINDOW_HEIGHT });
    tree.computeLayoutWithSize(root, WINDOW_WIDTH, WINDOW_HEIGHT);

    // Print the computed layout tree
    std.debug.print("Computed Layout Tree:\n", .{});
    std.debug.print("---------------------\n", .{});
    tree.printTree(root);

    // Print some specific layouts
    std.debug.print("\nKey Element Layouts:\n", .{});
    std.debug.print("--------------------\n", .{});

    const header_layout = tree.getLayout(header);
    std.debug.print("Header: pos=({d:.0}, {d:.0}) size=({d:.0} x {d:.0})\n", .{
        header_layout.location.x,
        header_layout.location.y,
        header_layout.size.width,
        header_layout.size.height,
    });

    const sidebar_layout = tree.getLayout(sidebar);
    std.debug.print("Sidebar: pos=({d:.0}, {d:.0}) size=({d:.0} x {d:.0})\n", .{
        sidebar_layout.location.x,
        sidebar_layout.location.y,
        sidebar_layout.size.width,
        sidebar_layout.size.height,
    });

    const content_layout = tree.getLayout(content);
    std.debug.print("Content: pos=({d:.0}, {d:.0}) size=({d:.0} x {d:.0})\n", .{
        content_layout.location.x,
        content_layout.location.y,
        content_layout.size.width,
        content_layout.size.height,
    });

    const footer_layout = tree.getLayout(footer);
    std.debug.print("Footer: pos=({d:.0}, {d:.0}) size=({d:.0} x {d:.0})\n", .{
        footer_layout.location.x,
        footer_layout.location.y,
        footer_layout.size.width,
        footer_layout.size.height,
    });

    std.debug.print("\nLayout calculation complete!\n", .{});
}

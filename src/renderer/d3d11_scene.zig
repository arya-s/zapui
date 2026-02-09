//! D3D11 Scene Renderer
//!
//! Renders a complete UI scene including quads and text using D3D11.
//! Integrates D3D11Renderer with D3D11TextRenderer for unified rendering.

const std = @import("std");
const d3d11_renderer = @import("d3d11_renderer.zig");
const d3d11_text = @import("d3d11_text.zig");
const scene_mod = @import("../scene.zig");
const geometry = @import("../geometry.zig");
const color_mod = @import("../color.zig");
const zaffy_mod = @import("../zaffy.zig");
const div_mod = @import("../elements/div.zig");

const D3D11Renderer = d3d11_renderer.D3D11Renderer;
const D3D11TextRenderer = d3d11_text.D3D11TextRenderer;
const Scene = scene_mod.Scene;
const Bounds = geometry.Bounds;
const Pixels = geometry.Pixels;

/// Render context for D3D11 scene rendering
pub const D3D11SceneContext = struct {
    renderer: *D3D11Renderer,
    text_renderer: *D3D11TextRenderer,

    /// Render a scene (quads only - text rendered separately)
    pub fn drawScene(self: *D3D11SceneContext, scene: *const Scene) void {
        self.renderer.drawScene(scene);
    }

    /// Render text for a div tree
    /// Call this after drawScene() to render text on top of quads
    pub fn drawDivText(
        self: *D3D11SceneContext,
        root: *const div_mod.Div,
        layout: *const zaffy_mod.Zaffy,
    ) void {
        self.drawDivTextRecursive(root, layout, 0, 0);
    }

    fn drawDivTextRecursive(
        self: *D3D11SceneContext,
        d: *const div_mod.Div,
        layout: *const zaffy_mod.Zaffy,
        parent_x: Pixels,
        parent_y: Pixels,
    ) void {
        const nid = d.node_id orelse return;
        const lay = layout.getLayout(nid);
        const x = parent_x + lay.location.x;
        const y = parent_y + lay.location.y;

        if (d.text_content_val) |text| {
            // Text starts at content area (after padding)
            // Resolve padding to pixels (simple case - just handle px values)
            const padding_left: Pixels = if (d.style.padding.left == .px) d.style.padding.left.px else 0;
            const padding_top: Pixels = if (d.style.padding.top == .px) d.style.padding.top.px else 0;
            const padding_bottom: Pixels = if (d.style.padding.bottom == .px) d.style.padding.bottom.px else 0;
            const tx = x + padding_left;
            // Center vertically with baseline offset, accounting for padding
            const content_height = lay.size.height - padding_top - padding_bottom;
            const ty = y + padding_top + content_height / 2 + 6;
            const tc = d.text_color_val.toRgba();
            self.text_renderer.draw(self.renderer, text, tx, ty, .{ tc.r, tc.g, tc.b, tc.a });
        }

        for (d.children_list.items) |child| {
            self.drawDivTextRecursive(child, layout, x, y);
        }
    }

    /// Convenience: render a complete div tree (quads + text)
    pub fn renderDiv(
        self: *D3D11SceneContext,
        root: *const div_mod.Div,
        layout: *const zaffy_mod.Zaffy,
        scene: *Scene,
    ) void {
        // Paint quads to scene
        scene.clear();
        root.paintQuadsOnly(scene, 0, 0, layout);
        scene.finish();

        // Render quads
        self.renderer.drawScene(scene);

        // Render text
        self.drawDivText(root, layout);
    }
};

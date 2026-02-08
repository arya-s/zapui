# Zaffy - Flexible UI Layout Library for Zig

A Zig port of [Taffy](https://github.com/DioxusLabs/taffy), a high-performance CSS-style layout library.

## Features

- **Flexbox Layout** - Full CSS Flexbox implementation
  - `flex-direction`: row, column, row-reverse, column-reverse
  - `flex-wrap`: nowrap, wrap, wrap-reverse
  - `justify-content`: flex-start, flex-end, center, space-between, space-around, space-evenly
  - `align-items`/`align-self`: flex-start, flex-end, center, baseline, stretch
  - `flex-grow`, `flex-shrink`, `flex-basis`
  - `gap` (row-gap and column-gap)

- **Size Properties**
  - `width`, `height` (auto, length, percent)
  - `min-width`, `max-width`, `min-height`, `max-height`
  - `aspect-ratio`

- **Spacing**
  - `padding` (left, right, top, bottom)
  - `margin` (with auto margin support)
  - `border`

- **Positioning**
  - `position`: relative, absolute
  - `inset`: left, right, top, bottom

## Quick Start

```zig
const zaffy = @import("zaffy.zig");

var tree = zaffy.Zaffy.init(allocator);
defer tree.deinit();

// Create a row container
const root = try tree.newLeaf(.{
    .flex_direction = .row,
    .size = .{ .width = .{ .length = 200 }, .height = .{ .length = 100 } },
});

// Add children with flex-grow
const child1 = try tree.newLeaf(.{ .flex_grow = 1 });
const child2 = try tree.newLeaf(.{ .flex_grow = 1 });

try tree.appendChild(root, child1);
try tree.appendChild(root, child2);

// Compute layout
tree.computeLayoutWithSize(root, 200, 100);

// Get results
const layout1 = tree.getLayout(child1);
// layout1.location.x == 0
// layout1.size.width == 100
```

## API Reference

### ZaffyTree

The main layout tree type.

```zig
// Create/destroy
var tree = zaffy.Zaffy.init(allocator);
tree.deinit();

// Create nodes
const id = try tree.newLeaf(style);
const id = try tree.newWithChildren(style, &.{child1, child2});

// Tree operations
try tree.appendChild(parent, child);
try tree.insertChildAtIndex(parent, index, child);
tree.removeChild(parent, child);
const child = tree.removeChildAtIndex(parent, index);

// Style and layout
tree.setStyle(node, style);
const style = tree.getStyle(node);
const layout = tree.getLayout(node);

// Compute layout
tree.computeLayout(root, available_space);
tree.computeLayoutWithSize(root, width, height);

// Debug
tree.printTree(root);
```

### Style

```zig
const style = zaffy.Style{
    .display = .flex,              // flex, block, grid, none
    .position = .relative,         // relative, absolute
    .flex_direction = .row,        // row, column, row_reverse, column_reverse
    .flex_wrap = .no_wrap,         // no_wrap, wrap, wrap_reverse
    .justify_content = .flex_start, // flex_start, flex_end, center, space_between, space_around, space_evenly
    .align_items = .stretch,       // flex_start, flex_end, center, baseline, stretch
    .align_content = .stretch,     // flex_start, flex_end, center, stretch, space_between, space_around, space_evenly
    .flex_grow = 0.0,
    .flex_shrink = 1.0,
    .flex_basis = .auto,           // auto, .{ .length = 100 }, .{ .percent = 0.5 }
    .size = .{ .width = .auto, .height = .auto },
    .min_size = .{ .width = .auto, .height = .auto },
    .max_size = .{ .width = .auto, .height = .auto },
    .padding = .{ .left = .{ .length = 0 }, ... },
    .margin = .{ .left = .{ .length = 0 }, ... },
    .border = .{ .left = .{ .length = 0 }, ... },
    .gap = .{ .width = .{ .length = 0 }, .height = .{ .length = 0 } },
};
```

### Layout Result

```zig
const layout = tree.getLayout(node);
layout.location.x;  // X position relative to parent
layout.location.y;  // Y position relative to parent
layout.size.width;  // Computed width
layout.size.height; // Computed height
layout.padding;     // Resolved padding
layout.border;      // Resolved border
layout.margin;      // Resolved margin
```

## Files

- `zaffy.zig` - Main ZaffyTree implementation
- `flexbox.zig` - Flexbox layout algorithm
- `geometry.zig` - Point, Size, Rect primitives
- `style.zig` - Style types and enums
- `tree.zig` - Layout, Cache, and tree types

## Differences from Rust Taffy

1. **No Grid layout** (yet) - Only Flexbox is implemented
2. **Fixed-size buffers** - Uses stack-allocated buffers instead of heap vectors for flex items/lines
3. **Simplified cache** - Basic caching without all the optimizations
4. **No measure functions** - Leaf nodes must have explicit sizes (text measurement to be added)

## License

MIT (same as original Taffy)

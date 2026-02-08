# Plan: Integrate FreeType + HarfBuzz from phantty into zapui

## Context

zapui currently uses stb_truetype for font rendering — simple but limited (no complex text shaping, no color emoji, no font fallback). phantty already has a mature FreeType + HarfBuzz setup with Zig wrappers in `pkg/freetype/` and `pkg/harfbuzz/`. Since the goal is to eventually use zapui as phantty's UI framework, the font systems should converge. This plan documents how to replace stb_truetype with phantty's FreeType + HarfBuzz, reusing as much existing code as possible.

## What Can Be Directly Reused from phantty

### Copy verbatim:
- `phantty/pkg/freetype/` → `zapui/pkg/freetype/` (9 Zig files + build.zig, self-contained FreeType wrapper)
- `phantty/pkg/harfbuzz/` → `zapui/pkg/harfbuzz/` (11 Zig files + build.zig, self-contained HarfBuzz wrapper)
- `phantty/pkg/zlib/` → `zapui/pkg/zlib/` (required by FreeType)
- `phantty/src/font/Atlas.zig` → replace `zapui/src/renderer/atlas.zig` (skyline bin-packing, better than current shelf-packing)

### Extract patterns from `phantty/src/AppWindow.zig`:
- Font metrics from SFNT tables (lines ~2380-2470) — proper hhea/OS/2/head fallback chain
- Glyph loading + color detection (lines ~1751-1855) — FT_LOAD_COLOR for emoji
- HarfBuzz shaping flow (lines ~1872-2055) — buffer setup, shape(), glyph extraction
- Dual atlas pattern (lines ~1140-1147) — separate grayscale + BGRA atlases

## Phased Migration

### Phase 0: Build System Setup
Copy `pkg/freetype/`, `pkg/harfbuzz/`, `pkg/zlib/` into zapui. Update `build.zig` to compile FreeType from ~35 C sources and HarfBuzz from C++ (`harfbuzz.cc`). Keep stb_truetype compiled — both coexist temporarily. Verify `zig build` succeeds with no code changes.

Key: HarfBuzz needs `linkLibCpp()` and `-DHAVE_FREETYPE=1`. Follow phantty's `build.zig` lines 119-165.

### Phase 1: Replace Atlas (Skyline Bin-Packing)
Replace zapui's shelf-packing atlas with phantty's skyline bin-packer. Create a `GlAtlas` wrapper that owns both the CPU-side atlas and GL texture with lazy sync via `modified` counter. Still using stb_truetype for rasterization — atlas change is independent.

### Phase 2: Replace Font Backend (stb_truetype → FreeType)
The big switchover. Replace all `stbtt_*` calls in `text_system.zig`:
- Font loading: `stbtt_InitFont` → `ft_lib.initFace()` / `initMemoryFace()`
- Metrics: `stbtt_GetFontVMetrics` → SFNT table reading (hhea/OS/2)
- Rasterization: `stbtt_MakeGlyphBitmap` → `ft_face.loadGlyph()` + `renderGlyph()`
- Add `FT_Set_Pixel_Sizes` wrapper to phantty's `face.zig` (not currently wrapped)
- Remove stb_truetype from build

### Phase 3: Add HarfBuzz Text Shaping
Replace manual codepoint-by-codepoint iteration in `shapeText()` with HarfBuzz:
- Add `hb_font` to FontData, `hb_buf` to TextSystem
- `shapeText()`: buffer.addUTF8() → shape() → extract GlyphInfo/GlyphPosition
- `measureText()`: shape then sum advances (eliminates separate kerning handling)
- Glyph IDs become font-internal indices (post-shaping) instead of codepoints

### Phase 4: Color Emoji Support
- Add color atlas (`GlAtlas` with `.bgra` format) to TextSystem and GlRenderer
- Detect BGRA bitmaps from FreeType (`bitmap.pixel_mode == FT_PIXEL_MODE_BGRA`)
- Color glyphs → `scene.insertPolySprite()` instead of `insertMonoSprite()`
- Add `drawPolySprites()` to gl_renderer.zig (shader already supports poly via `u_mono` uniform)
- BGRA→RGBA swizzle on CPU when copying to atlas

### Phase 5: Fix Div Text Measurement
Replace approximations in `div.zig`:
- Line 457: `len * size * 0.55` → `text_system.measureText(text, font_id, size)`
- Line 471: `size * 0.35` → `metrics.ascent` from `getFontMetrics()`

### Phase 6: Cleanup
Delete `src/vendor/stb_truetype.{c,h}`, remove from build.zig, remove temp_bitmap from TextSystem.

## TextSystem API Changes

```
Added fields:   ft_lib (Library), hb_buf (Buffer), color_atlas (?*GlAtlas)
Removed fields: temp_bitmap, temp_bitmap_size
FontData:       stbtt_fontinfo → ft_face (Face) + hb_font (Font)
```

Public methods keep the same signatures — internal implementation changes only.

## Critical Files

| File | Change |
|------|--------|
| `zapui/build.zig` | Add FreeType/HarfBuzz compilation |
| `zapui/src/text_system.zig` | Replace all stb calls with FreeType + HarfBuzz |
| `zapui/src/renderer/atlas.zig` | Replace with phantty's skyline atlas |
| `zapui/src/renderer/gl_renderer.zig` | Add color atlas, drawPolySprites(), lazy GPU sync |
| `zapui/src/elements/div.zig` | Replace 0.55/0.35 approximations |

## Risks

- **Build complexity** (high): FreeType needs ~35 C files + zlib; HarfBuzz needs C++. Platform-specific handling in phantty's build.zig may need adaptation.
- **Fixed-point arithmetic** (medium): FreeType uses 26.6 format everywhere. Wrong conversions = subtle positioning bugs.
- **Font size semantics** (medium): stb uses pixel height directly; FreeType uses points+DPI or pixel sizes. Need `FT_Set_Pixel_Sizes` (not yet wrapped).
- **Atlas sync timing** (medium): CPU-side atlas with lazy GPU upload must sync before draw calls.

## Dependency Graph

```
Phase 0 (build) ──→ Phase 1 (atlas) ──→ Phase 2 (FreeType) ──→ Phase 3 (HarfBuzz) ──→ Phase 5 (Div fix) ──→ Phase 6 (cleanup)
                                              ↓
                                         Phase 4 (color emoji)
```

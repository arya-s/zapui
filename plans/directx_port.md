# DirectX + Win32 Port Plan

## Goal
Port ZapUI to use native Win32 windowing and DirectX rendering on Windows, matching GPUI's approach.

## Current Architecture
```
src/
├── renderer/
│   ├── gl.zig           # OpenGL bindings
│   ├── gl_renderer.zig  # OpenGL renderer implementation
│   ├── atlas.zig        # Texture atlas (shared)
│   └── shaders.zig      # Shader compilation (OpenGL-specific)
├── window.zig           # Uses zglfw
└── ...
```

## Target Architecture
```
src/
├── platform/
│   ├── platform.zig     # Platform abstraction interface
│   ├── windows/
│   │   ├── win32.zig    # Win32 windowing
│   │   └── d3d11.zig    # DirectX 11 bindings
│   └── glfw/
│       └── glfw.zig     # GLFW windowing (for Linux/macOS)
├── renderer/
│   ├── renderer.zig     # Renderer interface
│   ├── dx11_renderer.zig # DirectX 11 implementation
│   ├── gl_renderer.zig  # OpenGL implementation (existing)
│   ├── atlas.zig        # Texture atlas (shared)
│   └── shaders/
│       ├── quad.hlsl    # DirectX shaders
│       └── quad.frag.glsl # OpenGL shaders (existing)
└── ...
```

## Phase 1: Platform Abstraction ✅
- [x] Create `Platform` interface for windowing
- [x] Create `Window` abstraction  
- [x] Move GLFW code behind the abstraction
- [x] Verify everything still works

## Phase 2: Renderer Abstraction  
- [ ] Create `Renderer` interface
- [ ] Abstract texture/atlas handling
- [ ] Move GL renderer behind the abstraction
- [ ] Verify everything still works

## Phase 3: Win32 Implementation ✅
- [x] Add Win32 API bindings (use zigwin32)
- [x] Implement Win32 window creation
- [x] Implement Win32 event loop
- [x] Implement keyboard/mouse input

## Phase 4: DirectX 11 Implementation ✅
- [x] Add D3D11 API bindings (via zigwin32)
- [x] D3D11 device, swap chain, render target view
- [x] Clear screen, present, resize
- [x] Port shaders to HLSL (quad.hlsl with SDF rounded corners, dashed borders)
- [x] Implement quad rendering with StructuredBuffer instancing
- [x] Blend state and rasterizer state for alpha blending
- [x] Implement sprite rendering with texture support
- [x] Implement D3D11Atlas for GPU texture atlas
- [x] FreeType text rendering with D3D11 (glyph rasterization to texture atlas)

## Phase 5: Integration & Testing
- [x] Build system changes for platform selection
- [ ] Test on Windows native with D3D11
- [ ] Compare screenshots with GPUI

## Dependencies
- Zig's `std.os.windows` for basic Win32
- Need D3D11 headers/bindings (maybe from zigwin32 or manual)

## References
- GPUI Windows platform: `/mnt/c/src/zed/crates/gpui/src/platform/windows/`
- zigwin32: https://github.com/marler/zigwin32
- DirectX 11 tutorials

## Notes
- Start with D3D11 (simpler than D3D12)
- Can use same atlas logic, just different GPU upload
- HLSL shaders are similar to GLSL, need to port

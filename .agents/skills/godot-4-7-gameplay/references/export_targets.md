# Desktop and HTML5 / Web Exporting (Godot 4.7)

## 1. Exporting via CLI

Godot 4.7 allows fully automated builds from command line interfaces and CI/CD pipelines.

### Headless Export Commands
```bash
# Export Windows Desktop Release
godot --headless --export-release "Windows Desktop" build/desktop/PixelPilferer.exe

# Export Web / HTML5 Release
godot --headless --export-release "Web" build/web/index.html
```

---

## 2. Configuration: `export_presets.cfg`

The export presets file defines target configurations:

```ini
[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/desktop/PixelPilferer.exe"

[preset.0.options]
binary_format/embed_pck=true
texture_format/bptc=false
texture_format/s3tc=true

[preset.1]
name="Web"
platform="Web"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
export_path="build/web/index.html"

[preset.1.options]
threads/thread_model=0 # 0 = Single-threaded (No SharedArrayBuffer required)
progressive_web_app/enabled=false
html/export_icon=true
html/canvas_resize_policy=2 # 2 = Adaptive
```

---

## 3. Web / HTML5 Critical Considerations

### A. Single-Thread vs Multi-Thread (COOP / COEP)
- **Multi-threaded Web Export:** Requires HTTP response headers:
  - `Cross-Origin-Opener-Policy: same-origin`
  - `Cross-Origin-Embedder-Policy: require-corp`
  Hosting on itch.io or GitHub Pages will fail unless these headers are enabled.
- **Single-threaded Web Export (`threads/thread_model=0`):** Supported natively in modern Godot 4. Eliminates the need for special headers and runs reliably on standard static web hosts.

### B. Audio Context Interaction
Browsers block audio playback until the user clicks or taps inside the iframe/canvas.
- Design an initial "Click to Start" title prompt so the browser audio context unlocks before gameplay audio starts.

### C. Canvas Sizing in HTML
Ensure the canvas fills the viewport or maintains integer pixel scale:
```html
<style>
  body, html {
    margin: 0;
    padding: 0;
    width: 100%;
    height: 100%;
    overflow: hidden;
    background-color: #000;
    display: flex;
    justify-content: center;
    align-items: center;
  }
  #canvas {
    image-rendering: pixelated;
    image-rendering: crisp-edges;
  }
</style>
```

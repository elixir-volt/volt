# Static Assets

Images, fonts, SVGs, and other non-code files are handled automatically when imported.

## Inlining

Small files (under 4 KB by default) are inlined as base64 data URIs:

```javascript
import icon from './icon.svg'
// icon = "data:image/svg+xml;base64,..."
```

## Hashed URLs

Larger files are copied to the output directory with content-hashed filenames:

```javascript
import photo from './photo.jpg'
// photo = "/assets/photo-a1b2c3d4.jpg"
```

## Supported Formats

Images (`.svg`, `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.avif`, `.ico`), fonts (`.woff`, `.woff2`, `.ttf`, `.otf`, `.eot`), media (`.mp4`, `.webm`, `.ogg`, `.mp3`, `.wav`), and other formats (`.pdf`, `.wasm`, `.txt`).

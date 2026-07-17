# FFmpegKitNext — Web (WebAssembly) Test App

A browser test application for the FFmpegKitNext **web/wasm** build. It loads the
`FFmpegKitModule` (an ES module hosted in a Web Worker) and exercises the FFmpegKit
JS bindings across the same feature tabs as the native test apps.

It also serves as the runtime verification of the binding layer: the app only reports
**Ready** once the worker confirms `Module.FFmpegKit` registered (i.e. the
`MAIN_MODULE=2` dead-code-elimination anchor held).

## Prerequisites

- The web bundle must be built first, in the `ffmpeg-kit-next` repo:
  ```
  cd ../../ffmpeg-kit-next
  ./nix-web.sh -p web-wasm32-emscripten
  ```
  This produces `prebuilt/bundle-web-wasm32/ffmpeg-kit-next/lib/` (the `.js`, `.wasm`
  and side-module `.so` files).
- Node.js (only for the tiny static server; the app itself has no build step).

## Run

```
./copy_local_binaries.sh        # copies lib/*.{js,wasm,so} and the JS binding in
node server.mjs                 # serves with the required COOP/COEP headers
```

Then open <http://localhost:8080>.

> The server sends `Cross-Origin-Opener-Policy: same-origin` and
> `Cross-Origin-Embedder-Policy: require-corp`. These are **required** — the module is
> threaded and needs `SharedArrayBuffer`, which the browser only grants under those
> headers. Any server you use must send them.

## Capability status of each tab

Every tab is now interactive (shown with a coloured dot). "Partial" tabs run real
commands that succeed only when the required external library is compiled into the
`lib/` you built against — otherwise they fail with a clear "unknown filter/encoder".

| Tab | Status | Notes |
|---|---|---|
| Command | Live | arbitrary built-in FFmpeg / FFprobe |
| Media Information | Live | `FFprobeKit.getMediaInformation` on any file |
| Concurrent | Live | multiple encodes via `executeAsync`, run in parallel |
| FFKit Protocols | Live | in-memory `ffkitmem:` input + output buffers (no MEMFS staging) |
| Video encode | Live | full software matrix — mpeg4, x264, openh264, x265, xvid, vp8, vp9, aom, svt-av1, kvazaar, theora, mjpeg, ffv1 |
| Audio encode | Live | full software matrix — aac, mp3 (lame/shine), mp2 (twolame), vorbis, opus, amr-nb/wb, ilbc, speex, lc3, wavpack, flac, pcm, soxr |
| Subtitle | Live | burns subtitles with libass (+ freetype/fontconfig/fribidi/harfbuzz) |
| Video stabilization | Live | two-pass libvidstab (vidstabdetect → vidstabtransform) |
| Https | Partial | native FFmpeg sockets can't open in the sandbox; the tab does the web pattern instead — `fetch()` in the page → `writeFile` → probe locally (CORS-permitting) |
| Other | Partial | external-library grab-bag (chromaprint, webp, libjxl, zscale, vvenc — all live; dav1d needs a cross-origin AV1 fetch, so it's CORS-limited) |

Video/audio codecs assume their libraries are in the `lib/` you built; a missing one
fails with a clear "unknown encoder". Hardware codecs (h264_videotoolbox, audiotoolbox)
have no browser equivalent and are intentionally absent — software encoders cover them.

## Layout

The FFmpegKitNext web package (the JS binding layer) is **not** part of this test app —
it lives in the main repo under `ffmpeg-kit-next/web/binding/`, is emitted into the
build bundle next to `lib/`, and is copied in here by `copy_local_binaries.sh` (into
`binding/`, gitignored). Its public API uses the **same class names as the native
platforms** (`FFmpegKit`, `FFprobeKit`, `FFmpegKitConfig`, sessions, value types). App
code never touches the Worker or the raw wasm `Module` — those stay behind the package's
internal `FFmpegKitFactory` (main-thread conduit) and `ffmpegkit.worker.js`
(`FFmpegKitWorker`, the only holder of `Module`). `binding/` and `lib/` are kept siblings
so the worker's `../lib` import resolves exactly as it does in the bundle.

```
index.html · css/app.css
js/app.js                     tab router + package bootstrap (init) + asset preload
js/ui.js                      small DOM helpers
js/tabs/*.js                  one module per tab (import the public API from ../../binding)

binding/                      shipped JS package      [copied in from the bundle, gitignored]
  index.js                    public entry: FFmpegKit, FFprobeKit, FFmpegKitConfig,
                              sessions, value types, enums + init()/readFile/writeFile
  FFmpegKit.js · FFprobeKit.js · FFmpegKitConfig.js   native-named public classes
  session.js · models.js · enums.js                   public sessions / value types / enums
  FFmpegKitFactory.js         internal: Worker + protocol + callback/session registry
  ffmpegkit.worker.js         internal: FFmpegKitWorker — owns Module, drains events

assets/                       web-owned sample images/fonts/subtitle
lib/                          built .js/.wasm/.so            [copied in, gitignored]
server.mjs                    static server with COOP/COEP
copy_local_binaries.sh        pulls lib + binding into place
```

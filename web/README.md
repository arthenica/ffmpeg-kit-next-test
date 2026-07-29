# FFmpegKitNext Web Test Application

The `web` folder contains a browser test application that consumes a local `ffmpeg-kit-next-web` WebAssembly package.

## Demo

<br/>

[![Test Application]](https://github.com/user-attachments/assets/477a465d-1931-467e-beb2-894d973289ed)

## Add FFmpegKitNext to a Web App

`ffmpeg-kit-next-web` is consumed from the locally generated package folder, not from npm.

```json
{
  "dependencies": {
    "ffmpeg-kit-next-web": "file:<path-to-ffmpeg-kit-next>/prebuilt/bundle-web-wasm32/ffmpeg-kit-next"
  }
}
```

Serve the complete generated package folder as static assets. The worker, `.wasm` file and side modules are resolved
relative to the package module, so keep the generated `dist` and `lib` layout intact.

The page that loads the package must be cross-origin isolated. Any server used by your app must send:

```text
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Those headers are required because the threaded WebAssembly module uses `SharedArrayBuffer`.

## Run This Test App

The test app copies the already-built web package into local `dist` and `lib` folders:

```sh
./copy_local_binaries.sh [path-to-ffmpeg-kit-next]
node server.mjs
```

Then open <http://localhost:8080>. The included server sets the required COOP and COEP headers.

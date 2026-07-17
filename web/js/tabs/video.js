/*
 * Copyright (c) 2021-2026 Taner Sener
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import { FFmpegKitConfig, readFile } from '../../dist/index.js';
import { encodeScript, el, executeFFmpegAsync, logView, reportResult, downloadBlob, previewFor, guessMime } from '../util.js';

const CODECS = {
  'mpeg4':           { codec: 'mpeg4',       ext: 'mp4',  pix: 'yuv420p',     opts: '' },
  'h264 (x264)':     { codec: 'libx264',     ext: 'mp4',  pix: 'yuv420p',     opts: '' },
  'h264 (openh264)': { codec: 'libopenh264', ext: 'mp4',  pix: 'yuv420p',     opts: '' },
  'x265':            { codec: 'libx265',     ext: 'mp4',  pix: 'yuv420p10le', opts: '-crf 28 -preset fast' },
  'xvid':            { codec: 'libxvid',     ext: 'mp4',  pix: 'yuv420p',     opts: '' },
  'vp8':             { codec: 'libvpx',      ext: 'webm', pix: 'yuv420p',     opts: '-b:v 1M -crf 10' },
  'vp9':             { codec: 'libvpx-vp9',  ext: 'webm', pix: 'yuv420p',     opts: '-b:v 2M' },
  'aom':             { codec: 'libaom-av1',  ext: 'mp4',  pix: 'yuv420p',     opts: '-crf 30 -strict experimental' },
  'svt-av1':         { codec: 'libsvtav1',   ext: 'mp4',  pix: 'yuv420p',     opts: '-preset 8 -crf 35' },
  'kvazaar':         { codec: 'libkvazaar',  ext: 'mp4',  pix: 'yuv420p',     opts: '' },
  'theora':          { codec: 'libtheora',   ext: 'ogv',  pix: 'yuv420p',     opts: '-qscale:v 7' },
  'hap':             { codec: 'hap',         ext: 'mov',  pix: 'yuv420p',     opts: '-format hap_q' },
};

export default {
  id: 'video',
  title: 'Video',
  capability: 'live',
  note:
    'Encodes a slideshow across the full software-codec matrix. Each entry needs its ' +
    'library in the build (x264/x265/xvid/openh264/vpx/aom/svt-av1/kvazaar/theora); if ' +
    'one is missing, FFmpeg reports an unknown encoder. Some outputs (e.g. x265/mp4, ' +
    'aom, theora) may not play in the browser but still download.',
  render(root, ctx) {
    FFmpegKitConfig.enableLogCallback(null);
    FFmpegKitConfig.enableStatisticsCallback(null);

    const select = el('select', {},
      ...Object.keys(CODECS).map((c) => el('option', { value: c }, c)));
    const log = logView();
    const stats = el('div', { class: 'stats' });
    const media = el('div', { class: 'result-media' });

    const encode = el('button', { class: 'action', onClick: async () => {
      if (!ctx.ready) return;
      log.clear();
      stats.textContent = '';
      media.replaceChildren();
      const { codec, ext, pix, opts } = CODECS[select.value];
      const output = `video.${ext}`;
      const command = encodeScript(codec, pix, opts, output);
      log.line(`encoding with ${codec} → ${output} …`, 'muted');
      try {
        const session = await executeFFmpegAsync(
          command,
          (l) => log.write(l.getMessage()),
          (s) => {
            stats.textContent =
              `frame ${s.getVideoFrameNumber()} · ${Math.round(s.getVideoFps())} fps · ` +
              `t=${s.getTime()}ms · ${s.getBitrate()} kbits/s · ${s.getSpeed()}x · ${s.getSize()} bytes`;
          }
        );
        await reportResult(log, session, { writeLogs: false });
        const rc = session.getReturnCode();
        if (!(rc && rc.isValueSuccess())) return;

        const bytes = await readFile(output);
        if (bytes) {
          const dl = downloadBlob(output, bytes, guessMime(output));
          const preview = previewFor(output, dl.url);
          media.replaceChildren(...(preview ? [preview] : []), el('div', {}, dl.link));
        }
      } catch (e) {
        log.line('error: ' + e.message, 'err');
      }
    }}, 'ENCODE');

    root.append(
      el('label', {}, 'Video codec'),
      select,
      el('div', { class: 'row' }, encode),
      stats,
      log.node,
      media
    );
  },
};

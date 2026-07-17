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

import { FFmpegKitConfig, writeFile, readFile } from '../../dist/index.js';
import { encodeScript, el, executeFFmpegAsync, logView, reportResult, downloadBlob, previewFor, guessMime } from '../util.js';

const DAV1D_URL =
  'http://download.opencontent.netflix.com.s3.amazonaws.com/AV1/Sparks/Sparks-5994fps-AV1-10bit-960x540-film-grain-synthesis-854kbps.obu';

async function executeWithLiveLogs(command, log) {
  const session = await executeFFmpegAsync(command, (l) => log.write(l.getMessage()));
  await reportResult(log, session, { writeLogs: false });
  return session;
}

const TESTS = {
  chromaprint: async (log) => {
    log.line('creating an audio sample…', 'muted');
    await executeWithLiveLogs(
      '-hide_banner -y -f lavfi -i sine=frequency=1000:duration=5 -c:a pcm_s16le audio-sample.wav',
      log
    );
    log.line("computing the 'chromaprint' fingerprint…", 'muted');
    await executeWithLiveLogs(
      '-hide_banner -y -i audio-sample.wav -f chromaprint -fp_format 2 chromaprint.txt',
      log
    );
    return null;
  },

  dav1d: async (log) => {
    log.line('dav1d needs an AV1 input; fetching the sample via the page…', 'muted');
    try {
      const res = await fetch(DAV1D_URL);
      if (!res.ok) {
        log.line('fetch failed: HTTP ' + res.status, 'err');
        return null;
      }
      await writeFile('av1.obu', new Uint8Array(await res.arrayBuffer()));
    } catch (e) {
      log.line('fetch blocked (expected — the sample is http + cross-origin): ' + e.message, 'err');
      log.line('Provide a local AV1 file (e.g. via WORKERFS) to exercise dav1d decoding.', 'muted');
      return null;
    }
    log.line('decoding AV1 with dav1d…', 'muted');
    await executeWithLiveLogs('-hide_banner -y -i av1.obu -c:v mpeg4 video.mp4', log);
    return { name: 'video.mp4' };
  },

  webp: async (log) => {
    log.line("encoding 'webp' from tree.jpg…", 'muted');
    await executeWithLiveLogs('-hide_banner -y -i tree.jpg video.webp', log);
    return { name: 'video.webp' };
  },

  libjxl: async (log) => {
    log.line("encoding 'libjxl' (JPEG XL) from tree.jpg…", 'muted');
    let s = await executeWithLiveLogs(
      '-hide_banner -y -i tree.jpg -frames:v 1 -vf ' +
        'format=rgb24,setparams=range=pc:color_primaries=bt709:color_trc=iec61966-2-1:colorspace=gbr ' +
        '-c:v libjxl -distance 1.0 -xyb 1 -update 1 image.jxl',
      log
    );
    const rc = s.getReturnCode();
    if (!(rc && rc.isValueSuccess())) return null;

    log.line("decoding 'libjxl' output to png…", 'muted');
    await executeWithLiveLogs(
      '-hide_banner -y -i image.jxl -frames:v 1 -c:v png -update 1 image.jxl.png',
      log
    );
    return { name: 'image.jxl.png' };
  },

  zscale: async (log) => {
    const source = await readFile('video.mp4');
    if (!source) {
      log.line("video.mp4 not found; native zscale expects the Video tab's output.", 'err');
      return null;
    }

    log.line("applying the 'zscale' tonemap chain to video.mp4…", 'muted');
    await executeWithLiveLogs(
      '-y -i video.mp4 -vf ' +
        'zscale=tin=smpte2084:min=bt2020nc:pin=bt2020:rin=tv:t=smpte2084:m=bt2020nc:p=bt2020:r=tv,' +
        'zscale=t=linear,tonemap=tonemap=clip,zscale=t=bt709,format=yuv420p -c:v mpeg4 video.zscaled.mp4',
      log
    );
    return { name: 'video.zscaled.mp4' };
  },

  vvenc: async (log) => {
    log.line("encoding 'libvvenc' (H.266/VVC)…", 'muted');
    await executeWithLiveLogs(
      encodeScript('libvvenc', 'yuv420p10le', '-preset faster -qp 32', 'video.266'),
      log
    );
    return { name: 'video.266' };
  },
};

export default {
  id: 'other',
  title: 'Other',
  capability: 'partial',
  note:
    'Miscellaneous external-library tests (chromaprint, dav1d, webp, libjxl, zscale, ' +
    'vvenc). Each runs a real command and succeeds only if that library is compiled ' +
    'into the web FFmpeg build; otherwise FFmpeg reports an unknown encoder/filter.',
  render(root, ctx) {
    FFmpegKitConfig.enableLogCallback(null);
    FFmpegKitConfig.enableStatisticsCallback(null);

    const select = el('select', {},
      ...Object.keys(TESTS).map((k) => el('option', { value: k }, k)));
    const log = logView();
    const media = el('div', { class: 'result-media' });

    const run = el('button', { class: 'action', onClick: async () => {
      if (!ctx.ready) return;
      log.clear();
      media.replaceChildren();
      const test = select.value;
      log.line(`running '${test}' test…`, 'muted');
      try {
        const out = await TESTS[test](log);
        if (out && out.name) {
          const bytes = await readFile(out.name);
          if (bytes && bytes.length) {
            const dl = downloadBlob(out.name, bytes, guessMime(out.name));
            const preview = previewFor(out.name, dl.url);
            media.replaceChildren(...(preview ? [preview] : []), el('div', {}, dl.link));
          }
        }
      } catch (e) {
        log.line('error: ' + e.message, 'err');
      }
    }}, 'RUN TEST');

    root.append(
      el('label', {}, 'Feature test'),
      select,
      el('div', { class: 'row' }, run),
      log.node,
      media
    );
  },
};

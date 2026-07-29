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

import { FFmpegKitConfig, Packages, readFile } from '../../dist/index.js';
import { shakingScript, el, executeFFmpegAsync, logView, reportResult, downloadBlob, previewFor, guessMime } from '../util.js';

export default {
  id: 'vidstab',
  title: 'Video stabilization',
  capability: 'live',
  note:
    'Creates the shared slideshow with added shake, analyzes it (vidstabdetect), ' +
    'then stabilizes it (vidstabtransform) with libvidstab.',
  render(root, ctx) {
    const log = logView();
    const media = el('div', { class: 'result-media' });

    FFmpegKitConfig.enableLogCallback((l) => log.write(l.getMessage()));
    FFmpegKitConfig.enableStatisticsCallback(null);

    const run = el('button', { class: 'action', onClick: async () => {
      if (!ctx.ready) return;
      log.clear();
      media.replaceChildren();
      try {
        const externalLibraries = await Packages.getExternalLibraries();
        const videoCodec = externalLibraries.includes('x264') ? 'libx264' : 'mpeg4';

        log.line('creating a shaky slideshow…', 'muted');
        let session = await executeFFmpegAsync(shakingScript('video.mp4', videoCodec));
        await reportResult(log, session, { writeLogs: false });
        let rc = session.getReturnCode();
        if (!(rc && rc.isValueSuccess())) return;

        log.line('pass 1: vidstabdetect…', 'muted');
        session = await executeFFmpegAsync(
          '-hide_banner -y -i video.mp4 -vf vidstabdetect=shakiness=10:accuracy=15:result=transforms.trf -f null -'
        );
        await reportResult(log, session, { writeLogs: false });
        rc = session.getReturnCode();
        if (!(rc && rc.isValueSuccess())) return;

        log.line('pass 2: vidstabtransform…', 'muted');
        session = await executeFFmpegAsync(
          `-hide_banner -y -i video.mp4 -vf vidstabtransform=smoothing=30:input=transforms.trf -c:v ${videoCodec} stabilized.mp4`
        );
        await reportResult(log, session, { writeLogs: false });
        rc = session.getReturnCode();
        if (!(rc && rc.isValueSuccess())) return;

        const bytes = await readFile('stabilized.mp4');
        if (bytes) {
          const dl = downloadBlob('stabilized.mp4', bytes, guessMime('stabilized.mp4'));
          const preview = previewFor('stabilized.mp4', dl.url);
          media.replaceChildren(...(preview ? [preview] : []), el('div', {}, dl.link));
        }
      } catch (e) {
        log.line('error: ' + e.message, 'err');
      }
    }}, 'STABILIZE VIDEO');

    root.append(el('div', { class: 'row' }, run), log.node, media);
  },
};

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
import { encodeScript, el, executeFFmpegAsync, logView, reportResult, downloadBlob, previewFor, guessMime } from '../util.js';

export default {
  id: 'subtitle',
  title: 'Subtitle',
  capability: 'live',
  note:
    'Creates the shared slideshow (as the Video tab does), then burns subtitle.srt onto ' +
    'it with the subtitles filter (libass + freetype/fontconfig).',
  render(root, ctx) {
    const log = logView();
    const stats = el('div', { class: 'stats' });
    const media = el('div', { class: 'result-media' });
    let progressLabel = 'Creating video';

    FFmpegKitConfig.enableLogCallback((l) => log.write(l.getMessage()));
    FFmpegKitConfig.enableStatisticsCallback((s) => {
      if (s.getTime() < 0) return;
      const percent = Math.trunc((s.getTime() * 100) / 9000);
      stats.textContent = `${progressLabel} ${percent}%`;
    });

    const run = el('button', { class: 'action', onClick: async () => {
      if (!ctx.ready) return;
      log.clear();
      stats.textContent = '';
      media.replaceChildren();
      const output = 'video_with_subtitles.mp4';
      try {
        const externalLibraries = await Packages.getExternalLibraries();
        const videoCodec = externalLibraries.includes('x264') ? 'libx264' : 'mpeg4';

        progressLabel = 'Creating video';
        log.line('creating the slideshow…', 'muted');
        let session = await executeFFmpegAsync(encodeScript(videoCodec, 'yuv420p', '', 'video.mp4'));
        await reportResult(log, session, { writeLogs: false });
        const rc = session.getReturnCode();
        if (!(rc && rc.isValueSuccess())) return;

        progressLabel = 'Burning subtitles';
        log.line('burning subtitles…', 'muted');
        session = await executeFFmpegAsync(
          `-hide_banner -y -i video.mp4 -vf "subtitles=filename='subtitle.srt':force_style='FontName=MyFontName'" -c:v ${videoCodec} ${output}`
        );
        await reportResult(log, session, { writeLogs: false });
        const burnReturnCode = session.getReturnCode();
        if (!(burnReturnCode && burnReturnCode.isValueSuccess())) return;

        const bytes = await readFile(output);
        if (bytes) {
          const dl = downloadBlob(output, bytes, guessMime(output));
          const preview = previewFor(output, dl.url);
          media.replaceChildren(...(preview ? [preview] : []), el('div', {}, dl.link));
        }
      } catch (e) {
        log.line('error: ' + e.message, 'err');
      }
    }}, 'BURN SUBTITLES');

    root.append(el('div', { class: 'row' }, run), stats, log.node, media);
  },
};

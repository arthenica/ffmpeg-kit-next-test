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

import { FFmpegKitConfig, FFprobeKit } from '../../dist/index.js';
import { el, logView, writeMediaInformation } from '../util.js';

export default {
  id: 'mediaInformation',
  title: 'Media Information',
  capability: 'live',
  render(root, ctx) {
    FFmpegKitConfig.enableLogCallback(null);
    FFmpegKitConfig.enableStatisticsCallback(null);

    const input = el('input', { type: 'text', value: 'tree.jpg' });
    const log = logView();

    const run = el('button', { class: 'action', onClick: async () => {
      if (!ctx.ready) return;
      log.clear();
      log.line('probing…', 'muted');
      try {
        const session = await FFprobeKit.getMediaInformation(input.value.trim());
        const media = session.getMediaInformation();
        if (!media) {
          log.line('no media information (probe failed or output not parsable)', 'err');
          const logs = await session.getAllLogsAsString();
          if (logs) log.write(logs);
          return;
        }
        writeMediaInformation(log, media);
      } catch (e) {
        log.line('error: ' + e.message, 'err');
      }
    }}, 'GET MEDIA INFORMATION');

    root.append(
      el('label', {}, 'File in the virtual filesystem (a preloaded sample, or one you produced in another tab)'),
      input,
      el('div', { class: 'row' }, run),
      log.node
    );
  },
};

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

import {FFmpegKit, FFmpegKitConfig} from '../../dist/index.js';
import {el, encodeScript, listFFmpegSessions, logView} from '../util.js';

export default {
  id: 'concurrent',
  title: 'Concurrent',
  capability: 'live',
  render(root, ctx) {
    const log = logView();
    if (ctx.ready) {
      FFmpegKitConfig.clearSessions().catch((e) =>
        log.line(`clear sessions failed: ${e.message}`, 'err')
      );
    }
    FFmpegKitConfig.enableLogCallback((l) =>
      log.write(`${l.getSessionId()}:${l.getMessage()}`)
    );
    FFmpegKitConfig.enableStatisticsCallback(null);

    // Session objects per encode slot (1..3), captured as soon as executeAsync posts
    // the run so we can cancel each by id while it runs.
    const sessions = { 1: null, 2: null, 3: null };

    const encode = (n) => {
      if (!ctx.ready) return;
      const output = `concurrent${n}.mp4`;
      const command = encodeScript('mpeg4', 'yuv420p', '', output);
      log.line(`encode ${n}: started`, 'muted');
      FFmpegKit.executeAsync(
        command,
        (session) => {
          const rc = session.getReturnCode();
          const id = session.getSessionId();
          if (rc && rc.isValueCancel()) log.line(`encode ${n} (session ${id}): ■ cancelled`, 'muted');
          else if (rc && rc.isValueSuccess()) log.line(`encode ${n} (session ${id}): ✓ ok`, 'ok');
          else log.line(`encode ${n} (session ${id}): ✗ failed (rc ${rc ? rc.getValue() : 'n/a'})`, 'err');
          listFFmpegSessions(log).catch((e) =>
            log.line(`list FFmpeg sessions failed: ${e.message}`, 'err')
          );
        }
      )
        .then((session) => {
          sessions[n] = session;
          if (n === 3) {
            FFmpegKitConfig.setSessionHistorySize(3).catch((e) =>
              log.line(`set session history size failed: ${e.message}`, 'err')
            );
          }
        })
        .catch((e) => log.line(`encode ${n}: error ${e.message}`, 'err'));
    };

    const cancel = (n) => {
      if (!ctx.ready) return;
      if (n === 0) {
        FFmpegKit.cancel();
        log.line('cancel ALL sessions', 'muted');
        return;
      }
      const id = sessions[n] && sessions[n].getSessionId();
      if (id != null) {
        FFmpegKit.cancel(id);
        log.line(`cancel ${n} (session ${id})`, 'muted');
      } else {
        log.line(`cancel ${n}: no running session`, 'muted');
      }
    };

    const encodeRow = el('div', { class: 'row' },
      el('button', { class: 'action', onClick: () => encode(1) }, 'ENCODE 1'),
      el('button', { class: 'action', onClick: () => encode(2) }, 'ENCODE 2'),
      el('button', { class: 'action', onClick: () => encode(3) }, 'ENCODE 3'));

    const cancelRow = el('div', { class: 'row' },
      el('button', { class: 'action secondary', onClick: () => cancel(1) }, 'CANCEL 1'),
      el('button', { class: 'action secondary', onClick: () => cancel(2) }, 'CANCEL 2'),
      el('button', { class: 'action secondary', onClick: () => cancel(3) }, 'CANCEL 3'),
      el('button', { class: 'action secondary', onClick: () => cancel(0) }, 'CANCEL ALL'));

    root.append(encodeRow, cancelRow, log.node);
  },
};

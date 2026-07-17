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

import { FFmpegKit, FFmpegKitConfig, FFprobeKit, writeFile } from '../../dist/index.js';
import { el, logView, reportResult, writeMediaInformation } from '../util.js';

const NATIVE_HTTPS_TIMEOUT_MS = 5000;

function quoteArg(value) {
  return `'${String(value).replace(/'/g, "'\\''")}'`;
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function cancelSession(session) {
  for (let i = 0; i < 20; i += 1) {
    const id = session?.getSessionId();
    if (id != null) {
      await FFmpegKit.cancel(id);
      return id;
    }
    await delay(50);
  }

  await FFmpegKit.cancel();
  return null;
}

// Https is special on the web: FFmpeg's own network protocols can't open sockets in
// the browser sandbox. The real pattern is to fetch remote media with the page and
// write it into the virtual filesystem, then run FFmpeg locally. This tab shows both:
// the native attempt (which fails as expected) and the working fetch+probe pattern.
export default {
  id: 'https',
  title: 'Https',
  capability: 'partial',
  note:
    "FFmpeg's own https/network protocols cannot open sockets in the browser sandbox, " +
    'so a native "-i https://…" fails to connect. The web pattern is to fetch the media ' +
    'with the page and write it into the virtual filesystem, then run FFmpeg locally ' +
    '(remote fetch is subject to the server\'s CORS policy).',
  render(root, ctx) {
    FFmpegKitConfig.enableLogCallback(null);
    FFmpegKitConfig.enableStatisticsCallback(null);

    const url = el('input', {
      type: 'text',
      value: 'https://upload.wikimedia.org/wikipedia/commons/c/c8/Example.ogg',
    });
    const log = logView();

    const attemptNative = el('button', { class: 'action secondary', onClick: async () => {
      if (!ctx.ready) return;
      log.clear();
      log.line('attempting native FFmpeg https (expected to fail in the sandbox)…', 'muted');
      attemptNative.disabled = true;
      let timedOut = false;
      let timer = null;
      try {
        const src = url.value.trim();
        const command = `-hide_banner -v error -rw_timeout ${NATIVE_HTTPS_TIMEOUT_MS * 1000} -i ${quoteArg(src)} -f null -`;
        let sessionRef = null;
        const pending = new Promise((resolve, reject) => {
          FFmpegKit.executeAsync(command, resolve, (l) => log.write(l.getMessage()))
            .then((session) => {
              sessionRef = session;
            })
            .catch(reject);
        });
        timer = setTimeout(async () => {
          timedOut = true;
          log.line(`native HTTPS did not finish after ${NATIVE_HTTPS_TIMEOUT_MS / 1000}s; cancelling…`, 'muted');
          const id = await cancelSession(sessionRef).catch(() => null);
          if (id == null) log.line('cancelled all FFmpeg sessions because this session id was not available', 'muted');
        }, NATIVE_HTTPS_TIMEOUT_MS);

        const session = await pending;
        await reportResult(log, session, { writeLogs: false });
        log.line(
          timedOut
            ? 'The native HTTPS attempt timed out; use the fetch + local probe path on web.'
            : 'If this failed to open the connection, that is the sandbox limitation.',
          'muted'
        );
      } catch (e) {
        log.line('error: ' + e.message, 'err');
      } finally {
        if (timer) clearTimeout(timer);
        attemptNative.disabled = false;
      }
    }}, 'ATTEMPT NATIVE HTTPS');

    const fetchProbe = el('button', { class: 'action', onClick: async () => {
      if (!ctx.ready) return;
      log.clear();
      const src = url.value.trim();
      const name = 'remote.' + (src.split('.').pop().split(/[?#]/)[0] || 'bin');
      log.line(`fetching ${src} with the page…`, 'muted');
      try {
        const res = await fetch(src);
        if (!res.ok) {
          log.line(`fetch failed: HTTP ${res.status}`, 'err');
          return;
        }
        const bytes = new Uint8Array(await res.arrayBuffer());
        await writeFile(name, bytes);
        log.line(`wrote ${bytes.length} bytes to ${name}; probing locally…`, 'ok');
        const session = await FFprobeKit.getMediaInformation(name);
        const media = session.getMediaInformation();
        if (media) {
          writeMediaInformation(log, media);
        } else {
          log.line('probe returned no media information', 'err');
          const logs = await session.getAllLogsAsString();
          if (logs) log.write(logs);
        }
      } catch (e) {
        // Most commonly a CORS rejection on the remote server.
        log.line('error (often CORS): ' + e.message, 'err');
      }
    }}, 'FETCH VIA PAGE + PROBE');

    root.append(
      el('label', {}, 'Remote media URL'),
      url,
      el('div', { class: 'row' }, fetchProbe, attemptNative),
      log.node
    );
  },
};

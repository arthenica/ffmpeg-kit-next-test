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

import {
  FFmpegKitConfig,
  FFprobeKit,
  FFmpegKitInputBuffer,
  FFmpegKitOutputBuffer,
  readFile,
} from '../../dist/index.js';
import { el, executeFFmpegAsync, logView, reportResult, downloadBlob, previewFor } from '../util.js';

const PROTOCOL_FFKITMEM = 'ffkitmem';
const PROTOCOLS = [PROTOCOL_FFKITMEM];

function escapeDrawtextText(value) {
  return value
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/'/g, "'\\''");
}

function humanReadableByteCount(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  const kb = bytes / 1024;
  if (kb < 1024) return `${kb.toFixed(1)} KB`;
  return `${(kb / 1024).toFixed(1)} MB`;
}

function buildFFKitMemProtocolCommand(inputUrl, outputUrl, fontPath, text) {
  const drawtext =
    `drawtext=fontfile=${fontPath}:text='${escapeDrawtextText(text)}':` +
    'x=(w-text_w)/2:y=h-th-40:fontsize=h/15:fontcolor=white:box=1:boxcolor=black@0.5';
  return `-y -i ${inputUrl} -vf "${drawtext}" -frames:v 1 -f image2 -c:v mjpeg ${outputUrl}`;
}

export default {
  id: 'ffkitProtocols',
  title: 'FFKit Protocols',
  capability: 'live',
  note:
    'ffkitmem runs with in-memory input/output buffers.',
  render(root, ctx) {
    const protocol = el('select', {},
      ...PROTOCOLS.map((p) => el('option', { value: p }, p)));
    const text = el('input', { type: 'text', value: 'FFmpegKitNext' });
    const status = el('div', { class: 'stats' }, 'Select a protocol, then run FFmpeg or FFprobe.');
    const log = logView();
    const media = el('div', { class: 'result-media' });

    FFmpegKitConfig.enableLogCallback((l) => log.write(l.getMessage()));
    FFmpegKitConfig.enableStatisticsCallback((s) => {
      if (s.getTime() < 0) return;
      const percent = Math.trunc((s.getTime() * 100) / 9000);
      status.textContent = `Encoding video ${percent}%`;
    });

    protocol.addEventListener('change', () => {
      log.clear();
      media.replaceChildren();
      status.textContent = 'Select a protocol, then run FFmpeg or FFprobe.';
    });

    const runFFmpeg = el('button', { class: 'action', onClick: async () => {
      if (!ctx.ready) return;

      log.clear();
      media.replaceChildren();
      status.textContent = 'Running...';
      let input = null;
      let output = null;
      try {
        const bytes = await readFile('tree.jpg');
        if (!bytes) {
          log.line('sample tree.jpg not found in MEMFS', 'err');
          status.textContent = 'Processing failed.';
          return;
        }
        input = await FFmpegKitInputBuffer.fromByteArray(bytes, 'jpg');
        output = await FFmpegKitOutputBuffer.create('jpg');

        const command = buildFFKitMemProtocolCommand(
          input.getUrl(),
          output.getUrl(),
          '/usr/share/fonts/doppioone_regular.ttf',
          text.value || ''
        );
        log.line(`ffkitmem ffmpeg command: ${command}`, 'muted');
        const session = await executeFFmpegAsync(command);
        await reportResult(log, session, { writeLogs: false });

        const rc = session.getReturnCode();
        if (!(rc && rc.isValueSuccess())) {
          status.textContent = 'Processing failed.';
          return;
        }

        const out = await output.toByteArray();
        const outputSize = await output.getSize();
        status.textContent =
          `in ${input.getUrl()} (${humanReadableByteCount(input.getSize())}) -> drawtext -> ` +
          `out ${output.getUrl()} (${humanReadableByteCount(outputSize)})`;
        const dl = downloadBlob('ffkitmem.jpg', out, 'image/jpeg');
        const preview = previewFor('ffkitmem.jpg', dl.url);
        media.replaceChildren(...(preview ? [preview] : []), el('div', {}, dl.link));
      } catch (e) {
        status.textContent = 'Processing failed.';
        log.line('error: ' + e.message, 'err');
      } finally {
        if (input) await input.close();
        if (output) await output.close();
      }
    }}, 'RUN FFMPEG');

    const runFFprobe = el('button', { class: 'action', onClick: async () => {
      if (!ctx.ready) return;

      log.clear();
      media.replaceChildren();
      status.textContent = 'Running...';
      let input = null;
      try {
        const bytes = await readFile('tree.jpg');
        if (!bytes) {
          log.line('sample tree.jpg not found in MEMFS', 'err');
          status.textContent = 'Processing failed.';
          return;
        }
        input = await FFmpegKitInputBuffer.fromByteArray(bytes, 'jpg');
        const command = `-hide_banner -print_format json -show_format -show_streams ${input.getUrl()}`;
        log.line(`ffkitmem ffprobe command: ${command}`, 'muted');
        const session = await FFprobeKit.execute(command);
        const rc = session.getReturnCode();
        const output = await session.getOutput();
        if (output) log.write(output);
        status.textContent = `ffprobe -> ${input.getUrl()}`;
        if (!(rc && rc.isValueSuccess())) {
          log.line('Command failed. Please check output for the details.', 'err');
        }
      } catch (e) {
        status.textContent = 'Processing failed.';
        log.line('error: ' + e.message, 'err');
      } finally {
        if (input) await input.close();
      }
    }}, 'RUN FFPROBE');

    root.append(
      el('label', {}, 'Protocol'),
      protocol,
      el('label', {}, 'Overlay text'),
      text,
      el('div', { class: 'row' }, runFFmpeg, runFFprobe),
      status,
      log.node,
      media
    );
  },
};

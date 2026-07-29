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
  FFmpegKit,
  FFmpegKitConfig,
  FFprobeSession,
  Level,
  LogRedirectionStrategy,
} from '../../dist/index.js';
import { el, listFFprobeSessions, logView, reportResult } from '../util.js';

export default {
  id: 'command',
  title: 'Command',
  capability: 'live',
  render(root, ctx) {
    FFmpegKitConfig.enableLogCallback(null);
    FFmpegKitConfig.enableStatisticsCallback(null);

    const command = el('textarea', { placeholder: '' });
    const log = logView();

    const runFFmpeg = el('button', { class: 'action', onClick: async () => {
      if (!ctx.ready) return;
      log.clear();
      const ffmpegCommand = command.value.trim();
      log.line(`Current log level is ${Level.levelToString(FFmpegKitConfig.getLogLevel())}.`);
      log.line('Testing FFmpeg COMMAND asynchronously.', 'muted');
      log.line(`FFmpeg process started with arguments: '${ffmpegCommand}'`, 'muted');
      try {
        const session = await FFmpegKit.execute(ffmpegCommand);
        await reportResult(log, session, { writeLogs: false });
        const output = await session.getOutput();
        if (output) log.write(output);
      } catch (e) {
        log.line('error: ' + e.message, 'err');
      }
    }}, 'RUN FFMPEG');

    const runFFprobe = el('button', { class: 'action', onClick: async () => {
      if (!ctx.ready) return;
      log.clear();
      const ffprobeCommand = command.value.trim();
      log.line('Testing FFprobe COMMAND asynchronously.', 'muted');
      log.line(`FFprobe process started with arguments: '${ffprobeCommand}'`, 'muted');
      try {
        const session = await FFprobeSession.create(
          FFmpegKitConfig.parseArguments(ffprobeCommand),
          async (completedSession) => {
            await reportResult(log, completedSession, { writeLogs: false });
            const output = await completedSession.getOutput();
            if (output) log.write(output);
          },
          null,
          LogRedirectionStrategy.NEVER_PRINT_LOGS
        );
        await FFmpegKitConfig.asyncFFprobeExecute(session);
        await listFFprobeSessions(log);
      } catch (e) {
        log.line('error: ' + e.message, 'err');
      }
    }}, 'RUN FFPROBE');

    root.append(
      el('label', {}, 'Command (omit the leading "ffmpeg" or "ffprobe")'),
      command,
      el('div', { class: 'row' }, runFFmpeg, runFFprobe),
      log.node
    );
  },
};

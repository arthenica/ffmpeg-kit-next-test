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

import { FFmpegKit, FFmpegKitConfig, readFile } from '../../dist/index.js';
import { el, listAllLogs, logView, reportResult, downloadBlob, previewFor, guessMime } from '../util.js';

const CODECS = {
  'mp2 (twolame)': { ext: 'mpg',  args: '-c:a mp2 -b:a 192k' },
  'mp3 (liblame)': { ext: 'mp3',  args: '-c:a libmp3lame -qscale:a 2' },
  'mp3 (libshine)': { ext: 'mp3', args: '-c:a libshine -qscale:a 2' },
  'vorbis': { ext: 'ogg', args: '-c:a libvorbis -b:a 64k' },
  'opus': { ext: 'opus', args: '-c:a libopus -b:a 64k -vbr on -compression_level 10' },
  'amr-nb': { ext: 'amr', args: '-ar 8000 -ab 12.2k -c:a libopencore_amrnb' },
  'amr-wb': { ext: 'amr', args: '-ar 8000 -ab 12.2k -c:a libvo_amrwbenc -strict experimental' },
  'ilbc': { ext: 'lbc', args: '-c:a libilbc -ar 8000 -b:a 15200' },
  'soxr': { ext: 'wav', args: '-af aresample=resampler=soxr -ar 44100' },
  'speex': { ext: 'spx', args: '-c:a libspeex -ar 16000' },
  'wavpack': { ext: 'wv', args: '-c:a wavpack -b:a 64k' },
  'lc3': { ext: 'lc3', args: '-ar 48000 -ac 1 -c:a liblc3 -b:a 96k -frame_duration 10' },
};

const SAMPLE = 'audio-sample.wav';

export default {
  id: 'audio',
  title: 'Audio',
  capability: 'live',
  note:
    'Encodes a 1 kHz tone across the software audio-codec matrix. Each entry needs its ' +
    'library in the build (lame/shine/twolame/vorbis/opus/amr/ilbc/speex/lc3/soxr); if ' +
    'one is missing, FFmpeg reports an unknown encoder. Many of these (amr, speex, lc3, ' +
    'wavpack) do not play in the browser but still download.',
  render(root, ctx) {
    const select = el('select', {},
      ...Object.keys(CODECS).map((c) => el('option', { value: c }, c)));
    const log = logView();
    const stats = el('div', { class: 'stats' });
    const media = el('div', { class: 'result-media' });

    FFmpegKitConfig.enableLogCallback(null);
    FFmpegKitConfig.enableStatisticsCallback(null);

    const createSampleCommand =
      `-hide_banner -y -f lavfi -i sine=frequency=1000:duration=5 -c:a pcm_s16le ${SAMPLE}`;

    const createAudioSample = async () => {
      log.line(`Creating audio sample with '${createSampleCommand}'.`, 'muted');
      const session = await FFmpegKit.execute(createSampleCommand);
      const rc = session.getReturnCode();
      if (rc && rc.isValueSuccess()) {
        log.line('AUDIO sample created', 'ok');
        return true;
      }

      log.line('Creating AUDIO sample failed. Please check logs for the details.', 'err');
      const output = await session.getOutput();
      if (output) log.write(output);
      return false;
    };

    const enableTabCallbacks = () => {
      FFmpegKitConfig.enableLogCallback((l) => log.write(l.getMessage()));
      FFmpegKitConfig.enableStatisticsCallback(null);
    };

    let samplePromise = Promise.resolve(false);
    if (ctx.ready) {
      samplePromise = createAudioSample()
        .catch((e) => {
          log.line('error: ' + e.message, 'err');
          return false;
        });
    }
    enableTabCallbacks();

    const encode = el('button', { class: 'action', onClick: async () => {
      if (!ctx.ready) return;
      log.clear();
      stats.textContent = '';
      media.replaceChildren();
      const sampleReady = await samplePromise;
      if (!sampleReady) {
        log.line('Audio sample is not available. Please check the activation logs for the details.', 'err');
        return;
      }

      const { ext, args } = CODECS[select.value];
      const output = `audio.${ext}`;
      const encodeCommand = `-hide_banner -y -i ${SAMPLE} ${args} ${output}`;
      try {
        log.line(`FFmpeg process started with arguments: '${encodeCommand}'.`, 'muted');
        const session = await FFmpegKit.execute(encodeCommand);
        await reportResult(log, session, { writeLogs: false });
        const encodeReturnCode = session.getReturnCode();
        if (!(encodeReturnCode && encodeReturnCode.isValueSuccess())) return;
        await listAllLogs(session, log);

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
      el('label', {}, 'Audio codec'),
      select,
      el('div', { class: 'row' }, encode),
      stats,
      log.node,
      media
    );
  },
};

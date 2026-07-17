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

// Tiny DOM helpers shared by the tab modules.

import {FFmpegKit, FFmpegKitConfig, FFprobeKit, Level} from '../dist/index.js';

export function el(tag, props = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(props)) {
    if (key === 'class') node.className = value;
    else if (key === 'text') node.textContent = value;
    else if (key === 'html') node.innerHTML = value;
    else if (key.startsWith('on') && typeof value === 'function') {
      node.addEventListener(key.slice(2).toLowerCase(), value);
    } else if (value !== null && value !== undefined) {
      node.setAttribute(key, value);
    }
  }
  for (const child of children.flat()) {
    if (child == null) continue;
    node.append(child.nodeType ? child : document.createTextNode(String(child)));
  }
  return node;
}

// A scrolling log panel with line-level styling.
export function logView() {
  const pre = el('pre', { class: 'log' });
  const normalizeLogText = (text) =>
    String(text ?? '').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  return {
    node: pre,
    clear: () => (pre.textContent = ''),
    line: (text, cls) => {
      const span = el('span', cls ? { class: cls } : {}, (text ?? '') + '\n');
      pre.append(span);
      pre.scrollTop = pre.scrollHeight;
    },
    write: (text) => {
      pre.append(document.createTextNode(normalizeLogText(text)));
      pre.scrollTop = pre.scrollHeight;
    },
  };
}

// Render a session's result summary into a log view. Pass `writeLogs: false` when
// the logs were already streamed live (via a logCallback) to avoid duplicating them.
export function executeFFmpegAsync(command, logCallback = null, statisticsCallback = null) {
  return new Promise((resolve, reject) => {
    FFmpegKit.executeAsync(command, resolve, logCallback, statisticsCallback).catch(reject);
  });
}

export async function listFFmpegSessions(log = null) {
  const sessionList = await FFmpegKit.listSessions();
  const write = (text) => {
    console.log(text);
    if (log) log.line(text);
  };

  write(`Listing ${sessionList.length} FFmpeg sessions asynchronously.`);

  let count = 0;
  for (const session of sessionList) {
    const sessionId = session.getSessionId();
    const startTime = session.getStartTime();
    const duration = session.getDuration();
    const state = FFmpegKitConfig.sessionStateToString(session.getState());
    const returnCode = session.getReturnCode();

    write(
      `Session ${count++} = id:${sessionId}, startTime:${startTime}, ` +
      `duration:${duration}, state:${state}, returnCode:${returnCode}.`
    );
  }
}

export async function listFFprobeSessions(log = null) {
  const sessionList = await FFprobeKit.listFFprobeSessions();
  const write = (text) => {
    console.log(text);
    if (log) log.line(text);
  };

  write(`Listing ${sessionList.length} FFprobe sessions asynchronously.`);

  let count = 0;
  for (const session of sessionList) {
    const sessionId = session.getSessionId();
    const startTime = session.getStartTime();
    const duration = session.getDuration();
    const state = FFmpegKitConfig.sessionStateToString(session.getState());
    const returnCode = session.getReturnCode();

    write(
      `Session ${count++} = id:${sessionId}, startTime:${startTime}, ` +
      `duration:${duration}, state:${state}, returnCode:${returnCode}.`
    );
  }
}

export async function listAllLogs(session, log = null) {
  const write = (text) => {
    console.log(text);
    if (log) log.line(text);
  };

  write(`Listing log entries for session: ${session.getSessionId()}`);
  const allLogs = await session.getAllLogs();
  for (const entry of allLogs) {
    write(`${Level.levelToString(entry.getLevel())}:${entry.getMessage()}`);
  }
  write(`Listed log entries for session: ${session.getSessionId()}`);
}

export async function listAllStatistics(session, log = null) {
  const write = (text) => {
    console.log(text);
    if (log) log.line(text);
  };

  write(`Listing statistics entries for session: ${session.getSessionId()}`);
  const allStatistics = await session.getAllStatistics();
  for (const s of allStatistics) {
    write(
      `${s.getVideoFrameNumber()}:${s.getVideoFps()}:${s.getVideoQuality()}:` +
      `${s.getSize()}:${s.getTime()}:${s.getBitrate()}:${s.getSpeed()}`
    );
  }
  write(`Listed statistics entries for session: ${session.getSessionId()}`);
}

export async function reportResult(log, session, { writeLogs = true } = {}) {
  const rc = session.getReturnCode();
  if (rc && rc.isValueSuccess()) {
    log.line(`✓ completed (rc ${rc.getValue()}) in ${session.getDuration()} ms`, 'ok');
  } else if (rc && rc.isValueCancel()) {
    log.line('■ cancelled', 'muted');
  } else {
    const code = rc ? rc.getValue() : 'n/a';
    log.line(`✗ failed (rc ${code})`, 'err');
    if (session.getFailStackTrace()) log.line(session.getFailStackTrace(), 'err');
  }
  const logs = writeLogs ? await session.getAllLogsAsString() : '';
  if (logs) log.write(logs);
}

const EXT_MIME = {
  mp4: 'video/mp4', avi: 'video/x-msvideo', webm: 'video/webm', ogv: 'video/ogg',
  mov: 'video/quicktime', mkv: 'video/x-matroska',
  m4a: 'audio/mp4', aac: 'audio/aac', flac: 'audio/flac', wav: 'audio/wav',
  mp3: 'audio/mpeg', ogg: 'audio/ogg', opus: 'audio/ogg',
  jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', gif: 'image/gif',
};

export function guessMime(name) {
  const ext = (name || '').split('.').pop().toLowerCase();
  return EXT_MIME[ext] || 'application/octet-stream';
}

// Build a preview element (<video>/<audio>/<img>) for a produced file, or null.
// Video/audio elements self-heal on decode error: the file encoded fine, but the
// browser may not support the codec (e.g. mpeg4 — browser <video> needs H.264/VP8/
// VP9/AV1, which require external libraries not yet in the web build). In that case
// we replace the broken player with an explanation instead of failing silently.
export function previewFor(name, url) {
  const mime = guessMime(name);
  if (mime.startsWith('image/')) return el('img', { src: url });
  if (!mime.startsWith('video/') && !mime.startsWith('audio/')) return null;

  const kind = mime.startsWith('video/') ? 'video' : 'audio';
  const media = el(kind, { controls: '', src: url });
  const wrap = el('div', {}, media);
  media.addEventListener('error', () => {
    wrap.replaceChildren(
      el('div', { class: 'notice' },
        `Encoded successfully, but the browser can't play this codec (${name}). ` +
        `Browser playback needs H.264/VP8/VP9/AV1 or AAC/Opus/Vorbis/FLAC — most of ` +
        `these require external codec libraries not yet wired into the web build. ` +
        `Use the download link, or open it in a desktop player.`)
    );
  });
  return wrap;
}

export function downloadBlob(name, bytes, mime) {
  const blob = new Blob([bytes], { type: mime || 'application/octet-stream' });
  const url = URL.createObjectURL(blob);
  const a = el('a', { href: url, download: name, text: `download ${name}` });
  // Revoke lazily so the click can use the URL.
  a.addEventListener('click', () => setTimeout(() => URL.revokeObjectURL(url), 30000));
  return { url, link: a, blob };
}

// Shared slideshow generators built from the three preloaded sample images — mirrors
// the native Video helper (generateEncodeVideoScript / generateShakingVideoScript). The
// Video, Subtitle and Video-stabilization tabs all build their source clip from these,
// exactly as the iOS/Android/linux apps do.
const IMAGES = ['tree.jpg', 'lake.jpg', 'sunset.jpg'];

const SCALE = "scale=w='if(gte(iw/ih,640/427),min(iw,640),-1)':h='if(gte(iw/ih,640/427),-1,min(ih,427))',scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=sar=1/1";
const PAD = 'pad=width=640:height=427:x=(640-iw)/2:y=(427-ih)/2:color=#00000000';

// The canonical crossfade slideshow (Video tab, and the Subtitle tab's source).
export function encodeScript(codec, pixelFormat, opts, output) {
  const [a, b, c] = IMAGES;
  const customOptions = opts ? `${opts} ` : '';
  const filter =
    `[0:v]setpts=PTS-STARTPTS,${SCALE},split=2[stream1out1][stream1out2];` +
    `[1:v]setpts=PTS-STARTPTS,${SCALE},split=2[stream2out1][stream2out2];` +
    `[2:v]setpts=PTS-STARTPTS,${SCALE},split=2[stream3out1][stream3out2];` +
    `[stream1out1]${PAD},trim=duration=3,select=lte(n\\,90)[stream1overlaid];` +
    `[stream1out2]${PAD},trim=duration=1,select=lte(n\\,30)[stream1ending];` +
    `[stream2out1]${PAD},trim=duration=2,select=lte(n\\,60)[stream2overlaid];` +
    `[stream2out2]${PAD},trim=duration=1,select=lte(n\\,30),split=2[stream2starting][stream2ending];` +
    `[stream3out1]${PAD},trim=duration=2,select=lte(n\\,60)[stream3overlaid];` +
    `[stream3out2]${PAD},trim=duration=1,select=lte(n\\,30)[stream3starting];` +
    `[stream2starting][stream1ending]blend=all_expr='if(gte(X,(W/2)*T/1)*lte(X,W-(W/2)*T/1),B,A)':shortest=1[stream2blended];` +
    `[stream3starting][stream2ending]blend=all_expr='if(gte(X,(W/2)*T/1)*lte(X,W-(W/2)*T/1),B,A)':shortest=1[stream3blended];` +
    `[stream1overlaid][stream2blended][stream2overlaid][stream3blended][stream3overlaid]concat=n=5:v=1:a=0,scale=w=640:h=424,format=${pixelFormat}[video]`;
  return (
    `-hide_banner -y -loop 1 -i "${a}" -loop 1 -i '${b}' -loop 1 -i "${c}" ` +
    `-filter_complex "${filter}" -map [video] -fps_mode cfr ${customOptions}-c:v ${codec} -r 30 ${output}`
  );
}

// The jittery slideshow the Video-stabilization tab feeds to vidstabdetect/transform.
export function shakingScript(output) {
  const [a, b, c] = IMAGES;
  const filter =
    `[0:v]setpts=PTS-STARTPTS,${SCALE}[stream1out];` +
    `[1:v]setpts=PTS-STARTPTS,${SCALE}[stream2out];` +
    `[2:v]setpts=PTS-STARTPTS,${SCALE}[stream3out];` +
    `[stream1out]${PAD},trim=duration=3[stream1overlaid];` +
    `[stream2out]${PAD},trim=duration=3[stream2overlaid];` +
    `[stream3out]${PAD},trim=duration=3[stream3overlaid];` +
    `[3:v][stream1overlaid]overlay=x='2*mod(n\\,4)':y='2*mod(n\\,2)',trim=duration=3[stream1shaking];` +
    `[3:v][stream2overlaid]overlay=x='2*mod(n\\,4)':y='2*mod(n\\,2)',trim=duration=3[stream2shaking];` +
    `[3:v][stream3overlaid]overlay=x='2*mod(n\\,4)':y='2*mod(n\\,2)',trim=duration=3[stream3shaking];` +
    `[stream1shaking][stream2shaking][stream3shaking]concat=n=3:v=1:a=0,scale=w=640:h=424,format=yuv420p[video]`;
  return (
    `-hide_banner -y -loop 1 -i "${a}" -loop 1 -i '${b}' -loop 1 -i ${c} ` +
    `-f lavfi -i color=black:s=640x427 ` +
    `-filter_complex "${filter}" -map [video] -fps_mode cfr -c:v mpeg4 -r 30 ${output}`
  );
}

function isPresent(value) {
  return value !== null && value !== undefined;
}

function appendIfPresent(log, label, value) {
  if (isPresent(value)) log.line(`${label}: ${value}`);
}

function appendTags(log, prefix, tags) {
  if (!tags) return;
  for (const key of Object.keys(tags)) {
    log.line(`${prefix}: ${key}:${tags[key]}`);
  }
}

export function writeMediaInformation(log, information) {
  log.line(`Media information for ${information.getFilename() ?? ''}`);
  appendIfPresent(log, 'Format', information.getFormat());
  appendIfPresent(log, 'Long format', information.getLongFormat());
  appendIfPresent(log, 'Bitrate', information.getBitrate());
  appendIfPresent(log, 'Duration', information.getDuration());
  appendIfPresent(log, 'Start time', information.getStartTime());
  appendIfPresent(log, 'Size', information.getSize());
  appendTags(log, 'Tag', information.getTags && information.getTags());

  const streams = information.getStreams ? information.getStreams() : [];
  for (const stream of streams || []) {
    appendIfPresent(log, 'Stream index', stream.getIndex());
    appendIfPresent(log, 'Stream type', stream.getType());
    appendIfPresent(log, 'Stream codec', stream.getCodec());
    appendIfPresent(log, 'Stream codec long', stream.getCodecLong());
    appendIfPresent(log, 'Stream format', stream.getFormat());
    appendIfPresent(log, 'Stream width', stream.getWidth());
    appendIfPresent(log, 'Stream height', stream.getHeight());
    appendIfPresent(log, 'Stream bitrate', stream.getBitrate());
    appendIfPresent(log, 'Stream sample rate', stream.getSampleRate());
    appendIfPresent(log, 'Stream sample format', stream.getSampleFormat && stream.getSampleFormat());
    appendIfPresent(log, 'Stream channel layout', stream.getChannelLayout());
    appendIfPresent(log, 'Stream sample aspect ratio', stream.getSampleAspectRatio && stream.getSampleAspectRatio());
    appendIfPresent(log, 'Stream display ascpect ratio', stream.getDisplayAspectRatio && stream.getDisplayAspectRatio());
    appendIfPresent(log, 'Stream average frame rate', stream.getAverageFrameRate && stream.getAverageFrameRate());
    appendIfPresent(log, 'Stream real frame rate', stream.getRealFrameRate && stream.getRealFrameRate());
    appendIfPresent(log, 'Stream time base', stream.getTimeBase && stream.getTimeBase());
    appendIfPresent(log, 'Stream codec time base', stream.getCodecTimeBase && stream.getCodecTimeBase());
    appendTags(log, 'Stream tag', stream.getTags && stream.getTags());
  }

  const chapters = information.getChapters ? information.getChapters() : [];
  for (const chapter of chapters || []) {
    appendIfPresent(log, 'Chapter id', chapter.getId());
    appendIfPresent(log, 'Chapter time base', chapter.getTimeBase());
    appendIfPresent(log, 'Chapter start', chapter.getStart());
    appendIfPresent(log, 'Chapter start time', chapter.getStartTime());
    appendIfPresent(log, 'Chapter end', chapter.getEnd());
    appendIfPresent(log, 'Chapter end time', chapter.getEndTime());
    appendTags(log, 'Chapter tag', chapter.getTags && chapter.getTags());
  }
}

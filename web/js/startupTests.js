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
  FFmpegSession,
  Level,
  Packages,
} from '../dist/index.js';

function now() {
  const date = new Date();
  return (
    `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()} ` +
    `${date.getHours()}:${date.getMinutes()}:${date.getSeconds()}.${date.getMilliseconds()}`
  );
}

function ffprint(text) {
  const chunks = String(text).match(/.{1,900}/g) || [''];
  for (const chunk of chunks) {
    console.log(`${now()} - ${chunk}`);
  }
}

function assertEqual(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${expected}, got ${actual}`);
  }
}

function assertSessionHistorySize(sessionList, maxSize) {
  if (sessionList.length > maxSize) {
    throw new Error(`Session history exceeded ${maxSize}: ${sessionList.length}`);
  }
}

async function testCommonApiMethods() {
  ffprint('Testing common api methods.');

  const version = await FFmpegKitConfig.getFFmpegVersion();
  ffprint(`FFmpeg version: ${version}`);

  const platform = await FFmpegKitConfig.getPlatform();
  ffprint(`Platform: ${platform}`);

  ffprint(`Old log level: ${Level.levelToString(FFmpegKitConfig.getLogLevel())}`);
  await FFmpegKitConfig.setLogLevel(Level.AV_LOG_INFO);
  ffprint(`New log level: ${Level.levelToString(FFmpegKitConfig.getLogLevel())}`);

  const externalLibraries = await Packages.getExternalLibraries();
  for (const value of externalLibraries) {
    ffprint(`External library: ${value}`);
  }
}

function testParseArguments() {
  ffprint('Testing parseArguments.');

  let argumentArray = FFmpegKitConfig.parseArguments(
    '-hide_banner -loop 1 -i file.jpg -filter_complex [0:v]setpts=PTS-STARTPTS[video] -map [video] -fps_mode cfr video.mp4'
  );
  assertEqual(argumentArray.length, 12, 'simple command argument count');
  assertEqual(argumentArray[0], '-hide_banner', 'simple argument 0');
  assertEqual(argumentArray[1], '-loop', 'simple argument 1');
  assertEqual(argumentArray[2], '1', 'simple argument 2');
  assertEqual(argumentArray[3], '-i', 'simple argument 3');
  assertEqual(argumentArray[4], 'file.jpg', 'simple argument 4');
  assertEqual(argumentArray[5], '-filter_complex', 'simple argument 5');
  assertEqual(argumentArray[6], '[0:v]setpts=PTS-STARTPTS[video]', 'simple argument 6');
  assertEqual(argumentArray[7], '-map', 'simple argument 7');
  assertEqual(argumentArray[8], '[video]', 'simple argument 8');
  assertEqual(argumentArray[9], '-fps_mode', 'simple argument 9');
  assertEqual(argumentArray[10], 'cfr', 'simple argument 10');
  assertEqual(argumentArray[11], 'video.mp4', 'simple argument 11');

  argumentArray = FFmpegKitConfig.parseArguments(
    "-loop 1 'file one.jpg'  -filter_complex  '[0:v]setpts=PTS-STARTPTS[video]'  -map  [video]  video.mp4 "
  );
  assertEqual(argumentArray.length, 8, 'single quotes argument count');
  assertEqual(argumentArray[0], '-loop', 'single quotes argument 0');
  assertEqual(argumentArray[1], '1', 'single quotes argument 1');
  assertEqual(argumentArray[2], 'file one.jpg', 'single quotes argument 2');
  assertEqual(argumentArray[3], '-filter_complex', 'single quotes argument 3');
  assertEqual(argumentArray[4], '[0:v]setpts=PTS-STARTPTS[video]', 'single quotes argument 4');
  assertEqual(argumentArray[5], '-map', 'single quotes argument 5');
  assertEqual(argumentArray[6], '[video]', 'single quotes argument 6');
  assertEqual(argumentArray[7], 'video.mp4', 'single quotes argument 7');

  argumentArray = FFmpegKitConfig.parseArguments(
    '-loop  1 "file one.jpg"   -filter_complex "[0:v]setpts=PTS-STARTPTS[video]"  -map  [video]  video.mp4 '
  );
  assertEqual(argumentArray.length, 8, 'double quotes argument count');
  assertEqual(argumentArray[0], '-loop', 'double quotes argument 0');
  assertEqual(argumentArray[1], '1', 'double quotes argument 1');
  assertEqual(argumentArray[2], 'file one.jpg', 'double quotes argument 2');
  assertEqual(argumentArray[3], '-filter_complex', 'double quotes argument 3');
  assertEqual(argumentArray[4], '[0:v]setpts=PTS-STARTPTS[video]', 'double quotes argument 4');
  assertEqual(argumentArray[5], '-map', 'double quotes argument 5');
  assertEqual(argumentArray[6], '[video]', 'double quotes argument 6');
  assertEqual(argumentArray[7], 'video.mp4', 'double quotes argument 7');

  argumentArray = FFmpegKitConfig.parseArguments(
    ' -i   file:///tmp/input.mp4 -vcodec libx264 -vf "scale=1024:1024,pad=width=1024:height=1024:x=0:y=0:color=black"  -acodec copy  -q:v 0  -q:a   0 video.mp4'
  );
  assertEqual(argumentArray.length, 13, 'filter command argument count');
  assertEqual(argumentArray[0], '-i', 'filter argument 0');
  assertEqual(argumentArray[1], 'file:///tmp/input.mp4', 'filter argument 1');
  assertEqual(argumentArray[2], '-vcodec', 'filter argument 2');
  assertEqual(argumentArray[3], 'libx264', 'filter argument 3');
  assertEqual(argumentArray[4], '-vf', 'filter argument 4');
  assertEqual(
    argumentArray[5],
    'scale=1024:1024,pad=width=1024:height=1024:x=0:y=0:color=black',
    'filter argument 5'
  );
  assertEqual(argumentArray[6], '-acodec', 'filter argument 6');
  assertEqual(argumentArray[7], 'copy', 'filter argument 7');
  assertEqual(argumentArray[8], '-q:v', 'filter argument 8');
  assertEqual(argumentArray[9], '0', 'filter argument 9');
  assertEqual(argumentArray[10], '-q:a', 'filter argument 10');
  assertEqual(argumentArray[11], '0', 'filter argument 11');
  assertEqual(argumentArray[12], 'video.mp4', 'filter argument 12');

  argumentArray = FFmpegKitConfig.parseArguments(
    '  -i   file:///tmp/input.mp4 -vf "subtitles=file:///tmp/subtitles.srt:force_style=\'FontSize=16,PrimaryColour=&HFFFFFF&\'" -vcodec libx264   -acodec copy  -q:v 0 -q:a  0  video.mp4'
  );
  assertEqual(argumentArray.length, 13, 'single-quote style argument count');
  assertEqual(argumentArray[0], '-i', 'single-quote style argument 0');
  assertEqual(argumentArray[1], 'file:///tmp/input.mp4', 'single-quote style argument 1');
  assertEqual(argumentArray[2], '-vf', 'single-quote style argument 2');
  assertEqual(
    argumentArray[3],
    "subtitles=file:///tmp/subtitles.srt:force_style='FontSize=16,PrimaryColour=&HFFFFFF&'",
    'single-quote style argument 3'
  );
  assertEqual(argumentArray[4], '-vcodec', 'single-quote style argument 4');
  assertEqual(argumentArray[5], 'libx264', 'single-quote style argument 5');
  assertEqual(argumentArray[6], '-acodec', 'single-quote style argument 6');
  assertEqual(argumentArray[7], 'copy', 'single-quote style argument 7');
  assertEqual(argumentArray[8], '-q:v', 'single-quote style argument 8');
  assertEqual(argumentArray[9], '0', 'single-quote style argument 9');
  assertEqual(argumentArray[10], '-q:a', 'single-quote style argument 10');
  assertEqual(argumentArray[11], '0', 'single-quote style argument 11');
  assertEqual(argumentArray[12], 'video.mp4', 'single-quote style argument 12');

  argumentArray = FFmpegKitConfig.parseArguments(
    '  -i   file:///tmp/input.mp4 -vf "subtitles=file:///tmp/subtitles.srt:force_style=\\"FontSize=16,PrimaryColour=&HFFFFFF&\\"" -vcodec libx264   -acodec copy  -q:v 0 -q:a  0  video.mp4'
  );
  assertEqual(argumentArray.length, 13, 'escaped double-quote style argument count');
  assertEqual(argumentArray[0], '-i', 'escaped double-quote style argument 0');
  assertEqual(argumentArray[1], 'file:///tmp/input.mp4', 'escaped double-quote style argument 1');
  assertEqual(argumentArray[2], '-vf', 'escaped double-quote style argument 2');
  assertEqual(
    argumentArray[3],
    'subtitles=file:///tmp/subtitles.srt:force_style=\\"FontSize=16,PrimaryColour=&HFFFFFF&\\"',
    'escaped double-quote style argument 3'
  );
  assertEqual(argumentArray[4], '-vcodec', 'escaped double-quote style argument 4');
  assertEqual(argumentArray[5], 'libx264', 'escaped double-quote style argument 5');
  assertEqual(argumentArray[6], '-acodec', 'escaped double-quote style argument 6');
  assertEqual(argumentArray[7], 'copy', 'escaped double-quote style argument 7');
  assertEqual(argumentArray[8], '-q:v', 'escaped double-quote style argument 8');
  assertEqual(argumentArray[9], '0', 'escaped double-quote style argument 9');
  assertEqual(argumentArray[10], '-q:a', 'escaped double-quote style argument 10');
  assertEqual(argumentArray[11], '0', 'escaped double-quote style argument 11');
  assertEqual(argumentArray[12], 'video.mp4', 'escaped double-quote style argument 12');
}

async function setSessionHistorySizeTest() {
  ffprint('Testing setSessionHistorySize.');

  let newSize = 15;
  await FFmpegKitConfig.setSessionHistorySize(newSize);
  for (let i = 1; i <= newSize + 5; i += 1) {
    await FFmpegSession.create(['argument1', 'argument2']);
    assertSessionHistorySize(await FFmpegKitConfig.getSessions(), newSize);
  }

  newSize = 3;
  await FFmpegKitConfig.setSessionHistorySize(newSize);
  for (let i = 1; i <= newSize + 5; i += 1) {
    await FFmpegSession.create(['argument1', 'argument2']);
    assertSessionHistorySize(await FFmpegKitConfig.getSessions(), newSize);
  }
}

export async function runStartupTests() {
  await testCommonApiMethods();
  testParseArguments();
  await setSessionHistorySizeTest();
}

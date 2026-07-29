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

// Bootstraps the FFmpegKitNext web package, builds the tab bar, and renders the
// active tab.

import {FFmpegKitConfig, writeFile} from '../dist/index.js';
import {el} from './util.js';
import {runStartupTests} from './startupTests.js';

import command from './tabs/command.js';
import mediaInformation from './tabs/mediaInformation.js';
import video from './tabs/video.js';
import audio from './tabs/audio.js';
import concurrent from './tabs/concurrent.js';
import ffkitProtocols from './tabs/ffkitProtocols.js';
import subtitle from './tabs/subtitle.js';
import vidstab from './tabs/vidstab.js';
import https from './tabs/https.js';
import other from './tabs/other.js';

const TABS = [
    command,
    video,
    https,
    mediaInformation,
    audio,
    subtitle,
    vidstab,
    concurrent,
    ffkitProtocols,
    other,
];

const banner = document.getElementById('status-banner');
const tabbar = document.getElementById('tabbar');
const content = document.getElementById('content');

const ctx = {ready: false};

let activeId = TABS[0].id;

function renderTabBar() {
    tabbar.replaceChildren(
        ...TABS.map((tab) =>
            el(
                'button',
                {
                    class: tab.id === activeId ? 'active' : '',
                    onClick: () => {
                        activeId = tab.id;
                        renderTabBar();
                        renderActiveTab();
                    },
                },
                tab.title
            )
        )
    );
}

function renderActiveTab() {
    const tab = TABS.find((t) => t.id === activeId);
    content.replaceChildren();

    content.append(el('h2', {}, tab.title));

    if (tab.note) {
        content.append(el('div', {class: 'notice'}, tab.note));
    }

    const root = el('div');
    content.append(root);
    tab.render(root, ctx);
}

renderTabBar();
renderActiveTab();

// Sample media the tabs reference by name. Preloading into the module's virtual
// filesystem is the *app's* job — the shipped library worker no longer bundles
// test assets — so we fetch them and write them in via the public writeFile API.
const SAMPLE_ASSETS = [
    {source: 'tree.jpg', target: 'tree.jpg'},
    {source: 'lake.jpg', target: 'lake.jpg'},
    {source: 'sunset.jpg', target: 'sunset.jpg'},
    {source: 'subtitle.srt', target: 'subtitle.srt'},
    {source: 'doppioone_regular.ttf', target: '/usr/share/fonts/doppioone_regular.ttf'},
    {source: 'notosansarabic_regular.ttf', target: '/usr/share/fonts/notosansarabic_regular.ttf'},
    {source: 'notosanssc_regular.ttf', target: '/usr/share/fonts/notosanssc_regular.ttf'},
];

async function preloadAssets() {
    const loaded = [];
    for (const asset of SAMPLE_ASSETS) {
        try {
            const res = await fetch(new URL('../assets/' + asset.source, import.meta.url));
            if (!res.ok) continue;
            await writeFile(asset.target, new Uint8Array(await res.arrayBuffer()));
            loaded.push(asset.target);
        } catch {
            /* asset is optional */
        }
    }
    return loaded;
}

function configureFonts() {
    return FFmpegKitConfig.setFontDirectoryList(['/usr/share/fonts'], {
        MyFontName: 'Doppio One',
        NotoSansArabic: 'Noto Sans Arabic',
        NotoSansSC: 'Noto Sans SC',
    });
}

FFmpegKitConfig.init()
    .then(async () => {
        const version = await FFmpegKitConfig.getVersion();
        const assets = await preloadAssets();
        const fontConfig = await configureFonts().catch((err) => ({
            ok: false,
            error: err.message,
        }));
        ctx.ready = true;
        ctx.fontConfig = fontConfig;
        banner.className = 'ready';
        banner.textContent = `Ready — FFmpegKitNext ${version || '?'} · assets: ${assets.length} loaded`;
        // Re-render so tabs can enable their controls now that the module is ready.
        renderActiveTab();
        runStartupTests().catch((err) => {
            console.error('Startup API tests failed:', err);
        });
    })
    .catch((err) => {
        banner.className = 'error';
        banner.textContent = 'Failed to load module: ' + err.message;
    });

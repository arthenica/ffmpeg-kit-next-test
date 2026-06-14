/*
 * Copyright (c) 2018-2021, 2026 Taner Sener
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

package com.arthenica.ffmpegkit.test;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentActivity;
import androidx.viewpager2.adapter.FragmentStateAdapter;

public class PagerAdapter extends FragmentStateAdapter {
    private static final int NUMBER_OF_TABS = 10;

    private final Context context;

    PagerAdapter(FragmentActivity fragmentActivity, Context context) {
        super(fragmentActivity);
        this.context = context;
    }

    @NonNull
    @Override
    public Fragment createFragment(final int position) {
        switch (position) {
            case 0: {
                return CommandTabFragment.newInstance();
            }
            case 1: {
                return VideoTabFragment.newInstance();
            }
            case 2: {
                return HttpsTabFragment.newInstance();
            }
            case 3: {
                return AudioTabFragment.newInstance();
            }
            case 4: {
                return SubtitleTabFragment.newInstance();
            }
            case 5: {
                return VidStabTabFragment.newInstance();
            }
            case 6: {
                return PipeTabFragment.newInstance();
            }
            case 7: {
                return ConcurrentExecutionTabFragment.newInstance();
            }
            case 8: {
                return OtherTabFragment.newInstance();
            }
            case 9: {
                return FFKitProtocolsTabFragment.newInstance();
            }
            default: {
                throw new IllegalArgumentException(String.format("Unknown tab position: %d", position));
            }
        }
    }

    @Override
    public int getItemCount() {
        return NUMBER_OF_TABS;
    }

    public CharSequence getPageTitle(final int position) {
        switch (position) {
            case 0: {
                return context.getString(R.string.command_tab);
            }
            case 1: {
                return context.getString(R.string.video_tab);
            }
            case 2: {
                return context.getString(R.string.https_tab);
            }
            case 3: {
                return context.getString(R.string.audio_tab);
            }
            case 4: {
                return context.getString(R.string.subtitle_tab);
            }
            case 5: {
                return context.getString(R.string.vidstab_tab);
            }
            case 6: {
                return context.getString(R.string.pipe_tab);
            }
            case 7: {
                return context.getString(R.string.concurrent_tab);
            }
            case 8: {
                return context.getString(R.string.other_tab);
            }
            case 9: {
                return context.getString(R.string.ffkit_protocols_tab);
            }
            default: {
                return null;
            }
        }
    }

}

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

package com.arthenica.ffmpegkit.test

import android.content.Context
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import androidx.viewpager2.adapter.FragmentStateAdapter

class PagerAdapter(fragmentActivity: FragmentActivity, private val context: Context) : FragmentStateAdapter(fragmentActivity) {

    override fun createFragment(position: Int): Fragment {
        return when (position) {
            0 -> CommandTabFragment()
            1 -> VideoTabFragment()
            2 -> HttpsTabFragment()
            3 -> AudioTabFragment()
            4 -> SubtitleTabFragment()
            5 -> VidStabTabFragment()
            6 -> PipeTabFragment()
            7 -> ConcurrentExecutionTabFragment()
            8 -> OtherTabFragment()
            9 -> FFKitProtocolsTabFragment()
            else -> throw IllegalArgumentException("Unknown tab position: $position")
        }
    }

    override fun getItemCount(): Int {
        return NUMBER_OF_TABS
    }

    fun getPageTitle(position: Int): CharSequence? {
        return when (position) {
            0 -> context.getString(R.string.command_tab)
            1 -> context.getString(R.string.video_tab)
            2 -> context.getString(R.string.https_tab)
            3 -> context.getString(R.string.audio_tab)
            4 -> context.getString(R.string.subtitle_tab)
            5 -> context.getString(R.string.vidstab_tab)
            6 -> context.getString(R.string.pipe_tab)
            7 -> context.getString(R.string.concurrent_tab)
            8 -> context.getString(R.string.other_tab)
            9 -> context.getString(R.string.ffkit_protocols_tab)
            else -> null
        }
    }

    companion object {
        private const val NUMBER_OF_TABS = 10
    }
}

/*
 * Copyright (c) 2018-2026 Taner Sener
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
import android.graphics.Color
import android.graphics.Typeface
import android.media.MediaPlayer
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.MediaController
import android.widget.TextView
import android.widget.VideoView
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.graphics.toColorInt
import androidx.core.net.toUri
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.fragment.app.Fragment
import androidx.viewpager2.widget.ViewPager2
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.FFmpegKitConfig
import com.arthenica.ffmpegkit.FFprobeKit
import com.arthenica.ffmpegkit.Level
import com.arthenica.ffmpegkit.Signal
import com.arthenica.ffmpegkit.test.databinding.ActivityMainBinding
import com.arthenica.ffmpegkit.util.ResourcesUtil
import com.arthenica.smartexception.java.Exceptions
import java.io.File
import java.io.IOException
import kotlin.math.roundToInt

fun Fragment.cacheFile(name: String): File = File(requireContext().cacheDir, name)

fun Fragment.filesFile(name: String): File = File(requireContext().filesDir, name)

fun VideoView.playFile(context: Context, file: File) {
    val mediaController = MediaController(context)
    mediaController.setAnchorView(this)
    setVideoURI("file://${file.absolutePath}".toUri())
    setMediaController(mediaController)
    requestFocus()
    setOnPreparedListener { _: MediaPlayer -> setBackgroundColor(0x00000000) }
    setOnErrorListener { _: MediaPlayer, _: Int, _: Int ->
        stopPlayback()
        false
    }
    start()
}

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(SystemBarStyle.dark(Color.TRANSPARENT))

        super.onCreate(savedInstanceState)

        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val pagerAdapter = PagerAdapter(this, this)
        binding.pager.adapter = pagerAdapter
        setupTabs(binding.pager, pagerAdapter)

        ViewCompat.setOnApplyWindowInsetsListener(binding.rootLayout) { _, windowInsets ->
            val bars = windowInsets.getInsets(
                WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout()
            )
            binding.toolbar.setPadding(0, bars.top, 0, 0)
            binding.pager.setPadding(bars.left, 0, bars.right, bars.bottom)
            WindowInsetsCompat.CONSUMED
        }

        try {
            registerApplicationFonts()
            Log.d(TAG, "Application fonts registered.")
        } catch (e: IOException) {
            Log.e(TAG, "Font registration failed.${Exceptions.getStackTraceString(e)}.")
        }

        Log.d(TAG, "Listing supported camera ids.")
        listSupportedCameraIds()

        FFmpegKitConfig.ignoreSignal(Signal.SIGXCPU)
        FFmpegKitConfig.setLogLevel(Level.AV_LOG_INFO)
    }

    @Throws(IOException::class)
    fun registerApplicationFonts() {
        val cacheDirectory = cacheDir
        val fontDirectory = File(cacheDirectory, "fonts")

        val fontDirectoryCreated = fontDirectory.mkdirs()
        if (!fontDirectoryCreated) {
            Log.i(TAG, "Failed to create font directory: ${fontDirectory.absolutePath}.")
        }

        ResourcesUtil.rawResourceToFile(resources, R.raw.doppioone_regular, File(fontDirectory, "doppioone_regular.ttf"))
        ResourcesUtil.rawResourceToFile(resources, R.raw.truenorg, File(fontDirectory, "truenorg.otf"))

        val fontNameMapping = hashMapOf<String?, String?>()
        fontNameMapping["MyFontName"] = "Doppio One"
        FFmpegKitConfig.setFontDirectoryList(this, listOf(fontDirectory.absolutePath, "/system/fonts"), fontNameMapping)
        FFmpegKitConfig.setEnvironmentVariable("FFREPORT", "file=${File(cacheDirectory.absolutePath, "ffreport.txt").absolutePath}")
    }

    fun listSupportedCameraIds() {
        val supportedCameraIds = FFmpegKitConfig.getSupportedCameraIds(this)
        if (supportedCameraIds.isEmpty()) {
            Log.d(TAG, "No supported cameras found.")
        } else {
            for (supportedCameraId in supportedCameraIds) {
                Log.d(TAG, "Supported camera detected: $supportedCameraId")
            }
        }
    }

    private fun setupTabs(viewPager: ViewPager2, pagerAdapter: PagerAdapter) {
        val tabScrollView = binding.tabScrollView
        val tabStrip = binding.tabStrip
        val density = resources.displayMetrics.density
        val horizontalPadding = (24 * density).roundToInt()
        val minTabWidth = (88 * density).roundToInt()
        val selectedColor = ContextCompat.getColor(this, R.color.navigationColor)
        val unselectedColor = "#f39c12".toColorInt()

        for (i in 0 until pagerAdapter.itemCount) {
            val tab = TextView(this)
            tab.text = pagerAdapter.getPageTitle(i)
            tab.gravity = android.view.Gravity.CENTER
            tab.setSingleLine(true)
            tab.setTextColor(unselectedColor)
            tab.textSize = 14f
            tab.setTypeface(Typeface.DEFAULT, Typeface.BOLD)
            tab.setPadding(horizontalPadding, 0, horizontalPadding, 0)
            tab.minWidth = minTabWidth
            tab.setOnClickListener { viewPager.setCurrentItem(i, true) }
            tabStrip.addView(
                tab,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.MATCH_PARENT
                )
            )
        }

        viewPager.registerOnPageChangeCallback(object : ViewPager2.OnPageChangeCallback() {
            override fun onPageSelected(position: Int) {
                updateSelectedTab(tabStrip, tabScrollView, position, selectedColor, unselectedColor)
            }
        })
        updateSelectedTab(tabStrip, tabScrollView, 0, selectedColor, unselectedColor)
    }

    private fun updateSelectedTab(tabStrip: LinearLayout, tabScrollView: HorizontalScrollView, selectedPosition: Int, selectedColor: Int, unselectedColor: Int) {
        for (i in 0 until tabStrip.childCount) {
            val tab = tabStrip.getChildAt(i) as TextView
            val selected = i == selectedPosition
            tab.setBackgroundResource(if (selected) R.drawable.tab_indicator else 0)
            tab.setTextColor(if (selected) selectedColor else unselectedColor)
        }

        val selectedTab = tabStrip.getChildAt(selectedPosition)
        selectedTab?.post {
            val scrollX = selectedTab.left - (tabScrollView.width - selectedTab.width) / 2
            tabScrollView.smoothScrollTo(scrollX, 0)
        }
    }

    companion object {
        const val TAG = "ffmpeg-kit-next-test"

        init {
            Exceptions.registerRootPackage("com.arthenica")
        }

        @JvmField
        val handler = Handler(Looper.getMainLooper())

        @JvmStatic
        fun listFFmpegSessions() {
            val ffmpegSessions = FFmpegKit.listSessions()
            Log.d(TAG, "Listing FFmpeg sessions.")
            for (i in ffmpegSessions.indices) {
                val session = ffmpegSessions[i]
                Log.d(
                    TAG,
                    String.format(
                        "Session %d = id:%d, startTime:%s, duration:%s, state:%s, returnCode:%s.",
                        i,
                        session.getSessionId(),
                        session.getStartTime(),
                        session.getDuration(),
                        session.getState(),
                        session.getReturnCode()
                    )
                )
            }
            Log.d(TAG, "Listed FFmpeg sessions.")
        }

        @JvmStatic
        fun listFFprobeSessions() {
            val ffprobeSessions = FFprobeKit.listFFprobeSessions()
            Log.d(TAG, "Listing FFprobe sessions.")
            for (i in ffprobeSessions.indices) {
                val session = ffprobeSessions[i]
                Log.d(
                    TAG,
                    String.format(
                        "Session %d = id:%d, startTime:%s, duration:%s, state:%s, returnCode:%s.",
                        i,
                        session.getSessionId(),
                        session.getStartTime(),
                        session.getDuration(),
                        session.getState(),
                        session.getReturnCode()
                    )
                )
            }
            Log.d(TAG, "Listed FFprobe sessions.")
        }

        @JvmStatic
        fun addUIAction(action: () -> Unit) {
            handler.post(action)
        }

        @JvmStatic
        fun notNull(string: String?, valuePrefix: String): String {
            return if (string == null) "" else "$valuePrefix$string"
        }
    }
}

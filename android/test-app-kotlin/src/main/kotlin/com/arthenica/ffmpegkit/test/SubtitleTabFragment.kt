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

import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.Fragment
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.FFmpegKitConfig
import com.arthenica.ffmpegkit.ReturnCode
import com.arthenica.ffmpegkit.Statistics
import com.arthenica.ffmpegkit.test.databinding.FragmentSubtitleTabBinding
import com.arthenica.ffmpegkit.util.DialogUtil
import com.arthenica.ffmpegkit.util.ResourcesUtil
import com.arthenica.smartexception.java.Exceptions
import java.io.File
import java.io.IOException
import java.math.BigDecimal
import java.math.RoundingMode

class SubtitleTabFragment : Fragment(R.layout.fragment_subtitle_tab) {

    private enum class State {
        IDLE,
        CREATING,
        BURNING
    }

    private var _binding: FragmentSubtitleTabBinding? = null
    private val binding: FragmentSubtitleTabBinding
        get() = requireNotNull(_binding)
    private lateinit var createProgressDialog: AlertDialog
    private lateinit var burnProgressDialog: AlertDialog
    private var statistics: Statistics? = null
    private var state = State.IDLE
    private var sessionId: Long? = null

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        _binding = FragmentSubtitleTabBinding.bind(view)

        binding.burnSubtitlesButton.setOnClickListener { burnSubtitles() }
        state = State.IDLE
    }

    override fun onDestroyView() {
        _binding = null
        super.onDestroyView()
    }

    override fun onResume() {
        super.onResume()
        setActive()
    }

    fun enableLogCallback() {
        FFmpegKitConfig.enableLogCallback { log -> Log.d(MainActivity.TAG, log.message) }
    }

    fun enableStatisticsCallback() {
        FFmpegKitConfig.enableStatisticsCallback { newStatistics ->
            MainActivity.addUIAction {
                statistics = newStatistics
                updateProgressDialog()
            }
        }
    }

    fun burnSubtitles() {
        val image1File = cacheFile("tree.jpg")
        val image2File = cacheFile("lake.jpg")
        val image3File = cacheFile("sunset.jpg")
        val videoFile = getVideoFile()
        val videoWithSubtitlesFile = getVideoWithSubtitlesFile()

        try {
            binding.videoPlayerFrame.stopPlayback()

            Log.d(MainActivity.TAG, "Testing SUBTITLE burning")

            showCreateProgressDialog()

            ResourcesUtil.resourceToFile(resources, R.drawable.tree, image1File)
            ResourcesUtil.resourceToFile(resources, R.drawable.lake, image2File)
            ResourcesUtil.resourceToFile(resources, R.drawable.sunset, image3File)
            ResourcesUtil.rawResourceToFile(resources, R.raw.subtitle, getSubtitleFile())

            val ffmpegCommand = FFmpegCommands.buildEncodeVideoCommand(image1File.absolutePath, image2File.absolutePath, image3File.absolutePath, videoFile.absolutePath, "mpeg4", "")

            Log.d(MainActivity.TAG, String.format("FFmpeg process started with arguments: '%s'.", ffmpegCommand))

            state = State.CREATING

            sessionId = FFmpegKit.executeAsync(ffmpegCommand) { session ->
                Log.d(MainActivity.TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", session.getState(), session.getReturnCode(), MainActivity.notNull(session.getFailStackTrace(), "\n")))

                hideCreateProgressDialog()

                if (ReturnCode.isSuccess(session.getReturnCode())) {
                    MainActivity.addUIAction {
                        Log.d(MainActivity.TAG, "Create completed successfully; burning subtitles.")

                        val burnSubtitlesCommand = String.format("-y -i %s -vf subtitles=filename='%s':force_style='FontName=MyFontName' -c:v mpeg4 %s", videoFile.absolutePath, getSubtitleFile().absolutePath, videoWithSubtitlesFile.absolutePath)

                        showBurnProgressDialog()

                        Log.d(MainActivity.TAG, String.format("FFmpeg process started with arguments: '%s'.", burnSubtitlesCommand))

                        state = State.BURNING

                        FFmpegKit.executeAsync(burnSubtitlesCommand) { secondSession ->
                            hideBurnProgressDialog()

                            MainActivity.addUIAction {
                                if (ReturnCode.isSuccess(secondSession.getReturnCode())) {
                                    Log.d(MainActivity.TAG, "Burn subtitles completed successfully; playing video.")
                                    playVideo()
                                } else if (ReturnCode.isCancel(secondSession.getReturnCode())) {
                                    Popup.show(requireContext(), "Burn subtitles operation cancelled.")
                                    Log.e(MainActivity.TAG, "Burn subtitles operation cancelled")
                                } else {
                                    Popup.show(requireContext(), "Burn subtitles failed. Please check logs for the details.")
                                    Log.d(MainActivity.TAG, String.format("Burn subtitles failed with state %s and rc %s.%s", secondSession.getState(), secondSession.getReturnCode(), MainActivity.notNull(secondSession.getFailStackTrace(), "\n")))
                                }
                            }
                        }
                    }
                }
            }.getSessionId()

            Log.d(MainActivity.TAG, String.format("Async FFmpeg process started with sessionId %d.", sessionId))
        } catch (e: IOException) {
            Log.e(MainActivity.TAG, String.format("Burn subtitles failed %s.", Exceptions.getStackTraceString(e)))
            Popup.show(requireContext(), "Burn subtitles failed")
        }
    }

    fun playVideo() {
        binding.videoPlayerFrame.playFile(requireContext(), getVideoWithSubtitlesFile())
    }

    fun getSubtitleFile(): File {
        return cacheFile("subtitle.srt")
    }

    fun getVideoFile(): File {
        return filesFile("video.mp4")
    }

    fun getVideoWithSubtitlesFile(): File {
        return filesFile("video-with-subtitles.mp4")
    }

    fun setActive() {
        Log.i(MainActivity.TAG, "Subtitle Tab Activated")
        enableLogCallback()
        enableStatisticsCallback()
        Popup.show(requireContext(), getString(R.string.subtitle_test_tooltip_text))
    }

    fun showCreateProgressDialog() {
        statistics = null

        createProgressDialog = DialogUtil.createCancellableProgressDialog(requireContext(), "Creating video") {
            if (sessionId != null) {
                Log.d(
                    MainActivity.TAG,
                    String.format("Cancelling FFmpeg execution with sessionId %d.", sessionId)
                )
                FFmpegKit.cancel(sessionId!!)
            }
        }
        createProgressDialog.show()
    }

    fun updateProgressDialog() {
        val currentStatistics = statistics
        if (currentStatistics == null || currentStatistics.time < 0) {
            return
        }

        val timeInMilliseconds = currentStatistics.time
        val totalVideoDuration = 9000

        val completePercentage = BigDecimal(timeInMilliseconds).multiply(BigDecimal(100)).divide(BigDecimal(totalVideoDuration), 0, RoundingMode.HALF_UP).toString()

        when (state) {
            State.CREATING -> {
                val textView = createProgressDialog.findViewById<TextView>(R.id.progressDialogText)
                if (textView != null) {
                    textView.text = "Creating video: % $completePercentage."
                }
            }
            State.BURNING -> {
                val textView = burnProgressDialog.findViewById<TextView>(R.id.progressDialogText)
                if (textView != null) {
                    textView.text = "Burning subtitles: % $completePercentage."
                }
            }
            State.IDLE -> Unit
        }
    }

    fun hideCreateProgressDialog() {
        createProgressDialog.dismiss()
    }

    fun showBurnProgressDialog() {
        statistics = null

        burnProgressDialog = DialogUtil.createCancellableProgressDialog(requireContext(), "Burning subtitles") {
            FFmpegKit.cancel()
        }
        burnProgressDialog.show()
    }

    fun hideBurnProgressDialog() {
        burnProgressDialog.dismiss()
    }

}

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
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.Fragment
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.FFmpegKitConfig
import com.arthenica.ffmpegkit.ReturnCode
import com.arthenica.ffmpegkit.Statistics
import com.arthenica.ffmpegkit.test.databinding.FragmentVideoTabBinding
import com.arthenica.ffmpegkit.util.DialogUtil
import com.arthenica.ffmpegkit.util.ResourcesUtil
import com.arthenica.smartexception.java.Exceptions
import java.io.File
import java.io.IOException
import java.math.BigDecimal
import java.math.RoundingMode

class VideoTabFragment : Fragment(R.layout.fragment_video_tab), AdapterView.OnItemSelectedListener {
    private var _binding: FragmentVideoTabBinding? = null
    private val binding: FragmentVideoTabBinding
        get() = requireNotNull(_binding)
    private lateinit var progressDialog: AlertDialog
    private lateinit var selectedCodec: String
    private var statistics: Statistics? = null

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        _binding = FragmentVideoTabBinding.bind(view)

        val adapter = ArrayAdapter.createFromResource(requireContext(), R.array.video_codec, R.layout.spinner_item)
        adapter.setDropDownViewResource(R.layout.spinner_dropdown_item)
        binding.videoCodecSpinner.adapter = adapter
        binding.videoCodecSpinner.onItemSelectedListener = this

        binding.encodeButton.setOnClickListener { encodeVideo() }

        progressDialog = DialogUtil.createProgressDialog(requireContext(), "Encoding video")
        selectedCodec = resources.getStringArray(R.array.video_codec)[0]
    }

    override fun onDestroyView() {
        _binding = null
        super.onDestroyView()
    }

    override fun onResume() {
        super.onResume()
        setActive()
    }

    override fun onItemSelected(parent: AdapterView<*>, view: View?, position: Int, id: Long) {
        selectedCodec = parent.getItemAtPosition(position).toString()
    }

    override fun onNothingSelected(parent: AdapterView<*>) {
        // DO NOTHING
    }

    fun encodeVideo() {
        val image1File = cacheFile("tree.jpg")
        val image2File = cacheFile("lake.jpg")
        val image3File = cacheFile("sunset.jpg")
        val videoFile = getVideoFile()

        try {
            binding.videoPlayerFrame.stopPlayback()

            if (videoFile.exists()) {
                videoFile.delete()
            }

            val videoCodec = selectedCodec

            Log.d(MainActivity.TAG, String.format("Testing VIDEO encoding with '%s' codec", videoCodec))

            showProgressDialog()

            ResourcesUtil.resourceToFile(resources, R.drawable.tree, image1File)
            ResourcesUtil.resourceToFile(resources, R.drawable.lake, image2File)
            ResourcesUtil.resourceToFile(resources, R.drawable.sunset, image3File)

            val ffmpegCommand = FFmpegCommands.buildEncodeVideoCommand(image1File.absolutePath, image2File.absolutePath, image3File.absolutePath, videoFile.absolutePath, getSelectedVideoCodec(), getPixelFormat(), getCustomOptions())

            Log.d(MainActivity.TAG, String.format("FFmpeg process started with arguments: '%s'.", ffmpegCommand))

            val session = FFmpegKit.executeAsync(ffmpegCommand, { session ->
                val returnCode = session.getReturnCode()

                hideProgressDialog()

                MainActivity.addUIAction {
                    if (ReturnCode.isSuccess(returnCode)) {
                        Log.d(MainActivity.TAG, String.format("Encode completed successfully in %d milliseconds; playing video.", session.getDuration()))
                        playVideo()
                    } else {
                        Popup.show(requireContext(), "Encode failed. Please check logs for the details.")
                        Log.d(MainActivity.TAG, String.format("Encode failed with state %s and rc %s.%s", session.getState(), returnCode, MainActivity.notNull(session.getFailStackTrace(), "\n")))
                    }
                }
            }, { log ->
                Log.d(MainActivity.TAG, log.message)
            }, { statistics ->
                this.statistics = statistics
                MainActivity.addUIAction { updateProgressDialog() }
            })

            Log.d(MainActivity.TAG, String.format("Async FFmpeg process started with sessionId %d.", session.getSessionId()))
        } catch (e: IOException) {
            Log.e(MainActivity.TAG, String.format("Encode video failed %s.", Exceptions.getStackTraceString(e)))
            Popup.show(requireContext(), "Encode video failed")
        }
    }

    fun playVideo() {
        binding.videoPlayerFrame.playFile(requireContext(), getVideoFile())
    }

    fun getPixelFormat(): String {
        return if ("x265" == selectedCodec) {
            "yuv420p10le"
        } else {
            "yuv420p"
        }
    }

    fun getSelectedVideoCodec(): String {
        var videoCodec = selectedCodec

        videoCodec = when (videoCodec) {
            "x264" -> "libx264"
            "h264_mediacodec" -> "h264_mediacodec"
            "hevc_mediacodec" -> "hevc_mediacodec"
            "openh264" -> "libopenh264"
            "x265" -> "libx265"
            "xvid" -> "libxvid"
            "vp8" -> "libvpx"
            "vp9" -> "libvpx-vp9"
            "aom" -> "libaom-av1"
            "svt-av1" -> "libsvtav1"
            "kvazaar" -> "libkvazaar"
            "theora" -> "libtheora"
            else -> videoCodec
        }

        return videoCodec
    }

    fun getVideoFile(): File {
        val extension = when (selectedCodec) {
            "vp8", "vp9" -> "webm"
            "theora" -> "ogv"
            "hap" -> "mov"
            else -> "mp4"
        }

        val video = "video.$extension"
        return filesFile(video)
    }

    fun getCustomOptions(): String {
        return when (selectedCodec) {
            "x265" -> "-crf 28 -preset fast "
            "vp8" -> "-b:v 1M -crf 10 "
            "vp9" -> "-b:v 2M "
            "aom" -> "-crf 30 -strict experimental "
            "svt-av1" -> "-preset 8 -crf 35 "
            "theora" -> "-qscale:v 7 "
            "hap" -> "-format hap_q "
            else -> ""
        }
    }

    fun setActive() {
        Log.i(MainActivity.TAG, "Video Tab Activated")
        FFmpegKitConfig.enableLogCallback(null)
        FFmpegKitConfig.enableStatisticsCallback(null)
        Popup.show(requireContext(), getString(R.string.video_test_tooltip_text))
        TranscoderBridge.getInstance()
    }

    fun showProgressDialog() {
        statistics = null
        progressDialog.show()
    }

    fun updateProgressDialog() {
        val currentStatistics = statistics
        if (currentStatistics == null || currentStatistics.time < 0) {
            return
        }

        val timeInMilliseconds = currentStatistics.time
        val totalVideoDuration = 9000

        val completePercentage = BigDecimal(timeInMilliseconds).multiply(BigDecimal(100)).divide(BigDecimal(totalVideoDuration), 0, RoundingMode.HALF_UP).toString()

        val textView = progressDialog.findViewById<TextView>(R.id.progressDialogText)
        if (textView != null) {
            textView.text = String.format("Encoding video: %% %s.", completePercentage)
        }
    }

    fun hideProgressDialog() {
        progressDialog.dismiss()

        MainActivity.addUIAction {
            progressDialog = DialogUtil.createProgressDialog(requireContext(), "Encoding video")
        }
    }
}

class TranscoderBridge {
    companion object {
        @JvmStatic
        fun getInstance(): TranscoderBridge {
            FFmpegKitConfig.enableFFmpegSessionCompleteCallback(fun (session) {
                Log.d(MainActivity.TAG,"I AM SESSION COMPLETE CALLBACK")
            })

            FFmpegKitConfig.enableStatisticsCallback(fun (stats) {
                Log.d(MainActivity.TAG, "I AM STATISTICS CALLBACK")
            })

            return TranscoderBridge()
        }
    }
}

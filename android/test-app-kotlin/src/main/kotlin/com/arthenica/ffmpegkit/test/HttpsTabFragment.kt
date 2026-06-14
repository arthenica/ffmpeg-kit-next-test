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
import android.text.method.ScrollingMovementMethod
import android.util.Log
import android.view.View
import androidx.fragment.app.Fragment
import com.arthenica.ffmpegkit.Chapter
import com.arthenica.ffmpegkit.FFmpegKitConfig
import com.arthenica.ffmpegkit.FFprobeKit
import com.arthenica.ffmpegkit.MediaInformationSessionCompleteCallback
import com.arthenica.ffmpegkit.StreamInformation
import com.arthenica.ffmpegkit.test.databinding.FragmentHttpsTabBinding
import org.json.JSONObject
import java.util.Random

class HttpsTabFragment : Fragment(R.layout.fragment_https_tab) {
    private var _binding: FragmentHttpsTabBinding? = null
    private val binding: FragmentHttpsTabBinding
        get() = requireNotNull(_binding)

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        _binding = FragmentHttpsTabBinding.bind(view)

        binding.getInfoFromUrlButton.setOnClickListener { runGetMediaInformation(1) }
        binding.getRandomInfoButton1.setOnClickListener { runGetMediaInformation(2) }
        binding.getRandomInfoButton2.setOnClickListener { runGetMediaInformation(3) }
        binding.getInfoAndFailButton.setOnClickListener { runGetMediaInformation(4) }

        binding.outputText.movementMethod = ScrollingMovementMethod()
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
        FFmpegKitConfig.enableLogCallback(null)
        FFmpegKitConfig.enableStatisticsCallback(null)
    }

    fun runGetMediaInformation(buttonNumber: Int) {
        val testUrl: String = when (buttonNumber) {
            1 -> {
                var url = binding.urlText.text.toString()
                if (url.isEmpty()) {
                    url = HTTPS_TEST_DEFAULT_URL
                    binding.urlText.setText(url)
                }
                url
            }
            2, 3 -> getRandomTestUrl()
            else -> {
                binding.urlText.setText(HTTPS_TEST_FAIL_URL)
                HTTPS_TEST_FAIL_URL
            }
        }

        Log.d(MainActivity.TAG, String.format("Testing HTTPS with for button %d using url %s.", buttonNumber, testUrl))

        if (buttonNumber == 4) {
            clearOutput()
        }

        FFprobeKit.getMediaInformationAsync(testUrl, createNewCompleteCallback())
    }

    fun setActive() {
        Log.i(MainActivity.TAG, "Https Tab Activated")
        enableLogCallback()
        Popup.show(requireContext(), getString(R.string.https_test_tooltip_text))
    }

    fun appendOutput(logMessage: String) {
        MainActivity.addUIAction { binding.outputText.append(logMessage) }
    }

    fun clearOutput() {
        binding.outputText.text = ""
    }

    private fun getRandomTestUrl(): String {
        return when (testUrlRandom.nextInt(3)) {
            0 -> HTTPS_TEST_RANDOM_URL_1
            1 -> HTTPS_TEST_RANDOM_URL_2
            else -> HTTPS_TEST_RANDOM_URL_3
        }
    }

    private fun createNewCompleteCallback(): MediaInformationSessionCompleteCallback {
        return MediaInformationSessionCompleteCallback { session ->
            synchronized(outputLock) {
                val information = session.getMediaInformation()
                if (information == null) {
                    appendOutput("Get media information failed\n")
                    appendOutput(String.format("State: %s\n", session.getState()))
                    appendOutput(String.format("Duration: %s\n", session.getDuration()))
                    appendOutput(String.format("Return Code: %s\n", session.getReturnCode()))
                    appendOutput(String.format("Fail stack trace: %s\n", MainActivity.notNull(session.getFailStackTrace(), "\n")))
                    appendOutput(String.format("Output: %s\n", session.getOutput()))
                } else {
                    appendOutput("Media information for " + information.getFilename() + "\n")

                    if (information.getFormat() != null) {
                        appendOutput("Format: " + information.getFormat() + "\n")
                    }
                    if (information.getBitrate() != null) {
                        appendOutput("Bitrate: " + information.getBitrate() + "\n")
                    }
                    if (information.getDuration() != null) {
                        appendOutput("Duration: " + information.getDuration() + "\n")
                    }
                    if (information.getStartTime() != null) {
                        appendOutput("Start time: " + information.getStartTime() + "\n")
                    }
                    val informationTags = information.getTags()
                    if (informationTags != null) {
                        val tags: JSONObject = informationTags
                        val keys = tags.keys()
                        while (keys.hasNext()) {
                            val next = keys.next()
                            appendOutput("Tag: " + next + ":" + tags.optString(next) + "\n")
                        }
                    }
                    for (stream: StreamInformation in information.getStreams()) {
                        if (stream.getIndex() != null) {
                            appendOutput("Stream index: " + stream.getIndex() + "\n")
                        }
                        if (stream.getType() != null) {
                            appendOutput("Stream type: " + stream.getType() + "\n")
                        }
                        if (stream.getCodec() != null) {
                            appendOutput("Stream codec: " + stream.getCodec() + "\n")
                        }
                        if (stream.getCodecLong() != null) {
                            appendOutput("Stream codec long: " + stream.getCodecLong() + "\n")
                        }
                        if (stream.getFormat() != null) {
                            appendOutput("Stream format: " + stream.getFormat() + "\n")
                        }
                        if (stream.getWidth() != null) {
                            appendOutput("Stream width: " + stream.getWidth() + "\n")
                        }
                        if (stream.getHeight() != null) {
                            appendOutput("Stream height: " + stream.getHeight() + "\n")
                        }
                        if (stream.getBitrate() != null) {
                            appendOutput("Stream bitrate: " + stream.getBitrate() + "\n")
                        }
                        if (stream.getSampleRate() != null) {
                            appendOutput("Stream sample rate: " + stream.getSampleRate() + "\n")
                        }
                        if (stream.getSampleFormat() != null) {
                            appendOutput("Stream sample format: " + stream.getSampleFormat() + "\n")
                        }
                        if (stream.getChannelLayout() != null) {
                            appendOutput("Stream channel layout: " + stream.getChannelLayout() + "\n")
                        }
                        if (stream.getSampleAspectRatio() != null) {
                            appendOutput("Stream sample aspect ratio: " + stream.getSampleAspectRatio() + "\n")
                        }
                        if (stream.getDisplayAspectRatio() != null) {
                            appendOutput("Stream display ascpect ratio: " + stream.getDisplayAspectRatio() + "\n")
                        }
                        if (stream.getAverageFrameRate() != null) {
                            appendOutput("Stream average frame rate: " + stream.getAverageFrameRate() + "\n")
                        }
                        if (stream.getRealFrameRate() != null) {
                            appendOutput("Stream real frame rate: " + stream.getRealFrameRate() + "\n")
                        }
                        if (stream.getTimeBase() != null) {
                            appendOutput("Stream time base: " + stream.getTimeBase() + "\n")
                        }
                        if (stream.getCodecTimeBase() != null) {
                            appendOutput("Stream codec time base: " + stream.getCodecTimeBase() + "\n")
                        }
                        val streamTags = stream.getTags()
                        if (streamTags != null) {
                            val tags: JSONObject = streamTags
                            val keys = tags.keys()
                            while (keys.hasNext()) {
                                val next = keys.next()
                                appendOutput(String.format("Stream tag: %s:%s\n", next, tags.optString(next)))
                            }
                        }
                    }
                    for (chapter: Chapter in information.getChapters()) {
                        if (chapter.getId() != null) {
                            appendOutput("Chapter id: " + chapter.getId() + "\n")
                        }
                        if (chapter.getTimeBase() != null) {
                            appendOutput("Chapter time base: " + chapter.getTimeBase() + "\n")
                        }
                        if (chapter.getStart() != null) {
                            appendOutput("Chapter start: " + chapter.getStart() + "\n")
                        }
                        if (chapter.getStartTime() != null) {
                            appendOutput("Chapter start time: " + chapter.getStartTime() + "\n")
                        }
                        if (chapter.getEnd() != null) {
                            appendOutput("Chapter end: " + chapter.getEnd() + "\n")
                        }
                        if (chapter.getEndTime() != null) {
                            appendOutput("Chapter end time: " + chapter.getEndTime() + "\n")
                        }
                        val chapterTags = chapter.getTags()
                        if (chapterTags != null) {
                            val tags: JSONObject = chapterTags
                            val keys = tags.keys()
                            while (keys.hasNext()) {
                                val next = keys.next()
                                appendOutput(String.format("Chapter tag: %s:%s\n", next, tags.optString(next)))
                            }
                        }
                    }
                }
            }
        }
    }

    companion object {
        const val HTTPS_TEST_DEFAULT_URL = "https://download.blender.org/peach/trailer/trailer_1080p.ogg"
        const val HTTPS_TEST_FAIL_URL = "https://download2.blender.org/peach/trailer/trailer_1080p.ogg"
        const val HTTPS_TEST_RANDOM_URL_1 = "https://filesamples.com/samples/video/mov/sample_640x360.mov"
        const val HTTPS_TEST_RANDOM_URL_2 = "https://filesamples.com/samples/audio/mp3/sample3.mp3"
        const val HTTPS_TEST_RANDOM_URL_3 = "https://filesamples.com/samples/image/webp/sample1.webp"

        private val testUrlRandom = Random()
        private val outputLock = Object()

    }
}

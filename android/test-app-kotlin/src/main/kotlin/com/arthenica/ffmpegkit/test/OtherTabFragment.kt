/*
 * Copyright (c) 2021, 2026 Taner Sener
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
import android.widget.AdapterView
import android.widget.ArrayAdapter
import androidx.fragment.app.Fragment
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.FFmpegKitConfig
import com.arthenica.ffmpegkit.ReturnCode
import com.arthenica.ffmpegkit.test.databinding.FragmentOtherTabBinding
import com.arthenica.ffmpegkit.util.ResourcesUtil
import com.arthenica.smartexception.java.Exceptions
import java.io.File
import java.io.IOException

class OtherTabFragment : Fragment(R.layout.fragment_other_tab), AdapterView.OnItemSelectedListener {
    private var _binding: FragmentOtherTabBinding? = null
    private val binding: FragmentOtherTabBinding
        get() = requireNotNull(_binding)
    private lateinit var selectedTest: String

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        _binding = FragmentOtherTabBinding.bind(view)

        val adapter = ArrayAdapter.createFromResource(requireContext(), R.array.other_test, R.layout.spinner_item)
        adapter.setDropDownViewResource(R.layout.spinner_dropdown_item)
        binding.otherTestSpinner.adapter = adapter
        binding.otherTestSpinner.onItemSelectedListener = this

        binding.runButton.setOnClickListener { runTest() }
        binding.outputText.movementMethod = ScrollingMovementMethod()

        selectedTest = resources.getStringArray(R.array.other_test)[0]
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
        selectedTest = parent.getItemAtPosition(position).toString()
    }

    override fun onNothingSelected(parent: AdapterView<*>) {
        // DO NOTHING
    }

    fun runTest() {
        clearOutput()

        when (selectedTest) {
            "chromaprint" -> testChromaprint()
            "dav1d" -> testDav1d()
            "webp" -> testWebp()
            "zscale" -> testZscale()
        }
    }

    fun testChromaprint() {
        Log.d(MainActivity.TAG, "Testing 'chromaprint' mutex")

        val audioSampleFile = getChromaprintSampleFile()
        if (audioSampleFile.exists()) {
            audioSampleFile.delete()
        }

        val ffmpegCommand = String.format("-hide_banner -y -f lavfi -i sine=frequency=1000:duration=5 -c:a pcm_s16le %s", audioSampleFile.absolutePath)

        Log.d(MainActivity.TAG, String.format("Creating audio sample with '%s'.", ffmpegCommand))

        FFmpegKit.executeAsync(ffmpegCommand) { session ->
            Log.d(MainActivity.TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", session.getState(), session.getReturnCode(), MainActivity.notNull(session.getFailStackTrace(), "\n")))

            if (ReturnCode.isSuccess(session.getReturnCode())) {
                Log.d(MainActivity.TAG, "AUDIO sample created")

                val chromaprintCommand = String.format("-hide_banner -y -i %s -f chromaprint -fp_format 2 %s", audioSampleFile, getChromaprintOutputFile().absolutePath)

                Log.d(MainActivity.TAG, String.format("FFmpeg process started with arguments: '%s'.", chromaprintCommand))

                FFmpegKit.executeAsync(chromaprintCommand, { session1 ->
                    MainActivity.addUIAction {
                        Log.d(MainActivity.TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", session1.getState(), session1.getReturnCode(), MainActivity.notNull(session1.getFailStackTrace(), "\n")))

                        if (ReturnCode.isSuccess(session1.getReturnCode())) {
                            Popup.show(requireContext(), "Testing chromaprint completed successfully.")
                        } else {
                            Popup.show(requireContext(), "Testing chromaprint failed. Please check logs for the details.")
                        }
                    }
                }, { log -> MainActivity.addUIAction { appendOutput(log.message) } }, null)
            } else {
                Popup.show(requireContext(), "Creating AUDIO sample failed. Please check logs for the details.")
            }
        }
    }

    fun testDav1d() {
        Log.d(MainActivity.TAG, "Testing decoding 'av1' codec")

        val ffmpegCommand = String.format("-hide_banner -y -i %s %s", DAV1D_TEST_DEFAULT_URL, getDav1dOutputFile().absolutePath)

        Log.d(MainActivity.TAG, String.format("FFmpeg process started with arguments: '%s'.", ffmpegCommand))

        FFmpegKit.executeAsync(ffmpegCommand, { session ->
            Log.d(MainActivity.TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", session.getState(), session.getReturnCode(), MainActivity.notNull(session.getFailStackTrace(), "\n")))
        }, { log -> MainActivity.addUIAction { appendOutput(log.message) } }, null)
    }

    fun testWebp() {
        val imageFile = cacheFile("machupicchu.jpg")
        val outputFile = filesFile("video.webp")

        try {
            ResourcesUtil.resourceToFile(resources, R.drawable.machupicchu, imageFile)

            Log.d(MainActivity.TAG, "Testing 'webp' codec")

            val ffmpegCommand = String.format("-hide_banner -y -i %s %s", imageFile.absolutePath, outputFile.absolutePath)

            Log.d(MainActivity.TAG, String.format("FFmpeg process started with arguments: '%s'.", ffmpegCommand))

            FFmpegKit.executeAsync(ffmpegCommand, { session ->
                Log.d(MainActivity.TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", session.getState(), session.getReturnCode(), MainActivity.notNull(session.getFailStackTrace(), "\n")))

                MainActivity.addUIAction {
                    if (ReturnCode.isSuccess(session.getReturnCode())) {
                        Popup.show(requireContext(), "Encode webp completed successfully.")
                    } else {
                        Popup.show(requireContext(), "Encode webp failed. Please check logs for the details.")
                    }
                }
            }, { log -> MainActivity.addUIAction { appendOutput(log.message) } }, null)
        } catch (e: IOException) {
            Log.e(MainActivity.TAG, String.format("Encode webp failed %s.", Exceptions.getStackTraceString(e)))
            Popup.show(requireContext(), "Encode webp failed")
        }
    }

    fun testZscale() {
        val videoFile = filesFile("video.mp4")
        val zscaledVideoFile = filesFile("video.zscaled.mp4")

        Log.d(MainActivity.TAG, "Testing 'zscale' filter with video file created on the Video tab")

        val ffmpegCommand = FFmpegCommands.buildZscaleVideoCommand(videoFile.absolutePath, zscaledVideoFile.absolutePath)

        Log.d(MainActivity.TAG, String.format("FFmpeg process started with arguments: '%s'.", ffmpegCommand))

        FFmpegKit.executeAsync(ffmpegCommand, { session ->
            Log.d(MainActivity.TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", session.getState(), session.getReturnCode(), MainActivity.notNull(session.getFailStackTrace(), "\n")))

            MainActivity.addUIAction {
                if (ReturnCode.isSuccess(session.getReturnCode())) {
                    Popup.show(requireContext(), "zscale completed successfully.")
                } else {
                    Popup.show(requireContext(), "zscale failed. Please check logs for the details.")
                }
            }
        }, { log -> MainActivity.addUIAction { appendOutput(log.message) } }, null)
    }

    fun getChromaprintSampleFile(): File {
        return filesFile("audio-sample.wav")
    }

    fun getDav1dOutputFile(): File {
        return filesFile("video.mp4")
    }

    fun getChromaprintOutputFile(): File {
        return filesFile("chromaprint.txt")
    }

    fun setActive() {
        Log.i(MainActivity.TAG, "Other Tab Activated")
        FFmpegKitConfig.enableLogCallback(null)
        FFmpegKitConfig.enableStatisticsCallback(null)
        Popup.show(requireContext(), getString(R.string.other_test_tooltip_text))
    }

    fun appendOutput(logMessage: String) {
        binding.outputText.append(logMessage)
    }

    fun clearOutput() {
        binding.outputText.text = ""
    }

    companion object {
        const val DAV1D_TEST_DEFAULT_URL = "http://download.opencontent.netflix.com.s3.amazonaws.com/AV1/Sparks/Sparks-5994fps-AV1-10bit-960x540-film-grain-synthesis-854kbps.obu"

    }
}

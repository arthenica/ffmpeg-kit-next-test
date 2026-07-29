/*
 * Copyright (c) 2020-2021, 2026 Taner Sener
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
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.FFmpegKitConfig
import com.arthenica.ffmpegkit.ReturnCode
import com.arthenica.ffmpegkit.test.databinding.FragmentConcurrentTabBinding
import com.arthenica.ffmpegkit.util.ResourcesUtil
import com.arthenica.smartexception.java.Exceptions
import java.io.IOException
import java.util.Locale

class ConcurrentExecutionTabFragment : Fragment(R.layout.fragment_concurrent_tab) {
    private var _binding: FragmentConcurrentTabBinding? = null
    private val binding: FragmentConcurrentTabBinding
        get() = requireNotNull(_binding)
    private var sessionId1 = 0L
    private var sessionId2 = 0L
    private var sessionId3 = 0L

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        _binding = FragmentConcurrentTabBinding.bind(view)

        binding.encodeButton1.setOnClickListener { encodeVideo(1) }
        binding.encodeButton2.setOnClickListener { encodeVideo(2) }
        binding.encodeButton3.setOnClickListener { encodeVideo(3) }
        binding.cancelButton1.setOnClickListener { cancel(1) }
        binding.cancelButton2.setOnClickListener { cancel(2) }
        binding.cancelButton3.setOnClickListener { cancel(3) }
        binding.cancelButtonAll.setOnClickListener { cancel(0) }
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
        FFmpegKitConfig.enableLogCallback { log ->
            MainActivity.addUIAction {
                appendOutput(String.format(Locale.getDefault(), "%d -> %s", log.sessionId, log.message))
            }
        }
    }

    fun encodeVideo(buttonNumber: Int) {
        val image1File = cacheFile("tree.jpg")
        val image2File = cacheFile("lake.jpg")
        val image3File = cacheFile("sunset.jpg")
        val videoFile = filesFile(String.format(Locale.getDefault(), "video%d.mp4", buttonNumber))

        try {
            Log.d(MainActivity.TAG, String.format("Testing CONCURRENT EXECUTION for button %d.", buttonNumber))

            ResourcesUtil.resourceToFile(resources, R.drawable.tree, image1File)
            ResourcesUtil.resourceToFile(resources, R.drawable.lake, image2File)
            ResourcesUtil.resourceToFile(resources, R.drawable.sunset, image3File)

            val ffmpegCommand = FFmpegCommands.buildEncodeVideoCommand(image1File.absolutePath, image2File.absolutePath, image3File.absolutePath, videoFile.absolutePath, "mpeg4", "")

            Log.d(MainActivity.TAG, String.format("FFmpeg process starting for button %d with arguments: '%s'.", buttonNumber, ffmpegCommand))

            val session = FFmpegKit.executeAsync(ffmpegCommand) { session ->
                val state = session.getState()
                val returnCode = session.getReturnCode()

                if (ReturnCode.isCancel(returnCode)) {
                    Log.d(MainActivity.TAG, String.format("FFmpeg process ended with cancel for button %d with sessionId %d.", buttonNumber, session.getSessionId()))
                } else {
                    Log.d(MainActivity.TAG, String.format("FFmpeg process ended with state %s and rc %s for button %d with sessionId %d.%s", state, returnCode, buttonNumber, session.getSessionId(), MainActivity.notNull(session.getFailStackTrace(), "\n")))

                    Log.d(MainActivity.TAG, String.format("Deleting session with id %d", session.getSessionId()))
                    FFmpegKitConfig.deleteSession(session.getSessionId())
                }
            }

            val sessionId = session.getSessionId()

            Log.d(MainActivity.TAG, String.format("Async FFmpeg process started for button %d with sessionId %d.", buttonNumber, sessionId))

            when (buttonNumber) {
                1 -> sessionId1 = sessionId
                2 -> sessionId2 = sessionId
                else -> {
                    sessionId3 = sessionId
                    FFmpegKitConfig.setSessionHistorySize(3)
                }
            }
        } catch (e: IOException) {
            Log.e(MainActivity.TAG, String.format("Encode video failed %s.", Exceptions.getStackTraceString(e)))
            Popup.show(requireContext(), "Encode video failed")
        }

        MainActivity.listFFmpegSessions()
    }

    fun cancel(buttonNumber: Int) {
        var sessionId = 0L

        when (buttonNumber) {
            1 -> sessionId = sessionId1
            2 -> sessionId = sessionId2
            3 -> sessionId = sessionId3
        }

        Log.d(MainActivity.TAG, String.format("Cancelling FFmpeg process for button %d with sessionId %d.", buttonNumber, sessionId))

        if (sessionId == 0L) {
            FFmpegKit.cancel()
        } else {
            FFmpegKit.cancel(sessionId)
        }
    }

    fun setActive() {
        Log.i(MainActivity.TAG, "Concurrent Execution Tab Activated")
        enableLogCallback()
        Popup.show(requireContext(), getString(R.string.concurrent_execution_test_tooltip_text))
    }

    fun appendOutput(logMessage: String) {
        binding.outputText.append(logMessage)
    }
}

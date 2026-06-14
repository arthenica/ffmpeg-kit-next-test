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

import android.os.Bundle
import android.text.method.ScrollingMovementMethod
import android.util.AndroidRuntimeException
import android.util.Log
import android.view.View
import androidx.fragment.app.Fragment
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.FFmpegKitConfig
import com.arthenica.ffmpegkit.FFprobeSession
import com.arthenica.ffmpegkit.LogRedirectionStrategy
import com.arthenica.ffmpegkit.SessionState
import com.arthenica.ffmpegkit.test.databinding.FragmentCommandTabBinding

class CommandTabFragment : Fragment(R.layout.fragment_command_tab) {
    private var _binding: FragmentCommandTabBinding? = null
    private val binding: FragmentCommandTabBinding
        get() = requireNotNull(_binding)

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        _binding = FragmentCommandTabBinding.bind(view)

        binding.runFFmpegButton.setOnClickListener { runFFmpeg() }
        binding.runFFprobeButton.setOnClickListener { runFFprobe() }
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

    fun runFFmpeg() {
        clearOutput()

        val ffmpegCommand = binding.commandText.text.toString()

        Log.d(MainActivity.TAG, String.format("Current log level is %s.", FFmpegKitConfig.getLogLevel()))
        Log.d(MainActivity.TAG, "Testing FFmpeg COMMAND asynchronously.")
        Log.d(MainActivity.TAG, String.format("FFmpeg process started with arguments: '%s'", ffmpegCommand))

        FFmpegKit.executeAsync(ffmpegCommand, { session ->
            val state = session.getState()
            val returnCode = session.getReturnCode()

            Log.d(MainActivity.TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", FFmpegKitConfig.sessionStateToString(state), returnCode, MainActivity.notNull(session.getFailStackTrace(), "\n")))

            if (state == SessionState.FAILED || returnCode == null || !returnCode.isValueSuccess()) {
                MainActivity.addUIAction {
                    Popup.show(requireContext(), "Command failed. Please check output for the details.")
                }
            }
        }, { log ->
            MainActivity.addUIAction { appendOutput(log.message) }
            throw AndroidRuntimeException("I am test exception thrown by the application")
        }, null)
    }

    fun runFFprobe() {
        clearOutput()

        val ffprobeCommand = binding.commandText.text.toString()

        Log.d(MainActivity.TAG, "Testing FFprobe COMMAND asynchronously.")
        Log.d(MainActivity.TAG, String.format("FFprobe process started with arguments: '%s'", ffprobeCommand))

        val session = FFprobeSession.create(FFmpegKitConfig.parseArguments(ffprobeCommand), { session ->
            val state = session.getState()
            val returnCode = session.getReturnCode()

            MainActivity.addUIAction { appendOutput(session.getOutput()) }

            Log.d(MainActivity.TAG, String.format("FFprobe process exited with state %s and rc %s.%s", FFmpegKitConfig.sessionStateToString(state), returnCode, MainActivity.notNull(session.getFailStackTrace(), "\n")))

            if (state == SessionState.FAILED || session.getReturnCode()?.isValueSuccess() != true) {
                MainActivity.addUIAction {
                    Popup.show(requireContext(), "Command failed. Please check output for the details.")
                }
            }
        }, null, LogRedirectionStrategy.NEVER_PRINT_LOGS)

        FFmpegKitConfig.asyncFFprobeExecute(session)

        MainActivity.listFFprobeSessions()
    }

    private fun setActive() {
        Log.i(MainActivity.TAG, "Command Tab Activated")
        FFmpegKitConfig.enableLogCallback(null)
        Popup.show(requireContext(), getString(R.string.command_test_tooltip_text))
    }

    fun appendOutput(logMessage: String) {
        binding.outputText.append(logMessage)
    }

    fun clearOutput() {
        binding.outputText.text = ""
    }
}

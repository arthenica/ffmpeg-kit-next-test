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
import com.arthenica.ffmpegkit.SessionState
import com.arthenica.ffmpegkit.Statistics
import com.arthenica.ffmpegkit.test.databinding.FragmentPipeTabBinding
import com.arthenica.ffmpegkit.util.AsyncCatImageTask
import com.arthenica.ffmpegkit.util.DialogUtil
import com.arthenica.ffmpegkit.util.ResourcesUtil
import com.arthenica.smartexception.java.Exceptions
import java.io.File
import java.io.IOException
import java.math.BigDecimal
import java.math.RoundingMode

class PipeTabFragment : Fragment(R.layout.fragment_pipe_tab) {
    private var _binding: FragmentPipeTabBinding? = null
    private val binding: FragmentPipeTabBinding
        get() = requireNotNull(_binding)
    private lateinit var progressDialog: AlertDialog
    private var statistics: Statistics? = null

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        _binding = FragmentPipeTabBinding.bind(view)

        binding.createButton.setOnClickListener { createVideo() }
        progressDialog = DialogUtil.createProgressDialog(requireContext(), "Creating video")
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

    fun startAsyncCatImageProcess(imagePath: String, namedPipePath: String) {
        AsyncCatImageTask.execute(imagePath, namedPipePath)
    }

    fun createVideo() {
        val image1File = cacheFile("machupicchu.jpg")
        val image2File = cacheFile("pyramid.jpg")
        val image3File = cacheFile("stonehenge.jpg")
        val videoFile = getVideoFile()

        val pipe1 = FFmpegKitConfig.registerNewFFmpegPipe(requireContext())!!
        val pipe2 = FFmpegKitConfig.registerNewFFmpegPipe(requireContext())!!
        val pipe3 = FFmpegKitConfig.registerNewFFmpegPipe(requireContext())!!

        try {
            binding.videoPlayerFrame.stopPlayback()

            if (videoFile.exists()) {
                videoFile.delete()
            }

            Log.d(MainActivity.TAG, "Testing PIPE with 'mpeg4' codec")

            showProgressDialog()

            ResourcesUtil.resourceToFile(resources, R.drawable.machupicchu, image1File)
            ResourcesUtil.resourceToFile(resources, R.drawable.pyramid, image2File)
            ResourcesUtil.resourceToFile(resources, R.drawable.stonehenge, image3File)

            val ffmpegCommand = FFmpegCommands.buildCreateVideoWithPipesCommand(pipe1, pipe2, pipe3, videoFile.absolutePath)

            Log.d(MainActivity.TAG, String.format("FFmpeg process started with arguments: '%s'.", ffmpegCommand))

            FFmpegKit.executeAsync(ffmpegCommand) { session ->
                val state: SessionState = session.getState()
                val returnCode = session.getReturnCode()

                Log.d(MainActivity.TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", state, returnCode, MainActivity.notNull(session.getFailStackTrace(), "\n")))

                hideProgressDialog()

                FFmpegKitConfig.closeFFmpegPipe(pipe1)
                FFmpegKitConfig.closeFFmpegPipe(pipe2)
                FFmpegKitConfig.closeFFmpegPipe(pipe3)

                MainActivity.addUIAction {
                    if (ReturnCode.isSuccess(returnCode)) {
                        Log.d(MainActivity.TAG, "Create completed successfully; playing video.")
                        playVideo()
                    } else {
                        Popup.show(requireContext(), "Create failed. Please check logs for the details.")
                    }
                }
            }

            startAsyncCatImageProcess(image1File.absolutePath, pipe1)
            startAsyncCatImageProcess(image2File.absolutePath, pipe2)
            startAsyncCatImageProcess(image3File.absolutePath, pipe3)
        } catch (e: IOException) {
            Log.e(MainActivity.TAG, String.format("Create video failed %s.", Exceptions.getStackTraceString(e)))
            Popup.show(requireContext(), "Create video failed")
        }
    }

    fun playVideo() {
        binding.videoPlayerFrame.playFile(requireContext(), getVideoFile())
    }

    fun getVideoFile(): File {
        return filesFile("video.mp4")
    }

    fun setActive() {
        Log.i(MainActivity.TAG, "Pipe Tab Activated")
        enableLogCallback()
        enableStatisticsCallback()
        Popup.show(requireContext(), getString(R.string.pipe_test_tooltip_text))
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
            textView.text = String.format("Creating video: %% %s.", completePercentage)
        }
    }

    fun hideProgressDialog() {
        progressDialog.dismiss()

        MainActivity.addUIAction {
            progressDialog = DialogUtil.createProgressDialog(requireContext(), "Creating video")
        }
    }
}

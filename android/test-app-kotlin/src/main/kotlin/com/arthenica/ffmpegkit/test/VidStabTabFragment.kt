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
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.Fragment
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.FFmpegKitConfig
import com.arthenica.ffmpegkit.ReturnCode
import com.arthenica.ffmpegkit.test.databinding.FragmentVidstabTabBinding
import com.arthenica.ffmpegkit.util.DialogUtil
import com.arthenica.ffmpegkit.util.ResourcesUtil
import com.arthenica.smartexception.java.Exceptions
import java.io.File
import java.io.IOException

class VidStabTabFragment : Fragment(R.layout.fragment_vidstab_tab) {
    private var _binding: FragmentVidstabTabBinding? = null
    private val binding: FragmentVidstabTabBinding
        get() = requireNotNull(_binding)
    private lateinit var createProgressDialog: AlertDialog
    private lateinit var stabilizeProgressDialog: AlertDialog

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        _binding = FragmentVidstabTabBinding.bind(view)

        binding.stabilizeVideoButton.setOnClickListener { stabilizeVideo() }
        createProgressDialog = DialogUtil.createProgressDialog(requireContext(), "Creating video")
        stabilizeProgressDialog = DialogUtil.createProgressDialog(requireContext(), "Stabilizing video")
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

    fun disableStatisticsCallback() {
        FFmpegKitConfig.enableStatisticsCallback(null)
    }

    fun stabilizeVideo() {
        val image1File = cacheFile("tree.jpg")
        val image2File = cacheFile("lake.jpg")
        val image3File = cacheFile("sunset.jpg")
        val shakeResultsFile = getShakeResultsFile()
        val videoFile = getVideoFile()
        val stabilizedVideoFile = getStabilizedVideoFile()

        try {
            binding.videoPlayerFrame.stopPlayback()
            binding.stabilizedVideoPlayerFrame.stopPlayback()

            if (shakeResultsFile.exists()) {
                shakeResultsFile.delete()
            }
            if (videoFile.exists()) {
                videoFile.delete()
            }
            if (stabilizedVideoFile.exists()) {
                stabilizedVideoFile.delete()
            }

            Log.d(MainActivity.TAG, "Testing VID.STAB")

            showCreateProgressDialog()

            ResourcesUtil.resourceToFile(resources, R.drawable.tree, image1File)
            ResourcesUtil.resourceToFile(resources, R.drawable.lake, image2File)
            ResourcesUtil.resourceToFile(resources, R.drawable.sunset, image3File)

            val videoCodec = FFmpegCommands.getPackageVideoCodec()
            val ffmpegCommand = FFmpegCommands.buildShakingVideoCommand(image1File.absolutePath, image2File.absolutePath, image3File.absolutePath, videoFile.absolutePath, videoCodec)

            Log.d(MainActivity.TAG, String.format("FFmpeg process started with arguments: '%s'.", ffmpegCommand))

            FFmpegKit.executeAsync(ffmpegCommand) { session ->
                Log.d(MainActivity.TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", session.getState(), session.getReturnCode(), MainActivity.notNull(session.getFailStackTrace(), "\n")))

                hideCreateProgressDialog()

                MainActivity.addUIAction {
                    if (ReturnCode.isSuccess(session.getReturnCode())) {
                        Log.d(MainActivity.TAG, "Create completed successfully; stabilizing video.")

                        val analyzeVideoCommand = String.format("-y -i %s -vf vidstabdetect=shakiness=10:accuracy=15:result=%s -f null -", videoFile.absolutePath, shakeResultsFile.absolutePath)

                        showStabilizeProgressDialog()

                        Log.d(MainActivity.TAG, String.format("FFmpeg process started with arguments: '%s'.", analyzeVideoCommand))

                        FFmpegKit.executeAsync(analyzeVideoCommand) { secondSession ->
                            Log.d(MainActivity.TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", secondSession.getState(), secondSession.getReturnCode(), MainActivity.notNull(secondSession.getFailStackTrace(), "\n")))

                            if (ReturnCode.isSuccess(secondSession.getReturnCode())) {
                                val stabilizeVideoCommand = String.format("-y -i %s -vf vidstabtransform=smoothing=30:input=%s -c:v %s %s", videoFile.absolutePath, shakeResultsFile.absolutePath, videoCodec, stabilizedVideoFile.absolutePath)

                                Log.d(MainActivity.TAG, String.format("FFmpeg process started with arguments: '%s'.", stabilizeVideoCommand))

                                FFmpegKit.executeAsync(stabilizeVideoCommand) { thirdSession ->
                                    Log.d(MainActivity.TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", thirdSession.getState(), thirdSession.getReturnCode(), MainActivity.notNull(thirdSession.getFailStackTrace(), "\n")))

                                    hideStabilizeProgressDialog()

                                    MainActivity.addUIAction {
                                        if (ReturnCode.isSuccess(thirdSession.getReturnCode())) {
                                            Log.d(MainActivity.TAG, "Stabilize video completed successfully; playing videos.")
                                            playVideo()
                                            playStabilizedVideo()
                                        } else {
                                            Popup.show(requireContext(), "Stabilize video failed. Please check logs for the details.")
                                        }
                                    }
                                }
                            } else {
                                MainActivity.addUIAction {
                                    hideStabilizeProgressDialog()
                                    Popup.show(requireContext(), "Stabilize video failed. Please check logs for the details.")
                                }
                            }
                        }
                    } else {
                        Popup.show(requireContext(), "Create video failed. Please check logs for the details.")
                    }
                }
            }
        } catch (e: IOException) {
            Log.e(MainActivity.TAG, String.format("Stabilize video failed %s.", Exceptions.getStackTraceString(e)))
            Popup.show(requireContext(), "Stabilize video failed")
        }
    }

    fun playVideo() {
        binding.videoPlayerFrame.playFile(requireContext(), getVideoFile())
    }

    fun playStabilizedVideo() {
        binding.stabilizedVideoPlayerFrame.playFile(requireContext(), getStabilizedVideoFile())
    }

    fun getShakeResultsFile(): File {
        return cacheFile("transforms.trf")
    }

    fun getVideoFile(): File {
        return filesFile("video.mp4")
    }

    fun getStabilizedVideoFile(): File {
        return filesFile("video-stabilized.mp4")
    }

    fun setActive() {
        Log.i(MainActivity.TAG, "VidStab Tab Activated")
        enableLogCallback()
        disableStatisticsCallback()
        Popup.show(requireContext(), getString(R.string.vidstab_test_tooltip_text))
    }

    fun showCreateProgressDialog() {
        createProgressDialog.show()
    }

    fun hideCreateProgressDialog() {
        createProgressDialog.dismiss()
    }

    fun showStabilizeProgressDialog() {
        stabilizeProgressDialog.show()
    }

    fun hideStabilizeProgressDialog() {
        stabilizeProgressDialog.dismiss()
    }

}

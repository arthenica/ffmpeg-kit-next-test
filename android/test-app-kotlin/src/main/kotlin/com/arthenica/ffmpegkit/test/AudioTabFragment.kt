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
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.Fragment
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.FFmpegKitConfig
import com.arthenica.ffmpegkit.ReturnCode
import com.arthenica.ffmpegkit.test.databinding.FragmentAudioTabBinding
import com.arthenica.ffmpegkit.util.DialogUtil
import java.io.File

class AudioTabFragment : Fragment(R.layout.fragment_audio_tab), AdapterView.OnItemSelectedListener {
    private var _binding: FragmentAudioTabBinding? = null
    private val binding: FragmentAudioTabBinding
        get() = requireNotNull(_binding)
    private lateinit var progressDialog: AlertDialog
    private lateinit var selectedCodec: String

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        _binding = FragmentAudioTabBinding.bind(view)

        val adapter = ArrayAdapter.createFromResource(requireContext(), R.array.audio_codec, R.layout.spinner_item)
        adapter.setDropDownViewResource(R.layout.spinner_dropdown_item)
        binding.audioCodecSpinner.adapter = adapter
        binding.audioCodecSpinner.onItemSelectedListener = this

        binding.encodeButton.setOnClickListener { encodeAudio() }
        binding.encodeButton.isEnabled = false
        binding.outputText.movementMethod = ScrollingMovementMethod()

        progressDialog = DialogUtil.createProgressDialog(requireContext(), "Encoding audio")

        selectedCodec = resources.getStringArray(R.array.audio_codec)[0]
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
            MainActivity.addUIAction { appendOutput(log.message) }
        }
    }

    fun disableLogCallback() {
        FFmpegKitConfig.enableLogCallback(null)
    }

    fun disableStatisticsCallback() {
        FFmpegKitConfig.enableStatisticsCallback(null)
    }

    override fun onItemSelected(parent: AdapterView<*>, view: View?, position: Int, id: Long) {
        selectedCodec = parent.getItemAtPosition(position).toString()
    }

    override fun onNothingSelected(parent: AdapterView<*>) {
        // DO NOTHING
    }

    fun encodeAudio() {
        val audioOutputFile = getAudioOutputFile()
        if (audioOutputFile.exists()) {
            audioOutputFile.delete()
        }

        val audioCodec = selectedCodec

        android.util.Log.d(MainActivity.TAG, String.format("Testing AUDIO encoding with '%s' codec.", audioCodec))

        val ffmpegCommand = generateAudioEncodeScript()

        showProgressDialog()

        clearOutput()

        android.util.Log.d(MainActivity.TAG, String.format("FFmpeg process started with arguments: '%s'.", ffmpegCommand))

        FFmpegKit.executeAsync(ffmpegCommand) { session ->
            val state = session.getState()
            val returnCode = session.getReturnCode()

            hideProgressDialog()

            MainActivity.addUIAction {
                if (ReturnCode.isSuccess(returnCode)) {
                    Popup.show(requireContext(), "Encode completed successfully.")
                    android.util.Log.d(MainActivity.TAG, "Encode completed successfully.")
                } else {
                    Popup.show(requireContext(), "Encode failed. Please check logs for the details.")
                    android.util.Log.d(MainActivity.TAG, String.format("Encode failed with state %s and rc %s.%s", state, returnCode, MainActivity.notNull(session.getFailStackTrace(), "\n")))
                }
            }
        }
    }

    fun createAudioSample() {
        android.util.Log.d(MainActivity.TAG, "Creating AUDIO sample before the test.")

        val audioSampleFile = getAudioSampleFile()
        if (audioSampleFile.exists()) {
            audioSampleFile.delete()
        }

        val ffmpegCommand = String.format("-hide_banner -y -f lavfi -i sine=frequency=1000:duration=5 -c:a pcm_s16le %s", audioSampleFile.absolutePath)

        android.util.Log.d(MainActivity.TAG, String.format("Creating audio sample with '%s'.", ffmpegCommand))

        val session = FFmpegKit.execute(ffmpegCommand)
        if (ReturnCode.isSuccess(session.getReturnCode())) {
            binding.encodeButton.isEnabled = true
            android.util.Log.d(MainActivity.TAG, "AUDIO sample created")
        } else {
            android.util.Log.d(MainActivity.TAG, String.format("Creating AUDIO sample failed with state %s and rc %s.%s", session.getState(), session.getReturnCode(), MainActivity.notNull(session.getFailStackTrace(), "\n")))
            Popup.show(requireContext(), "Creating AUDIO sample failed. Please check logs for the details.")
        }
    }

    fun getAudioOutputFile(): File {
        val extension = when (selectedCodec) {
            "mp2 (twolame)" -> "mpg"
            "mp3 (liblame)", "mp3 (libshine)" -> "mp3"
            "vorbis" -> "ogg"
            "opus" -> "opus"
            "amr-nb", "amr-wb" -> "amr"
            "ilbc" -> "lbc"
            "speex" -> "spx"
            "wavpack" -> "wv"
            else -> "wav"
        }

        val audio = "audio.$extension"
        return filesFile(audio)
    }

    fun getAudioSampleFile(): File {
        return filesFile("audio-sample.wav")
    }

    fun setActive() {
        android.util.Log.i(MainActivity.TAG, "Audio Tab Activated")
        disableStatisticsCallback()
        disableLogCallback()
        createAudioSample()
        enableLogCallback()
        Popup.show(requireContext(), getString(R.string.audio_test_tooltip_text))
    }

    fun appendOutput(logMessage: String) {
        binding.outputText.append(logMessage)
    }

    fun clearOutput() {
        binding.outputText.text = ""
    }

    fun showProgressDialog() {
        progressDialog.show()
    }

    fun hideProgressDialog() {
        progressDialog.dismiss()
    }

    fun generateAudioEncodeScript(): String {
        val audioSampleFile = getAudioSampleFile().absolutePath
        val audioOutputFile = getAudioOutputFile().absolutePath

        return when (selectedCodec) {
            "mp2 (twolame)" -> String.format("-hide_banner -y -i %s -c:a mp2 -b:a 192k %s", audioSampleFile, audioOutputFile)
            "mp3 (liblame)" -> String.format("-hide_banner -y -i %s -c:a libmp3lame -qscale:a 2 %s", audioSampleFile, audioOutputFile)
            "mp3 (libshine)" -> String.format("-hide_banner -y -i %s -c:a libshine -qscale:a 2 %s", audioSampleFile, audioOutputFile)
            "vorbis" -> String.format("-hide_banner -y -i %s -c:a libvorbis -b:a 64k %s", audioSampleFile, audioOutputFile)
            "opus" -> String.format("-hide_banner -y -i %s -c:a libopus -b:a 64k -vbr on -compression_level 10 %s", audioSampleFile, audioOutputFile)
            "amr-nb" -> String.format("-hide_banner -y -i %s -ar 8000 -ab 12.2k -c:a libopencore_amrnb %s", audioSampleFile, audioOutputFile)
            "amr-wb" -> String.format("-hide_banner -y -i %s -ar 8000 -ab 12.2k -c:a libvo_amrwbenc -strict experimental %s", audioSampleFile, audioOutputFile)
            "ilbc" -> String.format("-hide_banner -y -i %s -c:a ilbc -ar 8000 -b:a 15200 %s", audioSampleFile, audioOutputFile)
            "speex" -> String.format("-hide_banner -y -i %s -c:a libspeex -ar 16000 %s", audioSampleFile, audioOutputFile)
            "wavpack" -> String.format("-hide_banner -y -i %s -c:a wavpack -b:a 64k %s", audioSampleFile, audioOutputFile)
            else -> String.format("-hide_banner -y -i %s -af aresample=resampler=soxr -ar 44100 %s", audioSampleFile, audioOutputFile)
        }
    }

}

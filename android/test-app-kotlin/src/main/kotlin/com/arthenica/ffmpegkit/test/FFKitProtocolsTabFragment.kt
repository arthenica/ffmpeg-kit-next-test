/*
 * Copyright (c) 2026 Taner Sener
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

import android.Manifest
import android.app.Activity.RESULT_OK
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.text.method.ScrollingMovementMethod
import android.util.Log
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.fragment.app.Fragment
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.FFmpegKitConfig
import com.arthenica.ffmpegkit.FFmpegKitInputBuffer
import com.arthenica.ffmpegkit.FFmpegKitOutputBuffer
import com.arthenica.ffmpegkit.FFprobeKit
import com.arthenica.ffmpegkit.ReturnCode
import com.arthenica.ffmpegkit.test.databinding.FragmentFfkitProtocolsTabBinding
import com.arthenica.ffmpegkit.util.ResourcesUtil
import com.arthenica.smartexception.java.Exceptions
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.io.InputStream

class FFKitProtocolsTabFragment : Fragment(R.layout.fragment_ffkit_protocols_tab), AdapterView.OnItemSelectedListener {
    private var _binding: FragmentFfkitProtocolsTabBinding? = null
    private val binding: FragmentFfkitProtocolsTabBinding
        get() = requireNotNull(_binding)

    private var selectedProtocol = PROTOCOL_FFKITMEM
    private var selectedImageBytes: ByteArray? = null
    private var cameraFile: File? = null

    private var pendingFFKitMemFFprobe = false

    private lateinit var galleryLauncher: ActivityResultLauncher<String>
    private lateinit var cameraLauncher: ActivityResultLauncher<Uri>
    private lateinit var cameraPermissionLauncher: ActivityResultLauncher<String>
    private lateinit var safCreateDocumentLauncher: ActivityResultLauncher<Intent>
    private lateinit var safOpenDocumentLauncher: ActivityResultLauncher<Intent>

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        galleryLauncher = registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
            if (uri != null) {
                handleImagePicked(readImageBytes { requireContext().contentResolver.openInputStream(uri) })
            }
        }

        cameraLauncher = registerForActivityResult(ActivityResultContracts.TakePicture()) { success ->
            val file = cameraFile
            if (java.lang.Boolean.TRUE == success && file != null && file.exists()) {
                handleImagePicked(readImageBytes { FileInputStream(file) })
            }
        }

        cameraPermissionLauncher = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            if (java.lang.Boolean.TRUE == granted) {
                launchCamera()
            } else {
                Popup.show(requireContext(), getString(R.string.protocol_camera_denied))
            }
        }

        safCreateDocumentLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val data = result.data
            val uri = data?.data
            if (result.resultCode == RESULT_OK && uri != null) {
                runFFKitSafFFmpeg(uri)
            }
        }

        safOpenDocumentLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val data = result.data
            val uri = data?.data
            if (result.resultCode == RESULT_OK && uri != null) {
                runFFKitSafFFprobe(uri)
            }
        }
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        _binding = FragmentFfkitProtocolsTabBinding.bind(view)

        binding.outputText.movementMethod = ScrollingMovementMethod()
        binding.runFFmpegButton.setOnClickListener { onRunFFmpeg() }
        binding.runFFprobeButton.setOnClickListener { onRunFFprobe() }

        val adapter = ArrayAdapter.createFromResource(requireContext(), R.array.protocol_list, R.layout.spinner_item)
        adapter.setDropDownViewResource(R.layout.spinner_dropdown_item)
        binding.protocolSpinner.adapter = adapter
        binding.protocolSpinner.onItemSelectedListener = this

        updateUiForProtocol()
    }

    override fun onDestroyView() {
        _binding = null
        super.onDestroyView()
    }

    override fun onResume() {
        super.onResume()
        Log.i(MainActivity.TAG, "FFKitProtocols Tab Activated")
        setActive()
    }

    fun setActive() {
        FFmpegKitConfig.enableLogCallback(null)
        FFmpegKitConfig.enableStatisticsCallback(null)
        Popup.show(requireContext(), getString(R.string.protocol_test_tooltip_text))
    }

    override fun onItemSelected(parent: AdapterView<*>, view: View?, position: Int, id: Long) {
        selectedProtocol = parent.getItemAtPosition(position).toString()
        updateUiForProtocol()
    }

    override fun onNothingSelected(parent: AdapterView<*>) {
        // DO NOTHING
    }

    private fun updateUiForProtocol() {
        val ffkitmem = PROTOCOL_FFKITMEM == selectedProtocol
        binding.overlayTextInput.visibility = if (ffkitmem) View.VISIBLE else View.GONE
        binding.resultImageView.visibility = View.GONE
        binding.resultImageView.setImageDrawable(null)
        binding.outputText.visibility = View.GONE
        binding.outputText.text = ""
        binding.statusText.text = getString(R.string.protocol_status_idle)
    }

    private fun onRunFFmpeg() {
        when (selectedProtocol) {
            PROTOCOL_FFKITMEM -> {
                pendingFFKitMemFFprobe = false
                showImageSourceChooser()
            }
            PROTOCOL_FFKITSAF -> launchFFKitSafCreateDocument()
            else -> Popup.show(requireContext(), getString(R.string.protocol_not_implemented))
        }
    }

    private fun onRunFFprobe() {
        when (selectedProtocol) {
            PROTOCOL_FFKITMEM -> {
                pendingFFKitMemFFprobe = true
                showImageSourceChooser()
            }
            PROTOCOL_FFKITSAF -> launchFFKitSafOpenDocument()
            else -> Popup.show(requireContext(), getString(R.string.protocol_not_implemented))
        }
    }

    private fun showImageSourceChooser() {
        val options = arrayOf<CharSequence>(
            getString(R.string.protocol_take_photo),
            getString(R.string.protocol_choose_gallery)
        )
        AlertDialog.Builder(requireContext())
            .setTitle(R.string.protocol_dialog_title)
            .setItems(options) { _, which ->
                if (which == 0) {
                    launchCameraWithPermission()
                } else {
                    galleryLauncher.launch("image/*")
                }
            }
            .show()
    }

    private fun launchCameraWithPermission() {
        if (ContextCompat.checkSelfPermission(requireContext(), Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
            return
        }
        launchCamera()
    }

    private fun launchCamera() {
        cameraFile = cacheFile("camera_capture.jpg")
        val file = cameraFile ?: return
        val outputUri = FileProvider.getUriForFile(requireContext(), requireContext().packageName + ".fileprovider", file)
        cameraLauncher.launch(outputUri)
    }

    private fun handleImagePicked(bytes: ByteArray?) {
        if (bytes == null) {
            return
        }
        selectedImageBytes = bytes
        if (pendingFFKitMemFFprobe) {
            runFFKitMemFFprobe()
        } else {
            runFFKitMemFFmpeg()
        }
    }

    private fun runFFKitMemFFmpeg() {
        val selectedBytes = selectedImageBytes ?: return

        val input: FFmpegKitInputBuffer
        val output: FFmpegKitOutputBuffer
        val command: String
        try {
            val fontFile = cacheFile("doppioone_regular.ttf")
            ResourcesUtil.rawResourceToFile(resources, R.raw.doppioone_regular, fontFile)

            input = FFmpegKitInputBuffer.fromByteArray(selectedBytes, "jpg")
            output = FFmpegKitOutputBuffer.create("jpg")
            command = FFmpegCommands.buildFFKitMemProtocolCommand(
                input.getUrl(),
                output.getUrl(),
                fontFile.absolutePath,
                binding.overlayTextInput.text.toString()
            )
        } catch (e: Exception) {
            Log.e(MainActivity.TAG, String.format("Preparing ffkitmem run failed.%s", Exceptions.getStackTraceString(e)))
            Popup.show(requireContext(), getString(R.string.protocol_run_failed))
            return
        }

        val inputUrl = input.getUrl()
        val outputUrl = output.getUrl()
        val inputSize = input.getSize()
        binding.statusText.text = getString(R.string.protocol_running)
        Log.d(MainActivity.TAG, String.format("ffkitmem ffmpeg command: %s", command))

        FFmpegKit.executeAsync(command) { session ->
            try {
                if (ReturnCode.isSuccess(session.getReturnCode())) {
                    val result = output.toByteArray()
                    val outputSize = output.getSize()
                    val bitmap = BitmapFactory.decodeByteArray(result, 0, result.size)
                    val status = formatMemProtocolStatus(inputUrl, inputSize, outputUrl, outputSize)
                    MainActivity.addUIAction {
                        showImageResult(bitmap)
                        binding.statusText.text = status
                    }
                } else {
                    Log.e(MainActivity.TAG, String.format("ffkitmem ffmpeg failed: rc=%s%n%s", session.getReturnCode(), session.getAllLogsAsString()))
                    val logs = session.getAllLogsAsString()
                    MainActivity.addUIAction {
                        showTextResult(logs)
                        binding.statusText.text = getString(R.string.protocol_run_failed)
                        Popup.show(requireContext(), getString(R.string.protocol_run_failed))
                    }
                }
            } finally {
                input.close()
                output.close()
            }
        }
    }

    private fun runFFKitMemFFprobe() {
        val selectedBytes = selectedImageBytes ?: return

        val input: FFmpegKitInputBuffer
        try {
            input = FFmpegKitInputBuffer.fromByteArray(selectedBytes, "jpg")
        } catch (e: Exception) {
            Log.e(MainActivity.TAG, String.format("Preparing ffkitmem ffprobe failed.%s", Exceptions.getStackTraceString(e)))
            Popup.show(requireContext(), getString(R.string.protocol_run_failed))
            return
        }

        val inputUrl = input.getUrl()
        val command = "-hide_banner -print_format json -show_format -show_streams $inputUrl"
        binding.statusText.text = getString(R.string.protocol_running)
        Log.d(MainActivity.TAG, String.format("ffkitmem ffprobe command: %s", command))

        FFprobeKit.executeAsync(command) { session ->
            try {
                val success = ReturnCode.isSuccess(session.getReturnCode())
                val output = session.getOutput()
                MainActivity.addUIAction {
                    showTextResult(output)
                    binding.statusText.text = "ffprobe -> $inputUrl"
                    if (!success) {
                        Popup.show(requireContext(), getString(R.string.protocol_run_failed))
                    }
                }
            } finally {
                input.close()
            }
        }
    }

    private fun launchFFKitSafCreateDocument() {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .setType("video/*")
            .putExtra(Intent.EXTRA_TITLE, "video.mp4")
            .addCategory(Intent.CATEGORY_OPENABLE)
        safCreateDocumentLauncher.launch(intent)
    }

    private fun launchFFKitSafOpenDocument() {
        val intent = Intent(Intent.ACTION_GET_CONTENT)
            .setType("*/*")
            .putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/*", "audio/*"))
            .addCategory(Intent.CATEGORY_OPENABLE)
        safOpenDocumentLauncher.launch(intent)
    }

    private fun runFFKitSafFFmpeg(outputUri: Uri) {
        val image1File = cacheFile("tree.jpg")
        val image2File = cacheFile("lake.jpg")
        val image3File = cacheFile("sunset.jpg")
        val videoPath = FFmpegKitConfig.getSafParameter(requireContext(), outputUri, "rw")

        val command: String
        try {
            val videoCodec = getCodec(videoPath)
            ResourcesUtil.resourceToFile(resources, R.drawable.tree, image1File)
            ResourcesUtil.resourceToFile(resources, R.drawable.lake, image2File)
            ResourcesUtil.resourceToFile(resources, R.drawable.sunset, image3File)
            command = FFmpegCommands.buildEncodeVideoCommand(
                image1File.absolutePath,
                image2File.absolutePath,
                image3File.absolutePath,
                videoPath,
                videoCodec,
                getCustomOptions(videoCodec)
            )
        } catch (e: IOException) {
            Log.e(MainActivity.TAG, String.format("Encode video failed.%s", Exceptions.getStackTraceString(e)))
            Popup.show(requireContext(), getString(R.string.protocol_run_failed))
            return
        }

        binding.statusText.text = getString(R.string.protocol_running)
        showTextResult(getString(R.string.protocol_running))
        Log.d(MainActivity.TAG, String.format("saf ffmpeg command: %s", command))

        FFmpegKit.executeAsync(command) { session ->
            val success = ReturnCode.isSuccess(session.getReturnCode())
            val logs = session.getAllLogsAsString()
            MainActivity.addUIAction {
                showTextResult(logs)
                binding.statusText.text = if (success) "Encode completed." else getString(R.string.protocol_run_failed)
                if (!success) {
                    Popup.show(requireContext(), getString(R.string.protocol_run_failed))
                }
            }
        }
    }

    private fun runFFKitSafFFprobe(inputUri: Uri) {
        val command = "-hide_banner -print_format json -show_format -show_streams " +
            FFmpegKitConfig.getSafParameterForRead(requireContext(), inputUri)

        binding.statusText.text = getString(R.string.protocol_running)
        Log.d(MainActivity.TAG, String.format("saf ffprobe command: %s", command))

        FFprobeKit.executeAsync(command) { session ->
            val success = ReturnCode.isSuccess(session.getReturnCode())
            val output = session.getOutput()
            MainActivity.addUIAction {
                showTextResult(output)
                binding.statusText.text = if (success) getString(R.string.protocol_status_idle) else getString(R.string.protocol_run_failed)
                if (!success) {
                    Popup.show(requireContext(), getString(R.string.protocol_run_failed))
                }
            }
        }
    }

    private fun getCodec(videoPath: String): String {
        var extension = "mp4"
        val pos = videoPath.lastIndexOf('.')
        if (pos >= 0) {
            extension = videoPath.substring(pos + 1)
        }

        return when (extension) {
            "webm" -> "vp8"
            "mkv" -> "aom"
            "ogv" -> "theora"
            "mov" -> "hap"
            "mp4" -> "mpeg4"
            else -> "mpeg4"
        }
    }

    private fun getCustomOptions(videoCodec: String): String {
        return when (videoCodec) {
            "x265" -> "-crf 28 -preset fast "
            "vp8" -> "-b:v 1M -crf 10 "
            "vp9" -> "-b:v 2M "
            "aom" -> "-crf 30 -strict experimental "
            "theora" -> "-qscale:v 7 "
            "hap" -> "-format hap_q "
            else -> "-movflags faststart "
        }
    }

    private fun showImageResult(bitmap: Bitmap) {
        binding.outputText.visibility = View.GONE
        binding.resultImageView.visibility = View.VISIBLE
        binding.resultImageView.setImageBitmap(bitmap)
    }

    private fun showTextResult(text: String) {
        binding.resultImageView.visibility = View.GONE
        binding.outputText.visibility = View.VISIBLE
        binding.outputText.text = text
        binding.outputText.scrollTo(0, 0)
    }

    private fun interface InputStreamSupplier {
        @Throws(IOException::class)
        fun open(): InputStream?
    }

    private fun readImageBytes(supplier: InputStreamSupplier): ByteArray? {
        return try {
            readAllBytes(supplier.open())
        } catch (e: Exception) {
            Log.e(MainActivity.TAG, String.format("Reading selected image failed.%s", Exceptions.getStackTraceString(e)))
            Popup.show(requireContext(), getString(R.string.protocol_read_failed))
            null
        }
    }

    @Throws(IOException::class)
    private fun readAllBytes(inputStream: InputStream?): ByteArray {
        if (inputStream == null) {
            throw IOException("Input stream is null")
        }
        inputStream.use { input ->
            ByteArrayOutputStream().use { buffer ->
                val chunk = ByteArray(8192)
                var read: Int
                while (input.read(chunk).also { read = it } != -1) {
                    buffer.write(chunk, 0, read)
                }
                return buffer.toByteArray()
            }
        }
    }

    companion object {
        private const val PROTOCOL_FFKITMEM = "ffkitmem"
        private const val PROTOCOL_FFKITSAF = "ffkitsaf"

        @JvmStatic
        fun formatMemProtocolStatus(inputUrl: String, inputSize: Long, outputUrl: String, outputSize: Long): String {
            return "in $inputUrl (${ResourcesUtil.humanReadableByteCount(inputSize)})" +
                " -> drawtext -> " +
                "out $outputUrl (${ResourcesUtil.humanReadableByteCount(outputSize)})"
        }
    }
}

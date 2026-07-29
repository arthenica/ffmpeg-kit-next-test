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

package com.arthenica.ffmpegkit.nativetest

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import com.arthenica.ffmpegkit.FFmpegKitConfig
import com.arthenica.ffmpegkit.nativetest.databinding.ActivityNativeTestBinding
import java.io.File

/**
 * Drives the native prefab consumer ([native-test.c]) through four escalating checks and a
 * cross-check that asserts the native path and the JVM FFmpegKit path report the same bundled
 * FFmpeg. Every check runs off the main thread and appends its result to the shared output view.
 */
class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityNativeTestBinding
    private val mainHandler = Handler(Looper.getMainLooper())

    /** JNI entry points implemented in native-test.c. */
    private external fun nativeAvVersionInfo(): String
    private external fun nativeVersionReport(): String
    private external fun nativeConfiguration(): String
    private external fun nativeProbe(): String
    private external fun nativeEncode(outputPath: String): String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityNativeTestBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.versionButton.setOnClickListener { runCheck("VERSION") { versionCheck() } }
        binding.probeButton.setOnClickListener { runCheck("PROBE") { nativeProbe() } }
        binding.encodeButton.setOnClickListener { runCheck("ENCODE") { encodeCheck() } }
        binding.crossCheckButton.setOnClickListener { runCheck("CROSS-CHECK") { crossCheck() } }
    }

    /** Check 1: prove headers resolve, libraries link and load, and report versions. */
    private fun versionCheck(): String =
        "${nativeVersionReport()}\n\nconfiguration:\n${nativeConfiguration()}"

    /** Check 3: encode a synthetic clip into the app cache directory. */
    private fun encodeCheck(): String {
        val output = File(cacheDir, "native-test-output.mp4")
        return nativeEncode(output.absolutePath)
    }

    /**
     * Cross-check: the native prefab path (av_version_info) and the JVM FFmpegKit path
     * (FFmpegKitConfig.getFFmpegVersion) must report the exact same bundled FFmpeg version.
     * Same AAR, two consumption paths, identical result.
     */
    private fun crossCheck(): String {
        val native = nativeAvVersionInfo()
        val jvm = FFmpegKitConfig.getFFmpegVersion()
        val verdict = if (native == jvm) "MATCH ✓" else "MISMATCH ✗"
        return "native (prefab) : $native\nJVM (FFmpegKit) : $jvm\nresult          : $verdict"
    }

    private fun runCheck(name: String, block: () -> String) {
        appendOutput("\n=== $name ===\n")
        Thread {
            val result = try {
                block()
            } catch (t: Throwable) {
                Log.e(TAG, "$name failed.", t)
                "EXCEPTION: ${t.message}"
            }
            mainHandler.post { appendOutput("$result\n") }
        }.start()
    }

    private fun appendOutput(text: String) {
        binding.outputText.append(text)
        binding.outputScroll.post { binding.outputScroll.fullScroll(View.FOCUS_DOWN) }
    }

    companion object {
        const val TAG = "ffmpeg-kit-next-native-test"

        init {
            System.loadLibrary("native-test")
        }
    }
}

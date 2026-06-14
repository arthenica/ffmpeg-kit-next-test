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

package com.arthenica.ffmpegkit.util

import android.util.Log
import com.arthenica.ffmpegkit.test.MainActivity
import com.arthenica.smartexception.java.Exceptions
import java.io.IOException
import java.util.concurrent.Executors

object AsyncCatImageTask {
    private val executorService = Executors.newCachedThreadPool()

    fun execute(inputPath: String, outputPath: String) {
        executorService.execute {
            try {
                val asyncCommand = "cat $inputPath > $outputPath"
                Log.d(MainActivity.TAG, "Starting async cat image command: $asyncCommand")

                val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", asyncCommand))
                val rc = process.waitFor()

                Log.d(MainActivity.TAG, "Async cat image command: $asyncCommand exited with $rc.")
            } catch (e: IOException) {
                Log.e(MainActivity.TAG, "Async cat image command failed for $inputPath.${Exceptions.getStackTraceString(e)}")
            } catch (e: InterruptedException) {
                Log.e(MainActivity.TAG, "Async cat image command failed for $inputPath.${Exceptions.getStackTraceString(e)}")
            }
        }
    }
}

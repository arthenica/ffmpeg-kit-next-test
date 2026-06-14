/*
 * Copyright (c) 2019-2021 Alexander Berezhnoi
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

package com.arthenica.ffmpegkit.util

import android.content.res.Resources
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import com.arthenica.ffmpegkit.test.MainActivity
import com.arthenica.smartexception.java.Exceptions
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.Locale

object ResourcesUtil {
    @Throws(IOException::class)
    fun resourceToFile(resources: Resources, resourceId: Int, file: File) {
        val bitmap = BitmapFactory.decodeResource(resources, resourceId)

        if (file.exists()) {
            file.delete()
        }

        FileOutputStream(file).use { outputStream ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 100, outputStream)
        }
    }

    @Throws(IOException::class)
    fun rawResourceToFile(resources: Resources, resourceId: Int, file: File) {
        if (file.exists()) {
            file.delete()
        }

        try {
            resources.openRawResource(resourceId).use { inputStream ->
                FileOutputStream(file).use { outputStream ->
                    inputStream.copyTo(outputStream)
                }
            }
        } catch (e: IOException) {
            Log.e(MainActivity.TAG, "Saving raw resource failed.${Exceptions.getStackTraceString(e)}")
        }
    }

    fun humanReadableByteCount(bytes: Long): String {
        if (bytes < 1024) {
            return "$bytes B"
        }
        val kb = bytes / 1024.0
        if (kb < 1024) {
            return String.format(Locale.US, "%.1f KB", kb)
        }
        return String.format(Locale.US, "%.1f MB", kb / 1024.0)
    }
}

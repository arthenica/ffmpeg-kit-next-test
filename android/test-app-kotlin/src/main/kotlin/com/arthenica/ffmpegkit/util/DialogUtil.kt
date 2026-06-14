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

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import androidx.appcompat.app.AlertDialog
import com.arthenica.ffmpegkit.test.databinding.CancellableProgressDialogLayoutBinding
import com.arthenica.ffmpegkit.test.databinding.ProgressDialogLayoutBinding

object DialogUtil {
    fun createProgressDialog(context: Context, text: String): AlertDialog {
        val builder = AlertDialog.Builder(context)
        val inflater = context.getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater?
        if (inflater != null) {
            val binding = ProgressDialogLayoutBinding.inflate(inflater)
            builder.setView(binding.root)
            binding.progressDialogText.text = text
        }
        builder.setCancelable(false)
        return builder.create()
    }

    fun createCancellableProgressDialog(context: Context, text: String, onClickListener: View.OnClickListener): AlertDialog {
        val builder = AlertDialog.Builder(context)
        val inflater = context.getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater?
        if (inflater != null) {
            val binding = CancellableProgressDialogLayoutBinding.inflate(inflater)
            builder.setView(binding.root)
            binding.progressDialogText.text = text
            binding.cancelButton.setOnClickListener(onClickListener)
        }
        builder.setCancelable(false)
        return builder.create()
    }
}

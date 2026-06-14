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

package com.arthenica.ffmpegkit.test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class FFmpegCommandsTest {

    @Test
    public void buildFFKitMemProtocolCommandWiresMemoryUrlsFontAndTextFile() {
        String command = FFmpegCommands.buildFFKitMemProtocolCommand(
                "ffkitmem:5.jpg", "ffkitmem:6.jpg", "/cache/font.ttf", "/cache/text.txt");

        assertTrue(command, command.contains("-i ffkitmem:5.jpg"));
        assertTrue(command, command.endsWith("ffkitmem:6.jpg"));
        assertTrue(command, command.contains("drawtext=fontfile=/cache/font.ttf:text='/cache/text.txt':"));
        assertTrue(command, command.contains("-frames:v 1"));
        assertTrue(command, command.contains("-f image2"));
        assertTrue(command, command.contains("-c:v mjpeg"));

        int vf = command.indexOf("-vf ");
        String filterArg = command.substring(vf + 4).split(" ", 2)[0];
        assertTrue("filter arg must be space-free: " + filterArg, filterArg.contains("drawtext="));
        assertEquals(-1, filterArg.indexOf(' '));
    }

}

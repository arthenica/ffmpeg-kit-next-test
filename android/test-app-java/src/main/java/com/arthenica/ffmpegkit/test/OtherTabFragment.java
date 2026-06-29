/*
 * Copyright (c) 2021, 2026 Taner Sener
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

import static com.arthenica.ffmpegkit.test.MainActivity.TAG;
import static com.arthenica.ffmpegkit.test.MainActivity.notNull;

import android.os.Bundle;
import android.text.method.ScrollingMovementMethod;
import android.util.Log;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.Spinner;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;

import com.arthenica.ffmpegkit.FFmpegKit;
import com.arthenica.ffmpegkit.FFmpegKitConfig;
import com.arthenica.ffmpegkit.ReturnCode;
import com.arthenica.ffmpegkit.util.ResourcesUtil;
import com.arthenica.smartexception.java.Exceptions;

import java.io.File;
import java.io.IOException;

public class OtherTabFragment extends Fragment implements AdapterView.OnItemSelectedListener {

    public static final String DAV1D_TEST_DEFAULT_URL = "http://download.opencontent.netflix.com.s3.amazonaws.com/AV1/Sparks/Sparks-5994fps-AV1-10bit-960x540-film-grain-synthesis-854kbps.obu";

    private TextView outputText;
    private String selectedTest;

    public OtherTabFragment() {
        super(R.layout.fragment_other_tab);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        Spinner otherTestSpinner = view.findViewById(R.id.otherTestSpinner);
        ArrayAdapter<CharSequence> adapter = ArrayAdapter.createFromResource(requireContext(), R.array.other_test, R.layout.spinner_item);
        adapter.setDropDownViewResource(R.layout.spinner_dropdown_item);
        otherTestSpinner.setAdapter(adapter);
        otherTestSpinner.setOnItemSelectedListener(this);

        Button runButton = view.findViewById(R.id.runButton);
        runButton.setOnClickListener(v -> runTest());

        outputText = view.findViewById(R.id.outputText);
        outputText.setMovementMethod(new ScrollingMovementMethod());

        selectedTest = getResources().getStringArray(R.array.other_test)[0];
    }

    @Override
    public void onResume() {
        super.onResume();
        setActive();
    }

    public static OtherTabFragment newInstance() {
        return new OtherTabFragment();
    }

    @Override
    public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
        selectedTest = parent.getItemAtPosition(position).toString();
    }

    @Override
    public void onNothingSelected(AdapterView<?> parent) {
        // DO NOTHING
    }

    public void runTest() {
        clearOutput();

        switch (selectedTest) {
            case "chromaprint":
                testChromaprint();
                break;
            case "dav1d":
                testDav1d();
                break;
            case "webp":
                testWebp();
                break;
            case "libjxl":
                testLibjxl();
                break;
            case "zscale":
                testZscale();
                break;
            case "vvenc":
                testVvenc();
                break;
        }
    }

    protected void testChromaprint() {
        Log.d(TAG, "Testing 'chromaprint' mutex");

        final File audioSampleFile = getChromaprintSampleFile();
        if (audioSampleFile.exists()) {
            audioSampleFile.delete();
        }

        String ffmpegCommand = String.format("-hide_banner -y -f lavfi -i sine=frequency=1000:duration=5 -c:a pcm_s16le %s", audioSampleFile.getAbsolutePath());

        android.util.Log.d(TAG, String.format("Creating audio sample with '%s'.", ffmpegCommand));

        FFmpegKit.executeAsync(ffmpegCommand, session -> {
            Log.d(TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", session.getState(), session.getReturnCode(), notNull(session.getFailStackTrace(), "\n")));

            if (ReturnCode.isSuccess(session.getReturnCode())) {
                Log.d(TAG, "AUDIO sample created");

                String chromaprintCommand = String.format("-hide_banner -y -i %s -f chromaprint -fp_format 2 %s", audioSampleFile, getChromaprintOutputFile().getAbsolutePath());

                Log.d(TAG, String.format("FFmpeg process started with arguments: '%s'.", chromaprintCommand));

                FFmpegKit.executeAsync(chromaprintCommand, session1 -> MainActivity.addUIAction(() -> {
                    Log.d(TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", session1.getState(), session1.getReturnCode(), notNull(session1.getFailStackTrace(), "\n")));

                    if (ReturnCode.isSuccess(session1.getReturnCode())) {
                        Popup.show(requireContext(), "Testing chromaprint completed successfully.");
                    } else {
                        Popup.show(requireContext(), "Testing chromaprint failed. Please check logs for the details.");
                    }
                }), log -> MainActivity.addUIAction(() -> appendOutput(log.getMessage())), null);

            } else {
                Popup.show(requireContext(), "Creating AUDIO sample failed. Please check logs for the details.");
            }
        });
    }

    protected void testDav1d() {
        Log.d(TAG, "Testing decoding 'av1' codec");

        final String ffmpegCommand = String.format("-hide_banner -y -i %s -c:v mpeg4 %s", DAV1D_TEST_DEFAULT_URL, getDav1dOutputFile().getAbsolutePath());

        Log.d(TAG, String.format("FFmpeg process started with arguments: '%s'.", ffmpegCommand));

        FFmpegKit.executeAsync(ffmpegCommand, session -> Log.d(TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", session.getState(), session.getReturnCode(), notNull(session.getFailStackTrace(), "\n"))), log -> MainActivity.addUIAction(() -> {
            appendOutput(log.getMessage());
        }), null);
    }

    protected void testWebp() {
        final File imageFile = new File(requireContext().getCacheDir(), "machupicchu.jpg");
        final File outputFile = new File(requireContext().getFilesDir(), "video.webp");

        try {
            ResourcesUtil.resourceToFile(getResources(), R.drawable.machupicchu, imageFile);

            Log.d(TAG, "Testing 'webp' codec");

            final String ffmpegCommand = String.format("-hide_banner -y -i %s %s", imageFile.getAbsolutePath(), outputFile.getAbsolutePath());

            Log.d(TAG, String.format("FFmpeg process started with arguments: '%s'.", ffmpegCommand));

            FFmpegKit.executeAsync(ffmpegCommand, session -> {
                Log.d(TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", session.getState(), session.getReturnCode(), notNull(session.getFailStackTrace(), "\n")));

                MainActivity.addUIAction(() -> {
                    if (ReturnCode.isSuccess(session.getReturnCode())) {
                        Popup.show(requireContext(), "Encode webp completed successfully.");
                    } else {
                        Popup.show(requireContext(), "Encode webp failed. Please check logs for the details.");
                    }
                });
            }, log -> MainActivity.addUIAction(() -> {
                appendOutput(log.getMessage());
            }), null);

        } catch (IOException e) {
            Log.e(TAG, String.format("Encode webp failed %s.", Exceptions.getStackTraceString(e)));
            Popup.show(requireContext(), "Encode webp failed");
        }
    }

    protected void testZscale() {
        final File videoFile = new File(requireContext().getFilesDir(), "video.mp4");
        final File zscaledVideoFile = new File(requireContext().getFilesDir(), "video.zscaled.mp4");

        Log.d(TAG, "Testing 'zscale' filter with video file created on the Video tab");

        final String ffmpegCommand = FFmpegCommands.buildZscaleVideoCommand(videoFile.getAbsolutePath(), zscaledVideoFile.getAbsolutePath());

        Log.d(TAG, String.format("FFmpeg process started with arguments: '%s'.", ffmpegCommand));

        FFmpegKit.executeAsync(ffmpegCommand, session -> {
            Log.d(TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", session.getState(), session.getReturnCode(), notNull(session.getFailStackTrace(), "\n")));

            MainActivity.addUIAction(() -> {
                if (ReturnCode.isSuccess(session.getReturnCode())) {
                    Popup.show(requireContext(), "zscale completed successfully.");
                } else {
                    Popup.show(requireContext(), "zscale failed. Please check logs for the details.");
                }
            });
        }, log -> MainActivity.addUIAction(() -> {
            appendOutput(log.getMessage());
        }), null);
    }

    protected void testLibjxl() {
        final File imageFile = new File(requireContext().getCacheDir(), "machupicchu.jpg");
        final File jxlOutputFile = getLibjxlOutputFile();
        final File decodedOutputFile = getLibjxlDecodedOutputFile();

        if (jxlOutputFile.exists()) {
            jxlOutputFile.delete();
        }
        if (decodedOutputFile.exists()) {
            decodedOutputFile.delete();
        }

        try {
            ResourcesUtil.resourceToFile(getResources(), R.drawable.machupicchu, imageFile);

            Log.d(TAG, "Testing 'libjxl' codec");

            final String ffmpegCommand = String.format("-hide_banner -y -i %s -frames:v 1 -vf format=rgb24,setparams=range=pc:color_primaries=bt709:color_trc=iec61966-2-1:colorspace=gbr -c:v libjxl -distance 1.0 -xyb 1 -update 1 %s", imageFile.getAbsolutePath(), jxlOutputFile.getAbsolutePath());

            Log.d(TAG, String.format("FFmpeg process started with arguments: '%s'.", ffmpegCommand));

            FFmpegKit.executeAsync(ffmpegCommand, session -> {
                Log.d(TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", session.getState(), session.getReturnCode(), notNull(session.getFailStackTrace(), "\n")));

                if (ReturnCode.isSuccess(session.getReturnCode())) {
                    final String decodeCommand = String.format("-hide_banner -y -i %s -frames:v 1 -c:v png -update 1 %s", jxlOutputFile.getAbsolutePath(), decodedOutputFile.getAbsolutePath());

                    Log.d(TAG, String.format("FFmpeg process started with arguments: '%s'.", decodeCommand));

                    FFmpegKit.executeAsync(decodeCommand, session1 -> Log.d(TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", session1.getState(), session1.getReturnCode(), notNull(session1.getFailStackTrace(), "\n"))), log -> MainActivity.addUIAction(() -> {
                        appendOutput(log.getMessage());
                    }), null);
                }
            }, log -> MainActivity.addUIAction(() -> {
                appendOutput(log.getMessage());
            }), null);
        } catch (IOException e) {
            Log.e(TAG, String.format("Encode libjxl failed %s.", Exceptions.getStackTraceString(e)));
            Popup.show(requireContext(), "Encode libjxl failed");
        }
    }

    protected void testVvenc() {
        final File image1File = new File(requireContext().getCacheDir(), "machupicchu.jpg");
        final File image2File = new File(requireContext().getCacheDir(), "pyramid.jpg");
        final File image3File = new File(requireContext().getCacheDir(), "stonehenge.jpg");
        final File outputFile = getVvencOutputFile();

        if (outputFile.exists()) {
            outputFile.delete();
        }

        try {
            ResourcesUtil.resourceToFile(getResources(), R.drawable.machupicchu, image1File);
            ResourcesUtil.resourceToFile(getResources(), R.drawable.pyramid, image2File);
            ResourcesUtil.resourceToFile(getResources(), R.drawable.stonehenge, image3File);

            Log.d(TAG, "Testing 'vvenc' codec");

            final String ffmpegCommand = FFmpegCommands.buildEncodeVideoCommand(image1File.getAbsolutePath(), image2File.getAbsolutePath(), image3File.getAbsolutePath(), outputFile.getAbsolutePath(), "libvvenc", "yuv420p10le", "-preset faster -qp 32 ");

            Log.d(TAG, String.format("FFmpeg process started with arguments: '%s'.", ffmpegCommand));

            FFmpegKit.executeAsync(ffmpegCommand, session -> Log.d(TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", session.getState(), session.getReturnCode(), notNull(session.getFailStackTrace(), "\n"))), log -> MainActivity.addUIAction(() -> {
                appendOutput(log.getMessage());
            }), null);
        } catch (IOException e) {
            Log.e(TAG, String.format("Encode vvenc failed %s.", Exceptions.getStackTraceString(e)));
            Popup.show(requireContext(), "Encode vvenc failed");
        }
    }

    public File getChromaprintSampleFile() {
        return new File(requireContext().getFilesDir(), "audio-sample.wav");
    }

    public File getDav1dOutputFile() {
        return new File(requireContext().getFilesDir(), "video.mp4");
    }

    public File getChromaprintOutputFile() {
        return new File(requireContext().getFilesDir(), "chromaprint.txt");
    }

    public File getLibjxlOutputFile() {
        return new File(requireContext().getFilesDir(), "image.jxl");
    }

    public File getLibjxlDecodedOutputFile() {
        return new File(requireContext().getFilesDir(), "image.jxl.png");
    }

    public File getVvencOutputFile() {
        return new File(requireContext().getFilesDir(), "video.266");
    }

    public void setActive() {
        android.util.Log.i(MainActivity.TAG, "Other Tab Activated");
        FFmpegKitConfig.enableLogCallback(null);
        FFmpegKitConfig.enableStatisticsCallback(null);
        Popup.show(requireContext(), getString(R.string.other_test_tooltip_text));
    }

    public void appendOutput(final String logMessage) {
        outputText.append(logMessage);
    }

    public void clearOutput() {
        outputText.setText("");
    }

}

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

package com.arthenica.ffmpegkit.test;

import static com.arthenica.ffmpegkit.test.MainActivity.TAG;
import static com.arthenica.ffmpegkit.test.MainActivity.notNull;

import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.MediaController;
import android.widget.TextView;
import android.widget.VideoView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.Fragment;

import com.arthenica.ffmpegkit.FFmpegKit;
import com.arthenica.ffmpegkit.FFmpegKitConfig;
import com.arthenica.ffmpegkit.FFmpegSession;
import com.arthenica.ffmpegkit.FFmpegSessionCompleteCallback;
import com.arthenica.ffmpegkit.LogCallback;
import com.arthenica.ffmpegkit.ReturnCode;
import com.arthenica.ffmpegkit.SessionState;
import com.arthenica.ffmpegkit.Statistics;
import com.arthenica.ffmpegkit.StatisticsCallback;
import com.arthenica.ffmpegkit.util.AsyncCatImageTask;
import com.arthenica.ffmpegkit.util.DialogUtil;
import com.arthenica.ffmpegkit.util.ResourcesUtil;
import com.arthenica.smartexception.java.Exceptions;

import java.io.File;
import java.io.IOException;
import java.math.BigDecimal;
import java.math.RoundingMode;

public class PipeTabFragment extends Fragment {
    private VideoView videoView;
    private AlertDialog progressDialog;
    private Statistics statistics;

    public PipeTabFragment() {
        super(R.layout.fragment_pipe_tab);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        View createButton = view.findViewById(R.id.createButton);
        if (createButton != null) {
            createButton.setOnClickListener(new View.OnClickListener() {

                @Override
                public void onClick(View v) {
                    createVideo();
                }
            });
        }

        videoView = view.findViewById(R.id.videoPlayerFrame);

        progressDialog = DialogUtil.createProgressDialog(requireContext(), "Creating video");
    }

    @Override
    public void onResume() {
        super.onResume();
        setActive();
    }

    public static PipeTabFragment newInstance() {
        return new PipeTabFragment();
    }

    public void enableLogCallback() {
        FFmpegKitConfig.enableLogCallback(new LogCallback() {

            @Override
            public void apply(final com.arthenica.ffmpegkit.Log log) {
                Log.d(MainActivity.TAG, log.getMessage());
            }
        });
    }

    public void enableStatisticsCallback() {
        FFmpegKitConfig.enableStatisticsCallback(new StatisticsCallback() {

            @Override
            public void apply(final Statistics newStatistics) {
                MainActivity.addUIAction(new Runnable() {

                    @Override
                    public void run() {
                        PipeTabFragment.this.statistics = newStatistics;
                        updateProgressDialog();
                    }
                });
            }
        });
    }

    void startAsyncCatImageProcess(final String imagePath, final String namedPipePath) {
        AsyncCatImageTask.execute(imagePath, namedPipePath);
    }

    public void createVideo() {
        final File image1File = new File(requireContext().getCacheDir(), "tree.jpg");
        final File image2File = new File(requireContext().getCacheDir(), "lake.jpg");
        final File image3File = new File(requireContext().getCacheDir(), "sunset.jpg");
        final File videoFile = getVideoFile();

        final String pipe1 = FFmpegKitConfig.registerNewFFmpegPipe(requireContext());
        final String pipe2 = FFmpegKitConfig.registerNewFFmpegPipe(requireContext());
        final String pipe3 = FFmpegKitConfig.registerNewFFmpegPipe(requireContext());

        try {

            // IF VIDEO IS PLAYING STOP PLAYBACK
            videoView.stopPlayback();

            if (videoFile.exists()) {
                videoFile.delete();
            }

            final String videoCodec = FFmpegCommands.getPackageVideoCodec();

            Log.d(TAG, String.format("Testing PIPE with '%s' codec", videoCodec));

            showProgressDialog();

            ResourcesUtil.resourceToFile(getResources(), R.drawable.tree, image1File);
            ResourcesUtil.resourceToFile(getResources(), R.drawable.lake, image2File);
            ResourcesUtil.resourceToFile(getResources(), R.drawable.sunset, image3File);

            final String ffmpegCommand = FFmpegCommands.buildCreateVideoWithPipesCommand(pipe1, pipe2, pipe3, videoFile.getAbsolutePath(), videoCodec);

            Log.d(TAG, String.format("FFmpeg process started with arguments: '%s'.", ffmpegCommand));

            FFmpegKit.executeAsync(ffmpegCommand, new FFmpegSessionCompleteCallback() {

                @Override
                public void apply(final FFmpegSession session) {
                    final SessionState state = session.getState();
                    final ReturnCode returnCode = session.getReturnCode();

                    Log.d(TAG, String.format("FFmpeg process exited with state %s and rc %s.%s", state, returnCode, notNull(session.getFailStackTrace(), "\n")));

                    hideProgressDialog();

                    // CLOSE PIPES
                    FFmpegKitConfig.closeFFmpegPipe(pipe1);
                    FFmpegKitConfig.closeFFmpegPipe(pipe2);
                    FFmpegKitConfig.closeFFmpegPipe(pipe3);

                    MainActivity.addUIAction(new Runnable() {

                        @Override
                        public void run() {
                            if (ReturnCode.isSuccess(returnCode)) {
                                Log.d(TAG, "Create completed successfully; playing video.");
                                playVideo();
                            } else {
                                Popup.show(requireContext(), "Create failed. Please check logs for the details.");
                            }
                        }
                    });
                }
            });

            // START ASYNC PROCESSES AFTER INITIATING FFMPEG COMMAND
            startAsyncCatImageProcess(image1File.getAbsolutePath(), pipe1);
            startAsyncCatImageProcess(image2File.getAbsolutePath(), pipe2);
            startAsyncCatImageProcess(image3File.getAbsolutePath(), pipe3);

        } catch (IOException e) {
            Log.e(TAG, String.format("Create video failed %s.", Exceptions.getStackTraceString(e)));
            Popup.show(requireContext(), "Create video failed");
        }
    }

    protected void playVideo() {
        MediaController mediaController = new MediaController(requireContext());
        mediaController.setAnchorView(videoView);
        videoView.setVideoURI(Uri.parse("file://" + getVideoFile().getAbsolutePath()));
        videoView.setMediaController(mediaController);
        videoView.requestFocus();
        videoView.setOnPreparedListener(new MediaPlayer.OnPreparedListener() {

            @Override
            public void onPrepared(MediaPlayer mp) {
                videoView.setBackgroundColor(0x00000000);
            }
        });
        videoView.setOnErrorListener(new MediaPlayer.OnErrorListener() {

            @Override
            public boolean onError(MediaPlayer mp, int what, int extra) {
                videoView.stopPlayback();
                return false;
            }
        });
        videoView.start();
    }

    protected File getVideoFile() {
        return new File(requireContext().getFilesDir(), "video.mp4");
    }

    public void setActive() {
        Log.i(MainActivity.TAG, "Pipe Tab Activated");
        enableLogCallback();
        enableStatisticsCallback();
        Popup.show(requireContext(), getString(R.string.pipe_test_tooltip_text));
    }

    protected void showProgressDialog() {

        // CLEAN STATISTICS
        statistics = null;

        progressDialog.show();
    }

    protected void updateProgressDialog() {
        if (statistics == null || statistics.getTime() < 0) {
            return;
        }

        double timeInMilliseconds = this.statistics.getTime();
        int totalVideoDuration = 9000;

        String completePercentage = new BigDecimal(timeInMilliseconds).multiply(new BigDecimal(100)).divide(new BigDecimal(totalVideoDuration), 0, RoundingMode.HALF_UP).toString();

        TextView textView = progressDialog.findViewById(R.id.progressDialogText);
        if (textView != null) {
            textView.setText(String.format("Creating video: %% %s.", completePercentage));
        }
    }

    protected void hideProgressDialog() {
        progressDialog.dismiss();

        MainActivity.addUIAction(new Runnable() {

            @Override
            public void run() {
                PipeTabFragment.this.progressDialog = DialogUtil.createProgressDialog(requireContext(), "Creating video");
            }
        });
    }

}

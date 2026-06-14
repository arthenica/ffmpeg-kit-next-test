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

import static android.app.Activity.RESULT_OK;
import static com.arthenica.ffmpegkit.test.MainActivity.TAG;
import static com.arthenica.ffmpegkit.util.ResourcesUtil.humanReadableByteCount;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Bundle;
import android.text.method.ScrollingMovementMethod;
import android.util.Log;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.Spinner;
import android.widget.TextView;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.core.content.ContextCompat;
import androidx.core.content.FileProvider;
import androidx.fragment.app.Fragment;

import com.arthenica.ffmpegkit.FFmpegKit;
import com.arthenica.ffmpegkit.FFmpegKitConfig;
import com.arthenica.ffmpegkit.FFmpegKitInputBuffer;
import com.arthenica.ffmpegkit.FFmpegKitOutputBuffer;
import com.arthenica.ffmpegkit.FFprobeKit;
import com.arthenica.ffmpegkit.ReturnCode;
import com.arthenica.ffmpegkit.util.ResourcesUtil;
import com.arthenica.smartexception.java.Exceptions;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;

public class FFKitProtocolsTabFragment extends Fragment implements AdapterView.OnItemSelectedListener {

    private static final String PROTOCOL_FFKITMEM = "ffkitmem";
    private static final String PROTOCOL_FFKITSAF = "ffkitsaf";

    private EditText overlayTextInput;
    private ImageView resultImageView;
    private TextView outputText;
    private TextView statusText;

    private String selectedProtocol = PROTOCOL_FFKITMEM;
    private byte[] selectedImageBytes;
    private File cameraFile;

    // For the ffkitmem protocol both buttons need a picked image; this flag records
    // which tool to run once the image comes back from the picker.
    private boolean pendingFFKitMemFFprobe;

    private ActivityResultLauncher<String> galleryLauncher;
    private ActivityResultLauncher<Uri> cameraLauncher;
    private ActivityResultLauncher<String> cameraPermissionLauncher;
    private ActivityResultLauncher<Intent> safCreateDocumentLauncher;
    private ActivityResultLauncher<Intent> safOpenDocumentLauncher;

    public FFKitProtocolsTabFragment() {
        super(R.layout.fragment_ffkit_protocols_tab);
    }

    public static FFKitProtocolsTabFragment newInstance() {
        return new FFKitProtocolsTabFragment();
    }

    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        galleryLauncher = registerForActivityResult(new ActivityResultContracts.GetContent(), uri -> {
            if (uri != null) {
                handleImagePicked(readImageBytes(() -> requireContext().getContentResolver().openInputStream(uri)));
            }
        });

        cameraLauncher = registerForActivityResult(new ActivityResultContracts.TakePicture(), success -> {
            if (Boolean.TRUE.equals(success) && cameraFile != null && cameraFile.exists()) {
                handleImagePicked(readImageBytes(() -> new FileInputStream(cameraFile)));
            }
        });

        cameraPermissionLauncher = registerForActivityResult(new ActivityResultContracts.RequestPermission(), granted -> {
            if (Boolean.TRUE.equals(granted)) {
                launchCamera();
            } else {
                Popup.show(requireContext(), getString(R.string.protocol_camera_denied));
            }
        });

        safCreateDocumentLauncher = registerForActivityResult(new ActivityResultContracts.StartActivityForResult(), result -> {
            if (result.getResultCode() == RESULT_OK && result.getData() != null && result.getData().getData() != null) {
                runFFKitSafFFmpeg(result.getData().getData());
            }
        });

        safOpenDocumentLauncher = registerForActivityResult(new ActivityResultContracts.StartActivityForResult(), result -> {
            if (result.getResultCode() == RESULT_OK && result.getData() != null && result.getData().getData() != null) {
                runFFKitSafFFprobe(result.getData().getData());
            }
        });
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        overlayTextInput = view.findViewById(R.id.overlayTextInput);
        resultImageView = view.findViewById(R.id.resultImageView);
        outputText = view.findViewById(R.id.outputText);
        outputText.setMovementMethod(new ScrollingMovementMethod());
        statusText = view.findViewById(R.id.statusText);

        ((Button) view.findViewById(R.id.runFFmpegButton)).setOnClickListener(v -> onRunFFmpeg());
        ((Button) view.findViewById(R.id.runFFprobeButton)).setOnClickListener(v -> onRunFFprobe());

        Spinner protocolSpinner = view.findViewById(R.id.protocolSpinner);
        ArrayAdapter<CharSequence> adapter = ArrayAdapter.createFromResource(requireContext(), R.array.protocol_list, R.layout.spinner_item);
        adapter.setDropDownViewResource(R.layout.spinner_dropdown_item);
        protocolSpinner.setAdapter(adapter);
        protocolSpinner.setOnItemSelectedListener(this);

        updateUiForProtocol();
    }

    @Override
    public void onResume() {
        super.onResume();
        Log.i(TAG, "FFKitProtocols Tab Activated");
        setActive();
    }

    public void setActive() {
        FFmpegKitConfig.enableLogCallback(null);
        FFmpegKitConfig.enableStatisticsCallback(null);
        Popup.show(requireContext(), getString(R.string.protocol_test_tooltip_text));
    }

    @Override
    public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
        selectedProtocol = parent.getItemAtPosition(position).toString();
        updateUiForProtocol();
    }

    @Override
    public void onNothingSelected(AdapterView<?> parent) {
        // DO NOTHING
    }

    private void updateUiForProtocol() {
        final boolean ffkitmem = PROTOCOL_FFKITMEM.equals(selectedProtocol);
        overlayTextInput.setVisibility(ffkitmem ? View.VISIBLE : View.GONE);
        resultImageView.setVisibility(View.GONE);
        resultImageView.setImageDrawable(null);
        outputText.setVisibility(View.GONE);
        outputText.setText("");
        statusText.setText(getString(R.string.protocol_status_idle));
    }

    // region Button dispatch

    private void onRunFFmpeg() {
        switch (selectedProtocol) {
            case PROTOCOL_FFKITMEM:
                pendingFFKitMemFFprobe = false;
                showImageSourceChooser();
                break;
            case PROTOCOL_FFKITSAF:
                launchFFKitSafCreateDocument();
                break;
            default:
                Popup.show(requireContext(), getString(R.string.protocol_not_implemented));
        }
    }

    private void onRunFFprobe() {
        switch (selectedProtocol) {
            case PROTOCOL_FFKITMEM:
                pendingFFKitMemFFprobe = true;
                showImageSourceChooser();
                break;
            case PROTOCOL_FFKITSAF:
                launchFFKitSafOpenDocument();
                break;
            default:
                Popup.show(requireContext(), getString(R.string.protocol_not_implemented));
        }
    }

    // endregion

    // region ffkitmem protocol

    private void showImageSourceChooser() {
        final CharSequence[] options = new CharSequence[]{
                getString(R.string.protocol_take_photo),
                getString(R.string.protocol_choose_gallery)
        };
        new AlertDialog.Builder(requireContext())
                .setTitle(R.string.protocol_dialog_title)
                .setItems(options, (dialog, which) -> {
                    if (which == 0) {
                        launchCameraWithPermission();
                    } else {
                        galleryLauncher.launch("image/*");
                    }
                })
                .show();
    }

    private void launchCameraWithPermission() {
        if (ContextCompat.checkSelfPermission(requireContext(), Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            cameraPermissionLauncher.launch(Manifest.permission.CAMERA);
            return;
        }
        launchCamera();
    }

    private void launchCamera() {
        cameraFile = new File(requireContext().getCacheDir(), "camera_capture.jpg");
        Uri outputUri = FileProvider.getUriForFile(requireContext(), requireContext().getPackageName() + ".fileprovider", cameraFile);
        cameraLauncher.launch(outputUri);
    }

    private void handleImagePicked(final byte[] bytes) {
        if (bytes == null) {
            return;
        }
        selectedImageBytes = bytes;
        if (pendingFFKitMemFFprobe) {
            runFFKitMemFFprobe();
        } else {
            runFFKitMemFFmpeg();
        }
    }

    private void runFFKitMemFFmpeg() {
        if (selectedImageBytes == null) {
            return;
        }

        final FFmpegKitInputBuffer input;
        final FFmpegKitOutputBuffer output;
        final String command;
        try {
            final File fontFile = new File(requireContext().getCacheDir(), "doppioone_regular.ttf");
            ResourcesUtil.rawResourceToFile(getResources(), R.raw.doppioone_regular, fontFile);

            input = FFmpegKitInputBuffer.fromByteArray(selectedImageBytes, "jpg");
            output = FFmpegKitOutputBuffer.create("jpg");
            command = FFmpegCommands.buildFFKitMemProtocolCommand(
                    input.getUrl(), output.getUrl(), fontFile.getAbsolutePath(), overlayTextInput.getText().toString());
        } catch (final Exception e) {
            Log.e(TAG, String.format("Preparing ffkitmem run failed.%s", Exceptions.getStackTraceString(e)));
            Popup.show(requireContext(), getString(R.string.protocol_run_failed));
            return;
        }

        final String inputUrl = input.getUrl();
        final String outputUrl = output.getUrl();
        final long inputSize = input.getSize();
        statusText.setText(getString(R.string.protocol_running));
        Log.d(TAG, String.format("ffkitmem ffmpeg command: %s", command));

        FFmpegKit.executeAsync(command, session -> {
            try {
                if (ReturnCode.isSuccess(session.getReturnCode())) {
                    final byte[] result = output.toByteArray();
                    final long outputSize = output.getSize();
                    final Bitmap bitmap = BitmapFactory.decodeByteArray(result, 0, result.length);
                    final String status = formatMemProtocolStatus(inputUrl, inputSize, outputUrl, outputSize);
                    MainActivity.addUIAction(() -> {
                        showImageResult(bitmap);
                        statusText.setText(status);
                    });
                } else {
                    Log.e(TAG, String.format("ffkitmem ffmpeg failed: rc=%s%n%s",
                            session.getReturnCode(), session.getAllLogsAsString()));
                    final String logs = session.getAllLogsAsString();
                    MainActivity.addUIAction(() -> {
                        showTextResult(logs);
                        statusText.setText(getString(R.string.protocol_run_failed));
                        Popup.show(requireContext(), getString(R.string.protocol_run_failed));
                    });
                }
            } finally {
                input.close();
                output.close();
            }
        });
    }

    private void runFFKitMemFFprobe() {
        if (selectedImageBytes == null) {
            return;
        }

        final FFmpegKitInputBuffer input;
        try {
            input = FFmpegKitInputBuffer.fromByteArray(selectedImageBytes, "jpg");
        } catch (final Exception e) {
            Log.e(TAG, String.format("Preparing ffkitmem ffprobe failed.%s", Exceptions.getStackTraceString(e)));
            Popup.show(requireContext(), getString(R.string.protocol_run_failed));
            return;
        }

        final String inputUrl = input.getUrl();
        final String command = "-hide_banner -print_format json -show_format -show_streams " + inputUrl;
        statusText.setText(getString(R.string.protocol_running));
        Log.d(TAG, String.format("ffkitmem ffprobe command: %s", command));

        FFprobeKit.executeAsync(command, session -> {
            try {
                final boolean success = ReturnCode.isSuccess(session.getReturnCode());
                final String output = session.getOutput();
                MainActivity.addUIAction(() -> {
                    showTextResult(output);
                    statusText.setText("ffprobe -> " + inputUrl);
                    if (!success) {
                        Popup.show(requireContext(), getString(R.string.protocol_run_failed));
                    }
                });
            } finally {
                input.close();
            }
        });
    }

    // endregion

    // region saf protocol

    private void launchFFKitSafCreateDocument() {
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT)
                .setType("video/*")
                .putExtra(Intent.EXTRA_TITLE, "video.mp4")
                .addCategory(Intent.CATEGORY_OPENABLE);
        safCreateDocumentLauncher.launch(intent);
    }

    private void launchFFKitSafOpenDocument() {
        Intent intent = new Intent(Intent.ACTION_GET_CONTENT)
                .setType("*/*")
                .putExtra(Intent.EXTRA_MIME_TYPES, new String[]{"image/*", "video/*", "audio/*"})
                .addCategory(Intent.CATEGORY_OPENABLE);
        safOpenDocumentLauncher.launch(intent);
    }

    private void runFFKitSafFFmpeg(final Uri outputUri) {
        final File image1File = new File(requireContext().getCacheDir(), "machupicchu.jpg");
        final File image2File = new File(requireContext().getCacheDir(), "pyramid.jpg");
        final File image3File = new File(requireContext().getCacheDir(), "stonehenge.jpg");
        final String videoPath = FFmpegKitConfig.getSafParameter(requireContext(), outputUri, "rw");

        final String command;
        try {
            final String videoCodec = getCodec(videoPath);
            ResourcesUtil.resourceToFile(getResources(), R.drawable.machupicchu, image1File);
            ResourcesUtil.resourceToFile(getResources(), R.drawable.pyramid, image2File);
            ResourcesUtil.resourceToFile(getResources(), R.drawable.stonehenge, image3File);
            command = FFmpegCommands.buildEncodeVideoCommand(image1File.getAbsolutePath(),
                    image2File.getAbsolutePath(), image3File.getAbsolutePath(), videoPath, videoCodec, getCustomOptions(videoCodec));
        } catch (final IOException e) {
            Log.e(TAG, String.format("Encode video failed.%s", Exceptions.getStackTraceString(e)));
            Popup.show(requireContext(), getString(R.string.protocol_run_failed));
            return;
        }

        statusText.setText(getString(R.string.protocol_running));
        showTextResult(getString(R.string.protocol_running));
        Log.d(TAG, String.format("saf ffmpeg command: %s", command));

        FFmpegKit.executeAsync(command, session -> {
            final boolean success = ReturnCode.isSuccess(session.getReturnCode());
            final String logs = session.getAllLogsAsString();
            MainActivity.addUIAction(() -> {
                showTextResult(logs);
                statusText.setText(success ? "Encode completed." : getString(R.string.protocol_run_failed));
                if (!success) {
                    Popup.show(requireContext(), getString(R.string.protocol_run_failed));
                }
            });
        });
    }

    private void runFFKitSafFFprobe(final Uri inputUri) {
        final String command = "-hide_banner -print_format json -show_format -show_streams "
                + FFmpegKitConfig.getSafParameterForRead(requireContext(), inputUri);

        statusText.setText(getString(R.string.protocol_running));
        Log.d(TAG, String.format("saf ffprobe command: %s", command));

        FFprobeKit.executeAsync(command, session -> {
            final boolean success = ReturnCode.isSuccess(session.getReturnCode());
            final String output = session.getOutput();
            MainActivity.addUIAction(() -> {
                showTextResult(output);
                statusText.setText(success ? getString(R.string.protocol_status_idle) : getString(R.string.protocol_run_failed));
                if (!success) {
                    Popup.show(requireContext(), getString(R.string.protocol_run_failed));
                }
            });
        });
    }

    private String getCodec(final String videoPath) {
        String extension = "mp4";
        int pos = videoPath.lastIndexOf('.');
        if (pos >= 0) {
            extension = videoPath.substring(pos + 1);
        }

        switch (extension) {
            case "webm":
                return "vp8";
            case "mkv":
                return "aom";
            case "ogv":
                return "theora";
            case "mov":
                return "hap";
            case "mp4":
            default:
                return "mpeg4";
        }
    }

    private String getCustomOptions(final String videoCodec) {
        switch (videoCodec) {
            case "x265":
                return "-crf 28 -preset fast ";
            case "vp8":
                return "-b:v 1M -crf 10 ";
            case "vp9":
                return "-b:v 2M ";
            case "aom":
                return "-crf 30 -strict experimental ";
            case "theora":
                return "-qscale:v 7 ";
            case "hap":
                return "-format hap_q ";
            default:
                // kvazaar, mpeg4, x264, xvid
                return "-movflags faststart ";
        }
    }

    // endregion

    // region helpers

    private void showImageResult(final Bitmap bitmap) {
        outputText.setVisibility(View.GONE);
        resultImageView.setVisibility(View.VISIBLE);
        resultImageView.setImageBitmap(bitmap);
    }

    private void showTextResult(final String text) {
        resultImageView.setVisibility(View.GONE);
        outputText.setVisibility(View.VISIBLE);
        outputText.setText(text);
        outputText.scrollTo(0, 0);
    }

    private interface InputStreamSupplier {
        InputStream open() throws IOException;
    }

    private byte[] readImageBytes(final InputStreamSupplier supplier) {
        try {
            return readAllBytes(supplier.open());
        } catch (final Exception e) {
            Log.e(TAG, String.format("Reading selected image failed.%s", Exceptions.getStackTraceString(e)));
            Popup.show(requireContext(), getString(R.string.protocol_read_failed));
            return null;
        }
    }

    private byte[] readAllBytes(final InputStream inputStream) throws IOException {
        if (inputStream == null) {
            throw new IOException("Input stream is null");
        }
        try {
            final ByteArrayOutputStream buffer = new ByteArrayOutputStream();
            final byte[] chunk = new byte[8192];
            int read;
            while ((read = inputStream.read(chunk)) != -1) {
                buffer.write(chunk, 0, read);
            }
            return buffer.toByteArray();
        } finally {
            inputStream.close();
        }
    }

    public static String formatMemProtocolStatus(final String inputUrl, final long inputSize,
                                                 final String outputUrl, final long outputSize) {
        return "in " + inputUrl + " (" + humanReadableByteCount(inputSize) + ")"
                + " -> drawtext -> "
                + "out " + outputUrl + " (" + humanReadableByteCount(outputSize) + ")";
    }

    // endregion

}

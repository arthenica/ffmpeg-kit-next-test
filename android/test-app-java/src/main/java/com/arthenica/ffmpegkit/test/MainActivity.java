/*
 * Copyright (c) 2018-2026 Taner Sener
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

import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.View;
import android.widget.HorizontalScrollView;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.activity.EdgeToEdge;
import androidx.activity.SystemBarStyle;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.viewpager2.widget.ViewPager2;

import com.arthenica.ffmpegkit.FFmpegKit;
import com.arthenica.ffmpegkit.FFmpegKitConfig;
import com.arthenica.ffmpegkit.FFmpegSession;
import com.arthenica.ffmpegkit.FFprobeKit;
import com.arthenica.ffmpegkit.FFprobeSession;
import com.arthenica.ffmpegkit.Level;
import com.arthenica.ffmpegkit.Signal;
import com.arthenica.ffmpegkit.util.ResourcesUtil;
import com.arthenica.smartexception.java.Exceptions;

import java.io.File;
import java.io.IOException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;

public class MainActivity extends AppCompatActivity {

    public static final String TAG = "ffmpeg-kit-next-test";

    static {
        Exceptions.registerRootPackage("com.arthenica");
    }

    protected static final Handler handler = new Handler(Looper.getMainLooper());

    @Override
    protected void onCreate(final Bundle savedInstanceState) {
        EdgeToEdge.enable(this, SystemBarStyle.dark(Color.TRANSPARENT));

        super.onCreate(savedInstanceState);

        setContentView(R.layout.activity_main);

        final ViewPager2 viewPager = findViewById(R.id.pager);
        final PagerAdapter pagerAdapter = new PagerAdapter(this, this);
        viewPager.setAdapter(pagerAdapter);
        setupTabs(viewPager, pagerAdapter);

        final View toolbar = findViewById(R.id.toolbar);
        final View rootLayout = findViewById(R.id.rootLayout);
        ViewCompat.setOnApplyWindowInsetsListener(rootLayout, (v, windowInsets) -> {
            final Insets bars = windowInsets.getInsets(
                    WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout());
            toolbar.setPadding(0, bars.top, 0, 0);
            viewPager.setPadding(bars.left, 0, bars.right, bars.bottom);
            return WindowInsetsCompat.CONSUMED;
        });

        try {
            registerApplicationFonts();
            Log.d(TAG, "Application fonts registered.");
        } catch (final IOException e) {
            Log.e(TAG, String.format("Font registration failed.%s.", Exceptions.getStackTraceString(e)));
        }

        Log.d(TAG, "Listing supported camera ids.");
        listSupportedCameraIds();

        FFmpegKitConfig.ignoreSignal(Signal.SIGXCPU);
        FFmpegKitConfig.setLogLevel(Level.AV_LOG_INFO);
    }

    public static void listFFmpegSessions() {
        List<FFmpegSession> ffmpegSessions = FFmpegKit.listSessions();
        Log.d(TAG, "Listing FFmpeg sessions.");
        for (int i = 0; i < ffmpegSessions.size(); i++) {
            FFmpegSession session = ffmpegSessions.get(i);
            Log.d(TAG, String.format("Session %d = id:%d, startTime:%s, duration:%s, state:%s, returnCode:%s.",
                    i,
                    session.getSessionId(),
                    session.getStartTime(),
                    session.getDuration(),
                    session.getState(),
                    session.getReturnCode()));
        }
        Log.d(TAG, "Listed FFmpeg sessions.");
    }

    public static void listFFprobeSessions() {
        List<FFprobeSession> ffprobeSessions = FFprobeKit.listFFprobeSessions();
        Log.d(TAG, "Listing FFprobe sessions.");
        for (int i = 0; i < ffprobeSessions.size(); i++) {
            FFprobeSession session = ffprobeSessions.get(i);
            Log.d(TAG, String.format("Session %d = id:%d, startTime:%s, duration:%s, state:%s, returnCode:%s.",
                    i,
                    session.getSessionId(),
                    session.getStartTime(),
                    session.getDuration(),
                    session.getState(),
                    session.getReturnCode()));
        }
        Log.d(TAG, "Listed FFprobe sessions.");
    }

    public static void addUIAction(final Runnable runnable) {
        handler.post(runnable);
    }

    protected void registerApplicationFonts() throws IOException {
        final File cacheDirectory = getCacheDir();
        final File fontDirectory = new File(cacheDirectory, "fonts");

        boolean fontDirectoryCreated = fontDirectory.mkdirs();
        if (!fontDirectoryCreated) {
            android.util.Log.i(TAG, String.format("Failed to create font directory: %s.", fontDirectory.getAbsolutePath()));
        }

        // SAVE FONTS
        ResourcesUtil.rawResourceToFile(getResources(), R.raw.doppioone_regular, new File(fontDirectory, "doppioone_regular.ttf"));
        ResourcesUtil.rawResourceToFile(getResources(), R.raw.notosansarabic_regular, new File(fontDirectory, "notosansarabic_regular.ttf"));
        ResourcesUtil.rawResourceToFile(getResources(), R.raw.notosanssc_regular, new File(fontDirectory, "notosanssc_regular.ttf"));

        final HashMap<String, String> fontNameMapping = new HashMap<>();
        fontNameMapping.put("MyFontName", "Doppio One");
        FFmpegKitConfig.setFontDirectoryList(this, Arrays.asList(fontDirectory.getAbsolutePath(), "/system/fonts"), fontNameMapping);
        FFmpegKitConfig.setEnvironmentVariable("FFREPORT", String.format("file=%s", new File(cacheDirectory.getAbsolutePath(), "ffreport.txt").getAbsolutePath()));
    }

    protected void listSupportedCameraIds() {
        final List<String> supportedCameraIds = FFmpegKitConfig.getSupportedCameraIds(this);
        if (supportedCameraIds.isEmpty()) {
            android.util.Log.d(MainActivity.TAG, "No supported cameras found.");
        } else {
            for (String supportedCameraId : supportedCameraIds) {
                android.util.Log.d(MainActivity.TAG, "Supported camera detected: " + supportedCameraId);
            }
        }
    }

    static String notNull(final String string, final String valuePrefix) {
        return (string == null) ? "" : String.format("%s%s", valuePrefix, string);
    }

    private void setupTabs(final ViewPager2 viewPager, final PagerAdapter pagerAdapter) {
        final HorizontalScrollView tabScrollView = findViewById(R.id.tabScrollView);
        final LinearLayout tabStrip = findViewById(R.id.tabStrip);
        final float density = getResources().getDisplayMetrics().density;
        final int horizontalPadding = Math.round(24 * density);
        final int minTabWidth = Math.round(88 * density);
        final int selectedColor = ContextCompat.getColor(this, R.color.navigationColor);
        final int unselectedColor = Color.parseColor("#f39c12");

        for (int i = 0; i < pagerAdapter.getItemCount(); i++) {
            final int position = i;
            final TextView tab = new TextView(this);
            tab.setText(pagerAdapter.getPageTitle(position));
            tab.setGravity(android.view.Gravity.CENTER);
            tab.setSingleLine(true);
            tab.setTextColor(unselectedColor);
            tab.setTextSize(14);
            tab.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
            tab.setPadding(horizontalPadding, 0, horizontalPadding, 0);
            tab.setMinWidth(minTabWidth);
            tab.setOnClickListener(v -> viewPager.setCurrentItem(position, true));
            tabStrip.addView(tab, new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.MATCH_PARENT));
        }

        viewPager.registerOnPageChangeCallback(new ViewPager2.OnPageChangeCallback() {
            @Override
            public void onPageSelected(final int position) {
                updateSelectedTab(tabStrip, tabScrollView, position, selectedColor, unselectedColor);
            }
        });
        updateSelectedTab(tabStrip, tabScrollView, 0, selectedColor, unselectedColor);
    }

    private void updateSelectedTab(final LinearLayout tabStrip, final HorizontalScrollView tabScrollView, final int selectedPosition, final int selectedColor, final int unselectedColor) {
        for (int i = 0; i < tabStrip.getChildCount(); i++) {
            final TextView tab = (TextView) tabStrip.getChildAt(i);
            final boolean selected = i == selectedPosition;
            tab.setBackgroundResource(selected ? R.drawable.tab_indicator : 0);
            tab.setTextColor(selected ? selectedColor : unselectedColor);
        }

        final View selectedTab = tabStrip.getChildAt(selectedPosition);
        if (selectedTab != null) {
            selectedTab.post(() -> {
                final int scrollX = selectedTab.getLeft() - ((tabScrollView.getWidth() - selectedTab.getWidth()) / 2);
                tabScrollView.smoothScrollTo(scrollX, 0);
            });
        }
    }

}

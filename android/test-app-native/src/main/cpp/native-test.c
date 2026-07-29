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

/*
 * Native consumer of the ffmpeg-kit-next AAR through its prefab payload. This
 * file links directly against the exported FFmpeg libraries (avutil, avcodec,
 * avformat, avfilter, avdevice) via CMake find_package(ffmpeg-kit-next). It
 * exists to prove that the same AAR that serves the JVM FFmpegKit API also
 * serves a pure native/CMake consumer.
 */

#include <jni.h>
#include <string.h>
#include <sys/stat.h>

#include <android/log.h>
#include <libavformat/avformat.h>
#include <libavdevice/avdevice.h>
#include <libavfilter/avfilter.h>
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
#include <libavutil/imgutils.h>

#define LOG_TAG "ffmpeg-kit-next-native-test"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

/* Encode dimensions/rate for the synthetic clip produced by nativeEncode. */
#define ENC_WIDTH   320
#define ENC_HEIGHT  240
#define ENC_FPS     25
#define ENC_SECONDS 2

static jstring new_string(JNIEnv *env, const char *value) {
    return (*env)->NewStringUTF(env, value);
}

/* ------------------------------------------------------------------ */
/* Check 1: header + link + runtime load                              */
/* ------------------------------------------------------------------ */

JNIEXPORT jstring JNICALL
Java_com_arthenica_ffmpegkit_nativetest_MainActivity_nativeAvVersionInfo(JNIEnv *env, jobject thiz) {
    return new_string(env, av_version_info());
}

JNIEXPORT jstring JNICALL
Java_com_arthenica_ffmpegkit_nativetest_MainActivity_nativeVersionReport(JNIEnv *env, jobject thiz) {
    char report[512];
    snprintf(report, sizeof(report),
             "av_version_info : %s\n"
             "libavutil       : %u.%u.%u\n"
             "libavcodec      : %u.%u.%u\n"
             "libavformat     : %u.%u.%u\n"
             "libavfilter     : %u.%u.%u\n"
             "libavdevice     : %u.%u.%u",
             av_version_info(),
             AV_VERSION_MAJOR(avutil_version()), AV_VERSION_MINOR(avutil_version()), AV_VERSION_MICRO(avutil_version()),
             AV_VERSION_MAJOR(avcodec_version()), AV_VERSION_MINOR(avcodec_version()), AV_VERSION_MICRO(avcodec_version()),
             AV_VERSION_MAJOR(avformat_version()), AV_VERSION_MINOR(avformat_version()), AV_VERSION_MICRO(avformat_version()),
             AV_VERSION_MAJOR(avfilter_version()), AV_VERSION_MINOR(avfilter_version()), AV_VERSION_MICRO(avfilter_version()),
             AV_VERSION_MAJOR(avdevice_version()), AV_VERSION_MINOR(avdevice_version()), AV_VERSION_MICRO(avdevice_version()));
    return new_string(env, report);
}

JNIEXPORT jstring JNICALL
Java_com_arthenica_ffmpegkit_nativetest_MainActivity_nativeConfiguration(JNIEnv *env, jobject thiz) {
    return new_string(env, avcodec_configuration());
}

/* ------------------------------------------------------------------ */
/* Check 2: cross-module symbol resolution via a synthetic lavfi input */
/* ------------------------------------------------------------------ */

JNIEXPORT jstring JNICALL
Java_com_arthenica_ffmpegkit_nativetest_MainActivity_nativeProbe(JNIEnv *env, jobject thiz) {
    char report[1024];
    int offset = 0;
    char err[AV_ERROR_MAX_STRING_SIZE];

    /* The "lavfi" virtual input device is registered by libavdevice. */
    avdevice_register_all();

    const AVInputFormat *lavfi = av_find_input_format("lavfi");
    if (lavfi == NULL) {
        return new_string(env, "FAILED: lavfi input device not available");
    }

    AVFormatContext *fmt = NULL;
    const char *graph = "testsrc=duration=1:size=320x240:rate=1";

    int ret = avformat_open_input(&fmt, graph, lavfi, NULL);
    if (ret < 0) {
        av_strerror(ret, err, sizeof(err));
        snprintf(report, sizeof(report), "FAILED: avformat_open_input: %s", err);
        return new_string(env, report);
    }

    ret = avformat_find_stream_info(fmt, NULL);
    if (ret < 0) {
        av_strerror(ret, err, sizeof(err));
        avformat_close_input(&fmt);
        snprintf(report, sizeof(report), "FAILED: avformat_find_stream_info: %s", err);
        return new_string(env, report);
    }

    offset += snprintf(report + offset, sizeof(report) - offset,
                       "source  : %s\nstreams : %u\n", graph, fmt->nb_streams);

    for (unsigned int i = 0; i < fmt->nb_streams && offset < (int) sizeof(report); i++) {
        AVCodecParameters *par = fmt->streams[i]->codecpar;
        offset += snprintf(report + offset, sizeof(report) - offset,
                           "  #%u %s codec=%s %dx%d pix_fmt=%s\n",
                           i,
                           av_get_media_type_string(par->codec_type),
                           avcodec_get_name(par->codec_id),
                           par->width, par->height,
                           av_get_pix_fmt_name((enum AVPixelFormat) par->format) ? av_get_pix_fmt_name((enum AVPixelFormat) par->format) : "?");
    }

    avformat_close_input(&fmt);

    offset += snprintf(report + offset, sizeof(report) - offset, "OK");
    return new_string(env, report);
}

/* ------------------------------------------------------------------ */
/* Check 3: full synthetic encode + mux to an mp4 file                 */
/* ------------------------------------------------------------------ */

static int write_encoded_packets(AVFormatContext *oc, AVCodecContext *c, AVStream *st, AVFrame *frame, AVPacket *pkt) {
    int ret = avcodec_send_frame(c, frame);
    if (ret < 0) {
        return ret;
    }

    while (ret >= 0) {
        ret = avcodec_receive_packet(c, pkt);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
            return 0;
        } else if (ret < 0) {
            return ret;
        }

        av_packet_rescale_ts(pkt, c->time_base, st->time_base);
        pkt->stream_index = st->index;

        ret = av_interleaved_write_frame(oc, pkt);
        av_packet_unref(pkt);
        if (ret < 0) {
            return ret;
        }
    }

    return 0;
}

JNIEXPORT jstring JNICALL
Java_com_arthenica_ffmpegkit_nativetest_MainActivity_nativeEncode(JNIEnv *env, jobject thiz, jstring output_path) {
    char report[512];
    char err[AV_ERROR_MAX_STRING_SIZE];
    const char *filename = (*env)->GetStringUTFChars(env, output_path, NULL);

    AVFormatContext *oc = NULL;
    AVCodecContext *c = NULL;
    AVStream *st = NULL;
    AVFrame *frame = NULL;
    AVPacket *pkt = NULL;
    const int total_frames = ENC_FPS * ENC_SECONDS;
    int ret;

#define FAIL(msg) do { snprintf(report, sizeof(report), "FAILED: %s", msg); goto end; } while (0)
#define FAIL_AV(prefix, code) do { av_strerror((code), err, sizeof(err)); \
    snprintf(report, sizeof(report), "FAILED: %s: %s", (prefix), err); goto end; } while (0)

    avformat_alloc_output_context2(&oc, NULL, NULL, filename);
    if (oc == NULL) {
        avformat_alloc_output_context2(&oc, NULL, "mp4", filename);
    }
    if (oc == NULL) {
        FAIL("could not allocate output context");
    }

    const AVCodec *codec = avcodec_find_encoder(AV_CODEC_ID_MPEG4);
    if (codec == NULL) {
        FAIL("mpeg4 encoder not found");
    }

    st = avformat_new_stream(oc, NULL);
    if (st == NULL) {
        FAIL("could not allocate stream");
    }

    c = avcodec_alloc_context3(codec);
    if (c == NULL) {
        FAIL("could not allocate codec context");
    }

    c->width = ENC_WIDTH;
    c->height = ENC_HEIGHT;
    c->pix_fmt = AV_PIX_FMT_YUV420P;
    c->time_base = (AVRational) {1, ENC_FPS};
    c->framerate = (AVRational) {ENC_FPS, 1};
    c->gop_size = 12;
    c->bit_rate = 400000;
    st->time_base = c->time_base;

    if (oc->oformat->flags & AVFMT_GLOBALHEADER) {
        c->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    ret = avcodec_open2(c, codec, NULL);
    if (ret < 0) {
        FAIL_AV("avcodec_open2", ret);
    }

    ret = avcodec_parameters_from_context(st->codecpar, c);
    if (ret < 0) {
        FAIL_AV("avcodec_parameters_from_context", ret);
    }

    if (!(oc->oformat->flags & AVFMT_NOFILE)) {
        ret = avio_open(&oc->pb, filename, AVIO_FLAG_WRITE);
        if (ret < 0) {
            FAIL_AV("avio_open", ret);
        }
    }

    ret = avformat_write_header(oc, NULL);
    if (ret < 0) {
        FAIL_AV("avformat_write_header", ret);
    }

    frame = av_frame_alloc();
    if (frame == NULL) {
        FAIL("could not allocate frame");
    }
    frame->format = c->pix_fmt;
    frame->width = c->width;
    frame->height = c->height;
    ret = av_frame_get_buffer(frame, 0);
    if (ret < 0) {
        FAIL_AV("av_frame_get_buffer", ret);
    }

    pkt = av_packet_alloc();
    if (pkt == NULL) {
        FAIL("could not allocate packet");
    }

    for (int i = 0; i < total_frames; i++) {
        ret = av_frame_make_writable(frame);
        if (ret < 0) {
            FAIL_AV("av_frame_make_writable", ret);
        }

        /* Synthetic moving gradient (classic libavcodec encode example). */
        for (int y = 0; y < c->height; y++) {
            for (int x = 0; x < c->width; x++) {
                frame->data[0][y * frame->linesize[0] + x] = x + y + i * 3;
            }
        }
        for (int y = 0; y < c->height / 2; y++) {
            for (int x = 0; x < c->width / 2; x++) {
                frame->data[1][y * frame->linesize[1] + x] = 128 + y + i * 2;
                frame->data[2][y * frame->linesize[2] + x] = 64 + x + i * 5;
            }
        }

        frame->pts = i;

        ret = write_encoded_packets(oc, c, st, frame, pkt);
        if (ret < 0) {
            FAIL_AV("encode", ret);
        }
    }

    /* Flush the encoder. */
    ret = write_encoded_packets(oc, c, st, NULL, pkt);
    if (ret < 0) {
        FAIL_AV("flush", ret);
    }

    ret = av_write_trailer(oc);
    if (ret < 0) {
        FAIL_AV("av_write_trailer", ret);
    }

    {
        struct stat file_stat;
        long file_size = (stat(filename, &file_stat) == 0) ? (long) file_stat.st_size : -1;
        snprintf(report, sizeof(report),
                 "OK: encoded %d frames (%dx%d @ %d fps, mpeg4/mp4)\nfile : %s\nsize : %ld bytes",
                 total_frames, ENC_WIDTH, ENC_HEIGHT, ENC_FPS, filename, file_size);
    }

end:
    if (pkt != NULL) {
        av_packet_free(&pkt);
    }
    if (frame != NULL) {
        av_frame_free(&frame);
    }
    if (c != NULL) {
        avcodec_free_context(&c);
    }
    if (oc != NULL) {
        if (oc->pb != NULL && !(oc->oformat->flags & AVFMT_NOFILE)) {
            avio_closep(&oc->pb);
        }
        avformat_free_context(oc);
    }
    (*env)->ReleaseStringUTFChars(env, output_path, filename);

    return new_string(env, report);

#undef FAIL
#undef FAIL_AV
}

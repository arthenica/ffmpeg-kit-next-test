import React from 'react';
import {ScrollView, Text, TouchableOpacity, View} from 'react-native';
import RNFS from 'react-native-fs';
import {FFmpegKit, FFmpegKitConfig, ReturnCode} from 'ffmpeg-kit-next-react-native';
import {Picker} from '@react-native-picker/picker';
import {styles} from './style';
import {ProgressModal} from "./progress_modal";
import {deleteFile, ffprint, notNull} from './util';
import VideoUtil from "./video-util";

const DAV1D_TEST_DEFAULT_URL = "http://download.opencontent.netflix.com.s3.amazonaws.com/AV1/Sparks/Sparks-5994fps-AV1-10bit-960x540-film-grain-synthesis-854kbps.obu";

export default class OtherTab extends React.Component {
    constructor(props) {
        super(props);

        this.state = {
            selectedTest: 'chromaprint',
            outputText: ''
        };

        this.progressModalReference = React.createRef();
    }

    componentDidMount() {
        this.props.navigation.addListener('focus', (_) => {
            this.clearOutput();
            this.setActive();
        });
    }

    setActive() {
        ffprint("Other Tab Activated");
        FFmpegKitConfig.enableLogCallback(undefined);
        FFmpegKitConfig.enableStatisticsCallback(undefined);
    }

    logCallback = (log) => {
        this.appendOutput(log.getMessage());
    };

    appendOutput(logMessage) {
        this.setState((state) => ({outputText: state.outputText + logMessage}));
    };

    clearOutput() {
        this.setState({outputText: ''});
    }

    runTest = () => {
        this.clearOutput();

        switch (this.state.selectedTest) {
            case "chromaprint":
                this.testChromaprint();
                break;
            case "dav1d":
                this.testDav1d();
                break;
            case "webp":
                this.testWebp();
                break;
            case "libjxl":
                this.testLibjxl();
                break;
            case "zscale":
                this.testZscale();
                break;
            case "vvenc":
                this.testVvenc();
                break;
        }
    }

    testChromaprint() {
        ffprint("Testing 'chromaprint' mutex");

        let audioSampleFile = this.getChromaprintSampleFile();
        deleteFile(audioSampleFile);

        let ffmpegCommand = `-hide_banner -y -f lavfi -i sine=frequency=1000:duration=5 -c:a pcm_s16le ${audioSampleFile}`;

        ffprint(`Creating audio sample with \'${ffmpegCommand}\'.`);

        FFmpegKit.executeAsync(ffmpegCommand, async (session) => {
            const state = FFmpegKitConfig.sessionStateToString(await session.getState());
            const returnCode = await session.getReturnCode();
            const failStackTrace = await session.getFailStackTrace();

            ffprint(`FFmpeg process exited with state ${state} and rc ${returnCode}.${notNull(failStackTrace, "\\n")}`);

            if (ReturnCode.isSuccess(returnCode)) {
                ffprint("AUDIO sample created");

                let chromaprintCommand = `-hide_banner -y -i ${audioSampleFile} -f chromaprint -fp_format 2 ${this.getChromaprintOutputFile()}`;

                ffprint(`Creating audio sample with \'${chromaprintCommand}\'.`);

                FFmpegKit.executeAsync(chromaprintCommand, async (secondSession) => {
                    const secondState = FFmpegKitConfig.sessionStateToString(await secondSession.getState());
                    const secondReturnCode = await secondSession.getReturnCode();
                    const secondFailStackTrace = await secondSession.getFailStackTrace();

                    ffprint(`FFmpeg process exited with state ${secondState} and rc ${secondReturnCode}.${notNull(secondFailStackTrace, "\\n")}`);

                    if (ReturnCode.isSuccess(secondReturnCode)) {
                        ffprint("Testing chromaprint completed successfully.");
                    } else {
                        ffprint("Testing chromaprint failed. Please check logs for the details.");
                    }
                }, log => this.appendOutput(log.getMessage()));

            } else {
                ffprint("Creating AUDIO sample failed. Please check logs for the details.");
            }
        });
    }

    testDav1d() {
        ffprint("Testing decoding 'av1' codec");

        let ffmpegCommand = `-hide_banner -y -i ${DAV1D_TEST_DEFAULT_URL} -c:v mpeg4 ${this.getDav1dOutputFile()}`;

        ffprint(`FFmpeg process started with arguments \'${ffmpegCommand}\'.`);

        FFmpegKit.executeAsync(ffmpegCommand, async (session) => {
            const state = FFmpegKitConfig.sessionStateToString(await session.getState());
            const returnCode = await session.getReturnCode();
            const failStackTrace = await session.getFailStackTrace();

            ffprint(`FFmpeg process exited with state ${state} and rc ${returnCode}.${notNull(failStackTrace, "\\n")}`);
        }, log => {
            this.appendOutput(log.getMessage());
        });
    }

    testWebp() {
        let imagePath = VideoUtil.assetPath(VideoUtil.ASSET_1);
        let outputPath = `${RNFS.CachesDirectoryPath}/video.webp`;

        ffprint("Testing 'webp' codec");

        let ffmpegCommand = `-hide_banner -y -i ${imagePath} ${outputPath}`;

        ffprint(`FFmpeg process started with arguments \'${ffmpegCommand}\'.`);

        FFmpegKit.executeAsync(ffmpegCommand, async (session) => {
            const state = FFmpegKitConfig.sessionStateToString(await session.getState());
            const returnCode = await session.getReturnCode();
            const failStackTrace = await session.getFailStackTrace();

            ffprint(`FFmpeg process exited with state ${state} and rc ${returnCode}.${notNull(failStackTrace, "\\n")}`);

            if (ReturnCode.isSuccess(returnCode)) {
                ffprint("Encode webp completed successfully.");
            } else {
                ffprint("Encode webp failed. Please check logs for the details.");
            }
        }, log => {
            this.appendOutput(log.getMessage());
        });
    }

    testZscale() {
        let videoFile = `${RNFS.CachesDirectoryPath}/video.mp4`;
        let zscaledVideoFile = `${RNFS.CachesDirectoryPath}/video.zscaled.mp4`;

        ffprint("Testing 'zscale' filter with video file created on the Video tab");

        let ffmpegCommand = VideoUtil.generateZscaleVideoScript(videoFile, zscaledVideoFile);

        ffprint(`FFmpeg process started with arguments \'${ffmpegCommand}\'.`);

        FFmpegKit.executeAsync(ffmpegCommand, async (session) => {
            const state = FFmpegKitConfig.sessionStateToString(await session.getState());
            const returnCode = await session.getReturnCode();
            const failStackTrace = await session.getFailStackTrace();

            ffprint(`FFmpeg process exited with state ${state} and rc ${returnCode}.${notNull(failStackTrace, "\\n")}`);

            if (ReturnCode.isSuccess(returnCode)) {
                ffprint("zscale completed successfully.");
            } else {
                ffprint("zscale failed. Please check logs for the details.");
            }
        }, log => {
            this.appendOutput(log.getMessage());
        });
    }

    testLibjxl() {
        let imagePath = VideoUtil.assetPath(VideoUtil.ASSET_1);
        let jxlOutputFile = this.getLibjxlOutputFile();
        let decodedOutputFile = this.getLibjxlDecodedOutputFile();

        deleteFile(jxlOutputFile);
        deleteFile(decodedOutputFile);

        ffprint("Testing 'libjxl' codec");

        let ffmpegCommand = `-hide_banner -y -i ${imagePath} -frames:v 1 -vf format=rgb24,setparams=range=pc:color_primaries=bt709:color_trc=iec61966-2-1:colorspace=gbr -c:v libjxl -distance 1.0 -xyb 1 -update 1 ${jxlOutputFile}`;

        ffprint(`FFmpeg process started with arguments \'${ffmpegCommand}\'.`);

        FFmpegKit.executeAsync(ffmpegCommand, async (session) => {
            const state = FFmpegKitConfig.sessionStateToString(await session.getState());
            const returnCode = await session.getReturnCode();
            const failStackTrace = await session.getFailStackTrace();

            ffprint(`FFmpeg process exited with state ${state} and rc ${returnCode}.${notNull(failStackTrace, "\\n")}`);

            if (ReturnCode.isSuccess(returnCode)) {
                let decodeCommand = `-hide_banner -y -i ${jxlOutputFile} -frames:v 1 -c:v png -update 1 ${decodedOutputFile}`;

                ffprint(`FFmpeg process started with arguments \'${decodeCommand}\'.`);

                FFmpegKit.executeAsync(decodeCommand, async (decodeSession) => {
                    const decodeState = FFmpegKitConfig.sessionStateToString(await decodeSession.getState());
                    const decodeReturnCode = await decodeSession.getReturnCode();
                    const decodeFailStackTrace = await decodeSession.getFailStackTrace();

                    ffprint(`FFmpeg process exited with state ${decodeState} and rc ${decodeReturnCode}.${notNull(decodeFailStackTrace, "\\n")}`);
                }, log => {
                    this.appendOutput(log.getMessage());
                });
            }
        }, log => {
            this.appendOutput(log.getMessage());
        });
    }

    testVvenc() {
        let image1Path = VideoUtil.assetPath(VideoUtil.ASSET_1);
        let image2Path = VideoUtil.assetPath(VideoUtil.ASSET_2);
        let image3Path = VideoUtil.assetPath(VideoUtil.ASSET_3);
        let outputFile = this.getVvencOutputFile();

        deleteFile(outputFile);

        ffprint("Testing 'vvenc' codec");

        let ffmpegCommand = VideoUtil.generateEncodeVideoScriptWithCustomPixelFormat(image1Path, image2Path, image3Path, outputFile, "libvvenc", "yuv420p10le", "-preset faster -qp 32 ");

        ffprint(`FFmpeg process started with arguments \'${ffmpegCommand}\'.`);

        FFmpegKit.executeAsync(ffmpegCommand, async (session) => {
            const state = FFmpegKitConfig.sessionStateToString(await session.getState());
            const returnCode = await session.getReturnCode();
            const failStackTrace = await session.getFailStackTrace();

            ffprint(`FFmpeg process exited with state ${state} and rc ${returnCode}.${notNull(failStackTrace, "\\n")}`);
        }, log => {
            this.appendOutput(log.getMessage());
        });
    }

    getChromaprintSampleFile() {
        return `${RNFS.CachesDirectoryPath}/audio-sample.wav`;
    }

    getDav1dOutputFile() {
        return `${RNFS.CachesDirectoryPath}/video.mp4`;
    }

    getChromaprintOutputFile() {
        return `${RNFS.CachesDirectoryPath}/chromaprint.txt`;
    }

    getLibjxlOutputFile() {
        return `${RNFS.CachesDirectoryPath}/image.jxl`;
    }

    getLibjxlDecodedOutputFile() {
        return `${RNFS.CachesDirectoryPath}/image.jxl.png`;
    }

    getVvencOutputFile() {
        return `${RNFS.CachesDirectoryPath}/video.266`;
    }

    render() {
        return (
            <View style={styles.screenStyle}>
                <View style={styles.headerViewStyle}>
                    <Text
                        style={styles.headerTextStyle}>
                        FFmpegKitNext ReactNative
                    </Text>
                </View>
                <View>
                    <Picker
                        selectedValue={this.state.selectedTest}
                        onValueChange={(itemValue, itemIndex) =>
                            this.setState({selectedTest: itemValue})
                        }>
                        <Picker.Item label="chromaprint" value="chromaprint"/>
                        <Picker.Item label="dav1d" value="dav1d"/>
                        <Picker.Item label="webp" value="webp"/>
                        <Picker.Item label="libjxl" value="libjxl"/>
                        <Picker.Item label="zscale" value="zscale"/>
                        <Picker.Item label="vvenc" value="vvenc"/>
                    </Picker>
                </View>
                <View style={styles.buttonViewStyle}>
                    <TouchableOpacity
                        style={styles.buttonStyle}
                        onPress={this.runTest}>
                        <Text style={styles.buttonTextStyle}>RUN</Text>
                    </TouchableOpacity>
                </View>
                <ProgressModal
                    visible={false}
                    ref={this.progressModalReference}/>
                <View style={styles.outputViewStyle}>
                    <ScrollView
                        ref={(view) => {
                            this.scrollViewReference = view;
                        }}
                        onContentSizeChange={(width, height) => this.scrollViewReference.scrollTo({y: height})}
                        style={styles.outputScrollViewStyle}>
                        <Text style={styles.outputTextStyle}>{this.state.outputText}</Text>
                    </ScrollView>
                </View>
            </View>
        );
    }

}

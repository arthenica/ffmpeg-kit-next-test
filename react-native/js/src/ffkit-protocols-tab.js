import React from 'react';
import {Image, Platform, ScrollView, Text, TextInput, TouchableOpacity, View} from 'react-native';
import RNFS from 'react-native-fs';
import {Picker} from '@react-native-picker/picker';
import {
    FFmpegKit,
    FFmpegKitConfig,
    FFmpegKitInputBuffer,
    FFmpegKitOutputBuffer,
    FFprobeKit,
    ReturnCode
} from 'ffmpeg-kit-next-react-native';
import {styles} from './style';
import {ffprint, notNull} from './util';
import VideoUtil from "./video-util";
import {ProgressModal} from "./progress_modal";

const PROTOCOL_FFKITMEM = "ffkitmem";
const PROTOCOL_FFKITSAF = "ffkitsaf";

/**
 * Escapes overlay text for a single-quoted drawtext `text='...'` value that
 * itself lives inside a double-quoted `-vf` argument. Ported from the Android
 * FFmpegCommands.escapeDrawtextText.
 */
function escapeDrawtextText(text) {
    return text
        .replace(/\\/g, '\\\\')
        .replace(/"/g, '\\"')
        .replace(/'/g, "'\\''");
}

/**
 * Builds the ffkitmem drawtext command. Ported verbatim from the Android
 * FFmpegCommands.buildFFKitMemProtocolCommand.
 */
function buildFFKitMemProtocolCommand(inputUrl, outputUrl, fontPath, text) {
    const drawtext = `drawtext=fontfile=${fontPath}` +
        `:text='${escapeDrawtextText(text)}'` +
        `:x=(w-text_w)/2:y=h-th-40:fontsize=h/15` +
        `:fontcolor=white:box=1:boxcolor=black@0.5`;
    return `-y -i ${inputUrl} -vf "${drawtext}"` +
        ` -frames:v 1 -f image2 -c:v mjpeg ${outputUrl}`;
}

function humanReadableByteCount(bytes) {
    if (bytes < 1024) {
        return `${bytes} B`;
    }
    const kb = bytes / 1024.0;
    if (kb < 1024) {
        return `${kb.toFixed(1)} KB`;
    }
    return `${(kb / 1024.0).toFixed(1)} MB`;
}

export default class FFKitProtocolsTab extends React.Component {
    constructor(props) {
        super(props);

        this.state = {
            selectedProtocol: PROTOCOL_FFKITMEM,
            overlayText: 'FFmpegKitNext',
            outputText: '',
            statusText: 'Select a protocol, then run FFmpeg or FFprobe.',
            resultImage: null
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
        ffprint("FFKitProtocols Tab Activated");
        FFmpegKitConfig.enableLogCallback(this.logCallback);
        FFmpegKitConfig.enableStatisticsCallback(this.statisticsCallback);
    }

    logCallback = (log) => {
        this.appendOutput(log.getMessage());
    };

    statisticsCallback = (statistics) => {
        this.setState({statistics: statistics});
        this.updateProgressDialog();
    };

    // region Dropdown

    changedProtocol = (selectedProtocol) => {
        this.clearOutput();
        this.setState({
            selectedProtocol: selectedProtocol,
            resultImage: null,
            statusText: 'Select a protocol, then run FFmpeg or FFprobe.'
        });
    };

    // endregion

    // region Button dispatch

    runFFmpeg = () => {
        if (this.state.selectedProtocol === PROTOCOL_FFKITSAF) {
            if (Platform.OS !== 'android') {
                this.setState({statusText: 'SAF is only available on Android.'});
                ffprint('SAF is only available on Android.');
                return;
            }
            this.encodeVideoSaf();
        } else {
            this.runFFKitMemFFmpeg();
        }
    };

    runFFprobe = () => {
        if (this.state.selectedProtocol === PROTOCOL_FFKITSAF) {
            if (Platform.OS !== 'android') {
                this.setState({statusText: 'SAF is only available on Android.'});
                ffprint('SAF is only available on Android.');
                return;
            }
            this.runFFprobeSaf();
        } else {
            this.runFFKitMemFFprobe();
        }
    };

    // endregion

    // region ffkitmem protocol

    runFFKitMemFFmpeg = async () => {
        this.clearOutput();
        this.setState({resultImage: null, statusText: 'Running…'});

        const imagePath = VideoUtil.assetPath(VideoUtil.ASSET_1);
        const fontPath = VideoUtil.assetPath(VideoUtil.FONT_ASSET_1);

        try {
            const base64 = await RNFS.readFile(imagePath, 'base64');

            const input = await FFmpegKitInputBuffer.fromBase64(base64, 'jpg');
            const output = await FFmpegKitOutputBuffer.create('jpg');
            const inputUrl = input.getUrl();
            const inputSize = input.getSize();
            const command = buildFFKitMemProtocolCommand(inputUrl, output.getUrl(), fontPath, this.state.overlayText);

            ffprint(`ffkitmem ffmpeg command: ${command}`);

            FFmpegKit.executeAsync(command, async (session) => {
                const returnCode = await session.getReturnCode();
                if (ReturnCode.isSuccess(returnCode)) {
                    const result = await output.toBase64();
                    const outputSize = await output.getSize();
                    this.setState({
                        resultImage: `data:image/jpeg;base64,${result}`,
                        statusText: `in ${inputUrl} (${humanReadableByteCount(inputSize)})` +
                            ` -> drawtext -> ` +
                            `out ${output.getUrl()} (${humanReadableByteCount(outputSize)})`
                    });
                } else {
                    this.setState({resultImage: null, statusText: 'Processing failed.'});
                    ffprint('Processing failed. Please check output for the details.');
                }
                await input.close();
                await output.close();
            });
        } catch (err) {
            this.setState({resultImage: null, statusText: 'Processing failed.'});
            ffprint('Processing failed: ' + err);
        }
    };

    runFFKitMemFFprobe = async () => {
        this.clearOutput();
        this.setState({resultImage: null, statusText: 'Running…'});

        const imagePath = VideoUtil.assetPath(VideoUtil.ASSET_1);

        try {
            const base64 = await RNFS.readFile(imagePath, 'base64');

            const input = await FFmpegKitInputBuffer.fromBase64(base64, 'jpg');
            const inputUrl = input.getUrl();
            const command = `-hide_banner -print_format json -show_format -show_streams ${inputUrl}`;

            ffprint(`ffkitmem ffprobe command: ${command}`);

            FFprobeKit.execute(command).then(async (session) => {
                const returnCode = await session.getReturnCode();
                const output = await session.getOutput();
                this.appendOutput(output ?? '');
                this.setState({statusText: `ffprobe -> ${inputUrl}`});
                if (!ReturnCode.isSuccess(returnCode)) {
                    ffprint('Command failed. Please check output for the details.');
                }
                await input.close();
            });
        } catch (err) {
            ffprint('Command failed: ' + err);
        }
    };

    // endregion

    // region saf protocol (Android only)

    runFFprobeSaf = () => {
        FFmpegKitConfig.selectDocumentForRead('*/*', ['image/*', 'video/*', 'audio/*'])
            .then(uri => {
                FFmpegKitConfig.getSafParameterForRead(uri)
                    .then(safUrl => {
                        this.clearOutput();
                        this.setState({resultImage: null});

                        let ffprobeCommand = `-hide_banner -print_format json -show_format -show_streams ${safUrl}`;

                        ffprint('Testing FFprobe COMMAND asynchronously.');
                        ffprint(`FFprobe process started with arguments: \'${ffprobeCommand}\'.`);

                        FFprobeKit.execute(ffprobeCommand).then(async (session) => {
                            const state = FFmpegKitConfig.sessionStateToString(await session.getState());
                            const returnCode = await session.getReturnCode();
                            const failStackTrace = await session.getFailStackTrace();
                            session.getOutput().then(output => this.appendOutput(output));

                            ffprint(`FFprobe process exited with state ${state} and rc ${returnCode}.${notNull(failStackTrace, "\\n")}`);

                            if (!ReturnCode.isSuccess(returnCode)) {
                                ffprint("Command failed. Please check output for the details.");
                            }
                        });
                    });
            })
            .catch(err => ffprint('Select file failed: ' + err));
    };

    encodeVideoSaf = () => {
        FFmpegKitConfig.selectDocumentForWrite('video.mp4', 'video/*')
            .then(uri => {
                FFmpegKitConfig.getSafParameter(uri, "rw")
                    .then(safUrl => {
                        let image1Path = VideoUtil.assetPath(VideoUtil.ASSET_1);
                        let image2Path = VideoUtil.assetPath(VideoUtil.ASSET_2);
                        let image3Path = VideoUtil.assetPath(VideoUtil.ASSET_3);
                        let videoFile = safUrl;

                        let videoCodec = 'mpeg4';

                        ffprint(`Testing VIDEO encoding with '${videoCodec}' codec`);

                        this.clearOutput();
                        this.setState({resultImage: null});
                        this.hideProgressDialog();
                        this.showProgressDialog();

                        let ffmpegCommand = VideoUtil.generateEncodeVideoScript(image1Path, image2Path, image3Path, videoFile, videoCodec, '');

                        ffprint(`FFmpeg process started with arguments: \'${ffmpegCommand}\'.`);

                        FFmpegKit.executeAsync(ffmpegCommand, async (session) => {
                            const state = FFmpegKitConfig.sessionStateToString(await session.getState());
                            const returnCode = await session.getReturnCode();
                            const failStackTrace = await session.getFailStackTrace();

                            ffprint(`FFmpeg process exited with state ${state} and rc ${returnCode}.${notNull(failStackTrace, "\\n")}`);

                            this.hideProgressDialog();

                            if (ReturnCode.isSuccess(returnCode)) {
                                ffprint(`Encode completed successfully.`);
                            } else {
                                ffprint("Encode failed. Please check log for the details.");
                            }
                        }).then(session => ffprint(`Async FFmpeg process started with sessionId ${session.getSessionId()}.`));
                    });
            })
            .catch(err => ffprint('Select file failed: ' + err));
    };

    // endregion

    // region progress dialog (saf)

    showProgressDialog() {
        // CLEAN STATISTICS
        this.setState({statistics: undefined});
        this.progressModalReference.current.show(`Encoding video`);
    }

    updateProgressDialog() {
        let statistics = this.state.statistics;
        if (statistics === undefined || statistics.getTime() < 0) {
            return;
        }

        let timeInMilliseconds = statistics.getTime();
        let totalVideoDuration = 9000;
        let completePercentage = Math.round((timeInMilliseconds * 100) / totalVideoDuration);
        this.progressModalReference.current.update(`Encoding video % ${completePercentage}`);
    }

    hideProgressDialog() {
        this.progressModalReference.current.hide();
    }

    // endregion

    // region output helpers

    appendOutput(logMessage) {
        this.setState((state) => ({outputText: state.outputText + logMessage}));
    }

    clearOutput() {
        this.setState({outputText: ''});
    }

    // endregion

    render() {
        return (
            <View style={styles.screenStyle}>
                <View style={styles.headerViewStyle}>
                    <Text style={styles.headerTextStyle}>
                        FFmpegKitNext ReactNative
                    </Text>
                </View>
                <View>
                    <Picker
                        selectedValue={this.state.selectedProtocol}
                        onValueChange={(itemValue, itemIndex) =>
                            this.changedProtocol(itemValue)
                        }>
                        <Picker.Item label={PROTOCOL_FFKITMEM} value={PROTOCOL_FFKITMEM}/>
                        <Picker.Item label={PROTOCOL_FFKITSAF} value={PROTOCOL_FFKITSAF}/>
                    </Picker>
                </View>
                <View style={[styles.textInputViewStyle, {paddingTop: 0, paddingBottom: 20}]}>
                    <TextInput
                        style={styles.textInputStyle}
                        autoCapitalize='none'
                        autoCorrect={false}
                        placeholder="Text to draw on the photo"
                        underlineColorAndroid="transparent"
                        onChangeText={(overlayText) => this.setState({overlayText})}
                        value={this.state.overlayText}
                    />
                </View>
                <View style={[styles.buttonViewStyle, {flexDirection: 'row'}]}>
                    <TouchableOpacity
                        style={[styles.buttonStyle, {marginRight: 10}]}
                        onPress={this.runFFmpeg}>
                        <Text style={styles.buttonTextStyle}>RUN FFMPEG</Text>
                    </TouchableOpacity>
                    <TouchableOpacity
                        style={[styles.buttonStyle, {marginLeft: 10}]}
                        onPress={this.runFFprobe}>
                        <Text style={styles.buttonTextStyle}>RUN FFPROBE</Text>
                    </TouchableOpacity>
                </View>
                <ProgressModal
                    visible={false}
                    ref={this.progressModalReference}/>
                <View style={styles.outputViewStyle}>
                    {this.state.resultImage != null
                        ? <Image
                            style={styles.outputImageStyle}
                            resizeMode="contain"
                            source={{uri: this.state.resultImage}}/>
                        : <ScrollView
                            ref={(view) => {
                                this.scrollViewReference = view;
                            }}
                            onContentSizeChange={(width, height) => this.scrollViewReference.scrollTo({y: height})}
                            style={styles.outputScrollViewStyle}>
                            <Text style={styles.outputTextStyle}>{this.state.outputText}</Text>
                        </ScrollView>}
                </View>
                <View style={styles.statusViewStyle}>
                    <Text style={styles.statusTextStyle}>{this.state.statusText}</Text>
                </View>
            </View>
        );
    };

}

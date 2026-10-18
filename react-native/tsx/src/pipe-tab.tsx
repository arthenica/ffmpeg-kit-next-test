import React from 'react';
import {Text, TouchableOpacity, View} from 'react-native';
import RNFS from 'react-native-fs';
import VideoUtil from './video-util';
import {FFmpegKit, FFmpegKitConfig, Log, ReturnCode, Statistics} from 'ffmpeg-kit-next-react-native';
import {styles} from './style';
import {ProgressModal} from "./progress_modal";
import Video, {VideoRef} from 'react-native-video';
import {deleteFile, ffprint, listAllStatistics, notNull} from './util';
import type {TabProps} from './navigation';

type PipeTabProps = TabProps<'PIPE'>;

interface PipeTabState {
    statistics?: Statistics;
    videoVersion: number;
    paused?: boolean;
}

export default class PipeTab extends React.Component<PipeTabProps, PipeTabState> {

    private readonly progressModalReference: React.RefObject<ProgressModal | null>;
    private player: VideoRef | null = null;

    constructor(props: PipeTabProps) {
        super(props);

        this.state = {
            statistics: undefined,
            videoVersion: 0
        };

        this.progressModalReference = React.createRef<ProgressModal>();
    }

    componentDidMount() {
        this.props.navigation.addListener('focus', (_) => {
            this.pause();
            this.setActive();
        });
    }

    setActive() {
        ffprint("Pipe Tab Activated");
        FFmpegKitConfig.enableLogCallback(this.logCallback);
        FFmpegKitConfig.enableStatisticsCallback(this.statisticsCallback);
    }

    logCallback = (log: Log) => {
        ffprint(log.getMessage() as string);
    }

    statisticsCallback = (statistics: Statistics) => {
        this.setState({statistics: statistics});
        this.updateProgressDialog();
    }

    createVideo = () => {
        let videoFile = this.getVideoFile();
        FFmpegKitConfig.registerNewFFmpegPipe().then((pipe1) => {
            FFmpegKitConfig.registerNewFFmpegPipe().then((pipe2) => {
                FFmpegKitConfig.registerNewFFmpegPipe().then(async (pipe3) => {

                    // IF VIDEO IS PLAYING STOP PLAYBACK
                    this.pause();

                    deleteFile(videoFile);

                    const videoCodec = await VideoUtil.packageVideoCodec();

                    ffprint(`Testing PIPE with '${videoCodec}' codec`);

                    this.hideProgressDialog();
                    this.showProgressDialog();

                    let ffmpegCommand = VideoUtil.generateCreateVideoWithPipesScript(pipe1, pipe2, pipe3, videoFile, videoCodec);

                    ffprint(`FFmpeg process started with arguments: \'${ffmpegCommand}\'.`);

                    FFmpegKit.executeAsync(ffmpegCommand, async (session) => {
                            const state = FFmpegKitConfig.sessionStateToString(await session.getState());
                            const returnCode = await session.getReturnCode();
                            const failStackTrace = await session.getFailStackTrace();

                            ffprint(`FFmpeg process exited with state ${state} and rc ${returnCode}.${notNull(failStackTrace, "\\n")}`);

                            this.hideProgressDialog();

                            // CLOSE PIPES
                            FFmpegKitConfig.closeFFmpegPipe(pipe1);
                            FFmpegKitConfig.closeFFmpegPipe(pipe2);
                            FFmpegKitConfig.closeFFmpegPipe(pipe3);

                            if (ReturnCode.isSuccess(returnCode)) {
                                ffprint("Create completed successfully; playing video.");
                                this.playVideo();
                                listAllStatistics(session);
                            } else {
                                ffprint("Create failed. Please check log for the details.");
                            }
                        }
                    );

                    FFmpegKitConfig.writeToPipe(VideoUtil.assetPath(VideoUtil.ASSET_1), pipe1);
                    FFmpegKitConfig.writeToPipe(VideoUtil.assetPath(VideoUtil.ASSET_2), pipe2);
                    FFmpegKitConfig.writeToPipe(VideoUtil.assetPath(VideoUtil.ASSET_3), pipe3);
                });
            });
        });
    }

    playVideo() {
        // REMOUNT THE PLAYER SO IT (RE)LOADS THE SOURCE. THE FILE PATH IS FIXED, SO WITHOUT A NEW
        // KEY react-native-video WOULD NOT RELOAD A SOURCE THAT FAILED TO LOAD AT FIRST RENDER.
        this.setState(previousState => ({
            paused: false, videoVersion: previousState.videoVersion + 1
        }));
    }

    pause() {
        this.setState({paused: true});
    }

    getVideoFile(): string {
        return `${RNFS.CachesDirectoryPath}/video.mp4`;
    }

    showProgressDialog() {
        // CLEAN STATISTICS
        this.setState({statistics: undefined});
        this.progressModalReference.current?.show(`Creating video`);
    }

    updateProgressDialog() {
        let statistics = this.state.statistics;
        if (statistics === undefined || statistics.getTime() < 0) {
            return;
        }

        let timeInMilliseconds = statistics.getTime();
        let totalVideoDuration = 9000;
        let completePercentage = Math.round((timeInMilliseconds * 100) / totalVideoDuration);
        this.progressModalReference.current?.update(`Creating video % ${completePercentage}`);
    }

    hideProgressDialog() {
        this.progressModalReference.current?.hide();
    }

    onPlayError = (err: unknown) => {
        ffprint('Play error: ' + JSON.stringify(err));
    }

    render() {
        return (
            <View style={styles.screenStyle}>
                <View style={styles.headerViewStyle}>
                    <Text style={styles.headerTextStyle}>
                        FFmpegKitNext ReactNative
                    </Text>
                </View>
                <View style={[styles.buttonViewStyle, {paddingTop: 50, paddingBottom: 50}]}>
                    <TouchableOpacity
                        style={styles.buttonStyle}
                        onPress={this.createVideo}>
                        <Text style={styles.buttonTextStyle}>CREATE</Text>
                    </TouchableOpacity>
                </View>
                <ProgressModal
                    visible={false}
                    ref={this.progressModalReference}/>
                <Video key={`video-${this.state.videoVersion}`}
                       source={{uri: this.getVideoFile()}}
                       ref={(ref) => {
                           this.player = ref
                       }}
                       hideShutterView={true}
                       paused={this.state.paused}
                    // onError={this.onPlayError}
                       resizeMode={"stretch"}
                       style={styles.videoPlayerViewStyle}/>
            </View>
        );
    }

}

import React from 'react';
import {ScrollView, Text, TextInput, TouchableOpacity, View} from 'react-native';
import {styles} from './style';
import {ffprint, listFFprobeSessions, notNull} from './util';
import {
    FFmpegKit,
    FFmpegKitConfig,
    FFprobeSession,
    Level,
    LogCallback,
    LogRedirectionStrategy,
    SessionState,
    StatisticsCallback
} from "ffmpeg-kit-next-react-native";
import type {TabProps} from './navigation';

type CommandTabProps = TabProps<'COMMAND'>;

interface CommandTabState {
    commandText: string;
    outputText: string;
}

export default class CommandTab extends React.Component<CommandTabProps, CommandTabState> {

    private scrollViewReference: ScrollView | null = null;

    constructor(props: CommandTabProps) {
        super(props);

        this.state = {
            commandText: '', outputText: ''
        };
    }

    componentDidMount() {
        this.props.navigation.addListener('focus', (_) => {
            this.clearOutput();
            this.setActive();
        });
    }

    setActive() {
        ffprint("Command Tab Activated");
        FFmpegKitConfig.enableLogCallback(undefined as unknown as LogCallback);
        FFmpegKitConfig.enableStatisticsCallback(undefined as unknown as StatisticsCallback);
    }

    appendOutput(logMessage: string) {
        this.setState((state) => ({outputText: state.outputText + logMessage}));
    };

    clearOutput() {
        this.setState({outputText: ''});
    }

    runFFmpeg = () => {
        this.clearOutput();

        let ffmpegCommand = this.state.commandText;

        ffprint(`Current log level is ${Level.levelToString(FFmpegKitConfig.getLogLevel() as unknown as number)}.`);

        ffprint('Testing FFmpeg COMMAND asynchronously.');

        ffprint(`FFmpeg process started with arguments: \'${ffmpegCommand}\'.`);

        FFmpegKit.execute(ffmpegCommand).then(async (session) => {
            const sessionState = await session.getState();
            const state = FFmpegKitConfig.sessionStateToString(sessionState);
            const returnCode = await session.getReturnCode();
            const failStackTrace = await session.getFailStackTrace();
            const output = await session.getOutput();

            ffprint(`FFmpeg process exited with state ${state} and rc ${returnCode}.${notNull(failStackTrace, "\\n")}`);

            this.appendOutput(output);

            if (sessionState === SessionState.FAILED || !returnCode.isValueSuccess()) {
                ffprint("Command failed. Please check output for the details.");
            }
        });
    };

    runFFprobe = () => {
        this.clearOutput();

        let ffprobeCommand = this.state.commandText;

        ffprint('Testing FFprobe COMMAND asynchronously.');

        ffprint(`FFprobe process started with arguments: \'${ffprobeCommand}\'.`);

        FFprobeSession.create(FFmpegKitConfig.parseArguments(ffprobeCommand), async (session) => {
            const sessionState = await session.getState();
            const state = FFmpegKitConfig.sessionStateToString(sessionState);
            const returnCode = await session.getReturnCode();
            const failStackTrace = await session.getFailStackTrace();
            session.getOutput().then(output => this.appendOutput(output));

            ffprint(`FFprobe process exited with state ${state} and rc ${returnCode}.${notNull(failStackTrace, "\\n")}`);

            if (sessionState === SessionState.FAILED || !returnCode.isValueSuccess()) {
                ffprint("Command failed. Please check output for the details.");
            }

        }, undefined, LogRedirectionStrategy.NEVER_PRINT_LOGS).then(session => {
            FFmpegKitConfig.asyncFFprobeExecute(session);

            listFFprobeSessions();
        });
    };

    render() {
        return (<View style={styles.screenStyle}>
            <View style={styles.headerViewStyle}>
                <Text style={styles.headerTextStyle}>
                    FFmpegKitNext ReactNative
                </Text>
            </View>
            <View style={styles.textInputViewStyle}>
                <TextInput
                    style={styles.textInputStyle}
                    autoCapitalize='none'
                    autoCorrect={false}
                    placeholder="Enter command"
                    underlineColorAndroid="transparent"
                    onChangeText={(commandText) => this.setState({commandText})}
                    value={this.state.commandText}
                />
            </View>
            <View style={styles.buttonViewStyle}>
                <TouchableOpacity
                    style={styles.buttonStyle}
                    onPress={this.runFFmpeg}>
                    <Text style={styles.buttonTextStyle}>RUN FFMPEG</Text>
                </TouchableOpacity>
            </View>
            <View style={styles.buttonViewStyle}>
                <TouchableOpacity
                    style={styles.buttonStyle}
                    onPress={this.runFFprobe}>
                    <Text style={styles.buttonTextStyle}>RUN FFPROBE</Text>
                </TouchableOpacity>
            </View>
            <View style={styles.outputViewStyle}>
                <ScrollView
                    ref={(view) => {
                        this.scrollViewReference = view;
                    }}
                    onContentSizeChange={(width, height) => this.scrollViewReference?.scrollTo({y: height})}
                    style={styles.outputScrollViewStyle}>
                    <Text style={styles.outputTextStyle}>{this.state.outputText}</Text>
                </ScrollView>
            </View>
        </View>);
    };

}

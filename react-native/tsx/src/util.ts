import {
    FFmpegKit,
    FFmpegKitConfig,
    FFmpegSession,
    FFprobeKit,
    Level,
    Log,
    Session,
    Statistics
} from "ffmpeg-kit-next-react-native";
import RNFS from 'react-native-fs';
import {Platform} from "react-native";

export function today(): string {
    let now = new Date();
    return `${now.getFullYear()}-${now.getMonth()}-${now.getDate()}`;
}

export function now(): string {
    let now = new Date();
    return `${now.getFullYear()}-${now.getMonth()}-${now.getDate()} ${now.getHours()}:${now.getMinutes()}:${now.getSeconds()}.${now.getMilliseconds()}`;
}

export function ffprint(text: string): void {
    console.log(text.endsWith('\n') ? text.replace('\n', '') : text);
}

export function notNull(string: string | undefined | null, valuePrefix: string): string {
    return (string === undefined || string == null) ? "" : valuePrefix.concat(string);
}

export function listFFprobeSessions(): void {
    FFprobeKit.listFFprobeSessions().then(sessionList => {
        ffprint(`Listing ${sessionList.length} FFprobe sessions asynchronously.`);

        let count = 0;
        sessionList.forEach(async session => {
            const sessionId = session.getSessionId();
            const startTime = session.getStartTime();
            const duration = await session.getDuration();
            const state = FFmpegKitConfig.sessionStateToString(await session.getState());
            const returnCode = await session.getReturnCode();

            ffprint(`Session ${count++} = id:${sessionId}, startTime:${startTime}, duration:${duration}, state:${state}, returnCode:${returnCode}.`);
        });
    });
}

export function listFFmpegSessions(): void {
    FFmpegKit.listSessions().then(sessionList => {
        ffprint(`Listing ${sessionList.length} FFmpeg sessions asynchronously.`);

        let count = 0;
        sessionList.forEach(async session => {
            const sessionId = session.getSessionId();
            const startTime = session.getStartTime();
            const duration = await session.getDuration();
            const state = FFmpegKitConfig.sessionStateToString(await session.getState());
            const returnCode = await session.getReturnCode();

            ffprint(`Session ${count++} = id:${sessionId}, startTime:${startTime}, duration:${duration}, state:${state}, returnCode:${returnCode}.`);
        });
    });
}

export async function registerApplicationFonts(): Promise<void> {
    let fontNameMapping: {[key: string]: string} = {};
    fontNameMapping["MyFontName"] = "Doppio One";
    if (Platform.OS === 'ios') {
        await FFmpegKitConfig.setFontDirectoryList([RNFS.MainBundlePath], fontNameMapping);
    } else {
        await FFmpegKitConfig.setFontDirectoryList([RNFS.CachesDirectoryPath], fontNameMapping);
    }
    await FFmpegKitConfig.setEnvironmentVariable("FFREPORT", "file=" +
        RNFS.CachesDirectoryPath + "/" + today() + "-ffreport.txt");
}

export async function deleteFile(videoFile: string): Promise<void> {
    return RNFS.unlink(videoFile).catch(() => undefined);
}

export async function listAllLogs(session: Session): Promise<void> {
    ffprint(`Listing log entries for session: ${session.getSessionId()}`);
    let allLogs = await session.getAllLogs();
    allLogs.forEach((element: Log) => {
        ffprint(
            `${Level.levelToString(element.getLevel())}:${element.getMessage()}`);
    });
    ffprint(`Listed log entries for session: ${session.getSessionId()}`);
}

export async function listAllStatistics(session: FFmpegSession): Promise<void> {
    ffprint(`Listing statistics entries for session: ${session.getSessionId()}`);
    let allStatistics = await session.getAllStatistics();

    allStatistics.forEach((s: Statistics) => {
        ffprint(
            `${s.getVideoFrameNumber()}:${s.getVideoFps()}:${s.getVideoQuality()}:${s.getSize()}:${s.getTime()}:${s.getBitrate()}:${s.getSpeed()}`);
    });
    ffprint(`Listed statistics entries for session: ${session.getSessionId()}`);
}

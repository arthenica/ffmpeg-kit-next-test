import React from 'react';
import {LogBox} from 'react-native';
import {NavigationContainer} from '@react-navigation/native';
import {SafeAreaProvider, SafeAreaView} from 'react-native-safe-area-context';
import CommandTab from './command-tab'
import VideoTab from './video-tab'
import VideoUtil from "./video-util";
import Test from "./test-api";
import HttpsTab from "./https-tab";
import AudioTab from "./audio-tab";
import SubtitleTab from "./subtitle-tab";
import PipeTab from "./pipe-tab";
import VidStabTab from "./vid-stab-tab";
import ConcurrentExecutionTab from "./concurrent-execution-tab";
import FFKitProtocolsTab from "./ffkit-protocols-tab";
import OtherTab from "./other-tab";

import {createMaterialTopTabNavigator} from '@react-navigation/material-top-tabs';
import {registerApplicationFonts} from "./util";
import {FFmpegKitConfig} from "ffmpeg-kit-next-react-native";

LogBox.ignoreLogs([
    'ViewPropTypes will be removed from React Native. Migrate to ViewPropTypes exported from \'deprecated-react-native-prop-types\'.'
])

const Tab = createMaterialTopTabNavigator();

function BottomTabs() {
    return (
        <Tab.Navigator
            initialRouteName="COMMAND"
            tabBarPosition='bottom'
            screenOptions={{
                tabBarActiveTintColor: "dodgerblue",
                tabBarInactiveTintColor: "gray",
                tabBarShowIcon: false,
                tabBarScrollEnabled: true,
                tabBarLabelStyle: {
                    fontSize: 14,
                    fontWeight: "600",
                    textAlign: "center",
                    flex: 1,
                    height: 20
                },
                lazy: false
            }}>

            <Tab.Screen
                name="COMMAND"
                component={CommandTab}
                options={{
                    tabBarLabel: 'COMMAND'
                }}
            />
            <Tab.Screen
                name="VIDEO"
                component={VideoTab}
                options={{
                    tabBarLabel: 'VIDEO'
                }}
            />
            <Tab.Screen
                name="HTTPS"
                component={HttpsTab}
                options={{
                    tabBarLabel: 'HTTPS'
                }}
            />
            <Tab.Screen
                name="AUDIO"
                component={AudioTab}
                options={{
                    tabBarLabel: 'AUDIO'
                }}
            />
            <Tab.Screen
                name="SUBTITLE"
                component={SubtitleTab}
                options={{
                    tabBarLabel: 'SUBTITLE'
                }}
            />
            <Tab.Screen
                name="VID.STAB"
                component={VidStabTab}
                options={{
                    tabBarLabel: 'VID.STAB'
                }}
            />
            <Tab.Screen
                name="PIPE"
                component={PipeTab}
                options={{
                    tabBarLabel: 'PIPE'
                }}
            />
            <Tab.Screen
                name="CONCURRENT EXECUTION"
                component={ConcurrentExecutionTab}
                options={{
                    tabBarLabel: 'CONCURRENT EXECUTION'
                }}
            />
            <Tab.Screen
                name="FFKIT PROTOCOLS"
                component={FFKitProtocolsTab}
                options={{
                    tabBarLabel: 'FFKIT PROTOCOLS'
                }}
            />
            <Tab.Screen
                name="OTHER"
                component={OtherTab}
                options={{
                    tabBarLabel: 'OTHER'
                }}
            />
        </Tab.Navigator>
    );
}

export default class Main extends React.Component {
    constructor(props) {
        super(props);

        FFmpegKitConfig.init().then(() => {
            VideoUtil.prepareAssets();
            registerApplicationFonts();

            Test.testCommonApiMethods();
            Test.testParseArguments();
            Test.getSupportedCameraIdsTest();
            Test.setSessionHistorySizeTest();
        });
    }

    render() {
        return (
            <SafeAreaProvider>
                <SafeAreaView edges={['top']} style={{flex: 1, backgroundColor: '#F46842'}}>
                    <NavigationContainer>
                        <BottomTabs/>
                    </NavigationContainer>
                </SafeAreaView>
            </SafeAreaProvider>
        );
    }
}

import type {MaterialTopTabScreenProps} from '@react-navigation/material-top-tabs';

/**
 * Routes registered by the bottom tab navigator in `main.tsx`. None of them
 * takes parameters.
 */
export type TabParamList = {
    'COMMAND': undefined;
    'VIDEO': undefined;
    'HTTPS': undefined;
    'AUDIO': undefined;
    'SUBTITLE': undefined;
    'VID.STAB': undefined;
    'PIPE': undefined;
    'CONCURRENT EXECUTION': undefined;
    'FFKIT PROTOCOLS': undefined;
    'OTHER': undefined;
};

export type TabProps<RouteName extends keyof TabParamList> = MaterialTopTabScreenProps<TabParamList, RouteName>;

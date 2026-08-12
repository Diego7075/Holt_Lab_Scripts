%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PTB screen detection and VIEWPixx timing check
% This script has two independent sections:
%
% 1. Screen detection:
%    Opens each screen detected by PTB and displays its PTB screen  number
%    This allows the user to identify which physical monitor
%    corresponds to each PTB screen index
%
% 2. VIEWPixx timing check:clc

%    Opens the selected VIEWPixx screen, reports its resolution, measures
%    the inter-frame interval (IFI), and estimates the refresh rate
%
% Expected VIEWPixx settings:
% Resolution: 1920 × 1080
% Refresh rate: 120 Hz
% Background: gray [128 128 128]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

sca;
clear; 
clc;

% Sets common PTB defaults
PsychDefaultSetup(2);

% Checks if monitor timing is reliable. PTB checks if refresh timing, frame stability, windows interference, sampling rate, etc
% 0 = PTB does the checkings (keep it at 0 during experiments)
% 1 = PTB skips checking (keep it at 1 when debugging)
Screen('Preference', 'SkipSyncTests', 0);

% Changes how much visual junk PTB displays
% 0 = almost nothing shown, clean fullscreen startup (keep it at 0 for experiments)
% 1-3 = increase amount of debugging information
Screen('Preference', 'VisualDebugLevel', 0);

% Lists all screens currently detected by PTB
screens = Screen('Screens');

% Removes PTB screen 0 from the identification test
screens = screens(screens ~= 0);

for i = 1:length(screens)

    % Gets one PTB screen number and its screen rectangle
    screenNumber = screens(i);
    rect = Screen('Rect', screenNumber);

    fprintf('PTB screen %d rect: [%d %d %d %d]\n', ...
        screenNumber, rect(1), rect(2), rect(3), rect(4));

    % Opens the screen and displays its PTB screen number
    [window, ~] = Screen('OpenWindow', screenNumber, [0 0 0]);

    Screen('TextSize', window, 120);
    Screen('TextFont', window, 'Arial');

    msg = sprintf('PTB SCREEN %d', screenNumber);
    DrawFormattedText(window, msg, 'center', 'center', [255 255 255]);

    Screen('Flip', window);
    WaitSecs(5);

    sca;
    WaitSecs(1);

end

%% This is to check screen resolution and sampling rate in ViewPixx
% Ideal resolution: 1920 x 1080
% Ideal sampling rate: 120 Hz
% screenNumber = 2 (ViewSonic/VIEWPixx duplicated pair)
% Ideal color: gray [128 128 128]

sca;
clear; 
clc;

% Sets common PTB defaults
PsychDefaultSetup(2);

% Checks if monitor timing is reliable. PTB checks if refresh timing, frame stability, windows interference, sampling rate, etc
% 0 = PTB does the checkings (keep it at 0 during experiments)
% 1 = PTB skips checking (keep it at 1 when debugging)
Screen('Preference', 'SkipSyncTests', 0);

% Changes how much visual junk PTB displays
% 0 = almost nothing shown, clean fullscreen startup (keep it at 0 for experiments)
% 1-3 = increase amount of debugging information
Screen('Preference', 'VisualDebugLevel', 0);

% ViewSonic/VIEWPixx duplicated pair in current Windows/PTB layout
screenNumber = 2;

% Opens the VIEWPixx screen with a gray background
[window, rect] = Screen('OpenWindow', screenNumber, [128 128 128]);

fprintf('Screen rect: [%d %d %d %d]\n', rect(1), rect(2), rect(3), rect(4));

% Measures the duration of one monitor refresh
ifi = Screen('GetFlipInterval', window);

fprintf('IFI = %.6f sec\n', ifi);
fprintf('Refresh = %.2f Hz\n', 1/ifi);

WaitSecs(20);

sca;


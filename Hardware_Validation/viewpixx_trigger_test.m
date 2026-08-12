%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Trigger transmission test for BrainVision Recorder 2 using VIEWPixx Pixel
% Mode. This script sequentially displays predefined RGB trigger codes in
% the top-left screen pixel, allowing VIEWPixx to convert them into TTL
% pulses for validating trigger detection and recording during EEG
% acquisition
%
% Sequence:
% Stimulus computer -> ViewPixx EEG screen -> ActiCHamp amplifier -> Recording computer
%
% Each frame is assembled in PTB's back buffer and becomes visible only
% after Screen('Flip'). The trigger region is drawn over a background 
% texture before every screen refresh
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

sca;
clear; clc;

% VIEWPixx/VierSonic in current Windows/PTB layout
screenNumber = 2;

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

% Enables the Windows workaround for inaccurate screen timing queries
Screen('Preference', 'ConserveVRAM', 4096);

% Connect Matlab to ViewPixx
Datapixx('Open');

% Turns on Pixel Mode: allows ViewPixx to read the top left pixel and convert its RGB into TTL
Datapixx('EnablePixelMode');
Datapixx('RegWrRd');

% Opens a full-screen PTB window on the VIEWPixx
[window, ~] = Screen('OpenWindow', screenNumber, [128 128 128]);
disp(Screen('Rect', screenNumber));

% Makes RGB values use the 0–255 scale instead of 0–1
Screen('ColorRange', window, 255);

% Colors set
testColors = [
    15 0 0      % nothing
    31 0 0      % A1
    47 0 0      % B1
    63 0 0      % A1 + B1
    79 0 0      % C1
    95 0 0      % A1 + C1
    111 0 0     % B1 + C1
    127 0 0     % A1 + B1 + C1
    143 0 0     % D1
    159 0 0     % A1 + D1
    175 0 0     % B1 + D1
    191 0 0     % A1 + B1 + D1
    207 0 0     % C1 + D1
    223 0 0     % A1 + C1 + D1
    239 0 0     % B1 + C1 + D1
    255 0 0     % A1 + B1 + C1 + D1
    0 15 0      % nothing
    0 31 0      % E1
    0 47 0      % F1
    0 63 0      % E1 + F1
    0 79 0      % G1
    0 95 0      % E1 + G1
    0 111 0     % F1 + G1
    0 127 0     % E1 + F1 + G1
    0 143 0     % H1
    0 159 0     % E1 + H1
    0 175 0     % F1 + H1
    0 191 0     % E1 + F1 + H1
    0 207 0     % G1 + H1
    0 223 0     % E1 + G1 + H1
    0 239 0     % F1 + G1 + H1
    0 255 0     % E1 + F1 + G1 + H1
    0 0 15      % nothing
    0 0 31      % nothing
    0 0 47      % nothing
    0 0 63      % nothing
    0 0 79      % nothing
    0 0 95      % nothing
    0 0 111     % nothing
    0 0 127     % nothing
    0 0 143     % nothing
    0 0 159     % nothing
    0 0 175     % nothing
    0 0 191     % nothing
    0 0 207     % nothing
    0 0 223     % nothing
    0 0 239     % nothing
    0 0 255     % nothing
];

% Creates the background image. In a real experiment this could be replaced by any visual stimulus
img = zeros(1080, 1920, 3, 'uint8');
background = uint8([128 128 128]);

% Fills the image with the background color (in this case, gray [128 128 128])
img(:,:,1) = background(1);
img(:,:,2) = background(2);
img(:,:,3) = background(3);

% Converts the MATLAB image into a texture. This is done once before the experiment starts, and reused on every frame
backgroundTexture = Screen('MakeTexture', window, img);

% These are the trigger shapes drawn over the background texture. In PTB, shapes are always defined as [left top right bottom]
triggerPixel = [0 0 1 1];
triggerSquare = [0 0 40 40];

try
    for k = 1:size(testColors,1)

        % First screen
        % Draws the background and a 1×1 black pixel (no trigger)
        Screen('DrawTexture', window, backgroundTexture);
        Screen('FillRect', window, [0 0 0], triggerPixel);
        Screen('Flip', window);      
        WaitSecs(1);

        % Second screen
        % Takes one trigger color from the testColors list at a time
        rgb = uint8(testColors(k,:));
        fprintf('Testing trigger pixel RGB [%d %d %d]\n', rgb(1), rgb(2), rgb(3));
        
        % Draws the background and the trigger region
        Screen('DrawTexture', window, backgroundTexture);
        Screen('FillRect', window, rgb, triggerSquare);
        Screen('Flip', window);
        WaitSecs(1);

        % Third screen
        % Draws the background and returns the trigger pixel to black
        Screen('DrawTexture', window, backgroundTexture);
        Screen('FillRect', window, [0 0 0], triggerPixel);
        Screen('Flip', window);
        WaitSecs(1);

    end

    Datapixx('DisablePixelMode');
    Datapixx('RegWrRd');
    Datapixx('Close');
    sca;

catch ME
    sca;
    try
        Datapixx('DisablePixelMode');
        Datapixx('RegWrRd');
        Datapixx('Close');
    catch
    end
    rethrow(ME);
end


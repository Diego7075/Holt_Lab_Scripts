%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Audio-visual timing validation for EEG acquisition using VIEWPixx Pixel
% Mode. Each trial presents a synchronized visual trigger and auditory beep
% to verify the temporal alignment between digital trigger events and the
% recorded audio signal
%
% Sequence:
% Visual: 
% Stimulus computer -> ViewPixx EEG screen -> ActiCHamp amplifier -> Recording computer
% Audio :
% Stimulus computer -> Acoustic adapter/Headphones -> StimTrak -> ActiCHamp amplifier -> Recording computer
%
% Each frame is assembled in PTB's back buffer and becomes visible only
% after Screen('Flip'). The trigger region is drawn over a background 
% texture before every screen refresh
% 
% Trial sequence:
% 1. Gray screen with a 1×1 black pixel for 1.0 s
% 2. Gray screen with a 5×5 RGB trigger and synchronized beep for 100 ms
% 3. Gray screen with a 1×1 black pixel for 1.0 s
%
% The audio and visual stimulus are scheduled using the same target time,
% ensuring that both occur on the same video refresh.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

sca;
clear; 
clc;

% VIEWPixx in current Windows/PTB layout
screenNumber = 3;

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

% Disables some Windows optimizations that can interfere with precise timing
Screen('Preference', 'ConserveVRAM', 16384);

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
triggerRGB = [143 0 0];

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
triggerSquare = [0 0 5 5];

% Enables sound in PTB and load file
InitializePsychSound(1);
wav_file = 'C:\Users\HoltLabUsers\Scripts\timing_test.wav';
[beep, fs] = audioread(wav_file);

% PsychPortAudio expects channels x samples
beep = beep';

% If mono, duplicate to stereo
if size(beep,1) == 1
    beep = [beep; beep];
end
nrchannels = size(beep,1);

% Time control
nTrials = 50;
preWait = 1.0;
pulseDur = 0.10;
postWait = 1.0;

% Measures the duration of one monitor refresh with the inter-frame interval (IFI). Used to schedule future screen updates
ifi = Screen('GetFlipInterval', window);

try 
    
    % Opens the audio device and loads the beep into memory
    pahandle = PsychPortAudio('Open', [], 1, 1, fs, nrchannels);
    PsychPortAudio('FillBuffer', pahandle, beep);
    
    % Displays an initial idle screen before the experiment starts
    Screen('DrawTexture', window, backgroundTexture);
    Screen('FillRect', window, [0 0 0], triggerPixel);
    vbl = Screen('Flip', window);
    
    for trial = 1:nTrials
    
        fprintf('Trial %d/%d: visual RGB [143 0 0] + beep\n', trial, nTrials);
    
        % First screen
        % Draws the background and a 1×1 black pixel (no trigger), and displays the frame after the pre-stimulus waiting period
        Screen('DrawTexture', window, backgroundTexture);
        Screen('FillRect', window, [0 0 0], triggerPixel);

        % Displays the frame after the pre-stimulus waiting period
        vbl = Screen('Flip', window, vbl + preWait - 0.5*ifi);

        % Second screen
        % Draws the background and the trigger region
        Screen('DrawTexture', window, backgroundTexture);
        Screen('FillRect', window, triggerRGB, triggerSquare);
    
        % Schedules the audio and visual stimulus to occur on the same video frame
        targetTime = vbl + preWait;
        PsychPortAudio('Start', pahandle, 1, targetTime, 0);

        % Displays the frame at the scheduled time
        vbl = Screen('Flip', window, targetTime - 0.5*ifi);

        % Third screen
        % Draws the background and returns the trigger pixel to black
        Screen('DrawTexture', window, backgroundTexture);
        Screen('FillRect', window, [0 0 0], triggerPixel);

        % Displays the frame after the trigger duration has elapsed
        vbl = Screen('Flip', window, vbl + pulseDur - 0.5*ifi);

        WaitSecs(postWait);
    end

    PsychPortAudio('Close', pahandle);
    sca;

    Datapixx('DisablePixelMode');
    Datapixx('RegWrRd');
    Datapixx('Close');

catch ME
    try
        PsychPortAudio('Close');
    catch
    end

    sca;

    try
        Datapixx('DisablePixelMode');
        Datapixx('RegWrRd');
        Datapixx('Close');
    catch
    end

    rethrow(ME);
end
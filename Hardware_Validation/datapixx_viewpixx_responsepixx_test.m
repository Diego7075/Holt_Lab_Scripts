%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DATAPixx3 + VIEWPixx EEG + RESPONSEPixx validation
%
% This script validates the visual stimulation and response pathway
% involving the DATAPixx3, VIEWPixx EEG, and the RESPONSEPixx controllers
% (VPX-ACC-3100 Handheld and VPX-ACC-3000 Dual Handheld), actiCHamp Plus 
% amplifier, and BrainVision Recorder 2
%
% During each trial, a colored circle appears on the VIEWPixx EEG while the
% matching RESPONSEPixx button is illuminated. A 5 x 5 Pixel Mode trigger
% region simultaneously presents the trigger code assigned to that color
%
% The participant must press the illuminated button. After the correct
% response, the LED and colored circle are turned off, and the same Pixel
% Mode trigger is presented again to mark deactivation. Button press and
% release timestamps are displayed relative to the beginning of the script
%
% Each trigger remains visible for five consecutive display frames. The
% connected RESPONSEPixx controller is selected at startup, and every
% available button is validated twice in randomized order.
%
% Before running:
% - Connect the DATAPixx3 to the Stimulus Computer through USB
% - Connect the graphics card to DATAPixx3 Video In 1
% - Connect DATAPixx3 Video Out 1 to the VIEWPixx EEG
% - Connect the RESPONSEPixx to DATAPixx3 Digital IN
% - Connect the VIEWPixx EEG DB25 trigger output to the actiCHamp Plus
%   Trigger In connector
% - Open BrainVision Recorder 2 to verify the Pixel Mode trigger markers
%
% Expected behavior:
% - A colored circle appears and the matching RESPONSEPixx LED illuminates
% - Recorder 2 receives the trigger assigned to that color
% - The script waits until the illuminated button is pressed
% - The LED and circle turn off after the correct response
% - Recorder 2 receives the same trigger again to mark deactivation
% - Button press and release timestamps appear in the MATLAB Command Window
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

sca;
clear;
clc;

% VIEWPixx/ViewSonic in current Windows/PTB layout
screenNumber = 2;

% Number of successful trials required for each RESPONSEPixx button
nPresses = 2;

% Number of consecutive display frames used for each Pixel Mode trigger
triggerFrames = 5;

% Displays button release events in the MATLAB Command Window
showReleaseEvents = true;

% Duration of the interstimulus interval between validation trials (s)
isi = 1.0;

% Visual configuration
backgroundColor = uint8([128 128 128]);
cueDiameter = 250;

% Pixel Mode uses a 5 x 5 region in the upper-left corner
triggerSquare = [0 0 5 5];
triggerBaseline = [0 0 0];


% Select RESPONSEPixx controller
disp(' ');
disp('RESPONSEPixx controller');
disp('1 - Handheld (VPX-ACC-3100, 5 buttons)');
disp('2 - Dual Handheld (VPX-ACC-3000, 4 buttons)');
controller = input('Select controller: ');

switch controller
    case 1
        buttonNames = {'Green','Yellow','Red','Blue','White'};
        buttonInputs = [hex2dec('FFFB'),hex2dec('FFFD'),hex2dec('FFFE'),hex2dec('FFF7'),hex2dec('FFEF')];
        ledOutputs = [hex2dec('00040000'),hex2dec('00020000'),hex2dec('00010000'),hex2dec('00080000'),hex2dec('00100000')];
        cueColors = [0 255 0;255 255 0;255 0 0;0 0 255;255 255 255];
        pixelTriggerColors = [31 0 0;47 0 0;79 0 0;143 0 0;0 31 0];
        releaseState = hex2dec('FFFF');
        useMask = false;

    case 2
        buttonNames = {'Yellow','Green','Blue','Red'};
        buttonInputs = [hex2dec('000D'),hex2dec('000B'),hex2dec('0007'),hex2dec('000E')];
        ledOutputs = [hex2dec('00020000'),hex2dec('00040000'),hex2dec('00080000'),hex2dec('00010000')];
        cueColors = [255 255 0;0 255 0;0 0 255;255 0 0];
        pixelTriggerColors = [31 0 0;47 0 0;79 0 0;143 0 0];
        releaseState = hex2dec('000F');
        useMask = true;

    otherwise
        error('Invalid controller selection.');
end

validationOrder = repelem(1:length(buttonNames),nPresses);
validationOrder = validationOrder(randperm(numel(validationOrder)));

PsychDefaultSetup(2);
AssertOpenGL;

% Keeps PTB timing checks enabled for laboratory validation
Screen('Preference','SkipSyncTests',0);
Screen('Preference','VisualDebugLevel',0);

% Enables the Windows workaround for inaccurate screen timing queries
Screen('Preference', 'ConserveVRAM', 4096);

KbName('UnifyKeyNames');
escapeKey = KbName('ESCAPE');

try

    % Opens communication with the DATAPixx3 and clears active schedules
    Datapixx('Open');
    Datapixx('StopAllSchedules');
    Datapixx('RegWrRd');

    % Defines the time origin used for RESPONSEPixx timestamps
    timeZero = Datapixx('GetTime');

    % Enables VIEWPixx EEG Pixel Mode
    Datapixx('EnablePixelMode');

    % Configures Digital IN bits 16-20 as outputs for the RESPONSEPixx LEDs
    Datapixx('SetDinDataDirection',hex2dec('1F0000'));

    % Debouncing ensures that each physical press and release is logged as
    % one stable event
    Datapixx('EnableDinDebounce');

    % Creates and starts the RESPONSEPixx digital input event log
    Datapixx('SetDinLog');
    Datapixx('StartDinLog');
    Datapixx('RegWrRd');

    % Opens the VIEWPixx EEG and uses the standard 0-255 RGB range
    [window,windowRect] = Screen('OpenWindow',screenNumber,backgroundColor);
    Screen('ColorRange',window,255);

    % Defines a centered circular cue
    [xCenter,yCenter] = RectCenter(windowRect);
    cueRect = CenterRectOnPointd( ...
        [0 0 cueDiameter cueDiameter],xCenter,yCenter);

    % Creates one reusable gray background texture
    img = zeros(windowRect(4),windowRect(3),3,'uint8');
    img(:,:,1) = backgroundColor(1);
    img(:,:,2) = backgroundColor(2);
    img(:,:,3) = backgroundColor(3);
    backgroundTexture = Screen('MakeTexture',window,img);

    % Places the display and Pixel Mode trigger region at baseline
    Screen('DrawTexture',window,backgroundTexture);
    Screen('FillRect',window,triggerBaseline,triggerSquare);
    Screen('Flip',window);

    % Keeps the baseline visible before the first validation trial
    WaitSecs(1.0);

    % Clears any button events that occurred during initialization
    Datapixx('SetDinLog');
    Datapixx('RegWrRd');

    fprintf('Press the illuminated RESPONSEPixx button\n');
    fprintf('Press ESC on the keyboard to exit\n');

    for trial = 1:numel(validationOrder)

        % Selects the color and button assigned to the current trial
        expectedButton = validationOrder(trial);
        expectedName = buttonNames{expectedButton};
        expectedLED = ledOutputs(expectedButton);
        expectedCueColor = cueColors(expectedButton,:);
        expectedPixelTrigger = pixelTriggerColors(expectedButton,:);

        fprintf('\n----------------------------------------\n');
        fprintf('Trial %d of %d\n',trial,numel(validationOrder));
        fprintf('Waiting for %s button...\n',expectedName);
        fprintf('----------------------------------------\n');

        % Clears past RESPONSEPixx events before presenting the new cue
        Datapixx('SetDinLog');
        Datapixx('RegWrRd');

        % Illuminates the RESPONSEPixx button assigned to the current trial
        Datapixx('SetDinDataOut',expectedLED);
        Datapixx('RegWrRd');

        % Presents the colored cue and Pixel Mode trigger for five
        % consecutive display frames
        for frame = 1:triggerFrames
            Screen('DrawTexture',window,backgroundTexture);
            Screen('FillOval',window,expectedCueColor,cueRect);
            Screen('FillRect',window,expectedPixelTrigger,triggerSquare);
            Screen('Flip',window);
        end

        % Keeps the colored cue visible while returning the Pixel Mode
        % region to black
        Screen('DrawTexture',window,backgroundTexture);
        Screen('FillOval',window,expectedCueColor,cueRect);
        Screen('FillRect',window,triggerBaseline,triggerSquare);
        Screen('Flip',window);

        % Waits until the correct RESPONSEPixx button is pressed
        while true

            Datapixx('RegWrRd');
            buttonLogStatus = Datapixx('GetDinStatus');

            if buttonLogStatus.newLogFrames > 0

                % Reads the newest button event and its DATAPixx timestamp
                [data,timetags] = Datapixx('ReadDinLog');

                % FFFF indicates that all RESPONSEPixx buttons are released
                if useMask
                    currentState = bitand(uint16(data(1)),uint16(hex2dec('000F')));
                else
                    currentState = uint16(data(1));
                end
                
                if currentState == releaseState

                    if showReleaseEvents
                        fprintf('Released          %.6f s\n', ...
                            timetags(1)-timeZero);
                    end

                    Datapixx('SetDinLog');
                    Datapixx('RegWrRd');
                    continue

                end

                % Identifies which RESPONSEPixx button generated the event
                pressedButton = find(buttonInputs == currentState,1);

                if isempty(pressedButton)

                    fprintf('Unknown state (%04X)\n',data(1));

                    Datapixx('SetDinLog');
                    Datapixx('RegWrRd');
                    continue

                end

                % Accepts the response only when it matches the illuminated
                % button
                if pressedButton == expectedButton

                    fprintf('%s pressed      %.6f s\n', ...
                        expectedName,timetags(1)-timeZero);

                    % Turns off the RESPONSEPixx LED
                    Datapixx('SetDinDataOut',0);
                    Datapixx('RegWrRd');

                    % Presents the same Pixel Mode code for five frames to
                    % mark cue and LED deactivation in Recorder 2
                    for frame = 1:triggerFrames
                        Screen('DrawTexture',window,backgroundTexture);
                        Screen('FillRect',window, ...
                            expectedPixelTrigger,triggerSquare);
                        Screen('Flip',window);
                    end

                    % Returns the complete display to baseline
                    Screen('DrawTexture',window,backgroundTexture);
                    Screen('FillRect',window,triggerBaseline,triggerSquare);
                    Screen('Flip',window);

                    % Clears the press event before waiting for its release
                    Datapixx('SetDinLog');
                    Datapixx('RegWrRd');

                    % Keeps the current trial active until the participant
                    % releases the validated button
                    while true

                        Datapixx('RegWrRd');
                        releaseStatus = Datapixx('GetDinStatus');

                        if releaseStatus.newLogFrames > 0

                            [releaseData,releaseTime] = ...
                                Datapixx('ReadDinLog');

                            if useMask
                                releaseCurrentState = bitand(uint16(releaseData(1)),uint16(hex2dec('000F')));
                            else
                                releaseCurrentState = uint16(releaseData(1));
                            end
                            
                            if releaseCurrentState == releaseState

                                if showReleaseEvents
                                    fprintf('Released         %.6f s\n', ...
                                        releaseTime(1)-timeZero);
                                end

                                Datapixx('SetDinLog');
                                Datapixx('RegWrRd');
                                break

                            end

                            Datapixx('SetDinLog');
                            Datapixx('RegWrRd');

                        end

                        % Allows the script to end safely while waiting for
                        % the validated button to be released
                        [keyIsDown,~,keyCode] = KbCheck;

                        if keyIsDown && keyCode(escapeKey)
                            error('Validation terminated by the user');
                        end

                        WaitSecs(0.001);

                    end

                    % Keeps the baseline visible during the fixed ISI
                    Screen('DrawTexture',window,backgroundTexture);
                    Screen('FillRect',window,triggerBaseline,triggerSquare);
                    Screen('Flip',window);

                    WaitSecs(isi);

                    % Clears any button events accumulated during the ISI
                    Datapixx('SetDinLog');
                    Datapixx('RegWrRd');

                    % Advances to the next randomized validation trial
                    break

                else

                    fprintf('Wrong button (%s)\n', ...
                        buttonNames{pressedButton});
                    fprintf('Waiting for %s...\n',expectedName);

                    % Clears the incorrect event while keeping the current
                    % visual cue and LED active
                    Datapixx('SetDinLog');
                    Datapixx('RegWrRd');

                end

            end

            % Allows the script to end safely while waiting for a response
            [keyIsDown,~,keyCode] = KbCheck;

            if keyIsDown && keyCode(escapeKey)
                error('Validation terminated by the user');
            end

            WaitSecs(0.001);

        end

    end

    fprintf('\nRESPONSEPixx and Pixel Mode validation completed successfully\n');

    % Turns off all RESPONSEPixx LEDs and returns the display to baseline
    Datapixx('SetDinDataOut',0);
    Datapixx('RegWrRd');

    Screen('DrawTexture',window,backgroundTexture);
    Screen('FillRect',window,triggerBaseline,triggerSquare);
    Screen('Flip',window);

    % Closes the background texture
    Screen('Close',backgroundTexture);

    Datapixx('DisablePixelMode');
    Datapixx('RegWrRd');
    Datapixx('Close');

    sca;

catch ME

    % Ensures the RESPONSEPixx LEDs are turned off after an interruption
    try
        Datapixx('SetDinDataOut',0);
        Datapixx('RegWrRd');
    catch
    end

    % Disables Pixel Mode and closes communication if possible
    try
        Datapixx('DisablePixelMode');
        Datapixx('RegWrRd');
    catch
    end

    try
        Datapixx('Close');
    catch
    end

    sca;
    rethrow(ME);

end

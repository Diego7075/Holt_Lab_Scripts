%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RESPONSEPixx validation
%
% This script validates the communication between the DATAPixx3 and a
% RESPONSEPixx controller. Both the VPX-ACC-3100 (5-button Handheld) and 
% the VPX-ACC-3000 (4-button Dual Handheld) are supported. At startup the 
% user selects the connected controller, after which a randomized
% sequence of illuminated buttons is presented, and the participant must
% press the corresponding button to continue. Each button is validated
% twice before the script terminates
%
% Every correct button press generates a 5-ms TTL pulse through the
% DATAPixx3 digital outputs, allowing the trigger values to be verified in
% BrainVision Recorder 2 when the DATAPixx3 digital output is connected to
% the amplifier trigger input. Button press and release timestamps are
% displayed in the MATLAB Command Window relative to the beginning of the
% validation
%
% Before running:
% - Connect the RESPONSEPixx controller to the Digital In connector of the
%   DATAPixx3
% - Connect the DATAPixx3 digital output to the amplifier trigger input
%
% Expected behavior:
% - The LED corresponding to the requested button remains illuminated until
%   the correct button is pressed
% - Correct button presses generate a TTL trigger and are reported together
%   with their timestamp in the MATLAB Command Window
% - Optional button release events are displayed if enabled in the script
% - Every button is validated twice in a randomized order before the
%   validation is completed successfully
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

sca;
clear;
clc;

% Opens communication with the DATAPixx3 and stops any active schedules
Datapixx('Open');
Datapixx('StopAllSchedules');
Datapixx('RegWrRd');

% Defines the time origin used for all timestamps displayed
timeZero = Datapixx('GetTime');

% Debouncing filters out the rapid electrical oscillations ("contact
% bounce") produced immediately after a mechanical button is pressed or
% released.Each physical press and release will generate only one event
Datapixx('EnableDinDebounce');

% The RESPONSEPixx LEDs are not controlled by the DATAPixx Digital OUT 
% connector. They are controlled by bits 16–20 of the Digital IN register.
% Before those bits can drive the LEDs, they must be configured as outputs.
% Here we configure Digital IN bits 16-20 as output lines used to control 
% the RESPONSEPixx button LEDs
Datapixx('SetDinDataDirection', hex2dec('1F0000'));
Datapixx('RegWrRd');

% Creates an empty digital input log and starts recording all button events
Datapixx('SetDinLog');
Datapixx('StartDinLog');
Datapixx('RegWrRd');

disp('Press any RESPONSEPixx button...');
disp('Press ESC on the keyboard to exit.');

KbName('UnifyKeyNames');

% Displays button release events in the MATLAB Command Window
showReleaseEvents = true;

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
        triggerOutputs = [16 32 64 128 240];
        releaseState = hex2dec('FFFF');
        useMask = false;
    case 2
        buttonNames = {'Yellow','Green','Blue','Red'};
        buttonInputs = [hex2dec('000D'),hex2dec('000B'),hex2dec('0007'),hex2dec('000E')];
        ledOutputs = [hex2dec('00020000'),hex2dec('00040000'),hex2dec('00080000'),hex2dec('00010000')];
        triggerOutputs = [16 32 64 128];
        releaseState = hex2dec('000F');
        % useMask removes the upper 12 bits, allowing to separate case 1
        % from case 2 easily
        useMask = true;
    otherwise
        error('Invalid controller selection.');
end

nPresses = 2;
validationOrder = repelem(1:length(buttonNames),nPresses);
validationOrder = validationOrder(randperm(numel(validationOrder)));

% Loop
for trial = 1:length(validationOrder)

    % Selects the button that must be validated during the current trial
    expectedButton  = validationOrder(trial);

    % Retrieves the corresponding data
    expectedName    = buttonNames{expectedButton};
    expectedInput   = buttonInputs(expectedButton);
    expectedLED     = ledOutputs(expectedButton);
    expectedTrigger = triggerOutputs(expectedButton);

    fprintf('\n----------------------------------------\n');
    fprintf('Trial %d of %d\n',trial,length(validationOrder));
    fprintf('Waiting for %s button...\n',expectedName);
    fprintf('----------------------------------------\n');

    % % Displays the Digital IN output used to illuminate RESPONSEPixx LED
    % fprintf('LED output = %08X\n', expectedLED);
    % fprintf('Binary     = %s\n', dec2bin(expectedLED,32));

    % Illuminates the button that should be pressed
    Datapixx('SetDinDataOut',expectedLED);
    Datapixx('RegWrRd');

    % Waits until the correct button has been pressed
    while true

        % Updates the MATLAB register with the current DATAPixx values
        Datapixx('RegWrRd');

        % Checks whether new button events have been detected
        buttonLogStatus = Datapixx('GetDinStatus');

        if buttonLogStatus.newLogFrames > 0

            % Reads the newest button event together with its timestamp
            [data,timetags] = Datapixx('ReadDinLog');
            if useMask
                currentState = bitand(uint16(data(1)), uint16(hex2dec('000F')));
            else
                currentState = uint16(data(1));
            end

            % Button released
            if currentState == releaseState

                if showReleaseEvents
                    fprintf('Released          %.6f s\n',timetags(1) - timeZero);
                end

                Datapixx('SetDinLog');
                Datapixx('RegWrRd');
                continue

            end

            % Identifies which button was pressed
            pressedButton = find(buttonInputs == currentState,1);

            if isempty(pressedButton)

                fprintf('Unknown state (%04X)\n',data(1));

                Datapixx('SetDinLog');
                Datapixx('RegWrRd');
                continue

            end

            % Correct button
            if pressedButton == expectedButton
            
                fprintf('%s pressed      %.6f s\n', ...
                    expectedName, timetags(1) - timeZero);
            
                % Generates a 5 ms TTL pulse through the DATAPixx outputs
                Datapixx('SetDoutValues', expectedTrigger);
                Datapixx('RegWrRd');
            
                WaitSecs(0.005);
            
                Datapixx('SetDoutValues', 0);
                Datapixx('RegWrRd');
            
                % Turns off the LED corresponding to the validated button
                Datapixx('SetDinDataOut', 0);
                Datapixx('RegWrRd');
            
                % Clears the current event before waiting for the release
                Datapixx('SetDinLog');
                Datapixx('RegWrRd');
            
                % Waits until button release before next trial
                while true
            
                    Datapixx('RegWrRd');
            
                    buttonLogStatus = Datapixx('GetDinStatus');
            
                    if buttonLogStatus.newLogFrames > 0
            
                        [releaseData, releaseTime] = Datapixx('ReadDinLog');
                        if useMask
                            releaseCurrentState = bitand(uint16(releaseData(1)), uint16(hex2dec('000F')));
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
            
                            break;
            
                        end
            
                        Datapixx('SetDinLog');
                        Datapixx('RegWrRd');
            
                    end
            
                    WaitSecs(0.001);
            
                end
            
                % Advances to the next randomized trial
                break

            % Incorrect button
            else

                fprintf('Wrong button (%s)\n',...
                    buttonNames{pressedButton});

                fprintf('Waiting for %s...\n',expectedName);

                Datapixx('SetDinLog');
                Datapixx('RegWrRd');

            end

        end

        % Allows the script to end by pressing ESC
        [keyIsDown,~,keyCode] = KbCheck;

        if keyIsDown && keyCode(KbName('ESCAPE'))

            Datapixx('SetDinDataOut',0);
            Datapixx('SetDoutValues',0);
            Datapixx('RegWrRd');

            Datapixx('Close');
            return

        end

        WaitSecs(0.001);

    end

end

% Turns off all LEDs and digital outputs before closing the DATAPixx
Datapixx('SetDinDataOut',0);
Datapixx('SetDoutValues',0);
Datapixx('RegWrRd');

Datapixx('Close');

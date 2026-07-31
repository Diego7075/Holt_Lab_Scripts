%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Babyface microphone recording test with TriggerBox event markers
%
% This script records audio from the Babyface input using PsychPortAudio
% A start trigger is sent when recording begins, and a stop trigger is sent
% when ESC is pressed. The recorded audio is saved as a WAV file in the same
% folder as this script
%
% Sequence:
% Microphone -> Babyface -> Stimulus computer -> Matlab audio buffer -> WAV file
% Microphone -> Babyface -> Acoustic adapter -> StimTrak -> ActiCHamp amplifier -> Recording computer
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear;
clc;

% Enables sound in PTB
InitializePsychSound(1);
Fs       = 48000;
Channels = 1;

% This opens a serial connection between MATLAB and the TriggerBox
% COM4 is the USB-serial port the TriggerBox appears as
% 2000000 is the baud rate (communication speed)
% The TriggerBox expects a high rate so the latency stays very small
tb = serialport("COM4", 2000000);

idle         = uint8(0);
trigger_start = uint8(4);
trigger_stop  = uint8(8);
pulse_width  = 0.005;

% Searches for an available Babyface input device
devices = PsychPortAudio('GetDevices');
deviceID = [];

for k = 1:length(devices)

    if contains(devices(k).DeviceName,'Babyface','IgnoreCase',true) && ...
       devices(k).NrInputChannels > 0

        deviceID = devices(k).DeviceIndex;
        break

    end

end

if isempty(deviceID)
    error('Babyface not found.');
end

% Opens the Babyface input stream
pahandle = PsychPortAudio('Open', ...
    deviceID, ...
    2, ...
    1, ...
    Fs, ...
    Channels);

% Allocates an internal recording buffer capable of storing up to 600 seconds of audio before it is copied into MATLAB
PsychPortAudio('GetAudioData',pahandle,30);

try

    % Starts recording with a recording-start trigger
    PsychPortAudio('Start',pahandle,0,0,1);

    write(tb,idle,"uint8");
    WaitSecs(0.05);

    write(tb,trigger_start,"uint8");
    WaitSecs(pulse_width);

    write(tb,idle,"uint8");

    fprintf('Recording...\n');
    fprintf('Press ESC to stop.\n');

    KbName('UnifyKeyNames');

    while true

        [keyIsDown,~,keyCode] = KbCheck;

        if keyIsDown

            if keyCode(KbName('ESCAPE'))

                % Sends the recording-stop trigger before ending acquisition
                write(tb,idle,"uint8");
                WaitSecs(0.05);

                write(tb,trigger_stop,"uint8");
                WaitSecs(pulse_width);

                write(tb,idle,"uint8");

                break;

            end

        end

    end

    % Stops recording and retrieves the audio from the internal buffer
    PsychPortAudio('Stop',pahandle);
    [audio] = PsychPortAudio('GetAudioData',pahandle);

catch ME

    % Ensures the trigger line returns to idle
    try
        write(tb,idle,"uint8");
    catch
    end

    % Closes the audio device if it is still open
    try
        PsychPortAudio('Stop',pahandle);
    catch
    end

    try
        PsychPortAudio('Close',pahandle);
    catch
    end

    % Releases the TriggerBox serial port
    try
        delete(tb);
        clear tb;
    catch
    end

    rethrow(ME);

end

% Closes the audio device and TriggerBox after successful completion
PsychPortAudio('Close',pahandle);
delete(tb);
clear tb;

% Saves the WAV file in the same folder as this script
scriptFolder = fileparts(mfilename('fullpath'));
timestamp = string(datetime('now','Format','yyyyMMdd_HHmmss'));
filename = fullfile(scriptFolder, "Mic_" + timestamp + ".wav");
audiowrite(filename, audio', Fs, 'BitsPerSample', 24);

fprintf("Saved to:\n%s\n", filename);
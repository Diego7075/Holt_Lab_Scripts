%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% TriggerBox trigger transmission test for EEG acquisition
% This script sends a TTL trigger through the TriggerBox via a serial 
% connection, allowing verification of digital trigger detection by the EEG 
% recording system
% 
% Sequence:
% Stimulus computer -> StimTrak -> -> TriggerBox -> ActiCHamp amplifier
% Stimulus computer -> Acoustic adapter/Headphones -> StimTrak -> actiCHamp AUX
% 
% Before starting, make sure that:
% 1) You have the USB A to B cable plugged between computer and trigger box
% 2) Have available switches in the trigger box looking towards PC
% 3) Check that Recorder has Amplifier>DigitalPort Settings enabled
% 4) Select BNC devices in lower bits and PC triggers in higher bits
% 5) Launch Recorder 2, select your montage, and test this trigger
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% This opens a serial connection between MATLAB and the TriggerBox
% COM4 is the USB-serial port the TriggerBox appears as
% 2000000 is the baud rate (communication speed)
% The TriggerBox expects a high rate so the latency stays very small
tb = serialport("COM4", 2000000);

% 0 in binary is 00000000, meaning all 8 bits are LOW (idle state)
idle = uint8(0);

% This sends the actual trigger code
trigger = uint8(4); % uint8(1) = (00000001), so LN0 needs to be available

% pulse_width keeps the trigger high long enough to be detected
pulse_width = 0.005; % 5 ms

% Trigger example values:
% 1 → LN0
% 2 → LN1
% 4 → LN2
% 8 → LN3
% 16 → LN4
% 32 → LN5
% 64 → LN6
% 128 → LN7

% enforce baseline
write(tb, idle, "uint8");
pause(0.05);

% send trigger
write(tb, trigger, "uint8");
pause(pulse_width);

% reset
write(tb, idle, "uint8");

% closes the serial port so MATLAB releases COM4
clear tb



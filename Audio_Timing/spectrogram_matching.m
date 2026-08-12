%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Recover audio timing using spectrogram-template matching
%
% This script recovers the timing of auditory stimuli from the StimTrak AUX
% recording when dedicated hardware trigger markers are unavailable. Every
% WAV or FLAC file contained in the selected folder is characterized,
% matched against the StimTrak AUX recording using spectrogram-template
% correlation, and converted into an estimated file start, first audible
% sample, and file end.
%
% The script first measures the duration, leading silence, and trailing
% silence of every audio file. It then computes spectrograms of both the
% source audio and the StimTrak recording, and slides the source
% spectrogram across the recording to identify the location with the
% highest normalized correlation. The detected alignment is refined using
% parabolic interpolation to achieve sub-bin temporal precision.
%
% The estimated file start is obtained by subtracting the measured leading
% silence from the matched template location. This allows the same
% procedure to recover the beginning of audio files that start immediately
% with sound, as well as files containing leading and trailing silence.
%
% The script generates diagnostic figures illustrating the matching
% process and exports a results table containing the recovered timing
% estimates and matching quality for every detected stimulus.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear
clc
close all

% Variables
recording_folder = 'C:\Users\HoltLabUsers\Documents\BrainVision\Recorder2\Recordings';
% sound_folder = 'C:\Users\HoltLabUsers\Scripts\wav_files';
sound_folder = 'C:\Users\HoltLabUsers\Scripts\flac_files';

base = 'triggerbox_test_064';

nCh = 33;
stimCh = 32;

match_threshold = 0.60;

freq_min = 50;
freq_max = 500;

win_ms = 50;
overlap_frac = 0.90;

% Create output folders
results_folder = fullfile(sound_folder,'results');
figures_folder = fullfile(results_folder,'figures');

if ~exist(results_folder,'dir')
    mkdir(results_folder);
end

if ~exist(figures_folder,'dir')
    mkdir(figures_folder);
end

% Locate every supported audio file
wav_files = dir(fullfile(sound_folder,'*.wav'));
flac_files = dir(fullfile(sound_folder,'*.flac'));

audio_files = [wav_files; flac_files];

if isempty(audio_files)
    error('No WAV or FLAC files were found.');
end

% Read the BrainVision header
bvrh_file = fullfile(recording_folder,[base '.bvrh']);

header_txt = fileread(bvrh_file);

token = regexp(header_txt,...
    '"SamplingFrequencyInHertz"\s*:\s*([0-9.]+)',...
    'tokens','once');

if isempty(token)
    error('Could not find SamplingFrequencyInHertz in the BVRH file.');
end

fs_eeg = str2double(token{1});

% Read the BrainVision data
bvrd_file = fullfile(recording_folder,[base '.bvrd']);

fid = fopen(bvrd_file,'r');

if fid == -1
    error('Cannot open BVRD file:\n%s',bvrd_file);
end

raw = fread(fid,[nCh inf],'single=>double');

fclose(fid);

% Extract the StimTrak AUX channel
stimtrak = raw(stimCh,:);

t_stim = (0:length(stimtrak)-1) / fs_eeg;

% Display the complete StimTrak recording
figure;

plot(t_stim,stimtrak,'k');

xlabel('Time (s)');
ylabel('StimTrak amplitude');

title('Full StimTrak AUX recording');

grid on;

saveas(gcf,...
    fullfile(figures_folder,'StimTrak_recording.png'));

% Characterize every audio file
metadata = table();

for k = 1:length(audio_files)

    file_name = audio_files(k).name;
    file_path = fullfile(sound_folder,file_name);

    [y,fs_audio] = audioread(file_path);

    if size(y,2) > 1
        y = mean(y,2);
    end

    y = y - mean(y);

    threshold = max(0.001 * max(abs(y)),eps);

    first_audible_sample = find(abs(y) > threshold,1,'first');
    last_audible_sample = find(abs(y) > threshold,1,'last');

    if isempty(first_audible_sample)

        first_audible_sample = 1;
        last_audible_sample = length(y);

    end

    total_samples = length(y);
    duration_sec = total_samples / fs_audio;

    leading_silence_samples = first_audible_sample - 1;
    trailing_silence_samples = total_samples - last_audible_sample;

    leading_silence_sec = leading_silence_samples / fs_audio;
    trailing_silence_sec = trailing_silence_samples / fs_audio;

    metadata = [metadata;
        table( ...
        string(file_name), ...
        fs_audio, ...
        total_samples, ...
        duration_sec, ...
        leading_silence_samples, ...
        leading_silence_sec, ...
        trailing_silence_samples, ...
        trailing_silence_sec, ...
        'VariableNames',{ ...
        'File', ...
        'SamplingRate', ...
        'TotalSamples', ...
        'DurationSec', ...
        'LeadingSilenceSamples', ...
        'LeadingSilenceSec', ...
        'TrailingSilenceSamples', ...
        'TrailingSilenceSec'})];

end

% Search every audio file inside the StimTrak recording
detected_matches = table();

stim_seg = stimtrak - mean(stimtrak);

for w = 1:height(metadata)

    file_name = metadata.File(w);
    file_path = fullfile(sound_folder,file_name);

    fprintf('\n');
    fprintf('Processing %s\n',file_name);

    [y,fs_audio] = audioread(file_path);

    if size(y,2) > 1
        y = mean(y,2);
    end

    y = y - mean(y);

    win_audio = round((win_ms/1000) * fs_audio);
    overlap_audio = round(overlap_frac * win_audio);
    nfft_audio = 2^nextpow2(win_audio);

    win_stim = round((win_ms/1000) * fs_eeg);
    overlap_stim = round(overlap_frac * win_stim);
    nfft_stim = 2^nextpow2(win_stim);

    [S_audio,F_audio,T_audio] = spectrogram( ...
        y,...
        hamming(win_audio),...
        overlap_audio,...
        nfft_audio,...
        fs_audio);

    [S_stim,F_stim,T_stim] = spectrogram( ...
        stim_seg,...
        hamming(win_stim),...
        overlap_stim,...
        nfft_stim,...
        fs_eeg);

    P_audio = log10(abs(S_audio).^2 + eps);
    P_stim = log10(abs(S_stim).^2 + eps);

    keep_audio = F_audio >= freq_min & F_audio <= freq_max;
    keep_stim = F_stim >= freq_min & F_stim <= freq_max;

    F_common = F_stim(keep_stim);

    P_audio = interp1( ...
        F_audio(keep_audio),...
        P_audio(keep_audio,:),...
        F_common,...
        'linear',...
        'extrap');

    P_stim = P_stim(keep_stim,:);

    P_audio = zscore(P_audio,0,2);
    P_stim = zscore(P_stim,0,2);

    nAudio = size(P_audio,2);
    nStim = size(P_stim,2);

    if nStim < nAudio
        warning('%s is longer than the recording.',file_name);
        continue;
    end

    template = P_audio(:);
    template = template - mean(template);
    template_norm = norm(template);

    match_scores = nan(1,nStim-nAudio+1);

    for k = 1:length(match_scores)

        chunk = P_stim(:,k:k+nAudio-1);

        chunk = chunk(:);
        chunk = chunk - mean(chunk);

        match_scores(k) = ...
            dot(chunk,template) / ...
            (norm(chunk)*template_norm);

    end

    hop_sec = T_stim(2) - T_stim(1);

    min_peak_distance = ...
        round((metadata.DurationSec(w)/2)/hop_sec);

    fprintf('Max correlation: %.3f\n', max(match_scores));
    fprintf('Min correlation: %.3f\n', min(match_scores));

    [peak_scores,peak_bins] = findpeaks( ...
        match_scores,...
        'MinPeakHeight',match_threshold,...
        'MinPeakDistance',min_peak_distance);

    % Plot and save matching score
    [~,file_stem,~] = fileparts(char(file_name));
    
    lag_axis_ms = (T_stim(1:length(match_scores)) - T_audio(1))*1000;
    
    figure('Visible','off');
    
    plot(lag_axis_ms,match_scores,'k','LineWidth',1.5);
    hold on;
    
    yline(match_threshold,'k--');
    xline((T_stim(peak_bins)-T_audio(1))*1000,'r','LineWidth',2);
    
    plot((T_stim(peak_bins)-T_audio(1))*1000,...
         peak_scores,...
         'ro',...
         'MarkerFaceColor','r');

    xlabel('Lag inside recording (ms)')
    ylabel('Spectrogram-template correlation');
    
    title(['Template matching score: ' ...
           strrep(char(file_name),'_','\_')]);
    
    grid on;
    
    saveas(gcf,...
        fullfile(figures_folder,...
        [file_stem '_matching_score.png']));
    
    close(gcf);
    for m = 1:length(peak_bins)

        k = peak_bins(m);

        delta = 0;

        if k > 1 && k < length(match_scores)

            y1 = match_scores(k-1);
            y2 = match_scores(k);
            y3 = match_scores(k+1);

            denom = y1 - 2*y2 + y3;

            if denom ~= 0
                delta = 0.5*(y1-y3)/denom;
            end

        end

        matched_time_sec = ...
            (T_stim(k)-T_audio(1)) + ...
            delta*hop_sec;

        matched_sample = ...
            round(matched_time_sec*fs_eeg);

        leading_samples = ...
            round(metadata.LeadingSilenceSec(w)*fs_eeg);

        trailing_samples = ...
            round(metadata.TrailingSilenceSec(w)*fs_eeg);

        duration_samples = ...
            round(metadata.DurationSec(w)*fs_eeg);

        estimated_file_start = ...
            matched_sample - leading_samples;

        estimated_first_audible = ...
            estimated_file_start + leading_samples;

        estimated_file_end = ...
            estimated_file_start + duration_samples - 1;

        detected_matches = ...
            [detected_matches;
            table( ...
            string(file_name),...
            peak_scores(m),...
            matched_sample,...
            estimated_file_start,...
            estimated_first_audible,...
            estimated_file_end,...
            metadata.LeadingSilenceSec(w),...
            metadata.TrailingSilenceSec(w),...
            'VariableNames',{ ...
            'File',...
            'MatchScore',...
            'MatchedTemplateSample',...
            'EstimatedFileStartSample',...
            'EstimatedFirstAudibleSample',...
            'EstimatedFileEndSample',...
            'LeadingSilenceSec',...
            'TrailingSilenceSec'})];

        % Diagnostic figure: waveform + spectrogram comparison
        plot_k = peak_bins(m);
        plot_score = peak_scores(m);
        stim_best = P_stim(:,plot_k:plot_k+nAudio-1);
        T_plot = T_audio(1:size(stim_best,2));
        figure('Visible','off','Position',[100 100 900 900]);
        
        % Audio waveform
        subplot(3,1,1)
        t_audio = (0:length(y)-1)/fs_audio;
        plot(t_audio,y,'k')
        hold on
        xline(0,...
            'k--',...
            'File start',...
            'LineWidth',1.5);
        xline(metadata.LeadingSilenceSec(w),...
            'b',...
            'Audio starts',...
            'LineWidth',2);
        xlabel('Time (s)')
        ylabel('Amplitude')
        xline(metadata.DurationSec(w)-metadata.TrailingSilenceSec(w),...
            'r',...
            'Audio ends',...
            'LineWidth',2);
        title(sprintf('%s',char(file_name)),...
            'Interpreter','none')
        grid on
        
        % Audio spectrogram
        subplot(3,1,2)
        imagesc(T_audio,F_common,P_audio)
        axis xy
        xlabel('Time (s)')
        ylabel('Frequency (Hz)')
        title('Reference audio spectrogram')
        colorbar
        
        % Matched StimTrak spectrogram
        subplot(3,1,3)
        imagesc(T_plot,F_common,stim_best)
        axis xy
        xlabel('Aligned time (s)')
        ylabel('Frequency (Hz)')
        title(sprintf('StimTrak match   r = %.3f',plot_score))
        colorbar
        saveas(gcf,...
            fullfile(figures_folder,...
            sprintf('%s_match_%d.png',file_stem,m)));
        close(gcf)
    end
end

% Sort the recovered matches
detected_matches = sortrows( ...
    detected_matches,...
    'EstimatedFileStartSample');

% Display the recovered matches
disp('===========================================')
disp('RECOVERED AUDIO TIMING')
disp('===========================================')
disp(detected_matches)

% Export a text report
txt_file = fullfile(results_folder,'detected_matches.txt');

fid = fopen(txt_file,'w');

fprintf(fid,'RECOVERED AUDIO TIMING\n');
fprintf(fid,'======================\n\n');

fprintf(fid,...
'%-25s %-10s %-12s %-12s %-12s %-12s %-12s\n',...
'File',...
'Score',...
'Template',...
'FileStart',...
'FirstAudio',...
'FileEnd',...
'Duration(s)');

fprintf(fid,...
'%s\n',...
repmat('-',1,105));

for k = 1:height(detected_matches)

    fprintf(fid,...
        '%-25s %-10.4f %-12d %-12d %-12d %-12d %-12.3f\n',...
        char(detected_matches.File(k)),...
        detected_matches.MatchScore(k),...
        detected_matches.MatchedTemplateSample(k),...
        detected_matches.EstimatedFileStartSample(k),...
        detected_matches.EstimatedFirstAudibleSample(k),...
        detected_matches.EstimatedFileEndSample(k),...
        metadata.DurationSec(metadata.File == detected_matches.File(k)));
end

fclose(fid);

% Display a summary
fprintf('\n');
fprintf('===========================================\n');
fprintf('Recovery completed successfully\n');
fprintf('===========================================\n');
fprintf('Audio files analyzed : %d\n',height(metadata));
fprintf('Recovered matches    : %d\n',height(detected_matches));

if isempty(detected_matches)

    fprintf('No matches satisfied the correlation threshold (%.2f).\n', ...
        match_threshold);

else

    fprintf('Mean match score     : %.4f\n', ...
        mean(detected_matches.MatchScore));

    fprintf('Minimum match score  : %.4f\n', ...
        min(detected_matches.MatchScore));

    fprintf('Maximum match score  : %.4f\n', ...
        max(detected_matches.MatchScore));

    fprintf('Results saved to:\n');
    fprintf('%s\n',txt_file);

end

% Close all figures
close all
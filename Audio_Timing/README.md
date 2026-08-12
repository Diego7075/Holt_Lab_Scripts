# Audio Timing

MATLAB/Psychtoolbox utilities for configuring auditory stimulus output and empirically validating audio timing in the Holt Laboratory EEG setup.

These tools are used to measure the temporal relationship between scheduled auditory stimulation, the physical audio signal recorded through StimTrak, and VIEWPixx Pixel Mode markers recorded by BrainVision Recorder 2.

The workflow spans two computers:

* **Stimulus Computer** — presents the auditory stimuli and VIEWPixx Pixel Mode markers.
* **Recording Computer** — records the StimTrak AUX signal using BrainVision Recorder 2 and performs the subsequent spectrogram-matching analysis.

## Hardware

* Brain Products actiCHamp Plus
* BrainVision Recorder 2
* VPixx VIEWPixx EEG
* RME Babyface Pro FS
* StimTrak
* Acoustic Adapter
* MATLAB
* Psychtoolbox-3

---

## Scripts

### 1. `initialize_audio_output.m`

Provides a common PsychPortAudio initialization procedure for auditory experiments and validation scripts.

At startup, the function enumerates the available PsychPortAudio output devices and allows selection between two supported audio pathways:

1. Desktop headphone output (Realtek)
2. RME Babyface Analog 3/4

The selected device is located automatically using its device name, Windows WASAPI backend, and number of output channels.

The standard audio configuration is:

* Sample rate: 48000 Hz
* Output channels: 2
* `audioLatencyClass = 1`
* Audio volume: 1.0

For the RME Babyface pathway, the validated configuration uses a 512-sample buffer and 48000-Hz sample rate.

This function initializes the audio device only. Experiment-specific timing parameters such as `LatencyBias`, audio-pathway compensation, stimulus leading-silence compensation, and event scheduling are defined by the experiment or validation script.

---

### 2. `viewpixx_audio_latency_test.m`

**Runs on the Stimulus Computer.**

Measures and calibrates the temporal relationship between a VIEWPixx Pixel Mode marker and the physical onset of an auditory stimulus.

The script calls `initialize_audio_output.m` to initialize either the Realtek or RME Babyface audio pathway. It then locates the FLAC files in the configured audio-test directory and presents each file 10 times.

For each presentation, audio playback is scheduled together with a three-frame VIEWPixx Pixel Mode marker using RGB `[128 0 0]`.

The validation is recorded simultaneously using BrainVision Recorder 2 on the Recording Computer. The physical audio signal is captured through the StimTrak AUX channel, while Pixel Mode provides the corresponding hardware marker.

The primary synchronization measure is:

```text
FirstAudio - Pixel Mode
```

where `FirstAudio` represents the estimated physical onset of audible content in the StimTrak recording.

#### Timing compensation

Two timing components are maintained separately.

`audioLagCompensation` accounts for the physical timing offset introduced by the selected audio pathway.

`leadingSilenceCompensation` accounts for silent samples contained between the beginning of the audio file and the first audible sample.

The final PsychPortAudio timing correction is:

```text
LatencyBias = audioLagCompensation + leadingSilenceCompensation
```

Positive `LatencyBias` values move physical audio earlier relative to Pixel Mode, whereas negative values move it later.

The compensation values are specific to the validated hardware and stimulus configuration. Changes to the audio pathway, audio-device settings, stimulus leading silence, or relevant timing parameters require the relationship to be measured again.

The script also generates `played_sequence.txt`, providing the sequence of audio files presented during the validation.

---

### 3. `spectrogram_matching.m`

**Runs on the Recording Computer.**

Recovers the timing of auditory stimuli from the StimTrak AUX recording using spectrogram-template matching.

The script reads the BrainVision recording and compares the recorded StimTrak signal against the original WAV or FLAC stimulus files stored on the Recording Computer.

For each source audio file, the script first determines:

* File duration
* Leading silence
* Trailing silence

It then computes spectrograms of the source audio and StimTrak recording. The source spectrogram is moved across the recording, and normalized spectrogram correlation is used to identify candidate stimulus locations.

Detected peaks above the specified correlation threshold are refined using parabolic interpolation to improve temporal precision.

For every detected stimulus, the script estimates:

* `FileStart` — estimated beginning of the audio file
* `FirstAudio` — estimated onset of audible content
* `FileEnd` — estimated end of the audio file
* Match correlation score

The distinction between `FileStart` and `FirstAudio` is important when the source audio contains leading silence.

Diagnostic figures are generated for visual inspection of the matching procedure, including:

* Complete StimTrak recording
* Template-matching correlation scores
* Source audio waveform
* Reference audio spectrogram
* Matched StimTrak spectrogram

The recovered timing estimates are exported to:

```text
results/detected_matches.txt
```

The folders defined within `spectrogram_matching.m` correspond to the directory structure of the **Recording Computer**, where the BrainVision recordings and stimulus files used for the analysis are stored.

---

## Calibration Workflow

The complete procedure is:

```text
STIMULUS COMPUTER
─────────────────────────────────────

initialize_audio_output.m
          │
          ▼
viewpixx_audio_latency_test.m
          │
          ├────────► Audio output
          │              │
          │              ▼
          │           StimTrak
          │
          └────────► VIEWPixx Pixel Mode
                         │
                         ▼
                   actiCHamp Plus
                         │
                         ▼
                BrainVision Recorder 2


RECORDING COMPUTER
─────────────────────────────────────

BrainVision recording + original audio files
                         │
                         ▼
              spectrogram_matching.m
                         │
                         ▼
        Recover physical audio timing
                         │
                         ▼
             FileStart / FirstAudio
                         │
                         ▼
          Compare FirstAudio - Pixel Mode
                         │
                         ▼
          Determine timing compensation
                         │
                         ▼
       Validate values before transferring
             them to experiment code
```

## Recommended Procedure

1. Confirm the audio hardware configuration and device settings.
2. Run `viewpixx_audio_latency_test.m` on the Stimulus Computer.
3. Record the complete validation session using BrainVision Recorder 2.
4. Run `spectrogram_matching.m` on the Recording Computer.
5. Inspect the matching scores and diagnostic figures.
6. Compare the recovered `FirstAudio` timing against the corresponding Pixel Mode markers.
7. Determine the appropriate audio-pathway compensation.
8. Repeat the validation after applying the compensation to confirm the resulting synchronization.
9. Transfer the validated timing parameters to the experimental script.

---

## Important Timing Considerations

Software scheduling times should not be treated as equivalent to physical stimulus onset.

The purpose of this workflow is to measure the physical audio signal recorded through the EEG acquisition system and determine its relationship to the hardware Pixel Mode marker.

Timing-compensation values should therefore not be assumed to generalize across different:

* Audio devices or pathways
* Audio-device settings
* Buffer configurations
* Stimulus files
* Leading-silence durations
* PsychPortAudio timing configurations

Relevant changes require the audio timing to be validated again.

---

## Related Tools

General hardware and trigger validation scripts are documented in [`Hardware_Validation`](../Hardware_Validation/).
# Holt Lab Scripts

MATLAB/Psychtoolbox validation scripts for the Holt Laboratory neuroengineering platform. This repository contains standalone utilities used to validate hardware communication, timing accuracy, trigger transmission, audiovisual synchronization, and behavioral response acquisition before experimental data collection.

The scripts support the laboratory hardware configuration based on Brain Products, VPixx Technologies, and RME devices, and are intended to verify each component individually before validating the complete experimental pipeline.

## Hardware

* Brain Products actiCHamp Plus
* BrainVision Recorder 2
* Brain Products TriggerBox
* VPixx DATAPixx3
* VPixx VIEWPixx EEG
* VPixx RESPONSEPixx Handheld (VPX-ACC-3100)
* VPixx RESPONSEPixx Dual Handheld (VPX-ACC-3000)
* RME Babyface Pro FS
* StimTrak
* Acoustic Adapter
* MATLAB
* Psychtoolbox-3

---

## Repository Contents

### 1. `triggerbox_trigger_test.m`

Validates digital trigger transmission through the Brain Products TriggerBox.

A single TTL pulse is transmitted through the TriggerBox using a serial connection, allowing verification that BrainVision Recorder correctly detects digital trigger events from the actiCHamp amplifier.

**Validation path**

```
Stimulus Computer
        │
        ▼
    TriggerBox
        │
        ▼
 actiCHamp Plus
        │
        ▼
 BrainVision Recorder 2
```

---

### 2. `microphone_test.m`

Validates synchronized microphone acquisition and trigger generation.

The script records audio from an RME Babyface Pro FS microphone input using PsychPortAudio while simultaneously transmitting start and stop triggers through the TriggerBox. The recording is automatically saved as a WAV file.

**Validation path**

```
Microphone
      │
      ▼
Babyface Pro FS
      │
      ▼
MATLAB
      │
      ▼
WAV recording
```

Simultaneously,

```
Microphone
      │
      ▼
Babyface Pro FS
      │
      ▼
Acoustic Adapter
      │
      ▼
StimTrak
      │
      ▼
actiCHamp Plus
```

---

### 3. `viewpixx_screen_checking.m`

Verifies Psychtoolbox screen detection and VIEWPixx display timing.

The script first identifies every display detected by Psychtoolbox, allowing the user to determine the correct VIEWPixx screen index. It then opens the selected VIEWPixx display, measures the inter-frame interval (IFI), estimates the refresh rate, and confirms the expected display resolution.

Expected configuration:

* Resolution: 1920 × 1080
* Refresh rate: 120 Hz
* Background color: RGB [128 128 128]

---

### 4. VIEWPixx Pixel Mode validation

#### `viewpixx_trigger_test.m`

Validates Pixel Mode trigger transmission.

The script sequentially presents predefined RGB trigger values in the Pixel Mode region located in the upper-left corner of the VIEWPixx display. These RGB values are converted by the VIEWPixx into TTL pulses, allowing verification that BrainVision Recorder correctly detects every trigger combination.

**Validation path**

```
Stimulus Computer
        │
        ▼
VIEWPixx EEG
        │
        ▼
 actiCHamp Plus
        │
        ▼
BrainVision Recorder 2
```

---

#### `viewpixx_trigger_test_2.m`

Validates audiovisual synchronization using Pixel Mode.

Each trial presents a synchronized visual Pixel Mode trigger together with an auditory stimulus. Because both events are scheduled using the same Psychtoolbox target time, this script allows verification of the temporal alignment between recorded audio and digital trigger markers.

**Validation path**

Visual

```
Stimulus Computer
        │
        ▼
VIEWPixx EEG
        │
        ▼
 actiCHamp Plus
        │
        ▼
BrainVision Recorder 2
```

Audio

```
Stimulus Computer
        │
        ▼
Acoustic Adapter
        │
        ▼
StimTrak
        │
        ▼
 actiCHamp Plus
        │
        ▼
BrainVision Recorder 2
```

---

### 5. `datapixx_responsepixx_test.m`

Validates communication between the DATAPixx3 and RESPONSEPixx controllers.

Both supported RESPONSEPixx controllers can be selected at startup:

* VPX-ACC-3100 Handheld (5 buttons)
* VPX-ACC-3000 Dual Handheld (4 buttons)

The script validates LED control, button acquisition, timestamp generation, and TTL trigger transmission generated through the DATAPixx3 Digital OUT connector.

**Validation path**

```
Stimulus Computer
        │
        ▼
   DATAPixx3
        │
        ▼
 RESPONSEPixx
```

and

```
DATAPixx3 Digital OUT
          │
          ▼
 actiCHamp Plus
          │
          ▼
BrainVision Recorder 2
```

---

### 6. `datapixx_viewpixx_responsepixx_test.m`

Validates the complete visual experimental pipeline.

This script combines the DATAPixx3, VIEWPixx EEG, and RESPONSEPixx into the final hardware configuration used during behavioral experiments.

Both RESPONSEPixx controllers are supported. During each trial, the selected RESPONSEPixx button is illuminated while a matching colored cue appears on the VIEWPixx display. Simultaneously, Pixel Mode generates the corresponding hardware trigger. Correct responses are timestamped, and trigger activation and deactivation are verified in BrainVision Recorder.

**Validation path**

```
Stimulus Computer
        │
        ▼
   DATAPixx3
        │
        ├────────► RESPONSEPixx
        │
        ▼
 VIEWPixx EEG
        │
        ▼
 actiCHamp Plus
        │
        ▼
BrainVision Recorder 2
```

---

## Notes

These scripts are intended as independent validation utilities and can be executed individually depending on the hardware component being tested. They are primarily designed to verify hardware installation, timing accuracy, trigger transmission, and communication before running experimental protocols.

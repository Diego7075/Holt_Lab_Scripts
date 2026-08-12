# Holt Lab Scripts

MATLAB/Psychtoolbox utilities for the Holt Laboratory neuroengineering platform.

This repository contains scripts used to validate experimental hardware, characterize timing, and support the configuration of behavioral and EEG experiments using Brain Products, VPixx Technologies, and RME devices.

## Repository Structure

### [`Hardware_Validation/`](Hardware_Validation/)

Standalone utilities for testing individual components and hardware communication before running experimental protocols.

Current validation tools include:

* Brain Products TriggerBox trigger transmission
* Microphone acquisition and synchronization
* VIEWPixx display and refresh-rate validation
* VIEWPixx Pixel Mode trigger validation
* Audiovisual synchronization testing
* DATAPixx3 and RESPONSEPixx communication
* Combined DATAPixx3, VIEWPixx, and RESPONSEPixx validation

See [`Hardware_Validation/README.md`](Hardware_Validation/README.md) for detailed documentation.

---

### [`Audio_Timing/`](Audio_Timing/)

Utilities for configuring audio output and empirically validating auditory stimulus timing relative to VIEWPixx Pixel Mode markers.

The workflow includes:

* Standardized PsychPortAudio initialization for Realtek and RME Babyface output
* Physical audio-to-Pixel-Mode latency measurement
* StimTrak AUX recording with BrainVision Recorder 2
* Spectrogram-template matching for recovery of physical audio onset
* Estimation and validation of audio timing compensation

The calibration workflow spans both the **Stimulus Computer** and **Recording Computer**.

See [`Audio_Timing/README.md`](Audio_Timing/README.md) for detailed documentation.

---

## Main Hardware

* Brain Products actiCHamp Plus
* BrainVision Recorder 2
* Brain Products TriggerBox
* VPixx DATAPixx3
* VPixx VIEWPixx EEG
* VPixx RESPONSEPixx controllers
* RME Babyface Pro FS
* StimTrak
* Acoustic Adapter

## Software

* MATLAB
* Psychtoolbox-3

## Notes

The scripts in this repository are laboratory validation and configuration utilities. Hardware-dependent timing parameters should be empirically validated whenever relevant components, device settings, stimulus properties, or timing configurations are changed.
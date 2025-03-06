# Flutter Voice Recorder with Silence Detection

A Flutter application that provides a smart voice recording experience by automatically detecting silence and stopping the recording. This app calibrates to the ambient noise in the environment to intelligently distinguish between speech and background noise.

## Features

- Automatically stops recording after detecting silence for a configurable duration
- Adapts to background noise through automatic noise level calibration
- Efficiently handles audio processing to minimize battery usage
- Simple, clean UI for easy recording experience
- Uses flutter_sound for audio processing

## Technical Details

This application implements an adaptive voice activity detection (VAD) algorithm that:
- Measures and calibrates to the ambient noise level
- Uses relative thresholds for speech and silence detection
- Implements audio level smoothing to prevent false triggers
- Provides configurable silence duration for automatic recording termination

Perfect for note-taking apps, voice memos, or any application requiring smart audio recording capabilities.

# PoseMate AI

An Android mobile app (built with Flutter) that helps users copy a reference pose while taking a mirror selfie or a pose photo. It shows a faint ghost image of the reference pose over the live camera view, compares the user's pose using AI, gives short hints, and captures the photo automatically when the pose matches.

Built for the 4th International AI Championship (AIEF).

## Features

- Built-in pose library and custom reference image upload
- Ghost overlay of the reference pose on the live camera (front and back camera)
- Optional skeleton view
- Pose comparison using joint angles and a match score
- Rule-based hints for body parts that need to move
- Auto-capture after the pose stays matched for about 2 seconds, plus manual capture

## Tech Stack

- Flutter and Dart
- Google ML Kit Pose Detection
- Android (Flutter camera package)

## Project Proposal

See [PoseMate_AI_Project_Proposal.md](PoseMate_AI_Project_Proposal.md) for the full proposal.

## Status

In development.

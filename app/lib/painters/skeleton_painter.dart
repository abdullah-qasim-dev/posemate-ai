import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as ml_kit;

import '../models/pose_match_result.dart';

/// Holds the output of a single pose detection frame for drawing and UI updates.
class PoseDetectionResult {
  final List<ml_kit.Pose> poses;
  final Size absoluteImageSize;
  final ml_kit.InputImageRotation rotation;
  final bool isFrontCamera;
  final PoseMatchResult? matchResult;

  const PoseDetectionResult({
    required this.poses,
    required this.absoluteImageSize,
    required this.rotation,
    required this.isFrontCamera,
    this.matchResult,
  });

  /// Returns true if at least one person with valid landmarks was detected.
  bool get hasPerson =>
      poses.isNotEmpty && poses.first.landmarks.isNotEmpty;

  /// Returns total number of keypoints with sufficient confidence.
  int get detectedLandmarkCount {
    if (!hasPerson) return 0;
    return poses.first.landmarks.values
        .where((lm) => lm.likelihood >= 0.5)
        .length;
  }
}

/// A real-time skeleton overlay painter that renders Google ML Kit pose landmarks
/// and connecting bones on top of the camera preview.
///
/// Handles coordinate mapping, aspect ratio preservation (BoxFit.cover matching
/// the camera preview), rotation compensation, and front-camera mirroring.
class SkeletonPainter extends CustomPainter {
  final List<ml_kit.Pose> poses;
  final Size absoluteImageSize;
  final ml_kit.InputImageRotation rotation;
  final bool isFrontCamera;

  /// Minimum confidence likelihood required to render a landmark or bone.
  static const double _minLikelihood = 0.5;

  SkeletonPainter({
    required this.poses,
    required this.absoluteImageSize,
    required this.rotation,
    required this.isFrontCamera,
    super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty ||
        absoluteImageSize.width <= 0 ||
        absoluteImageSize.height <= 0) {
      return;
    }

    // 1. Compute effective image dimensions after rotation.
    // For 90deg and 270deg orientations, width and height are swapped.
    final bool isRotated =
        rotation == ml_kit.InputImageRotation.rotation90deg ||
            rotation == ml_kit.InputImageRotation.rotation270deg;

    final double imageWidth =
        isRotated ? absoluteImageSize.height : absoluteImageSize.width;
    final double imageHeight =
        isRotated ? absoluteImageSize.width : absoluteImageSize.height;

    if (imageWidth <= 0 || imageHeight <= 0) return;

    // 2. Uniform scale factor matching BoxFit.cover of the camera preview
    final double scaleX = size.width / imageWidth;
    final double scaleY = size.height / imageHeight;
    final double scale = math.max(scaleX, scaleY);

    // 3. Center offsets to account for cropped edges
    final double offsetX = (size.width - imageWidth * scale) / 2.0;
    final double offsetY = (size.height - imageHeight * scale) / 2.0;

    // Helper to project a landmark to screen canvas coordinates
    Offset? projectLandmark(ml_kit.PoseLandmark? landmark) {
      if (landmark == null || landmark.likelihood < _minLikelihood) {
        return null;
      }

      // In front camera mode, preview is mirrored horizontally so user sees
      // themselves naturally like a mirror. Flip landmark.x across imageWidth.
      final double rawX =
          isFrontCamera ? (imageWidth - landmark.x) : landmark.x;
      final double rawY = landmark.y;

      final double screenX = offsetX + rawX * scale;
      final double screenY = offsetY + rawY * scale;

      return Offset(screenX, screenY);
    }

    // 4. Draw skeletons for all detected poses (typically 1 for live tracking)
    for (final pose in poses) {
      final landmarks = pose.landmarks;

      // Color scheme:
      // - Left body: Electric Cyan (0xFF00E5FF)
      // - Right body: Neon Lavender (0xFFC084FC)
      // - Torso / Center: Vibrant Violet (0xFF7C5CF0)
      const Color leftColor = Color(0xFF00E5FF);
      const Color rightColor = Color(0xFFC084FC);
      const Color centerColor = Color(0xFF7C5CF0);

      // ── A. Draw Connecting Bones ──────────────────────────────────────────
      void drawBone(
        ml_kit.PoseLandmarkType type1,
        ml_kit.PoseLandmarkType type2,
        Color color,
      ) {
        final p1 = projectLandmark(landmarks[type1]);
        final p2 = projectLandmark(landmarks[type2]);

        if (p1 != null && p2 != null) {
          // Glow stroke
          final glowPaint = Paint()
            ..color = color.withValues(alpha: 0.35)
            ..strokeWidth = 7.0
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
          canvas.drawLine(p1, p2, glowPaint);

          // Core sharp stroke
          final corePaint = Paint()
            ..color = color
            ..strokeWidth = 3.0
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
          canvas.drawLine(p1, p2, corePaint);
        }
      }

      // Torso & Shoulders
      drawBone(ml_kit.PoseLandmarkType.leftShoulder,
          ml_kit.PoseLandmarkType.rightShoulder, centerColor);
      drawBone(ml_kit.PoseLandmarkType.leftShoulder,
          ml_kit.PoseLandmarkType.leftHip, centerColor);
      drawBone(ml_kit.PoseLandmarkType.rightShoulder,
          ml_kit.PoseLandmarkType.rightHip, centerColor);
      drawBone(ml_kit.PoseLandmarkType.leftHip,
          ml_kit.PoseLandmarkType.rightHip, centerColor);

      // Left Arm
      drawBone(ml_kit.PoseLandmarkType.leftShoulder,
          ml_kit.PoseLandmarkType.leftElbow, leftColor);
      drawBone(ml_kit.PoseLandmarkType.leftElbow,
          ml_kit.PoseLandmarkType.leftWrist, leftColor);
      drawBone(ml_kit.PoseLandmarkType.leftWrist,
          ml_kit.PoseLandmarkType.leftThumb, leftColor);
      drawBone(ml_kit.PoseLandmarkType.leftWrist,
          ml_kit.PoseLandmarkType.leftIndex, leftColor);

      // Right Arm
      drawBone(ml_kit.PoseLandmarkType.rightShoulder,
          ml_kit.PoseLandmarkType.rightElbow, rightColor);
      drawBone(ml_kit.PoseLandmarkType.rightElbow,
          ml_kit.PoseLandmarkType.rightWrist, rightColor);
      drawBone(ml_kit.PoseLandmarkType.rightWrist,
          ml_kit.PoseLandmarkType.rightThumb, rightColor);
      drawBone(ml_kit.PoseLandmarkType.rightWrist,
          ml_kit.PoseLandmarkType.rightIndex, rightColor);

      // Left Leg
      drawBone(ml_kit.PoseLandmarkType.leftHip,
          ml_kit.PoseLandmarkType.leftKnee, leftColor);
      drawBone(ml_kit.PoseLandmarkType.leftKnee,
          ml_kit.PoseLandmarkType.leftAnkle, leftColor);
      drawBone(ml_kit.PoseLandmarkType.leftAnkle,
          ml_kit.PoseLandmarkType.leftHeel, leftColor);
      drawBone(ml_kit.PoseLandmarkType.leftHeel,
          ml_kit.PoseLandmarkType.leftFootIndex, leftColor);

      // Right Leg
      drawBone(ml_kit.PoseLandmarkType.rightHip,
          ml_kit.PoseLandmarkType.rightKnee, rightColor);
      drawBone(ml_kit.PoseLandmarkType.rightKnee,
          ml_kit.PoseLandmarkType.rightAnkle, rightColor);
      drawBone(ml_kit.PoseLandmarkType.rightAnkle,
          ml_kit.PoseLandmarkType.rightHeel, rightColor);
      drawBone(ml_kit.PoseLandmarkType.rightHeel,
          ml_kit.PoseLandmarkType.rightFootIndex, rightColor);

      // Face / Head outline
      drawBone(ml_kit.PoseLandmarkType.leftEar,
          ml_kit.PoseLandmarkType.leftEye, leftColor);
      drawBone(ml_kit.PoseLandmarkType.leftEye,
          ml_kit.PoseLandmarkType.nose, centerColor);
      drawBone(ml_kit.PoseLandmarkType.nose,
          ml_kit.PoseLandmarkType.rightEye, centerColor);
      drawBone(ml_kit.PoseLandmarkType.rightEye,
          ml_kit.PoseLandmarkType.rightEar, rightColor);

      // ── B. Draw Keypoint Joints ───────────────────────────────────────────
      // Keypoints highlighted with larger glowing joints:
      // Nose, Shoulders, Elbows, Wrists, Hips, Knees, Ankles
      const Set<ml_kit.PoseLandmarkType> majorJoints = {
        ml_kit.PoseLandmarkType.nose,
        ml_kit.PoseLandmarkType.leftShoulder,
        ml_kit.PoseLandmarkType.rightShoulder,
        ml_kit.PoseLandmarkType.leftElbow,
        ml_kit.PoseLandmarkType.rightElbow,
        ml_kit.PoseLandmarkType.leftWrist,
        ml_kit.PoseLandmarkType.rightWrist,
        ml_kit.PoseLandmarkType.leftHip,
        ml_kit.PoseLandmarkType.rightHip,
        ml_kit.PoseLandmarkType.leftKnee,
        ml_kit.PoseLandmarkType.rightKnee,
        ml_kit.PoseLandmarkType.leftAnkle,
        ml_kit.PoseLandmarkType.rightAnkle,
      };

      for (final entry in landmarks.entries) {
        final landmark = entry.value;
        final point = projectLandmark(landmark);
        if (point == null) continue;

        final isMajor = majorJoints.contains(entry.key);
        final bool isLeft = entry.key.name.startsWith('left');
        final bool isRight = entry.key.name.startsWith('right');
        final Color jointColor = isLeft
            ? leftColor
            : (isRight ? rightColor : centerColor);

        // 1. Outer halo
        final haloPaint = Paint()
          ..color = jointColor.withValues(alpha: isMajor ? 0.35 : 0.2)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(point, isMajor ? 7.5 : 4.5, haloPaint);

        // 2. Solid joint ring
        final solidPaint = Paint()
          ..color = jointColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(point, isMajor ? 4.5 : 2.8, solidPaint);

        // 3. Crisp white center dot
        if (isMajor) {
          final centerDotPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;
          canvas.drawCircle(point, 2.0, centerDotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) {
    return oldDelegate.poses != poses ||
        oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.rotation != rotation ||
        oldDelegate.isFrontCamera != isFrontCamera;
  }
}

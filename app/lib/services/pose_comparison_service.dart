import 'dart:math' as math;
import 'package:flutter/material.dart' show Offset;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as ml_kit;

import '../models/pose.dart';
import '../models/pose_match_result.dart';

/// Service calculating planar joint angles from body landmarks and evaluating
/// similarity between a live user pose and a target reference pose.
class PoseComparisonService {
  /// Default tolerance angle in degrees (e.g., 45°). A difference of 0° scores 1.0;
  /// differences >= 45° score 0.0.
  static const double defaultAngleTolerance = 45.0;

  /// Default minimum confidence likelihood required for ML Kit landmarks.
  static const double defaultMinLikelihood = 0.5;

  /// Calculates the interior 2D angle (in degrees, 0° to 180°) at [vertex]
  /// formed by lines [first] -> [vertex] and [second] -> [vertex].
  ///
  /// Returns `null` if any coordinate is invalid/non-finite or if points are coincident.
  static double? calculateAngle({
    required Offset first,
    required Offset vertex,
    required Offset second,
  }) {
    // Check for NaN or infinite coordinates
    if (!first.dx.isFinite ||
        !first.dy.isFinite ||
        !vertex.dx.isFinite ||
        !vertex.dy.isFinite ||
        !second.dx.isFinite ||
        !second.dy.isFinite) {
      return null;
    }

    final double v1x = first.dx - vertex.dx;
    final double v1y = first.dy - vertex.dy;
    final double v2x = second.dx - vertex.dx;
    final double v2y = second.dy - vertex.dy;

    final double mag1 = math.sqrt(v1x * v1x + v1y * v1y);
    final double mag2 = math.sqrt(v2x * v2x + v2y * v2y);

    // If points are coincident or distance is negligible, angle is undefined
    if (mag1 < 1e-6 || mag2 < 1e-6) {
      return null;
    }

    final double dot = v1x * v2x + v1y * v2y;
    final double cosTheta = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    final double radians = math.acos(cosTheta);
    return radians * 180.0 / math.pi;
  }

  /// Extracts joint angles from a reference [Pose] using its normalized landmarks map.
  static Map<JointType, double> extractReferenceAngles(Pose pose) {
    return extractAnglesFromLandmarkMap(pose.normalizedLandmarks);
  }

  /// Extracts joint angles from any normalized landmark map (`Map<String, Offset>`).
  static Map<JointType, double> extractAnglesFromLandmarkMap(
    Map<String, Offset> landmarks,
  ) {
    final Map<JointType, double> angles = {};
    for (final joint in JointType.values) {
      final triple = _getLandmarkKeysForJoint(joint);
      final p1 = landmarks[triple.$1];
      final p2 = landmarks[triple.$2];
      final p3 = landmarks[triple.$3];

      if (p1 != null && p2 != null && p3 != null) {
        final angle = calculateAngle(first: p1, vertex: p2, second: p3);
        if (angle != null) {
          angles[joint] = angle;
        }
      }
    }
    return angles;
  }

  /// Extracts joint angles from an ML Kit [ml_kit.Pose].
  ///
  /// When [isFrontCamera] is `true`, left and right landmarks are mirrored so that
  /// users looking at the mirrored preview match the mirrored ghost overlay naturally.
  static Map<JointType, JointAngle> extractUserAngles({
    required ml_kit.Pose userPose,
    bool isFrontCamera = false,
    double minLikelihood = defaultMinLikelihood,
  }) {
    final Map<JointType, JointAngle> angles = {};

    for (final joint in JointType.values) {
      final types = _getMLKitLandmarkTypesForJoint(
        joint,
        isFrontCamera: isFrontCamera,
      );

      final lm1 = userPose.landmarks[types.$1];
      final lm2 = userPose.landmarks[types.$2];
      final lm3 = userPose.landmarks[types.$3];

      if (lm1 != null &&
          lm2 != null &&
          lm3 != null &&
          lm1.likelihood >= minLikelihood &&
          lm2.likelihood >= minLikelihood &&
          lm3.likelihood >= minLikelihood) {
        final p1 = Offset(lm1.x, lm1.y);
        final p2 = Offset(lm2.x, lm2.y);
        final p3 = Offset(lm3.x, lm3.y);

        final angle = calculateAngle(first: p1, vertex: p2, second: p3);
        if (angle != null) {
          final double avgConfidence =
              (lm1.likelihood + lm2.likelihood + lm3.likelihood) / 3.0;
          angles[joint] = JointAngle(
            type: joint,
            angleDegrees: angle,
            confidence: avgConfidence,
          );
        }
      }
    }

    return angles;
  }

  /// Compares a live [ml_kit.Pose] with a target reference [Pose].
  ///
  /// Returns a normalized [PoseMatchResult] with match score from 0.0% to 100.0%.
  static PoseMatchResult compare({
    required ml_kit.Pose? userPose,
    required Pose? referencePose,
    bool isFrontCamera = false,
    double angleTolerance = defaultAngleTolerance,
    double minLikelihood = defaultMinLikelihood,
  }) {
    if (referencePose == null) {
      return const PoseMatchResult.empty();
    }

    final refAngles = extractReferenceAngles(referencePose);
    if (refAngles.isEmpty) {
      return const PoseMatchResult.empty();
    }

    if (userPose == null || userPose.landmarks.isEmpty) {
      return PoseMatchResult(
        matchScore: 0.0,
        totalReferenceJoints: refAngles.length,
        matchedJointCount: 0,
        jointComparisons: const {},
        hasPerson: false,
      );
    }

    final userAngles = extractUserAngles(
      userPose: userPose,
      isFrontCamera: isFrontCamera,
      minLikelihood: minLikelihood,
    );

    return _calculateScore(
      refAngles: refAngles,
      userAngles: userAngles.map((k, v) => MapEntry(k, v.angleDegrees)),
      angleTolerance: angleTolerance,
      hasPerson: true,
    );
  }

  /// Compares two landmark maps directly. Useful for unit tests, offline matching,
  /// or when both poses are stored in normalized coordinate form.
  static PoseMatchResult compareLandmarkMaps({
    required Map<String, Offset>? userLandmarks,
    required Map<String, Offset>? referenceLandmarks,
    double angleTolerance = defaultAngleTolerance,
  }) {
    if (referenceLandmarks == null || referenceLandmarks.isEmpty) {
      return const PoseMatchResult.empty();
    }

    final refAngles = extractAnglesFromLandmarkMap(referenceLandmarks);
    if (refAngles.isEmpty) {
      return const PoseMatchResult.empty();
    }

    if (userLandmarks == null || userLandmarks.isEmpty) {
      return PoseMatchResult(
        matchScore: 0.0,
        totalReferenceJoints: refAngles.length,
        matchedJointCount: 0,
        jointComparisons: const {},
        hasPerson: false,
      );
    }

    final userAngles = extractAnglesFromLandmarkMap(userLandmarks);

    return _calculateScore(
      refAngles: refAngles,
      userAngles: userAngles,
      angleTolerance: angleTolerance,
      hasPerson: true,
    );
  }

  /// Internal scoring formula implementing bounded linear difference falloff
  /// and penalizing missing reference joints.
  static PoseMatchResult _calculateScore({
    required Map<JointType, double> refAngles,
    required Map<JointType, double> userAngles,
    required double angleTolerance,
    required bool hasPerson,
  }) {
    final Map<JointType, JointComparison> comparisons = {};
    double totalScoreSum = 0.0;

    for (final entry in refAngles.entries) {
      final joint = entry.key;
      final refAngle = entry.value;
      final userAngle = userAngles[joint];

      if (userAngle != null) {
        final double diff = (userAngle - refAngle).abs();
        // Linear score: 1.0 when diff == 0°, down to 0.0 when diff >= angleTolerance
        final double score = (1.0 - (diff / angleTolerance)).clamp(0.0, 1.0);

        comparisons[joint] = JointComparison(
          type: joint,
          referenceAngle: refAngle,
          userAngle: userAngle,
          angleDifference: diff,
          score: score,
        );

        totalScoreSum += score;
      }
    }

    // Normalized match score (0.0 to 100.0%)
    // Dividing by total reference joints ensures missing essential joints lower the score
    final double normalizedScore =
        (totalScoreSum / refAngles.length) * 100.0;

    return PoseMatchResult(
      matchScore: normalizedScore.clamp(0.0, 100.0),
      totalReferenceJoints: refAngles.length,
      matchedJointCount: comparisons.length,
      jointComparisons: comparisons,
      hasPerson: hasPerson,
    );
  }

  /// Maps a [JointType] to landmark key names `(first, vertex, second)`.
  static (String, String, String) _getLandmarkKeysForJoint(JointType joint) {
    switch (joint) {
      case JointType.leftElbow:
        return ('leftShoulder', 'leftElbow', 'leftWrist');
      case JointType.rightElbow:
        return ('rightShoulder', 'rightElbow', 'rightWrist');
      case JointType.leftShoulder:
        return ('leftElbow', 'leftShoulder', 'leftHip');
      case JointType.rightShoulder:
        return ('rightElbow', 'rightShoulder', 'rightHip');
      case JointType.leftHip:
        return ('leftShoulder', 'leftHip', 'leftKnee');
      case JointType.rightHip:
        return ('rightShoulder', 'rightHip', 'rightKnee');
      case JointType.leftKnee:
        return ('leftHip', 'leftKnee', 'leftAnkle');
      case JointType.rightKnee:
        return ('rightHip', 'rightKnee', 'rightAnkle');
    }
  }

  /// Maps a [JointType] to Google ML Kit [ml_kit.PoseLandmarkType] triples.
  ///
  /// Inverts left and right when [isFrontCamera] is `true` for natural mirror alignment.
  static (ml_kit.PoseLandmarkType, ml_kit.PoseLandmarkType, ml_kit.PoseLandmarkType)
      _getMLKitLandmarkTypesForJoint(
    JointType joint, {
    required bool isFrontCamera,
  }) {
    if (!isFrontCamera) {
      switch (joint) {
        case JointType.leftElbow:
          return (
            ml_kit.PoseLandmarkType.leftShoulder,
            ml_kit.PoseLandmarkType.leftElbow,
            ml_kit.PoseLandmarkType.leftWrist,
          );
        case JointType.rightElbow:
          return (
            ml_kit.PoseLandmarkType.rightShoulder,
            ml_kit.PoseLandmarkType.rightElbow,
            ml_kit.PoseLandmarkType.rightWrist,
          );
        case JointType.leftShoulder:
          return (
            ml_kit.PoseLandmarkType.leftElbow,
            ml_kit.PoseLandmarkType.leftShoulder,
            ml_kit.PoseLandmarkType.leftHip,
          );
        case JointType.rightShoulder:
          return (
            ml_kit.PoseLandmarkType.rightElbow,
            ml_kit.PoseLandmarkType.rightShoulder,
            ml_kit.PoseLandmarkType.rightHip,
          );
        case JointType.leftHip:
          return (
            ml_kit.PoseLandmarkType.leftShoulder,
            ml_kit.PoseLandmarkType.leftHip,
            ml_kit.PoseLandmarkType.leftKnee,
          );
        case JointType.rightHip:
          return (
            ml_kit.PoseLandmarkType.rightShoulder,
            ml_kit.PoseLandmarkType.rightHip,
            ml_kit.PoseLandmarkType.rightKnee,
          );
        case JointType.leftKnee:
          return (
            ml_kit.PoseLandmarkType.leftHip,
            ml_kit.PoseLandmarkType.leftKnee,
            ml_kit.PoseLandmarkType.leftAnkle,
          );
        case JointType.rightKnee:
          return (
            ml_kit.PoseLandmarkType.rightHip,
            ml_kit.PoseLandmarkType.rightKnee,
            ml_kit.PoseLandmarkType.rightAnkle,
          );
      }
    } else {
      // Mirrored mapping for front camera / mirror selfie mode
      switch (joint) {
        case JointType.leftElbow:
          return (
            ml_kit.PoseLandmarkType.rightShoulder,
            ml_kit.PoseLandmarkType.rightElbow,
            ml_kit.PoseLandmarkType.rightWrist,
          );
        case JointType.rightElbow:
          return (
            ml_kit.PoseLandmarkType.leftShoulder,
            ml_kit.PoseLandmarkType.leftElbow,
            ml_kit.PoseLandmarkType.leftWrist,
          );
        case JointType.leftShoulder:
          return (
            ml_kit.PoseLandmarkType.rightElbow,
            ml_kit.PoseLandmarkType.rightShoulder,
            ml_kit.PoseLandmarkType.rightHip,
          );
        case JointType.rightShoulder:
          return (
            ml_kit.PoseLandmarkType.leftElbow,
            ml_kit.PoseLandmarkType.leftShoulder,
            ml_kit.PoseLandmarkType.leftHip,
          );
        case JointType.leftHip:
          return (
            ml_kit.PoseLandmarkType.rightShoulder,
            ml_kit.PoseLandmarkType.rightHip,
            ml_kit.PoseLandmarkType.rightKnee,
          );
        case JointType.rightHip:
          return (
            ml_kit.PoseLandmarkType.leftShoulder,
            ml_kit.PoseLandmarkType.leftHip,
            ml_kit.PoseLandmarkType.leftKnee,
          );
        case JointType.leftKnee:
          return (
            ml_kit.PoseLandmarkType.rightHip,
            ml_kit.PoseLandmarkType.rightKnee,
            ml_kit.PoseLandmarkType.rightAnkle,
          );
        case JointType.rightKnee:
          return (
            ml_kit.PoseLandmarkType.leftHip,
            ml_kit.PoseLandmarkType.leftKnee,
            ml_kit.PoseLandmarkType.leftAnkle,
          );
      }
    }
  }
}

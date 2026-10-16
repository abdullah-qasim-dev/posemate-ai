/// Body joints evaluated during pose comparison.
enum JointType {
  leftElbow,
  rightElbow,
  leftShoulder,
  rightShoulder,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
}

/// Represents an angle measured at a specific joint.
class JointAngle {
  final JointType type;
  final double angleDegrees;
  final double confidence;

  const JointAngle({
    required this.type,
    required this.angleDegrees,
    required this.confidence,
  });
}

/// Detailed comparison between the user's joint angle and the reference angle.
class JointComparison {
  final JointType type;
  final double referenceAngle;
  final double userAngle;
  final double angleDifference;

  /// Normalized match score for this joint between 0.0 (poor) and 1.0 (perfect).
  final double score;

  const JointComparison({
    required this.type,
    required this.referenceAngle,
    required this.userAngle,
    required this.angleDifference,
    required this.score,
  });
}

/// Aggregated result of comparing a live user pose against a target reference pose.
class PoseMatchResult {
  /// Overall match score normalized between 0.0% and 100.0%.
  final double matchScore;

  /// Total number of joints specified by the reference pose.
  final int totalReferenceJoints;

  /// Number of reference joints successfully detected and matched in the user's pose.
  final int matchedJointCount;

  /// Individual comparison details per joint.
  final Map<JointType, JointComparison> jointComparisons;

  /// Whether a person was present and detectable in the frame.
  final bool hasPerson;

  /// Minimum score threshold (default 75%) to consider the pose adequately matched.
  static const double defaultMatchThreshold = 75.0;

  const PoseMatchResult({
    required this.matchScore,
    required this.totalReferenceJoints,
    required this.matchedJointCount,
    required this.jointComparisons,
    required this.hasPerson,
  });

  const PoseMatchResult.empty()
      : matchScore = 0.0,
        totalReferenceJoints = 0,
        matchedJointCount = 0,
        jointComparisons = const {},
        hasPerson = false;

  /// Whether the overall pose meets or exceeds the matching threshold.
  bool get isMatch => matchScore >= defaultMatchThreshold;
}

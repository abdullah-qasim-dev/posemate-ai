import 'package:flutter/material.dart' show Offset;

/// Model representing a reference pose in the PoseMate library.
class Pose {
  final String id;
  final String name;
  final String category;
  final String difficulty;
  final String assetPath;
  final String description;

  /// Normalized 2D landmark coordinates (0.0 to 1.0) for the target skeleton.
  final Map<String, Offset> normalizedLandmarks;

  const Pose({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.assetPath,
    required this.description,
    this.normalizedLandmarks = const {},
  });

  /// Curated list of library poses with real generated image assets and
  /// normalized target skeleton landmarks for Phase 3 Ghost Overlay.
  static const List<Pose> defaultPoses = [
    Pose(
      id: 't_pose',
      name: 'T-Pose',
      category: 'Calibration',
      difficulty: 'Beginner',
      assetPath: 'assets/poses/t_pose.jpg',
      description: 'Stand tall with arms outstretched horizontally at shoulder height.',
      normalizedLandmarks: {
        'nose': Offset(0.50, 0.15),
        'leftShoulder': Offset(0.42, 0.26),
        'rightShoulder': Offset(0.58, 0.26),
        'leftElbow': Offset(0.24, 0.26),
        'rightElbow': Offset(0.76, 0.26),
        'leftWrist': Offset(0.10, 0.26),
        'rightWrist': Offset(0.90, 0.26),
        'leftHip': Offset(0.45, 0.52),
        'rightHip': Offset(0.55, 0.52),
        'leftKnee': Offset(0.45, 0.72),
        'rightKnee': Offset(0.55, 0.72),
        'leftAnkle': Offset(0.45, 0.92),
        'rightAnkle': Offset(0.55, 0.92),
      },
    ),
    Pose(
      id: 'hands_on_hips',
      name: 'Hands on Hips',
      category: 'Casual & Standing',
      difficulty: 'Beginner',
      assetPath: 'assets/poses/hands_on_hips.jpg',
      description: 'Feet shoulder-width apart, hands resting comfortably on hips.',
      normalizedLandmarks: {
        'nose': Offset(0.50, 0.15),
        'leftShoulder': Offset(0.42, 0.26),
        'rightShoulder': Offset(0.58, 0.26),
        'leftElbow': Offset(0.28, 0.38),
        'rightElbow': Offset(0.72, 0.38),
        'leftWrist': Offset(0.39, 0.50),
        'rightWrist': Offset(0.61, 0.50),
        'leftHip': Offset(0.44, 0.52),
        'rightHip': Offset(0.56, 0.52),
        'leftKnee': Offset(0.44, 0.72),
        'rightKnee': Offset(0.56, 0.72),
        'leftAnkle': Offset(0.43, 0.92),
        'rightAnkle': Offset(0.57, 0.92),
      },
    ),
    Pose(
      id: 'tree_pose',
      name: 'Tree Pose (Vrksasana)',
      category: 'Yoga & Balance',
      difficulty: 'Intermediate',
      assetPath: 'assets/poses/tree_pose.jpg',
      description: 'Balance on one leg with hands pressed together at chest level.',
      normalizedLandmarks: {
        'nose': Offset(0.50, 0.15),
        'leftShoulder': Offset(0.43, 0.26),
        'rightShoulder': Offset(0.57, 0.26),
        'leftElbow': Offset(0.36, 0.36),
        'rightElbow': Offset(0.64, 0.36),
        'leftWrist': Offset(0.48, 0.32),
        'rightWrist': Offset(0.52, 0.32),
        'leftHip': Offset(0.45, 0.52),
        'rightHip': Offset(0.55, 0.52),
        'leftKnee': Offset(0.28, 0.64),
        'leftAnkle': Offset(0.48, 0.67),
        'rightKnee': Offset(0.54, 0.72),
        'rightAnkle': Offset(0.54, 0.92),
      },
    ),
    Pose(
      id: 'warrior_pose',
      name: 'Warrior Pose (Virabhadrasana)',
      category: 'Yoga & Athletic',
      difficulty: 'Intermediate',
      assetPath: 'assets/poses/warrior_pose.jpg',
      description: 'Lunge with front knee bent and arms extended parallel to floor.',
      normalizedLandmarks: {
        'nose': Offset(0.45, 0.16),
        'leftShoulder': Offset(0.39, 0.28),
        'rightShoulder': Offset(0.57, 0.28),
        'leftElbow': Offset(0.24, 0.28),
        'leftWrist': Offset(0.10, 0.28),
        'rightElbow': Offset(0.73, 0.28),
        'rightWrist': Offset(0.89, 0.28),
        'leftHip': Offset(0.43, 0.54),
        'rightHip': Offset(0.55, 0.54),
        'leftKnee': Offset(0.30, 0.70),
        'leftAnkle': Offset(0.21, 0.88),
        'rightKnee': Offset(0.70, 0.68),
        'rightAnkle': Offset(0.70, 0.88),
      },
    ),
    Pose(
      id: 'arms_crossed',
      name: 'Arms Crossed',
      category: 'Portrait & Casual',
      difficulty: 'Beginner',
      assetPath: 'assets/poses/arms_crossed.jpg',
      description: 'Confident standing pose with arms crossed over chest.',
      normalizedLandmarks: {
        'nose': Offset(0.50, 0.15),
        'leftShoulder': Offset(0.40, 0.26),
        'rightShoulder': Offset(0.60, 0.26),
        'leftElbow': Offset(0.33, 0.40),
        'rightElbow': Offset(0.67, 0.40),
        'leftWrist': Offset(0.56, 0.38),
        'rightWrist': Offset(0.44, 0.38),
        'leftHip': Offset(0.44, 0.52),
        'rightHip': Offset(0.56, 0.52),
        'leftKnee': Offset(0.44, 0.72),
        'rightKnee': Offset(0.56, 0.72),
        'leftAnkle': Offset(0.44, 0.92),
        'rightAnkle': Offset(0.56, 0.92),
      },
    ),
  ];
}

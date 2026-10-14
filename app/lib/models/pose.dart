/// Model representing a reference pose in the PoseMate library.
class Pose {
  final String id;
  final String name;
  final String category;
  final String difficulty;
  final String assetPath;
  final String description;

  const Pose({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.assetPath,
    required this.description,
  });

  /// Curated list of library poses with real generated image assets.
  static const List<Pose> defaultPoses = [
    Pose(
      id: 't_pose',
      name: 'T-Pose',
      category: 'Calibration',
      difficulty: 'Beginner',
      assetPath: 'assets/poses/t_pose.jpg',
      description: 'Stand tall with arms outstretched horizontally at shoulder height.',
    ),
    Pose(
      id: 'hands_on_hips',
      name: 'Hands on Hips',
      category: 'Casual & Standing',
      difficulty: 'Beginner',
      assetPath: 'assets/poses/hands_on_hips.jpg',
      description: 'Feet shoulder-width apart, hands resting comfortably on hips.',
    ),
    Pose(
      id: 'tree_pose',
      name: 'Tree Pose (Vrksasana)',
      category: 'Yoga & Balance',
      difficulty: 'Intermediate',
      assetPath: 'assets/poses/tree_pose.jpg',
      description: 'Balance on one leg with hands pressed together at chest level.',
    ),
    Pose(
      id: 'warrior_pose',
      name: 'Warrior Pose (Virabhadrasana)',
      category: 'Yoga & Athletic',
      difficulty: 'Intermediate',
      assetPath: 'assets/poses/warrior_pose.jpg',
      description: 'Lunge with front knee bent and arms extended parallel to floor.',
    ),
    Pose(
      id: 'arms_crossed',
      name: 'Arms Crossed',
      category: 'Portrait & Casual',
      difficulty: 'Beginner',
      assetPath: 'assets/poses/arms_crossed.jpg',
      description: 'Confident standing pose with arms crossed over chest.',
    ),
  ];
}

import 'package:flutter/material.dart';

import '../models/pose.dart';
import 'camera_screen.dart';

/// Screen displaying the curated library of reference poses.
///
/// Users browse poses with actual images and details. Tapping a pose selects it
/// and opens [CameraScreen] with that pose set as the reference guide.
class PoseLibraryScreen extends StatefulWidget {
  const PoseLibraryScreen({super.key});

  @override
  State<PoseLibraryScreen> createState() => _PoseLibraryScreenState();
}

class _PoseLibraryScreenState extends State<PoseLibraryScreen> {
  String _selectedCategory = 'All';

  final List<String> _categories = const [
    'All',
    'Calibration',
    'Casual & Standing',
    'Yoga & Balance',
    'Portrait & Casual',
  ];

  List<Pose> get _filteredPoses {
    if (_selectedCategory == 'All') return Pose.defaultPoses;
    return Pose.defaultPoses
        .where((p) => p.category == _selectedCategory)
        .toList();
  }

  void _onSelectPose(BuildContext context, Pose pose) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CameraScreen(selectedPose: pose),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D18),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFFE6ECFF),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Pose Library',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE6ECFF),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle / instructions header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
            child: Text(
              'Select a reference pose to open the camera with guided alignment.',
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFFA7B1CE).withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Category filter chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = category);
                    }
                  },
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFFA7B1CE),
                  ),
                  selectedColor: const Color(0xFF7C5CF0),
                  backgroundColor: const Color(0xFF0F1626),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF7C5CF0)
                          : const Color(0xFF24304D),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Grid of pose cards
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 16,
                childAspectRatio: 0.72,
              ),
              itemCount: _filteredPoses.length,
              itemBuilder: (context, index) {
                final pose = _filteredPoses[index];
                return _PoseCard(
                  pose: pose,
                  onTap: () => _onSelectPose(context, pose),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Card showing pose thumbnail, name, difficulty badge, and tap handler.
class _PoseCard extends StatelessWidget {
  final Pose pose;
  final VoidCallback onTap;

  const _PoseCard({required this.pose, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1626),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF24304D),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: const Color(0xFF7C5CF0).withValues(alpha: 0.2),
          highlightColor: const Color(0xFF7C5CF0).withValues(alpha: 0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pose Image with difficulty badge overlay
              Expanded(
                flex: 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      pose.assetPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFF162035),
                          child: const Center(
                            child: Icon(
                              Icons.accessibility_new_rounded,
                              size: 48,
                              color: Color(0xFF7C5CF0),
                            ),
                          ),
                        );
                      },
                    ),
                    // Gradient shadow over bottom of image
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              const Color(0xFF0F1626),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Difficulty badge top-right
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF7C5CF0).withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          pose.difficulty,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE6ECFF),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Title and category
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pose.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE6ECFF),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            pose.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFFA7B1CE).withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      // Action indicator button
                      Row(
                        children: [
                          const Text(
                            'Use pose',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7C5CF0),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: Color(0xFF7C5CF0),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

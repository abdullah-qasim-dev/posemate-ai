import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'screens/pose_library_screen.dart';

void main() {
  runApp(const PoseMateApp());
}

/// Root application widget configuring dark theme and initial route.
class PoseMateApp extends StatelessWidget {
  const PoseMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PoseMate AI',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D18),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C5CF0),
          surface: Color(0xFF0F1626),
          onSurface: Color(0xFFE6ECFF),
          outline: Color(0xFF24304D),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

/// Home dashboard screen of PoseMate AI matching the reference design.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// Opens the device image picker and navigates to the preview screen.
  Future<void> _pickImageFromGallery(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) {
        // User cancelled picker: handle gracefully without showing an error
        return;
      }

      if (!context.mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => GalleryPreviewScreen(imagePath: pickedFile.path),
        ),
      );
    } catch (_) {
      // Graceful fallback if picking is not supported on this platform/emulator
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D18),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top content group
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(context),
                          const SizedBox(height: 16),
                          _buildHeroCard(),
                          const SizedBox(height: 16),
                          _buildChooseFromLibraryButton(context),
                          const SizedBox(height: 12),
                          _buildSelectFromGalleryButton(context),
                          const SizedBox(height: 20),
                          _buildHowItWorksSection(),
                        ],
                      ),
                      // Footer at the very bottom
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: _buildFooter(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 1. Top Header with logo, app title/subtitle, and circular Saved Photos icon.
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // App logo container
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF7C5CF0),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.camera_alt_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        // App Title & Tagline
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PoseMate AI',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE6ECFF),
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Pose-Guided Photography',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFA7B1CE),
                ),
              ),
            ],
          ),
        ),
        // Circular Saved Photos button (42x42px)
        InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const SavedPhotosScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(21),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0F1626),
              border: Border.all(
                color: const Color(0xFF24304D),
                width: 1.2,
              ),
            ),
            child: const Icon(
              Icons.collections_outlined,
              color: Color(0xFFE6ECFF),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  /// 2. Hero Card highlighting the core product promise.
  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1626),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF24304D),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Small guidance chip in sentence case
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF7C5CF0).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF7C5CF0).withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 13,
                  color: Color(0xFFC4B5FD),
                ),
                SizedBox(width: 6),
                Text(
                  'Smart pose guidance',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE6ECFF),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Headline
          const Text(
            'Pose with confidence.\nLet AI perfect your shot.',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: Color(0xFFE6ECFF),
            ),
          ),
          const SizedBox(height: 10),
          // Subtitle
          const Text(
            'Overlay reference photos, align your posture with live feedback, and trigger auto-capture hands-free.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: Color(0xFFA7B1CE),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Primary button — Choose from pose library (66px height, 20px radius).
  Widget _buildChooseFromLibraryButton(BuildContext context) {
    return SizedBox(
      height: 66,
      width: double.infinity,
      child: Material(
        color: const Color(0xFF7C5CF0),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const PoseLibraryScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // 2x2 grid icon inside rounded square
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.grid_view_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Text
                const Expanded(
                  child: Text(
                    'Choose from pose library',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                // Small chevron
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 4. Secondary button — Select from gallery (66px height, 20px radius).
  Widget _buildSelectFromGalleryButton(BuildContext context) {
    return SizedBox(
      height: 66,
      width: double.infinity,
      child: Material(
        color: const Color(0xFF0F1626),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: Color(0xFF34426B),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _pickImageFromGallery(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // Gallery icon inside rounded square
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF18233B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.image_outlined,
                    color: Color(0xFFE6ECFF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Text
                const Expanded(
                  child: Text(
                    'Select from gallery',
                    style: TextStyle(
                      color: Color(0xFFE6ECFF),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                // Small chevron
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFA7B1CE),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 5. How It Works Section with three compact horizontal cards.
  Widget _buildHowItWorksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How it works',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE6ECFF),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: const [
            Expanded(
              child: _StepCard(
                stepNumber: '1',
                label: 'Pick a pose',
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _StepCard(
                stepNumber: '2',
                label: 'Follow the\nghost',
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _StepCard(
                stepNumber: '3',
                label: 'Auto-capture',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 6. Bottom footer notice regarding on-device AI.
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1626),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF24304D),
          width: 1.0,
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 18,
            color: Color(0xFFA7B1CE),
          ),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'On-Device AI · No images sent to the cloud',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFA7B1CE),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact numbered card widget used in the "How it works" section.
class _StepCard extends StatelessWidget {
  final String stepNumber;
  final String label;

  const _StepCard({
    required this.stepNumber,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.fromLTRB(6.0, 14.0, 6.0, 10.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1626),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF24304D),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          // Purple circle with step number (fixed at top with identical padding across all cards)
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF7C5CF0),
            ),
            alignment: Alignment.center,
            child: Text(
              stepNumber,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 9),
          // Label text aligned at top of text area so "Follow the ghost" does not shift circles
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE6ECFF),
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple placeholder screen for Saved Photos.
class SavedPhotosScreen extends StatelessWidget {
  const SavedPhotosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D18),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFE6ECFF), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Saved Photos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE6ECFF),
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C5CF0).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.collections_outlined,
                  size: 34,
                  color: Color(0xFF7C5CF0),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Saved Photos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE6ECFF),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'No saved photos yet.\nPhotos captured with auto-capture will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFFA7B1CE),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen previewing an image selected from the phone's gallery.
class GalleryPreviewScreen extends StatelessWidget {
  final String imagePath;

  const GalleryPreviewScreen({
    super.key,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D18),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFE6ECFF), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Gallery Image Preview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE6ECFF),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1626),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF24304D),
                      width: 1.2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: kIsWeb
                      ? Image.network(
                          imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => _buildErrorState(),
                        )
                      : Image.file(
                          File(imagePath),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => _buildErrorState(),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1626),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF24304D),
                    width: 1.0,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: Color(0xFF7C5CF0), size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Reference image loaded. Ready for pose alignment in next step.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFE6ECFF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 48, color: Color(0xFFA7B1CE)),
          SizedBox(height: 12),
          Text(
            'Could not render preview image',
            style: TextStyle(color: Color(0xFFA7B1CE), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

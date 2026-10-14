import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Screen displayed after a photo is captured, showing a preview/result.
///
/// Displays the captured image with options to retake or confirm.
class CapturePreviewScreen extends StatelessWidget {
  final String imagePath;

  const CapturePreviewScreen({
    super.key,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context),
      body: _buildBody(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Retake',
      ),
      title: const Text(
        'Photo Preview',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Full-screen image preview with natural aspect ratio ───────────
        _buildImagePreview(),

        // ── Bottom action bar ─────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildActionBar(context),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Center(
      child: Image.file(
        File(imagePath),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image_outlined,
                size: 56,
                color: Color(0xFF7C5CF0),
              ),
              SizedBox(height: 14),
              Text(
                'Could not load captured image.',
                style: TextStyle(color: Color(0xFFA7B1CE), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
          stops: [0.0, 1.0],
        ),
      ),
      child: Row(
        children: [
          // Retake button
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF34426B), width: 1.5),
                foregroundColor: const Color(0xFFE6ECFF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: const Color(0xFF0F1626).withValues(alpha: 0.8),
              ),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text(
                'Retake',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Use Photo button
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C5CF0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Photo saved! In future phases this will be saved to your gallery.',
                    ),
                    backgroundColor: Color(0xFF1E1030),
                  ),
                );
                // Pop back to home (pops preview and camera screen)
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: const Text(
                'Use Photo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

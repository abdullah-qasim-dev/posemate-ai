import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/photo_service.dart';

/// Screen displayed after a photo is captured or when a thumbnail is tapped
/// from the recent photos strip.
///
/// Supports interactive pinch-to-zoom, retake, and photo deletion.
class CapturePreviewScreen extends StatefulWidget {
  final String imagePath;
  final bool isReviewOnly;

  const CapturePreviewScreen({
    super.key,
    required this.imagePath,
    this.isReviewOnly = false,
  });

  @override
  State<CapturePreviewScreen> createState() => _CapturePreviewScreenState();
}

class _CapturePreviewScreenState extends State<CapturePreviewScreen> {
  bool _isDeleting = false;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1626),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Photo?',
          style: TextStyle(color: Color(0xFFE6ECFF), fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This will permanently remove the photo from PoseMate AI.',
          style: TextStyle(color: Color(0xFFA7B1CE)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFA7B1CE))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeleting = true);
      await PhotoService.deletePhoto(widget.imagePath);
      if (mounted) {
        Navigator.of(context).pop(true); // Return true indicating deletion
      }
    }
  }

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
      backgroundColor: Colors.black38,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.of(context).pop(false),
        tooltip: 'Back',
      ),
      title: Text(
        widget.isReviewOnly ? 'Saved Photo' : 'Photo Preview',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          icon: _isDeleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
          onPressed: _isDeleting ? null : _confirmDelete,
          tooltip: 'Delete photo',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Pinch-to-zoom interactive photo viewer ───────────
        _buildImagePreview(),

        // ── Bottom action bar (shown when capturing a new photo) ─────────────
        if (!widget.isReviewOnly)
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
      child: InteractiveViewer(
        minScale: 0.8,
        maxScale: 4.0,
        child: Image.file(
          File(widget.imagePath),
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
              onPressed: () => Navigator.of(context).pop(false),
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
                Navigator.of(context).pop(false);
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

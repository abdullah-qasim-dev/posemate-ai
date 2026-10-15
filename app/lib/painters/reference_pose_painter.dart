import 'package:flutter/material.dart';

/// Painter for the Target Reference Pose Skeleton Ghost Overlay.
///
/// Draws the ground-truth reference skeleton in a distinct warm Golden Amber
/// color with target joint crosshair rings, clearly distinguishable from the
/// user's live detected skeleton (which is rendered in Electric Cyan and Neon Lavender).
///
/// Correctly flips coordinates on the horizontal axis when [isFrontCamera] is true,
/// mirroring in unison with the camera preview and live pose skeleton.
class ReferencePosePainter extends CustomPainter {
  final Map<String, Offset> landmarks;
  final double opacity;
  final bool isFrontCamera;

  const ReferencePosePainter({
    required this.landmarks,
    required this.opacity,
    required this.isFrontCamera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty || opacity <= 0.01) return;

    // Golden Amber color palette for Target Reference Pose
    final Color boneGlowColor =
        const Color(0xFFFFB703).withValues(alpha: (opacity * 0.35).clamp(0.0, 1.0));
    final Color boneCoreColor =
        const Color(0xFFFFB703).withValues(alpha: (opacity * 0.90).clamp(0.0, 1.0));
    final Color jointRingColor =
        const Color(0xFFFFD166).withValues(alpha: (opacity * 0.95).clamp(0.0, 1.0));
    final Color jointDotColor =
        Colors.white.withValues(alpha: (opacity * 0.95).clamp(0.0, 1.0));

    // Convert normalized (0.0 to 1.0) landmark to screen coordinates.
    // Maps comfortably inside the visible camera preview area.
    Offset? project(String key) {
      final point = landmarks[key];
      if (point == null) return null;

      // In front-camera mode, flip horizontally to mirror user's perspective
      final double effectiveX = isFrontCamera ? (1.0 - point.dx) : point.dx;
      final double effectiveY = point.dy;

      final double screenX = effectiveX * size.width;
      // Vertically frame with top margin (below header/banners) and bottom margin (above shutter)
      final double usableHeight = size.height - 230;
      final double screenY = 110 + effectiveY * usableHeight;

      return Offset(screenX, screenY);
    }

    void drawBone(String k1, String k2) {
      final p1 = project(k1);
      final p2 = project(k2);
      if (p1 == null || p2 == null) return;

      // Outer glow pass
      final glowPaint = Paint()
        ..color = boneGlowColor
        ..strokeWidth = 7.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, glowPaint);

      // Core sharp pass
      final corePaint = Paint()
        ..color = boneCoreColor
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, corePaint);
    }

    // ── 1. Draw Connecting Bones ──────────────────────────────────────────
    // Torso & Shoulders
    drawBone('leftShoulder', 'rightShoulder');
    drawBone('leftShoulder', 'leftHip');
    drawBone('rightShoulder', 'rightHip');
    drawBone('leftHip', 'rightHip');

    // Left Arm
    drawBone('leftShoulder', 'leftElbow');
    drawBone('leftElbow', 'leftWrist');

    // Right Arm
    drawBone('rightShoulder', 'rightElbow');
    drawBone('rightElbow', 'rightWrist');

    // Left Leg
    drawBone('leftHip', 'leftKnee');
    drawBone('leftKnee', 'leftAnkle');

    // Right Leg
    drawBone('rightHip', 'rightKnee');
    drawBone('rightKnee', 'rightAnkle');

    // Head / Neck guide
    drawBone('nose', 'leftShoulder');
    drawBone('nose', 'rightShoulder');

    // ── 2. Draw Target Keypoints (Crosshair Rings) ─────────────────────────
    final ringPaint = Paint()
      ..color = jointRingColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final dotPaint = Paint()
      ..color = jointDotColor
      ..style = PaintingStyle.fill;

    for (final key in landmarks.keys) {
      final p = project(key);
      if (p == null) continue;

      // Outer target ring
      canvas.drawCircle(p, 6.5, ringPaint);
      // Inner target center dot
      canvas.drawCircle(p, 2.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ReferencePosePainter oldDelegate) {
    return oldDelegate.landmarks != landmarks ||
        oldDelegate.opacity != opacity ||
        oldDelegate.isFrontCamera != isFrontCamera;
  }
}

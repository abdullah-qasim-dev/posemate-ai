import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pose.dart';
import 'capture_preview_screen.dart';

/// Live camera preview screen with front/back camera switching and photo capture.
///
/// Can be opened with an optional [selectedPose] as the reference guide.
/// Aspect ratio is preserved naturally without stretching or distortion.
/// Front camera renders in normal orientation so right hand shows on the right side.
class CameraScreen extends StatefulWidget {
  final Pose? selectedPose;

  const CameraScreen({super.key, this.selectedPose});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  // ── State ────────────────────────────────────────────────────────────────
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0; // 0 = back, 1 = front (when available)
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  /// Pause camera when app goes to background, resume on foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _disposeController();
    } else if (state == AppLifecycleState.resumed) {
      _initController(_cameras[_selectedCameraIndex]);
    }
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Fetches available cameras and starts the controller.
  Future<void> _initCameras() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'No cameras found on this device.\nPlease run on a physical device or an emulator with camera support.';
        });
        return;
      }

      // Default to back camera; fall back to first camera found.
      _selectedCameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;

      await _initController(_cameras[_selectedCameraIndex]);
    } on CameraException catch (e) {
      setState(() {
        _isInitializing = false;
        _errorMessage = _friendlyError(e);
      });
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Failed to initialize camera: $e';
      });
    }
  }

  /// Initialises (or re-initialises) the [CameraController] for [camera].
  Future<void> _initController(CameraDescription camera) async {
    await _disposeController();

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = controller;

    try {
      await controller.initialize();
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } on CameraException catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = _friendlyError(e);
        });
      }
    }
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }

  // ── Camera Actions ────────────────────────────────────────────────────────

  /// Switches between front and back camera.
  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _isInitializing = true);

    // Find a camera with a different lens direction.
    final newIndex = _cameras.indexWhere(
      (c) => c.lensDirection != _cameras[_selectedCameraIndex].lensDirection,
    );
    if (newIndex == -1) return;

    _selectedCameraIndex = newIndex;
    await _initController(_cameras[_selectedCameraIndex]);
  }

  /// Captures a photo and navigates to [CapturePreviewScreen].
  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      HapticFeedback.mediumImpact();
      final XFile imageFile = await controller.takePicture();

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CapturePreviewScreen(
            imagePath: imageFile.path,
          ),
        ),
      );
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e)),
            backgroundColor: const Color(0xFF1E1030),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  bool get _isFrontCamera {
    if (_cameras.isEmpty) return false;
    return _cameras[_selectedCameraIndex].lensDirection ==
        CameraLensDirection.front;
  }

  String _friendlyError(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Camera permission was denied.\nPlease enable camera access in your device Settings to use PoseMate AI.';
      case 'CameraAccessRestricted':
        return 'Camera access is restricted on this device.';
      case 'AudioAccessDenied':
        return 'Microphone permission denied (not required for photos).';
      default:
        return 'Camera error: ${e.description ?? e.code}';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
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
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.selectedPose?.name ?? 'Camera',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.selectedPose != null)
            const Text(
              'Reference Pose Selected',
              style: TextStyle(
                color: Color(0xFFC4B5FD),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      actions: [
        if (_cameras.length >= 2)
          IconButton(
            onPressed: _isInitializing ? null : _flipCamera,
            icon: const Icon(
              Icons.flip_camera_ios_rounded,
              color: Colors.white,
              size: 26,
            ),
            tooltip: 'Flip camera',
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBody() {
    if (_isInitializing) return _buildLoadingState();
    if (_errorMessage != null) return _buildErrorState(_errorMessage!);
    return _buildCameraPreview();
  }

  /// Full-screen camera preview with controls overlaid at the bottom.
  Widget _buildCameraPreview() {
    final controller = _controller!;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── 1. Camera preview with exact aspect ratio (no stretch, normal orientation) ──
        _CameraPreviewWidget(
          controller: controller,
        ),

        // ── 2. Reference Pose guidance banner ──────────────────────────────
        if (widget.selectedPose != null)
          Positioned(
            top: 96,
            left: 16,
            right: 16,
            child: _buildPoseBanner(widget.selectedPose!),
          ),

        // ── 3. Bottom controls ─────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomControls(),
        ),

        // ── 4. Camera label chip ───────────────────────────────────────────
        Positioned(
          top: widget.selectedPose != null ? 178 : 96,
          left: 0,
          right: 0,
          child: Center(child: _buildCameraLabel()),
        ),
      ],
    );
  }

  Widget _buildPoseBanner(Pose pose) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1626).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF7C5CF0).withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Image.asset(
                pose.assetPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.accessibility_new_rounded,
                  color: Color(0xFF7C5CF0),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      pose.name,
                      style: const TextStyle(
                        color: Color(0xFFE6ECFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C5CF0).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pose.difficulty,
                        style: const TextStyle(
                          color: Color(0xFFC4B5FD),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  pose.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFA7B1CE).withValues(alpha: 0.9),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFC4B5FD),
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _showPoseDetails(pose),
          ),
        ],
      ),
    );
  }

  void _showPoseDetails(Pose pose) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F1626),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: Image.asset(
                      pose.assetPath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  pose.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE6ECFF),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${pose.category} • ${pose.difficulty}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7C5CF0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  pose.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFA7B1CE),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C5CF0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Got It',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
          stops: [0.0, 1.0],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Reference pose thumbnail (or spacer if none)
          if (widget.selectedPose != null)
            GestureDetector(
              onTap: () => _showPoseDetails(widget.selectedPose!),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF7C5CF0),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C5CF0).withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  widget.selectedPose!.assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.accessibility_new_rounded,
                    color: Color(0xFF7C5CF0),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 56),

          _ShutterButton(
            isCapturing: _isCapturing,
            onTap: _capturePhoto,
          ),

          _FlipButton(
            enabled: _cameras.length >= 2 && !_isInitializing,
            onTap: _flipCamera,
          ),
        ],
      ),
    );
  }

  Widget _buildCameraLabel() {
    final label = _isFrontCamera ? 'Front camera' : 'Back camera';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(label),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF7C5CF0)),
          SizedBox(height: 16),
          Text(
            'Starting camera\u2026',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              size: 64,
              color: Color(0xFF7C5CF0),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFE6ECFF),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C5CF0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _initCameras,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text(
                'Retry',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helper widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Renders the camera preview preserving natural body proportions without
/// distortion. In portrait orientation, portrait aspect ratio (height / width)
/// is computed so the preview fills the view without stretching horizontally.
/// Normal orientation is preserved so movements appear on their natural sides.
class _CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;

  const _CameraPreviewWidget({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Sensor aspect ratio from CameraController is reported in landscape (w / h > 1).
        // For portrait screen presentation, invert to get portrait aspect ratio (w / h < 1).
        double rawRatio = controller.value.aspectRatio;
        if (rawRatio <= 0) rawRatio = 16.0 / 9.0;
        final double cameraPortraitAspect =
            rawRatio > 1.0 ? (1.0 / rawRatio) : rawRatio;

        final double screenAspect =
            constraints.maxWidth / constraints.maxHeight;

        // Uniform scale factor ensuring the camera fills the screen without any stretching
        double scale = screenAspect / cameraPortraitAspect;
        if (scale < 1.0) {
          scale = 1.0 / scale;
        }

        return ClipRect(
          child: Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            color: Colors.black,
            child: Center(
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: AspectRatio(
                  aspectRatio: cameraPortraitAspect,
                  child: CameraPreview(controller),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated shutter / capture button.
class _ShutterButton extends StatelessWidget {
  final bool isCapturing;
  final VoidCallback onTap;

  const _ShutterButton({required this.isCapturing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isCapturing ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCapturing
              ? Colors.white.withValues(alpha: 0.6)
              : Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C5CF0).withValues(alpha: 0.55),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isCapturing
              ? const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF7C5CF0),
                  ),
                )
              : const Icon(
                  Icons.camera_alt_rounded,
                  color: Color(0xFF090D18),
                  size: 32,
                ),
        ),
      ),
    );
  }
}

/// Flip-camera shortcut button shown at the bottom-right.
class _FlipButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _FlipButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.15),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.flip_camera_ios_rounded,
          color: enabled ? Colors.white : Colors.white38,
          size: 26,
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io' show File, Platform;
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as ml_kit;

import '../models/pose.dart';
import '../models/pose_match_result.dart';
import '../painters/reference_pose_painter.dart';
import '../painters/skeleton_painter.dart';
import '../services/camera_image_converter.dart';
import '../services/photo_service.dart';
import '../services/pose_comparison_service.dart';
import 'capture_preview_screen.dart';

/// Display mode for the Reference Pose Ghost Overlay.
enum GhostOverlayMode {
  both,     // Semi-transparent reference photo + target wireframe skeleton
  image,    // Semi-transparent reference photo only
  skeleton, // Target wireframe skeleton only
  off,      // Hide reference ghost overlay
}

/// Live camera preview screen with Google ML Kit real-time pose detection,
/// Reference Pose Ghost Overlay with zoom and drag repositioning,
/// recent captured photos strip, automatic gallery saving, front/back switching, and photo capture.
class CameraScreen extends StatefulWidget {
  final Pose? selectedPose;

  const CameraScreen({super.key, this.selectedPose});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  // ── Camera State ──────────────────────────────────────────────────────────
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0; // 0 = back, 1 = front (when available)
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;

  // ── Photo Gallery & Recent Photos State ───────────────────────────────────
  List<File> _recentPhotos = [];
  bool _isLoadingPhotos = false;

  // ── Reference Pose & Ghost Overlay State ─────────────────────────────────
  Pose? _currentPose;
  double _overlayOpacity = 0.45;
  GhostOverlayMode _overlayMode = GhostOverlayMode.both;
  bool _isGhostControlsExpanded = true;

  // ── Zoom & Repositioning State ────────────────────────────────────────────
  double _overlayScale = 1.0;
  Offset _overlayOffset = Offset.zero;
  double _baseScale = 1.0;

  // ── Pose Detection State ──────────────────────────────────────────────────
  late final ml_kit.PoseDetector _poseDetector;
  final ValueNotifier<PoseDetectionResult?> _poseResultNotifier =
      ValueNotifier<PoseDetectionResult?>(null);

  bool _isStreaming = false;
  bool _isProcessingFrame = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize the active reference pose
    _currentPose = widget.selectedPose;

    // Initialize Google ML Kit Pose Detector in streaming mode for live camera feed
    _poseDetector = ml_kit.PoseDetector(
      options: ml_kit.PoseDetectorOptions(
        model: ml_kit.PoseDetectionModel.base,
        mode: ml_kit.PoseDetectionMode.stream,
      ),
    );

    // Load recent photos from local album storage
    _loadRecentPhotos();

    _initCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopImageStreamSync();
    _poseDetector.close();
    _poseResultNotifier.dispose();
    _disposeController();
    super.dispose();
  }

  /// Pause camera when app goes to background, resume on foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopImageStream();
      _disposeController();
    } else if (state == AppLifecycleState.resumed) {
      _loadRecentPhotos();
      if (_cameras.isNotEmpty) {
        _initController(_cameras[_selectedCameraIndex]);
      }
    }
  }

  // ── Photo Storage & Strip Loading ─────────────────────────────────────────

  /// Loads saved PoseMate AI photos, sorted newest first without duplicates.
  Future<void> _loadRecentPhotos() async {
    if (_isLoadingPhotos) return;
    _isLoadingPhotos = true;
    try {
      final photos = await PhotoService.getSavedPhotos();
      if (mounted) {
        setState(() {
          _recentPhotos = photos;
        });
      }
    } catch (e) {
      debugPrint('Error loading recent photos: $e');
    } finally {
      _isLoadingPhotos = false;
    }
  }

  /// Opens full-screen interactive preview for a saved photo with delete support.
  Future<void> _openPhotoPreview(File photo) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CapturePreviewScreen(
          imagePath: photo.path,
          isReviewOnly: true,
        ),
      ),
    );

    if (deleted == true && mounted) {
      await _loadRecentPhotos();
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

    // Use NV21 format on Android for zero-copy ML Kit processing.
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted) return;

      setState(() => _isInitializing = false);

      // Start real-time image streaming for pose detection
      await _startImageStream();
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
    await _stopImageStream();
    final controller = _controller;
    _controller = null;
    _poseResultNotifier.value = null;
    await controller?.dispose();
  }

  // ── Image Stream & AI Pose Detection ──────────────────────────────────────

  /// Starts frame processing pipeline from camera stream.
  Future<void> _startImageStream() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isStreaming ||
        controller.value.isStreamingImages) {
      return;
    }

    try {
      _isStreaming = true;
      await controller.startImageStream(_processCameraFrame);
    } catch (e) {
      debugPrint('Failed to start image stream: $e');
      _isStreaming = false;
    }
  }

  /// Stops frame streaming safely.
  Future<void> _stopImageStream() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        !_isStreaming ||
        !controller.value.isStreamingImages) {
      _isStreaming = false;
      return;
    }

    try {
      await controller.stopImageStream();
    } catch (e) {
      debugPrint('Failed to stop image stream: $e');
    } finally {
      _isStreaming = false;
    }
  }

  void _stopImageStreamSync() {
    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      try {
        controller.stopImageStream();
      } catch (_) {}
    }
    _isStreaming = false;
  }

  /// Processes each camera image frame through Google ML Kit Pose Detector.
  /// Throttled via [_isProcessingFrame] to prevent lag and ensure smooth 60fps.
  Future<void> _processCameraFrame(CameraImage image) async {
    if (!mounted ||
        _isProcessingFrame ||
        _isCapturing ||
        _controller == null ||
        !_isStreaming) {
      return;
    }

    _isProcessingFrame = true;

    try {
      final camera = _cameras[_selectedCameraIndex];
      final deviceOrientation = _controller?.value.deviceOrientation ??
          DeviceOrientation.portraitUp;

      // Convert CameraImage to ML Kit InputImage with rotation compensation
      final inputImage = CameraImageConverter.toInputImage(
        image: image,
        camera: camera,
        deviceOrientation: deviceOrientation,
      );

      if (inputImage == null) return;

      // Run Google ML Kit Pose Detection inference
      final poses = await _poseDetector.processImage(inputImage);

      // Compute live joint-angle match score against active reference pose
      final matchResult = (_currentPose != null && poses.isNotEmpty)
          ? PoseComparisonService.compare(
              userPose: poses.first,
              referencePose: _currentPose,
              isFrontCamera: _isFrontCamera,
            )
          : null;

      if (mounted && _isStreaming) {
        _poseResultNotifier.value = PoseDetectionResult(
          poses: poses,
          absoluteImageSize: Size(
            image.width.toDouble(),
            image.height.toDouble(),
          ),
          rotation: inputImage.metadata?.rotation ??
              ml_kit.InputImageRotation.rotation0deg,
          isFrontCamera: _isFrontCamera,
          matchResult: matchResult,
        );
      }
    } catch (e) {
      debugPrint('Error during pose detection: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  // ── Camera Actions & Automatic Gallery Saving ─────────────────────────────

  /// Switches between front and back camera.
  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _isInitializing) return;
    setState(() => _isInitializing = true);

    await _stopImageStream();
    _poseResultNotifier.value = null;

    final newIndex = _cameras.indexWhere(
      (c) => c.lensDirection != _cameras[_selectedCameraIndex].lensDirection,
    );
    if (newIndex == -1) {
      setState(() => _isInitializing = false);
      return;
    }

    _selectedCameraIndex = newIndex;
    await _initController(_cameras[_selectedCameraIndex]);
  }

  /// Captures a photo, automatically saves it to local app storage and device Gallery,
  /// refreshes the recent photos strip immediately, and opens [CapturePreviewScreen].
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

      // Temporarily stop stream to prevent camera resource conflict on Android
      await _stopImageStream();

      // Capture pure original photo (without overlay/skeleton artifacts)
      final XFile imageFile = await controller.takePicture();

      // 1. Automatically save to local directory and phone Gallery in album 'PoseMate AI'
      final saveResult = await PhotoService.saveCapturedPhoto(imageFile.path);
      final finalPath = saveResult.savedFile?.path ?? imageFile.path;

      // 2. Immediately reload recent photos strip to display the new thumbnail first
      await _loadRecentPhotos();

      // 3. Show success notification only after saving succeeds, or error if failed
      if (mounted) {
        if (saveResult.gallerySaved) {
          final message = saveResult.savedToAlbum
              ? 'Photo saved to Gallery (PoseMate AI)'
              : 'Photo saved to Gallery';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0F1626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          final errorMsg = saveResult.errorMessage ?? 'Permission denied or storage unavailable.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Failed to save to Gallery: $errorMsg',
                      style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF2A1215),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      if (!mounted) return;

      // 4. Open preview screen
      final deleted = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => CapturePreviewScreen(
            imagePath: finalPath,
          ),
        ),
      );

      // If user deleted the photo from preview, update strip
      if (deleted == true && mounted) {
        await _loadRecentPhotos();
      }

      // Resume live stream and pose tracking on return
      if (mounted) {
        await _startImageStream();
      }
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e)),
            backgroundColor: const Color(0xFF1E1030),
          ),
        );
        await _startImageStream();
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
            _currentPose?.name ?? 'Camera',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_currentPose != null)
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

  /// Full-screen camera preview with AI skeleton overlay, draggable/resizable reference ghost overlay,
  /// recent photos strip, and interactive overlay controls.
  Widget _buildCameraPreview() {
    final controller = _controller!;
    final pose = _currentPose;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── 1. Camera preview with exact aspect ratio (no stretch, normal orientation) ──
        _CameraPreviewWidget(
          controller: controller,
        ),

        // ── 2. Reference Pose Ghost Overlay (Image + Target Skeleton) with Drag & Zoom ──
        if (pose != null &&
            _overlayOpacity > 0.01 &&
            _overlayMode != GhostOverlayMode.off)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onScaleStart: (details) {
                _baseScale = _overlayScale;
              },
              onScaleUpdate: (details) {
                setState(() {
                  // Drag to reposition
                  _overlayOffset += details.focalPointDelta;
                  // Pinch to zoom
                  if (details.scale != 1.0) {
                    _overlayScale = (_baseScale * details.scale).clamp(0.5, 2.5);
                  }
                });
              },
              child: Transform.translate(
                offset: _overlayOffset,
                child: Transform.scale(
                  scale: _overlayScale,
                  alignment: Alignment.center,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Reference Ghost Photo Overlay
                      if (_overlayMode == GhostOverlayMode.both ||
                          _overlayMode == GhostOverlayMode.image)
                        _buildGhostImageOverlay(pose),

                      // Target Reference Skeleton (Golden Amber)
                      if (_overlayMode == GhostOverlayMode.both ||
                          _overlayMode == GhostOverlayMode.skeleton)
                        CustomPaint(
                          painter: ReferencePosePainter(
                            landmarks: pose.normalizedLandmarks,
                            opacity: _overlayOpacity,
                            isFrontCamera: _isFrontCamera,
                          ),
                          size: Size.infinite,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── 3. Live Detected ML Kit Skeleton (Cyan & Lavender) ─────────────
        ValueListenableBuilder<PoseDetectionResult?>(
          valueListenable: _poseResultNotifier,
          builder: (context, result, child) {
            if (result == null || result.poses.isEmpty) {
              return const SizedBox.shrink();
            }
            return CustomPaint(
              painter: SkeletonPainter(
                poses: result.poses,
                absoluteImageSize: result.absoluteImageSize,
                rotation: result.rotation,
                isFrontCamera: result.isFrontCamera,
              ),
              size: Size.infinite,
            );
          },
        ),

        // ── 4. Recent Photos Strip (Top, below AppBar) ────────────────────
        Positioned(
          top: 88,
          left: 0,
          right: 0,
          child: _buildRecentPhotosStrip(),
        ),

        // ── 5. Reference Pose guidance banner (top, below strip) ──────────
        if (pose != null)
          Positioned(
            top: 148,
            left: 16,
            right: 16,
            child: _buildPoseBanner(pose),
          ),

        // ── 6. AI Tracking Status Badge / No-Person Alert ─────────────────
        Positioned(
          top: pose != null ? 228 : 148,
          left: 16,
          right: 16,
          child: _buildPoseStatusIndicator(),
        ),

        // ── 7. Floating Ghost Opacity, Zoom, & Mode Controls Bar ───────────
        if (pose != null)
          Positioned(
            bottom: 116,
            left: 16,
            right: 16,
            child: _buildGhostControlsBar(),
          ),

        // ── 8. Bottom controls (Shutter, Flip, Pose info) ─────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomControls(),
        ),

        // ── 9. Camera label chip (Front / Back) ───────────────────────────
        Positioned(
          top: pose != null ? 280 : 200,
          left: 0,
          right: 0,
          child: Center(child: _buildCameraLabel()),
        ),
      ],
    );
  }

  // ── Recent Photos Strip Widget ───────────────────────────────────────────

  /// Compact horizontal scrollable strip displaying recent captured photos.
  /// Shows newest photo first. Tapping opens full-screen interactive preview.
  Widget _buildRecentPhotosStrip() {
    if (_recentPhotos.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1626).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_library_outlined,
                color: Color(0xFFA7B1CE),
                size: 15,
              ),
              SizedBox(width: 8),
              Text(
                'Your recent photos will appear here',
                style: TextStyle(
                  color: Color(0xFFA7B1CE),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _recentPhotos.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final photo = _recentPhotos[index];
          final isNewest = index == 0;

          return GestureDetector(
            onTap: () => _openPhotoPreview(photo),
            child: Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isNewest
                          ? const Color(0xFF7C5CF0)
                          : Colors.white.withValues(alpha: 0.25),
                      width: isNewest ? 2 : 1.2,
                    ),
                    boxShadow: [
                      if (isNewest)
                        BoxShadow(
                          color: const Color(0xFF7C5CF0).withValues(alpha: 0.45),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.file(
                    photo,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFF0F1626),
                      child: const Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white38,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                if (isNewest)
                  Positioned(
                    top: 3,
                    right: 3,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Ghost Overlay & Zoom/Opacity Controls ─────────────────────────────────

  /// Renders the semi-transparent reference pose photo aligned over the camera view.
  /// Correctly mirrored horizontally when using front camera.
  Widget _buildGhostImageOverlay(Pose pose) {
    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: _overlayOpacity.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(_isFrontCamera ? math.pi : 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 70.0),
              child: Image.asset(
                pose.assetPath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Floating glassmorphic control card with opacity slider, zoom slider,
  /// + and - zoom buttons, reset button, and overlay mode selector.
  Widget _buildGhostControlsBar() {
    final bool isPositionModified =
        _overlayScale != 1.0 || _overlayOffset != Offset.zero;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1626).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFB703).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row: Ghost label, percentage badge, zoom badge, mode toggles, and minimize button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB703).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.layers_rounded,
                  color: Color(0xFFFFB703),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Ghost',
                style: TextStyle(
                  color: Color(0xFFE6ECFF),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              // Opacity badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB703).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${(_overlayOpacity * 100).round()}%',
                  style: const TextStyle(
                    color: Color(0xFFFFD166),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Zoom scale badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C5CF0).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_overlayScale.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    color: Color(0xFFC4B5FD),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              // Overlay Mode Segmented Chips
              _buildModeChip('Both', GhostOverlayMode.both),
              const SizedBox(width: 4),
              _buildModeChip('Photo', GhostOverlayMode.image),
              const SizedBox(width: 4),
              _buildModeChip('Target', GhostOverlayMode.skeleton),
              const SizedBox(width: 4),
              _buildModeChip('Off', GhostOverlayMode.off),
              const SizedBox(width: 2),
              // Expand/collapse chevron
              InkWell(
                onTap: () {
                  setState(() {
                    _isGhostControlsExpanded = !_isGhostControlsExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    _isGhostControlsExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    color: const Color(0xFFA7B1CE),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

          // Collapsible controls: Opacity slider & Zoom controls
          if (_isGhostControlsExpanded) ...[
            const SizedBox(height: 8),

            // 1. Opacity Row
            Row(
              children: [
                const Icon(
                  Icons.opacity_rounded,
                  color: Color(0xFFA7B1CE),
                  size: 16,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Fade',
                  style: TextStyle(
                    color: Color(0xFFA7B1CE),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFFFFB703),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: const Color(0xFFFFB703),
                      overlayColor: const Color(0xFFFFB703).withValues(alpha: 0.2),
                      trackHeight: 3.5,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7.0,
                      ),
                    ),
                    child: Slider(
                      value: _overlayOpacity,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (value) {
                        setState(() {
                          _overlayOpacity = value;
                          if (_overlayOpacity > 0 &&
                              _overlayMode == GhostOverlayMode.off) {
                            _overlayMode = GhostOverlayMode.both;
                          }
                        });
                      },
                    ),
                  ),
                ),
                const Icon(
                  Icons.wb_sunny_rounded,
                  color: Color(0xFFFFD166),
                  size: 16,
                ),
              ],
            ),

            const SizedBox(height: 2),

            // 2. Zoom Row with - button, slider, + button, and reset button
            Row(
              children: [
                const Icon(
                  Icons.zoom_in_rounded,
                  color: Color(0xFFA7B1CE),
                  size: 16,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Size',
                  style: TextStyle(
                    color: Color(0xFFA7B1CE),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),

                // Minus Zoom Button
                _buildZoomButton(
                  icon: Icons.remove_rounded,
                  onTap: () {
                    setState(() {
                      _overlayScale = (_overlayScale - 0.1).clamp(0.5, 2.5);
                    });
                  },
                ),

                // Zoom Slider (0.5x to 2.5x)
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF7C5CF0),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: const Color(0xFF7C5CF0),
                      overlayColor: const Color(0xFF7C5CF0).withValues(alpha: 0.2),
                      trackHeight: 3.5,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7.0,
                      ),
                    ),
                    child: Slider(
                      value: _overlayScale,
                      min: 0.5,
                      max: 2.5,
                      onChanged: (value) {
                        setState(() {
                          _overlayScale = value;
                        });
                      },
                    ),
                  ),
                ),

                // Plus Zoom Button
                _buildZoomButton(
                  icon: Icons.add_rounded,
                  onTap: () {
                    setState(() {
                      _overlayScale = (_overlayScale + 0.1).clamp(0.5, 2.5);
                    });
                  },
                ),

                const SizedBox(width: 8),

                // Reset button (restores default size & position)
                InkWell(
                  onTap: () {
                    setState(() {
                      _overlayScale = 1.0;
                      _overlayOffset = Offset.zero;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPositionModified
                          ? const Color(0xFF7C5CF0).withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPositionModified
                            ? const Color(0xFF7C5CF0)
                            : Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.restart_alt_rounded,
                          color: isPositionModified
                              ? const Color(0xFFC4B5FD)
                              : Colors.white60,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Reset',
                          style: TextStyle(
                            color: isPositionModified
                                ? const Color(0xFFC4B5FD)
                                : Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Compact circular button for + and - zoom actions.
  Widget _buildZoomButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildModeChip(String label, GhostOverlayMode mode) {
    final bool isSelected = _overlayMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _overlayMode = mode;
          if (mode == GhostOverlayMode.off) {
            // Keep opacity stored but temporarily muted visually
          } else if (_overlayOpacity == 0.0) {
            _overlayOpacity = 0.45;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFB703)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isSelected ? const Color(0xFF090D18) : const Color(0xFFE6ECFF),
          ),
        ),
      ),
    );
  }

  // ── Guidance Banners & Status Badges ─────────────────────────────────────

  /// Shows whether a person is detected or guides user into frame.
  Widget _buildPoseStatusIndicator() {
    return ValueListenableBuilder<PoseDetectionResult?>(
      valueListenable: _poseResultNotifier,
      builder: (context, result, child) {
        final bool hasPerson = result?.hasPerson ?? false;

        Widget indicator;
        if (!hasPerson) {
          indicator = _buildNoPersonDetectedBanner();
        } else if (_currentPose != null && result?.matchResult != null) {
          indicator = _buildPoseMatchPill(result!.matchResult!);
        } else {
          indicator = _buildPersonDetectedPill(result!.detectedLandmarkCount);
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: indicator,
        );
      },
    );
  }

  /// Compact badge displaying the real-time pose match score and joint alignment count.
  Widget _buildPoseMatchPill(PoseMatchResult match) {
    final int score = match.matchScore.round();
    final bool isMatched = match.isMatch;

    final Color badgeColor = isMatched
        ? const Color(0xFF10B981) // Emerald green when matched (>= 75%)
        : (score >= 45
            ? const Color(0xFF7C5CF0) // Purple during good alignment
            : const Color(0xFFF59E0B)); // Amber when aligning

    return Center(
      key: const ValueKey('pose_match_pill'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1626).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.7),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: badgeColor.withValues(alpha: 0.25),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Match: $score% (${match.matchedJointCount}/${match.totalReferenceJoints} joints)',
              style: const TextStyle(
                color: Color(0xFFE6ECFF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact badge shown when body pose is actively tracked.
  Widget _buildPersonDetectedPill(int landmarkCount) {
    return Center(
      key: const ValueKey('person_detected'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1626).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Body Detected ($landmarkCount keypoints)',
              style: const TextStyle(
                color: Color(0xFFE6ECFF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Clear, friendly message banner shown when no person is detected in frame.
  Widget _buildNoPersonDetectedBanner() {
    return Center(
      key: const ValueKey('no_person_detected'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1626).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_search_rounded,
                color: Color(0xFFF59E0B),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No Person Detected',
                  style: TextStyle(
                    color: Color(0xFFE6ECFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Step into camera frame to track your pose',
                  style: TextStyle(
                    color: Color(0xFFA7B1CE),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
          GestureDetector(
            onTap: _showPoseSwitcherModal,
            child: ClipRRect(
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
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _showPoseSwitcherModal,
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
          ),
          // Quick Switch button
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: const Color(0xFFC4B5FD),
            ),
            onPressed: _showPoseSwitcherModal,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_horiz_rounded, size: 16),
                SizedBox(width: 3),
                Text('Switch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFC4B5FD),
              size: 19,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _showPoseDetails(pose),
          ),
        ],
      ),
    );
  }

  /// Opens a bottom sheet enabling users to switch between library poses seamlessly.
  void _showPoseSwitcherModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F1626),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, color: Color(0xFF7C5CF0), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Switch Reference Pose',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE6ECFF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: Pose.defaultPoses.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = Pose.defaultPoses[index];
                      final isSelected = item.id == _currentPose?.id;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _currentPose = item;
                            _overlayOffset = Offset.zero; // Center new pose
                          });
                          Navigator.of(context).pop();
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF7C5CF0).withValues(alpha: 0.16)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF7C5CF0)
                                  : Colors.white10,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Image.asset(
                                    item.assetPath,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFFE6ECFF),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.category} · ${item.difficulty}',
                                      style: const TextStyle(
                                        color: Color(0xFFA7B1CE),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF7C5CF0),
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          // Reference pose thumbnail shortcut OR latest photo shortcut
          if (_currentPose != null)
            GestureDetector(
              onTap: _showPoseSwitcherModal,
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
                  _currentPose!.assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.accessibility_new_rounded,
                    color: Color(0xFF7C5CF0),
                  ),
                ),
              ),
            )
          else if (_recentPhotos.isNotEmpty)
            GestureDetector(
              onTap: () => _openPhotoPreview(_recentPhotos.first),
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
                child: Image.file(
                  _recentPhotos.first,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.photo_library_rounded,
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
            'Starting camera & AI detector\u2026',
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

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Helper utility to convert live [CameraImage] frames into [InputImage]
/// instances compatible with Google ML Kit Pose Detection.
class CameraImageConverter {
  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Converts a [CameraImage] into an [InputImage] by calculating sensor
  /// and device rotation, extracting the raw byte buffer, and mapping the format.
  static InputImage? toInputImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    // 1. Calculate rotation compensation based on platform and camera lens
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      final deviceDegrees = _orientations[deviceOrientation] ?? 0;
      int rotationCompensation;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + deviceDegrees) % 360;
      } else {
        rotationCompensation = (sensorOrientation - deviceDegrees + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    rotation ??= InputImageRotation.rotation0deg;

    // 2. Prepare byte payload and format
    InputImageFormat? format;
    Uint8List bytes;

    if (Platform.isAndroid) {
      format = InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;

      if (image.planes.length == 1) {
        bytes = image.planes[0].bytes;
      } else if (image.planes.length == 3) {
        // Multi-plane YUV420_888 converted to single-plane NV21
        bytes = _yuv420ToNv21(image);
        format = InputImageFormat.nv21;
      } else {
        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        bytes = allBytes.done().buffer.asUint8List();
      }
    } else if (Platform.isIOS) {
      format = InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.bgra8888;

      if (image.planes.length == 1) {
        bytes = image.planes[0].bytes;
      } else {
        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        bytes = allBytes.done().buffer.asUint8List();
      }
    } else {
      return null;
    }

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: metadata,
    );
  }

  /// Converts Android multi-plane YUV420_888 frames into a single NV21 byte buffer.
  /// NV21 is the most widely supported format on Google ML Kit Android.
  static Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = width * height ~/ 2;
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    final Plane yPlane = image.planes[0];
    final Uint8List yBuffer = yPlane.bytes;

    if (yPlane.bytesPerRow == width) {
      nv21.setRange(0, ySize, yBuffer);
    } else {
      int yOffset = 0;
      int nv21Index = 0;
      for (int row = 0; row < height; row++) {
        nv21.setRange(nv21Index, nv21Index + width, yBuffer, yOffset);
        yOffset += yPlane.bytesPerRow;
        nv21Index += width;
      }
    }

    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];
    final Uint8List uBuffer = uPlane.bytes;
    final Uint8List vBuffer = vPlane.bytes;

    final int uRowStride = uPlane.bytesPerRow;
    final int vRowStride = vPlane.bytesPerRow;
    final int uPixelStride = uPlane.bytesPerPixel ?? 1;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;

    final int uvHeight = height ~/ 2;
    final int uvWidth = width ~/ 2;
    int nv21Index = ySize;

    for (int row = 0; row < uvHeight; row++) {
      for (int col = 0; col < uvWidth; col++) {
        final int uIndex = row * uRowStride + col * uPixelStride;
        final int vIndex = row * vRowStride + col * vPixelStride;

        nv21[nv21Index++] = vBuffer[vIndex];
        nv21[nv21Index++] = uBuffer[uIndex];
      }
    }

    return nv21;
  }
}

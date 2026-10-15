import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

/// Result object returned by [PhotoService.saveCapturedPhoto].
class SavePhotoResult {
  final bool success;
  final File? savedFile;
  final bool gallerySaved;
  final bool savedToAlbum;
  final String? errorMessage;

  const SavePhotoResult({
    required this.success,
    this.savedFile,
    this.gallerySaved = false,
    this.savedToAlbum = false,
    this.errorMessage,
  });
}

/// Service managing photo persistence, device gallery export (via Gal),
/// and local photo retrieval for PoseMate AI.
class PhotoService {
  static const String albumName = 'PoseMate AI';

  /// Returns the app's dedicated local storage directory for captured photos.
  static Future<Directory> getLocalPhotosDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${appDir.path}/PoseMatePhotos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    return photosDir;
  }

  /// Saves a captured camera photo to permanent local storage with a unique
  /// timestamp filename, then automatically saves it to the phone's native
  /// Gallery/MediaStore (in album "PoseMate AI" if supported).
  ///
  /// Does NOT save temporary preview frames or reference overlays; saves only
  /// the pure captured camera photo.
  static Future<SavePhotoResult> saveCapturedPhoto(String tempImagePath) async {
    try {
      final tempFile = File(tempImagePath);
      if (!await tempFile.exists()) {
        return const SavePhotoResult(
          success: false,
          gallerySaved: false,
          errorMessage: 'Captured image file was not found.',
        );
      }

      // 1. Generate unique timestamp-based filename to prevent overwriting
      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}_${now.millisecond.toString().padLeft(3, '0')}';
      final fileName = 'PoseMate_${dateStr}_$timeStr.jpg';

      final photosDir = await getLocalPhotosDirectory();
      final permanentFile = File('${photosDir.path}/$fileName');

      // 2. Copy the captured image to permanent local storage
      await tempFile.copy(permanentFile.path);

      // 3. Export to phone Gallery / MediaStore via Gal package
      bool gallerySaved = false;
      bool savedToAlbum = false;
      String? galleryError;

      // Request / verify gallery access permissions across Android versions
      bool hasAlbumAccess = false;
      try {
        hasAlbumAccess = await Gal.hasAccess(toAlbum: true);
        if (!hasAlbumAccess) {
          hasAlbumAccess = await Gal.requestAccess(toAlbum: true);
        }
      } catch (e) {
        debugPrint('Album access check error: $e');
      }

      // First attempt: Save into dedicated 'PoseMate AI' album
      if (hasAlbumAccess) {
        try {
          await Gal.putImage(permanentFile.path, album: albumName);
          gallerySaved = true;
          savedToAlbum = true;
        } catch (albumErr) {
          debugPrint('Saving to album "$albumName" failed ($albumErr). Falling back to default gallery...');
        }
      }

      // Second attempt / Fallback: Save directly to Gallery without album
      if (!gallerySaved) {
        bool hasGeneralAccess = false;
        try {
          hasGeneralAccess = await Gal.hasAccess(toAlbum: false);
          if (!hasGeneralAccess) {
            hasGeneralAccess = await Gal.requestAccess(toAlbum: false);
          }
        } catch (e) {
          debugPrint('General gallery access check error: $e');
        }

        try {
          await Gal.putImage(permanentFile.path);
          gallerySaved = true;
        } on GalException catch (e) {
          galleryError = e.type.message;
          debugPrint('GalException saving directly to gallery: ${e.type.message}');
        } catch (e) {
          galleryError = e.toString();
          debugPrint('Error saving directly to gallery: $e');
        }
      }

      return SavePhotoResult(
        success: true,
        savedFile: permanentFile,
        gallerySaved: gallerySaved,
        savedToAlbum: savedToAlbum,
        errorMessage: gallerySaved ? null : galleryError,
      );
    } catch (e) {
      debugPrint('Error in saveCapturedPhoto: $e');
      return SavePhotoResult(
        success: false,
        gallerySaved: false,
        errorMessage: 'Failed to process photo: $e',
      );
    }
  }

  /// Loads all existing PoseMate AI photos from local storage, sorted newest first.
  /// Eliminates duplicate entries.
  static Future<List<File>> getSavedPhotos() async {
    try {
      final photosDir = await getLocalPhotosDirectory();
      final entities = await photosDir.list().toList();

      final files = <File>[];
      final seenPaths = <String>{};

      for (final entity in entities) {
        if (entity is File) {
          final lower = entity.path.toLowerCase();
          if ((lower.endsWith('.jpg') ||
                  lower.endsWith('.jpeg') ||
                  lower.endsWith('.png')) &&
              !seenPaths.contains(entity.path)) {
            seenPaths.add(entity.path);
            files.add(entity);
          }
        }
      }

      // Sort newest first based on last modified time
      files.sort((a, b) {
        final aTime = a.lastModifiedSync();
        final bTime = b.lastModifiedSync();
        return bTime.compareTo(aTime);
      });

      return files;
    } catch (e) {
      debugPrint('Error retrieving saved photos: $e');
      return [];
    }
  }

  /// Deletes a photo from local app storage and reports status.
  static Future<bool> deletePhoto(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting photo ($filePath): $e');
      return false;
    }
  }
}

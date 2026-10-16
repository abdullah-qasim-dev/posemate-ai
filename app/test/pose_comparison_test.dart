import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as ml_kit;
import 'package:posemate_repo/models/pose.dart';
import 'package:posemate_repo/models/pose_match_result.dart';
import 'package:posemate_repo/services/pose_comparison_service.dart';

void main() {
  group('Joint-Angle Calculation (calculateAngle)', () {
    test('calculates 90-degree right angle accurately', () {
      final angle = PoseComparisonService.calculateAngle(
        first: const Offset(1, 0),
        vertex: const Offset(0, 0),
        second: const Offset(0, 1),
      );
      expect(angle, isNotNull);
      expect(angle!, closeTo(90.0, 0.001));
    });

    test('calculates 180-degree straight angle accurately', () {
      final angle = PoseComparisonService.calculateAngle(
        first: const Offset(-1, 0),
        vertex: const Offset(0, 0),
        second: const Offset(1, 0),
      );
      expect(angle, isNotNull);
      expect(angle!, closeTo(180.0, 0.001));
    });

    test('calculates 45-degree angle accurately', () {
      final angle = PoseComparisonService.calculateAngle(
        first: const Offset(1, 0),
        vertex: const Offset(0, 0),
        second: const Offset(1, 1),
      );
      expect(angle, isNotNull);
      expect(angle!, closeTo(45.0, 0.001));
    });

    test('calculates 0-degree angle for colinear overlapping rays', () {
      final angle = PoseComparisonService.calculateAngle(
        first: const Offset(1, 0),
        vertex: const Offset(0, 0),
        second: const Offset(2, 0),
      );
      expect(angle, isNotNull);
      expect(angle!, closeTo(0.0, 0.001));
    });

    test('returns null for coincident points where vertex equals endpoint', () {
      final angle = PoseComparisonService.calculateAngle(
        first: const Offset(0, 0),
        vertex: const Offset(0, 0),
        second: const Offset(1, 0),
      );
      expect(angle, isNull);
    });

    test('returns null when coordinates are NaN or infinite', () {
      expect(
        PoseComparisonService.calculateAngle(
          first: const Offset(double.nan, 0),
          vertex: const Offset(0, 0),
          second: const Offset(1, 0),
        ),
        isNull,
      );

      expect(
        PoseComparisonService.calculateAngle(
          first: const Offset(1, 0),
          vertex: const Offset(0, double.infinity),
          second: const Offset(1, 0),
        ),
        isNull,
      );
    });
  });

  group('Reference Pose Angle Extraction', () {
    test('extracts expected angles from default T-Pose', () {
      final tPose = Pose.defaultPoses.firstWhere((p) => p.id == 't_pose');
      final angles = PoseComparisonService.extractReferenceAngles(tPose);

      // In T-pose, outstretched arms should have ~180° elbow angle
      expect(angles[JointType.leftElbow], isNotNull);
      expect(angles[JointType.leftElbow]!, closeTo(180.0, 1.0));
      expect(angles[JointType.rightElbow], isNotNull);
      expect(angles[JointType.rightElbow]!, closeTo(180.0, 1.0));

      // Shoulders with torso should be roughly perpendicular (~90°-97°)
      expect(angles[JointType.leftShoulder], isNotNull);
      expect(angles[JointType.leftShoulder]!, inInclusiveRange(85.0, 105.0));

      // Straight legs should have ~180° knee angles
      expect(angles[JointType.leftKnee], isNotNull);
      expect(angles[JointType.leftKnee]!, closeTo(180.0, 1.0));
    });

    test('extracts bent elbow angle from Hands on Hips pose', () {
      final handsOnHips =
          Pose.defaultPoses.firstWhere((p) => p.id == 'hands_on_hips');
      final angles = PoseComparisonService.extractReferenceAngles(handsOnHips);

      // In Hands on Hips, elbow is bent at roughly ~85°-95°
      expect(angles[JointType.leftElbow], isNotNull);
      expect(angles[JointType.leftElbow]!, inInclusiveRange(80.0, 100.0));
    });
  });

  group('Pose Comparison & Match Scoring', () {
    test('identical landmark poses score 100% with all joints matched', () {
      final tPose = Pose.defaultPoses.firstWhere((p) => p.id == 't_pose');

      final result = PoseComparisonService.compareLandmarkMaps(
        userLandmarks: tPose.normalizedLandmarks,
        referenceLandmarks: tPose.normalizedLandmarks,
      );

      expect(result.hasPerson, isTrue);
      expect(result.matchScore, closeTo(100.0, 0.001));
      expect(result.matchedJointCount, equals(result.totalReferenceJoints));
      expect(result.totalReferenceJoints, equals(8));
      expect(result.isMatch, isTrue);

      // All individual joint scores should be 1.0 with 0° difference
      for (final comparison in result.jointComparisons.values) {
        expect(comparison.angleDifference, closeTo(0.0, 0.001));
        expect(comparison.score, equals(1.0));
      }
    });

    test('small natural human variation scores realistically high (85-95%)', () {
      final tPose = Pose.defaultPoses.firstWhere((p) => p.id == 't_pose');
      // Create a slightly perturbed pose (left wrist slightly lower)
      final perturbedLandmarks = Map<String, Offset>.from(tPose.normalizedLandmarks);
      perturbedLandmarks['leftWrist'] = const Offset(0.10, 0.29); // shifted by 0.03

      final result = PoseComparisonService.compareLandmarkMaps(
        userLandmarks: perturbedLandmarks,
        referenceLandmarks: tPose.normalizedLandmarks,
      );

      expect(result.matchScore, inInclusiveRange(85.0, 99.0));
      expect(result.isMatch, isTrue);
    });

    test('substantially different poses score low and isMatch is false', () {
      final tPose = Pose.defaultPoses.firstWhere((p) => p.id == 't_pose');
      final handsOnHips =
          Pose.defaultPoses.firstWhere((p) => p.id == 'hands_on_hips');

      // T-Pose arms are straight (180°), while Hands on Hips are bent (90°)
      final result = PoseComparisonService.compareLandmarkMaps(
        userLandmarks: handsOnHips.normalizedLandmarks,
        referenceLandmarks: tPose.normalizedLandmarks,
      );

      // Score should reflect large differences in arm angles
      expect(result.matchScore, lessThan(PoseMatchResult.defaultMatchThreshold));
      expect(result.isMatch, isFalse);
    });

    test('missing essential landmarks appropriately penalizes the score', () {
      final tPose = Pose.defaultPoses.firstWhere((p) => p.id == 't_pose');

      // Only provide upper body landmarks (shoulders, elbows, wrists)
      // Omit all lower body landmarks (hips, knees, ankles)
      final upperBodyOnly = <String, Offset>{
        'nose': tPose.normalizedLandmarks['nose']!,
        'leftShoulder': tPose.normalizedLandmarks['leftShoulder']!,
        'rightShoulder': tPose.normalizedLandmarks['rightShoulder']!,
        'leftElbow': tPose.normalizedLandmarks['leftElbow']!,
        'rightElbow': tPose.normalizedLandmarks['rightElbow']!,
        'leftWrist': tPose.normalizedLandmarks['leftWrist']!,
        'rightWrist': tPose.normalizedLandmarks['rightWrist']!,
      };

      final result = PoseComparisonService.compareLandmarkMaps(
        userLandmarks: upperBodyOnly,
        referenceLandmarks: tPose.normalizedLandmarks,
      );

      // Only 2 joints (leftElbow, rightElbow) can be computed without hips/knees
      expect(result.matchedJointCount, equals(2));
      expect(result.totalReferenceJoints, equals(8));
      // Even if the 2 elbows matched 100%, score must not exceed 25% (2 / 8)
      expect(result.matchScore, closeTo(25.0, 0.1));
      expect(result.isMatch, isFalse);
    });

    test('empty or null user pose returns 0% score and hasPerson false', () {
      final tPose = Pose.defaultPoses.firstWhere((p) => p.id == 't_pose');

      final nullResult = PoseComparisonService.compareLandmarkMaps(
        userLandmarks: null,
        referenceLandmarks: tPose.normalizedLandmarks,
      );
      expect(nullResult.matchScore, equals(0.0));
      expect(nullResult.hasPerson, isFalse);
      expect(nullResult.isMatch, isFalse);

      final emptyResult = PoseComparisonService.compareLandmarkMaps(
        userLandmarks: const {},
        referenceLandmarks: tPose.normalizedLandmarks,
      );
      expect(emptyResult.matchScore, equals(0.0));
      expect(emptyResult.hasPerson, isFalse);
    });

    test('empty or null reference pose returns empty result gracefully', () {
      final result = PoseComparisonService.compareLandmarkMaps(
        userLandmarks: {'nose': const Offset(0.5, 0.5)},
        referenceLandmarks: null,
      );
      expect(result.matchScore, equals(0.0));
      expect(result.totalReferenceJoints, equals(0));
      expect(result.hasPerson, isFalse);
    });
  });

  group('ML Kit Pose Landmark Integration', () {
    test('extracts angles from ml_kit.Pose with confidence thresholding', () {
      // Construct a mock ML Kit pose with high-confidence landmarks
      final landmarks = <ml_kit.PoseLandmarkType, ml_kit.PoseLandmark>{
        ml_kit.PoseLandmarkType.leftShoulder: ml_kit.PoseLandmark(
          type: ml_kit.PoseLandmarkType.leftShoulder,
          x: 100,
          y: 200,
          z: 0,
          likelihood: 0.95,
        ),
        ml_kit.PoseLandmarkType.leftElbow: ml_kit.PoseLandmark(
          type: ml_kit.PoseLandmarkType.leftElbow,
          x: 100,
          y: 300,
          z: 0,
          likelihood: 0.90,
        ),
        ml_kit.PoseLandmarkType.leftWrist: ml_kit.PoseLandmark(
          type: ml_kit.PoseLandmarkType.leftWrist,
          x: 200,
          y: 300,
          z: 0,
          likelihood: 0.85,
        ),
      };

      final mockPose = ml_kit.Pose(landmarks: landmarks);
      final angles = PoseComparisonService.extractUserAngles(
        userPose: mockPose,
        isFrontCamera: false,
      );

      // (100, 200) -> (100, 300) -> (200, 300) is a 90-degree bend
      expect(angles[JointType.leftElbow], isNotNull);
      expect(angles[JointType.leftElbow]!.angleDegrees, closeTo(90.0, 0.001));
      expect(angles[JointType.leftElbow]!.confidence, closeTo(0.90, 0.001));
    });

    test('ignores low confidence landmarks below threshold', () {
      final landmarks = <ml_kit.PoseLandmarkType, ml_kit.PoseLandmark>{
        ml_kit.PoseLandmarkType.leftShoulder: ml_kit.PoseLandmark(
          type: ml_kit.PoseLandmarkType.leftShoulder,
          x: 100,
          y: 200,
          z: 0,
          likelihood: 0.95,
        ),
        ml_kit.PoseLandmarkType.leftElbow: ml_kit.PoseLandmark(
          type: ml_kit.PoseLandmarkType.leftElbow,
          x: 100,
          y: 300,
          z: 0,
          likelihood: 0.30, // below 0.5 threshold
        ),
        ml_kit.PoseLandmarkType.leftWrist: ml_kit.PoseLandmark(
          type: ml_kit.PoseLandmarkType.leftWrist,
          x: 200,
          y: 300,
          z: 0,
          likelihood: 0.95,
        ),
      };

      final mockPose = ml_kit.Pose(landmarks: landmarks);
      final angles = PoseComparisonService.extractUserAngles(
        userPose: mockPose,
        isFrontCamera: false,
        minLikelihood: 0.5,
      );

      // Left elbow should not be extracted due to low confidence
      expect(angles[JointType.leftElbow], isNull);
    });

    test('supports front camera mirror mapping', () {
      final landmarks = <ml_kit.PoseLandmarkType, ml_kit.PoseLandmark>{
        ml_kit.PoseLandmarkType.rightShoulder: ml_kit.PoseLandmark(
          type: ml_kit.PoseLandmarkType.rightShoulder,
          x: 100,
          y: 200,
          z: 0,
          likelihood: 0.9,
        ),
        ml_kit.PoseLandmarkType.rightElbow: ml_kit.PoseLandmark(
          type: ml_kit.PoseLandmarkType.rightElbow,
          x: 100,
          y: 300,
          z: 0,
          likelihood: 0.9,
        ),
        ml_kit.PoseLandmarkType.rightWrist: ml_kit.PoseLandmark(
          type: ml_kit.PoseLandmarkType.rightWrist,
          x: 200,
          y: 300,
          z: 0,
          likelihood: 0.9,
        ),
      };

      final mockPose = ml_kit.Pose(landmarks: landmarks);

      // In front camera mirror mode, user's right arm maps to reference leftElbow
      final mirroredAngles = PoseComparisonService.extractUserAngles(
        userPose: mockPose,
        isFrontCamera: true,
      );
      expect(mirroredAngles[JointType.leftElbow], isNotNull);
      expect(mirroredAngles[JointType.leftElbow]!.angleDegrees, closeTo(90.0, 0.001));

      // In back camera mode, it maps to rightElbow
      final unmirroredAngles = PoseComparisonService.extractUserAngles(
        userPose: mockPose,
        isFrontCamera: false,
      );
      expect(unmirroredAngles[JointType.rightElbow], isNotNull);
      expect(unmirroredAngles[JointType.rightElbow]!.angleDegrees, closeTo(90.0, 0.001));
    });
  });
}

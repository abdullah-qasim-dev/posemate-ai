import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posemate_repo/main.dart';
import 'package:posemate_repo/models/pose.dart';
import 'package:posemate_repo/screens/camera_screen.dart';
import 'package:posemate_repo/screens/capture_preview_screen.dart';
import 'package:posemate_repo/screens/pose_library_screen.dart';

void main() {
  testWidgets('PoseMate AI Home Screen renders correctly at 390x844px without overflow',
      (WidgetTester tester) async {
    // Set 390x844px viewport as required
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const PoseMateApp());
    await tester.pumpAndSettle();

    // Verify Header
    expect(find.text('PoseMate AI'), findsOneWidget);
    expect(find.text('Pose-Guided Photography'), findsOneWidget);

    // Verify Hero Card
    expect(find.text('Smart pose guidance'), findsOneWidget);
    expect(find.text('Pose with confidence.\nLet AI perfect your shot.'), findsOneWidget);

    // Verify Buttons
    expect(find.text('Choose from pose library'), findsOneWidget);
    expect(find.text('Select from gallery'), findsOneWidget);

    // Verify "How it works" section and compact cards
    expect(find.text('How it works'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Pick a pose'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Follow the\nghost'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Auto-capture'), findsOneWidget);

    // Verify Footer
    expect(
      find.text('On-Device AI · No images sent to the cloud'),
      findsOneWidget,
    );

    // Verify no play icon anywhere on the screen
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });

  testWidgets('Navigation to Saved Photos screen works', (WidgetTester tester) async {
    await tester.pumpWidget(const PoseMateApp());
    await tester.pumpAndSettle();

    // Tap Saved Photos circular button (collections icon)
    await tester.tap(find.byIcon(Icons.collections_outlined));
    await tester.pumpAndSettle();

    // Verify Saved Photos screen appears
    expect(find.byType(SavedPhotosScreen), findsOneWidget);
    expect(find.text('Saved Photos'), findsWidgets);

    // Pop back to home
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Select from gallery tap handles cancellation gracefully',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PoseMateApp());
    await tester.pumpAndSettle();

    // Tap "Select from gallery" button
    await tester.tap(find.text('Select from gallery'));
    await tester.pumpAndSettle();

    // Since in unit test environment picker returns null or does not navigate,
    // HomeScreen remains safely mounted with no unhandled exceptions.
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('GalleryPreviewScreen displays image preview and status',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GalleryPreviewScreen(imagePath: 'dummy_pose.jpg'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gallery Image Preview'), findsOneWidget);
    expect(
      find.text('Reference image loaded. Ready for pose alignment in next step.'),
      findsOneWidget,
    );
  });

  testWidgets('CapturePreviewScreen renders retake and use-photo actions',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CapturePreviewScreen(imagePath: 'dummy_capture.jpg'),
      ),
    );
    await tester.pumpAndSettle();

    // App bar title
    expect(find.text('Photo Preview'), findsOneWidget);

    // Action buttons
    expect(find.text('Retake'), findsOneWidget);
    expect(find.text('Use Photo'), findsOneWidget);
  });

  testWidgets('CameraScreen widget can be instantiated and shows a Scaffold',
      (WidgetTester tester) async {
    // CameraScreen requires a real camera hardware; in a unit test environment
    // availableCameras() will return [] or throw, and the screen must handle
    // this gracefully by showing the error/empty state rather than crashing.
    await tester.pumpWidget(
      const MaterialApp(
        home: CameraScreen(),
      ),
    );
    // Allow async init to settle (will enter error state on CI / host machine)
    await tester.pump(const Duration(seconds: 1));

    // The Scaffold should always be present regardless of camera availability.
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('Navigation to Pose Library displays real poses and opens camera only on pose selection',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PoseMateApp());
    await tester.pumpAndSettle();

    // Tap "Choose from pose library"
    await tester.tap(find.text('Choose from pose library'));
    await tester.pumpAndSettle();

    // Verify PoseLibraryScreen appears, not CameraScreen immediately
    expect(find.byType(PoseLibraryScreen), findsOneWidget);
    expect(find.text('Pose Library'), findsOneWidget);

    // Verify initial visible poses are shown
    expect(find.text('T-Pose'), findsOneWidget);
    expect(find.text('Hands on Hips'), findsOneWidget);

    // Tap on the visible T-Pose card to open camera with selected pose
    await tester.tap(find.text('T-Pose'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Now CameraScreen is opened with T-Pose reference
    expect(find.byType(CameraScreen), findsOneWidget);
    expect(find.text('T-Pose'), findsWidgets);
  });

  testWidgets('CameraScreen with selected reference pose renders correctly and gracefully handles camera availability',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CameraScreen(selectedPose: Pose.defaultPoses.first),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Scaffold and AppBar always render with reference pose title
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('T-Pose'), findsWidgets);
    expect(find.text('Reference Pose Selected'), findsOneWidget);
  });
}


# PoseMate AI

## 1. Project Overview & Problem Statement
PoseMate AI is an Android mobile app that helps a person copy a reference pose while taking a mirror selfie or a pose photo (full-body or upper-body). The app shows a faint "ghost" image of the reference pose on top of the live camera view. The user moves their body until it matches the ghost. The app checks the user's pose using AI and tells them what to fix. When the pose matches, the app takes the photo by itself.

**Problem:** When we try to copy a pose from a picture, we keep looking at the reference, then at the camera, then change our arms or legs, and take many photos before one looks right. This is even harder when we are alone and using a mirror or a phone timer, or when we are taking someone else's photo and cannot explain the pose easily. A normal camera does not tell us how our pose is different from the reference. PoseMate AI solves this by showing the reference on the camera screen and giving live feedback.

## 2. Proposed Solution

1. The user picks a pose from the built-in pose library, or uploads their own reference image.
2. The app finds the body points (shoulders, elbows, wrists, knees, etc.) of the person in the reference image. If no clear person is found, the app shows a message and does not use that image.
3. The reference is shown as a semi-transparent ghost photo over the live camera view. The user can also turn on a skeleton view of the pose.
4. The app finds the user's body points from the live camera and compares them with the reference using joint angles. Only the body parts that are clearly visible in both the reference and the live camera are compared. For example, if the reference is an upper-body pose, only the shoulders, elbows and wrists are checked and the legs are ignored.
5. The app shows short hints like "raise your left arm a little".
6. When the pose stays matched for about 2 seconds, the app captures the photo automatically. The user can also press the capture button at any time.

The app works with both the front and back camera. All pose detection runs on the phone.

## 3. Objectives & Expected Outcomes

**Objectives**
- Build an Android app with a live camera view and pose selection.
- Add a built-in pose library and support for uploading a custom reference image.
- Use a ready-made AI model (Google ML Kit Pose Detection) to find body points in the reference image and in the live camera.
- Support both full-body and upper-body poses by comparing only the body points that are visible.
- Check uploaded images and show a message if no clear person is found.
- Show the reference as a ghost photo over the camera, with an optional skeleton view.
- Compare the user's pose with the reference using joint angles and give a match score.
- Give simple rule-based hints for the body parts that need to move.
- Take the photo automatically when the pose is matched, with a manual capture button also available.

**Expected Outcomes**
- A working Android prototype that guides the user to a selected pose.
- A small pose library (5-10 poses, full-body and upper-body).
- A live match score and body-part hints.
- Automatic photo capture and saving on the phone.

## 4. Target Users

- People who take mirror selfies or pose photos, of themselves or of someone else.
- Social media users who want to copy poses from reference pictures.
- Beginners who do not know how to stand or pose for a photo.
- Content creators who want to get the same pose again and again.

## 5. Key Features / Deliverables

**Features**
1. **Pose library:** 5-10 built-in reference poses (full-body and upper-body).
2. **Custom reference image:** upload your own image that has one clearly visible person (full-body or upper-body). If no pose is found, the app shows a message and does not use the image.
3. **Live camera:** front and back camera with a flip button.
4. **Ghost overlay:** semi-transparent reference photo on top of the live camera view.
5. **Skeleton toggle:** option to show or hide the skeleton of the reference pose.
6. **AI pose detection:** Google ML Kit Pose Detection finds body points from images and live camera frames.
7. **Pose matching:** angles of the joints that are visible in both the reference and the live camera are compared to get a match score.
8. **Live hints:** short rule-based hints for the visible body parts that need to change.
9. **Auto-capture:** photo is taken when the pose stays matched for about 2 seconds.
10. **Manual capture:** capture button for taking a photo anytime.
11. **Saved photos:** captured photos are saved on the phone.

**Deliverables**
- Android app prototype (APK).
- Source code with setup steps.
- Demo video and screenshots.
- Project documentation.


## 6. Implementation Plan & Timeline

| Dates | Work |
|---|---|
| 7–8 Oct | Finalize the project idea, define the MVP scope, identify core features, and select the pose detection approach. |
| 9–10 Oct | Set up Flutter and Android Studio, configure the development environment, implement the camera preview (front and back), and integrate ML Kit pose detection. |
| 11–12 Oct | Develop the pose selection screen, add the pose library, and implement custom image upload with a check for a clear, detectable pose. |
| 13–15 Oct | Implement the ghost overlay and skeleton toggle, develop joint angle comparison, and calculate the pose match score. |
| 16–18 Oct | Implement rule-based hints, add auto-capture after a 2-second hold, and support manual capture. |
| 19–20 Oct | Implement photo saving and test pose matching with different poses, camera distances, and front-facing and slightly angled views. |
| 21–22 Oct | Fix bugs, improve the user interface, test the complete application, and resolve integration issues. |
| 23 Oct | Record the demo video, prepare the final presentation, and perform final checks. |
| 24 Oct | Final demonstration and AI Championship competition. |

## 7. Resources or Requirements

- Flutter and Dart for building the app.
- Android Studio (for Android SDK and testing).
- Google ML Kit Pose Detection (ready-made model, no training needed).
- Flutter packages for camera, image picking and saving photos.
- An Android phone with a working camera for testing.
- Laptops for development.
- Git and GitHub for code.
- Pose photos for the library: photos taken by the team or images we are allowed to use.

## 8. Potential Challenges or Risks

- **Front camera mirroring:** the front camera preview is flipped, which can make left and right confusing. We will test this and fix the left/right hints.
- **Hidden body parts:** if some body parts are not visible in the live camera, the model may not detect them properly. The app will compare only the visible body points. If too few important points are visible, the app will stop matching and auto-capture, and will ask the user to move so that the needed body parts are in the frame.
- **Custom images:** an uploaded image may not show a person clearly, or may show very few body points. The app will show a message and not use such an image.
- **More than one person:** the app is made for one person at a time, so uploaded images should have only one person.
- **Different sizes and positions:** the user may be closer or farther than the reference. We will compare joint angles instead of exact positions to reduce this problem.
- **Lighting and phone speed:** low light or a slow phone can reduce accuracy and make the app lag. We will test and note the conditions where it works well.
- **Wrong auto-capture:** the match score can go up and down. Holding the match for 2 seconds and having a manual button will reduce wrong captures.
- **Limited time:** the app will focus on a few clear poses and a working end-to-end flow first.

## 9. Additional Details

- **Proposed platform:** Android mobile app, built with Flutter so that iOS support can be added later.
- **AI approach:** pre-trained pose detection (Google ML Kit) with joint angle comparison and rule-based hints.
- **Privacy:** pose detection runs on the phone and photos are saved locally.

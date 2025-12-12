<div align="center">
  <img src="CleanMacForFlutters/Assets.xcassets/AppIcon.appiconset/iconMacApp-2.jpg" alt="Clean Mac for Flutter icon" width="150"/>
</div>


# Clean Mac for Flutter

A macOS app that cleans Flutter project build artifacts and quickly frees up disk space.

## How it works
1. Open the app and grant **Full Disk Access** when prompted  
   (System Settings → Privacy & Security → Full Disk Access).  
   Without this permission, the app cannot delete project folders.
2. Click **Select folders** and choose the root folders of the Flutter projects you want to keep in the list.
3. Enable or disable each project using the toggle in the list (only enabled projects will be cleaned).
4. Press **Run clean**. The app shows the progress and, at the end, a summary with the number of folders removed and the disk space freed.
5. The selected paths are saved. Just reopen the app and run the cleaning again whenever needed.

## What is removed
- `build/`
- `.dart_tool/`
- `pubspec.lock`
- `ios/Pods`
- `ios/Podfile.lock`
- `ios/Gemfile.lock`

These items are automatically recreated by Flutter/Swift when running  
`flutter pub get`, `pod install`, or new builds, so it is safe to remove them to recover disk space.

## Extras
- **GitHub** button opens the project repository.
- **Support** button takes you to the contribution page.

## Download
Latest release:  
https://github.com/andrelucassvt/CleanMacForFlutter/releases

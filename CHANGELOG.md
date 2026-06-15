# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0-beta.1]

### Added

* 🌐 **Web platform support (Beta)**

  * Image compression using Canvas API
  * Quality control and max width/max height resizing
  * High-quality image scaling
  * Video compression with automatic backend selection:

    * **ffmpeg.wasm** (optional)

      * H.264/MP4 output
      * Enforced bitrate control
      * Accurate progress reporting
      * Internal hang timeout protection
    * **MediaRecorder fallback**

      * WebM output on Chromium and Firefox
      * MP4 output on Safari and iOS
      * Best-effort audio preservation
      * Time-based progress estimation
  * Quality presets aligned with native platforms:

    * Low (480p / 500 kbps)
    * Medium (720p / 1.5 Mbps)
    * High (1080p / 3 Mbps)

* Added `cancel()` API to abort in-flight video compression on all supported platforms

* Added resource cleanup APIs:

  * `release()`
  * `releaseResult()`
  * Revokes Blob URLs on Web
  * Deletes temporary files on Android and iOS

### Changed

* Centralized Dart-side error handling
* Added early input path validation
* Migrated platform channel communication to strongly typed method calls
* Improved cross-platform consistency between native and web implementations

### Notes

* Web compression results return a Blob Object URL rather than a local file path
* Use `Image.network` or network-based video sources on Web
* MediaRecorder fallback performs real-time encoding
* MediaRecorder bitrate is treated as a browser hint and may vary by platform
* ffmpeg.wasm removes MediaRecorder limitations but requires:

  * COOP: `same-origin`
  * COEP: `require-corp`
* Video compression is currently single-flight on Web

  * A second concurrent compression request returns a `BUSY` error

### Status

* Beta release
* Image compression is considered stable across all supported platforms
* Web video compression requires additional field testing before stable release

---

## [1.0.1] - 2025-11-12

### Fixed

* Fixed iOS build error caused by a missing Flutter framework import in the native implementation
* Resolved compilation issues on iOS devices and simulators
* No functional changes to compression behavior

---

## [1.0.0] - 2025-11-09

### Added

* Stable release of the `media_compressor` package

#### Image Compression

* Quality control (0–100)
* Max width and max height resizing
* EXIF orientation correction

#### Video Compression

* Quality presets (low, medium, high)
* Configurable bitrate
* Resolution scaling
* Real-time progress updates on Android

#### Platform Support

* Android support
* iOS support

#### Developer Experience

* Comprehensive error handling
* `CompressionResult` wrapper
* Detailed API documentation
* Singleton-style access pattern

### Changed

* Migrated to a simplified static API
* Improved validation in compression configuration classes
* Enhanced Android compression using AndroidX Media3 Transformer
* Improved output consistency across devices
* Improved overall compression stability

### Removed

* Experimental batch compression support
* iOS progress callbacks (Android progress retained)

---

## [0.0.1] - 2025-11-05

### Added

* Initial experimental pre-release
* Android-only implementation
* Basic image compression support
* Basic video compression support
* Limited compression configuration options
# Changelog

All notable changes to this project will be documented in this file.

## [1.0.1] - 2025-11-12
### Fixed
- Fixed iOS build error caused by missing Flutter framework import in native implementation
- Resolved compilation issues when running the plugin on iOS devices and simulators
- No functional changes - all compression features work as intended

## [1.0.0] - 2025-11-09
### Added
- Stable release of the `media_compressor` package
- Image compression with:
  - Quality control (0–100)
  - Max width / max height resizing
  - EXIF orientation correction
- Video compression with:
  - Quality presets (low, medium, high)
  - Configurable bitrate and resolution scaling
  - Real-time progress updates (Android)
- Cross-platform support for Android and iOS
- Comprehensive error handling and `CompressionResult` wrapper
- Detailed API usage documentation
- Singleton-style access for easy usage in apps

### Changed
- Migrated to a simplified static API (no instance setup needed)
- Improved validation in compression configuration classes
- Enhanced Android compression using AndroidX Media3 Transformer
- Improved stability and output consistency across devices

### Removed
- Removed experimental batch compression
- Removed iOS progress callbacks (Android progress retained)

---

## [0.0.1] - 2025-11-05
### Added
- Initial experimental pre-release
- Basic image compression support
- Basic video compression with limited configuration options
- Early Android-only implementation
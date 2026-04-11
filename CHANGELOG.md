# Changelog

All notable changes to PathFatter will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Production readiness configuration
- App Sandbox entitlements
- GitHub Actions CI workflow
- Privacy policy template
- Export options for Developer ID distribution

### Changed
- Configured version numbering (1.0 build 1)
- Added comprehensive .gitignore

### Fixed
- Release build verification

---

## [1.0] - 2026-04-11

### Added
- Initial production release
- Instant Windows ↔ macOS path conversion
- SharePoint URL to OneDrive path conversion
- Custom drive mapping configuration
- Path conversion history with pinning
- Safari Web Extension for browser integration
- Keyboard shortcuts (⌘C, ⌘O, ⌘S, ⌘V, Escape)
- Drag & drop file/folder support
- Interactive onboarding flow
- Settings window for configuration
- Full VoiceOver accessibility support
- Dynamic type scaling
- Reduced motion support
- Dark mode glassmorphism UI
- Time-based accent colors
- Spring animations throughout

### Technical
- Pure SwiftUI (no third-party dependencies)
- MVVM architecture
- Debounced saves to UserDefaults
- Thread-safe data operations
- macOS 14.0+ minimum deployment target
- Universal binary (arm64 + x86_64)

---

## Version Numbering

- **Marketing Version:** User-facing version (e.g., 1.0, 1.1, 2.0)
- **Build Number:** Internal build iteration (e.g., 1, 2, 10)
- Format: `MarketingVersion (Build)`

Example: `1.0 (1)` is version 1.0, build 1

---

## Release Process

1. Update version numbers in `PathFatter.xcodeproj/project.pbxproj`:
   - `MARKETING_VERSION`
   - `CURRENT_PROJECT_VERSION`
2. Update this CHANGELOG.md
3. Create git tag: `git tag -a v1.0 -m "Version 1.0"`
4. Push tag: `git push origin v1.0`
5. Archive and distribute

# Contributing to PathFatter

First off, thank you for considering contributing to PathFatter! It's people like you that make PathFatter such a great tool.

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

* **Use a clear and descriptive title**
* **Describe the exact steps to reproduce the problem**
* **Provide specific examples to demonstrate the steps**
* **Describe the behavior you observed and what behavior you expected**
* **Include screenshots if possible**
* **Include macOS version and PathFatter version**

Example:
```
**Steps to Reproduce:**
1. Open PathFatter
2. Paste this Windows path: `C:\Users\test\file.txt`
3. Click "Copy"
4. See error: [describe error]

**Expected:** Path should copy to clipboard
**Actual:** App crashes

**Version:** PathFatter 1.0, macOS 14.2
```

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* **Use a clear and descriptive title**
* **Provide a detailed description of the suggested enhancement**
* **Explain why this enhancement would be useful**
* **List some examples of how this enhancement would be used**

### Pull Requests

* Fill in the required template
* Follow the Swift style guide
* Include comments in your code where necessary
* Update documentation as needed
* Test your changes thoroughly

## Development Setup

### Prerequisites

* macOS 14.0 or later
* Xcode 15.0 or later
* Git

### Setting Up Your Development Environment

1. **Fork the repository**
   ```bash
   # Click "Fork" on GitHub, then:
   git clone https://github.com/YOUR_USERNAME/pathfatter.git
   cd pathfatter
   ```

2. **Open in Xcode**
   ```bash
   open PathFatter.xcodeproj
   ```

3. **Build and run**
   - Press ⌘R to build and run
   - The app should launch successfully

### Making Changes

1. **Create a branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```

2. **Make your changes**
   - Follow existing code style
   - Add comments for complex logic
   - Update tests if applicable

3. **Test your changes**
   - Build in Release mode
   - Test all affected features
   - Verify no regressions

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "Add amazing feature: description of what you added"
   ```

5. **Push to your fork**
   ```bash
   git push origin feature/amazing-feature
   ```

6. **Open a Pull Request**
   - Go to your fork on GitHub
   - Click "New Pull Request"
   - Fill in the PR template

## Coding Guidelines

### Swift Style

* Follow [Swift.org API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
* Use meaningful variable and function names
* Prefer `let` over `var` when possible
* Use type inference where appropriate
* Keep functions small and focused

### Code Organization

* Group related functionality together
* Use extensions for protocol conformances
* Keep views separate from business logic (MVVM pattern)
* Document public APIs with doc comments

### Example

```swift
/// Converts a Windows path to macOS format.
/// - Parameters:
///   - windowsPath: The Windows path to convert (e.g., "C:\\Temp\\file.txt")
///   - mappings: Custom drive letter mappings
/// - Returns: The equivalent macOS path, or nil if conversion fails
func convertToMacPath(_ windowsPath: String, using mappings: DriveMappings) -> String? {
    // Implementation
}
```

## Testing

### Manual Testing Checklist

Before submitting a PR, please verify:

- [ ] App builds successfully in Debug mode
- [ ] App builds successfully in Release mode
- [ ] No console errors or warnings
- [ ] Path conversion works correctly
- [ ] Settings can be opened and modified
- [ ] History displays correctly
- [ ] Keyboard shortcuts work
- [ ] Drag & drop works
- [ ] App doesn't crash during normal use

### Automated Testing (Future)

We're working on adding unit tests and UI tests. Contributions in this area are welcome!

## Documentation

* Update `README.md` if you add new features
* Update `CHANGELOG.md` with your changes
* Add inline comments for complex logic
* Update `PRODUCTION_READINESS.md` if build process changes

## Release Process

Releases are managed by the core team. Here's how we do it:

1. **Version numbering** follows Semantic Versioning (MAJOR.MINOR.PATCH)
2. **Update CHANGELOG.md** with all changes
3. **Update version numbers** in project file
4. **Create release tag** on GitHub
5. **Build and archive** for distribution
6. **Submit to App Store** (if applicable)

## Questions?

Feel free to open an issue with the "question" label if you have any questions about contributing!

## Thank You!

Your contributions to open source, large or small, make projects like this possible. Thank you for taking the time to contribute.

---

**Note:** This is a living document. If you notice something that could be improved, please suggest changes!

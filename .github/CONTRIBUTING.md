# Contributing to Jiggler

Thank you for your interest in contributing to Jiggler! This document provides guidelines and information for contributors.

## Development Setup

### Prerequisites
- macOS 10.15 or later
- Xcode 12.0 or later
- Git

### Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR-USERNAME/Jiggler.git
   cd Jiggler
   ```
3. Open the project in Xcode:
   ```bash
   open Jiggler.xcodeproj
   ```
4. Build and run (⌘R)

## Making Changes

### Branch Strategy
- The main branch is `main`
- Create feature branches from `main`
- Name your branch descriptively: `feature/zen-jiggle-fix` or `fix/battery-detection`

### Code Style
- Follow the existing Objective-C style in the project
- Use tabs for indentation (matching existing code)
- Keep manual reference counting patterns (this project doesn't use ARC)
- Add comments for non-obvious logic
- Update CLAUDE.md if you make significant architectural changes

### Testing Your Changes
Before submitting a PR:
1. Build the project without errors
2. Test all jiggle modes (Standard, Zen, Click)
3. Test conditional jiggling (CPU, battery, apps, etc.)
4. Verify status bar icon and menu work correctly
5. Test on your target macOS version
6. Check that accessibility permissions work

## Submitting Changes

### Pull Request Process

1. **Update your fork**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Commit your changes**
   - Write clear, descriptive commit messages
   - Reference issues if applicable: "Fix #42: Zen jiggle on macOS 26"
   - Keep commits focused and atomic

3. **Push to your fork**
   ```bash
   git push origin your-branch-name
   ```

4. **Create a Pull Request**
   - Provide a clear description of what your PR does
   - Explain **why** the change is needed
   - Include testing details
   - Reference any related issues

5. **Wait for CI checks**
   - GitHub Actions will automatically build your changes
   - Address any build failures or warnings
   - A maintainer will review when checks pass

### PR Review Process
- Be patient - maintainers review PRs as time permits
- Respond to feedback constructively
- Make requested changes in new commits (don't force-push during review)
- Once approved, a maintainer will merge your PR

## Automated Checks

All pull requests run through automated checks:

- **Build Check**: Ensures the project builds successfully
- **Code Quality**: Basic linting and style checks
- **PR Validation**: Verifies Xcode project integrity

These checks help maintain code quality and catch issues early.

## Reporting Issues

### Bug Reports
Include:
- macOS version
- Jiggler version
- Clear steps to reproduce
- Expected vs actual behavior
- Console logs if applicable

### Feature Requests
- Describe the feature clearly
- Explain the use case
- Consider how it fits with existing features

## Code of Conduct

- Be respectful and constructive
- Focus on the code, not the person
- Help create a welcoming environment
- Follow GitHub's Community Guidelines

## Questions?

- Open an issue for general questions
- Check existing issues and PRs first
- Be specific and provide context

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (see LICENSE file).

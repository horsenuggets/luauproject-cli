# Changelog

## 0.1.0
- Add PathHelpers module for cross-platform path normalization
- Add workflow to test install scripts after release
- Fix install command require path and always overwrite binary
- Fix name replacements in dev.project.json for new projects

## 0.0.4
- Add unit tests to CI workflow for PRs to main and release
- Add install command tests to CI workflow for PRs to main and release
- Fix Windows install command error (invalid stdio option)

## 0.0.3
- Add self-install command with cross-platform support (Windows, macOS, Linux)
- Add one-liner install scripts for quick installation from GitHub releases
- Add CI workflow for testing installation on all platforms
- Add Copilot code review ruleset to new project setup
- Simplify branch protection rules (remove PR review requirements)
- Update README with installation instructions

## 0.0.2
- Add multi-platform builds to release workflow (linux, macos, windows for x86_64 and aarch64)
- Separate production and development project configs

## 0.0.1
- Initial release

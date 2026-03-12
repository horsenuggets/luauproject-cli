# Changelog

## 0.1.8
- Add dev branch creation and protection to new project setup

## 0.1.7
- Sync project configs with luau-package-template
- Place private field after version instead of name in generated wally.toml

## 0.1.6
- Dynamically load submodules from template .gitmodules instead of hard-coding them

## 0.1.5
- Fix Windows install test script
- Parse CI job names dynamically for branch protection rules

## 0.1.4
- Fix CI builds producing non-portable executables by updating Lune to 0.10.4-horse.6.0
- Fix update command --version flag not being read correctly

## 0.1.3
- Fix launcher crash due to using wrong Lune process function

## 0.1.2
- Add self-update command (`luauproject update`) to download and install new versions
- Add `--version` flag to update command for installing specific versions
- Change installation layout to use versioned executables with a thin launcher
- Add launcher executable that delegates to the current version and cleans up old versions

## 0.1.1
- Add --privatepackage flag to skip Wally publishing for private packages
- Handle new dev.project.json structure from template (uses -dev suffix)

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

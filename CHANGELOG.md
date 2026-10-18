# Changelog

## 1.1.0

Refined chinchilla artwork and previews. The package remains compatible with the **v2** sprite format; the pet ID is still `chinchilla`, and the installed display name is now **龙猫**.

- More natural silver-gray fur, broader cheeks, a short muzzle, and consistent expressive paws.
- Distinct waiting, working, and review gestures; a corrected, clearly raised jump apex.
- Calibrated 16-direction gaze poses with reviewed scale, registration, and transitions.
- A portable local `preview.html` with nine state controls, pause, frame stepping, dark background, and pointer-controlled gaze.
- Updated state GIFs, contact sheet, directional previews, and English/Chinese installation guidance.
- The Windows installer reads the manifest as UTF-8 and uses its display name in pet-picker instructions, so the name **龙猫** is preserved correctly.
- Release archives `chinchilla-pet-1.1.0.zip` and `chinchilla-windows-1.1.0.zip`, with archive checksums in `SHA256SUMS.txt`.

The atlas passes v2 layout, transparency, and occupied-cell validation. Visual review accepts subtle diagonal cues at 157.5°, 225°, and 315°; blind review did not agree on every diagonal axis. Timing review used ordered frames. No specific Codex app build or live app playback is certified. Installation and backup restoration follow the existing workflow.

## 1.0.0

First packaged release of Chinchilla for Codex. The release version is independent of the Codex sprite format version, which remains **v2**.

- Nine animation states and 16 directional gaze poses.
- A minimal ZIP containing the two required pet files.
- A Windows installer bundle with SHA-256 package verification, automatic backups, and backup restoration.
- English installation instructions, format documentation, and animation previews.

Installation behavior is tested with Windows PowerShell 5.1 in isolated directories. The sprite package passes v2 atlas validation. App compatibility requires a Codex desktop version with custom v2 pet support; no specific app build is certified by this release.

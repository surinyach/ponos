# Codex handoff — Replace app branding with approved Ponos logo

TASK
BR-01 — Implement approved Ponos logo across launcher and shared header

GOAL
Use the supplied transparent golden Ponos emblem over `AppColors.surfaceTinted`
(`#EAF1F8`) in the Android launcher. For in-app header/main-menu placements,
tint the transparent emblem `AppColors.brandBronze` (`#98723D`) without a box.
The original dark-background imagery is retained as a historical reference.

REQUIREMENTS
- First inspect `docs/design/branding/README.md`, `design_rules.md`, `reference/approved_logo_original.png`, and both images under `preview/`.
- Use the provided transparent emblem; never redraw it or reconstruct a dark interior.
- Locate current shared app-header/sidebar branding widgets and the Android launcher-icon configuration.
- Replace the Android app icon and existing top-left application logo on mobile and desktop/web, plus any current main-menu logo placement.
- Keep the existing `Ponos` heading as separate UI text, with current typography and layout.
- Copy necessary images from `docs/design/branding/assets/` into the existing Flutter runtime asset tree, then register/reconfigure them appropriately. Do not load directly from `docs/design/`.
- Use adaptive foreground/background assets for Android where the existing workflow supports them.
- Preserve header sizes and spacing; tune only the icon slot if needed to avoid clipping or poor legibility.
- Update relevant asset/widget tests if affected.

CONSTRAINTS
- No new logo text, letters, borders, extra motifs or visual re-styling.
- Do not modify navigation, business logic, APIs, database or other unrelated features.
- Reuse the existing launcher-icon toolchain if present, without unnecessary dependencies.
- Do not replace historical screenshots or design reference files.

VALIDATION
- Inspect Android launcher icon after a rebuild, not just hot reload.
- Verify header in mobile and desktop/web at small rendered sizes and normal/high text scaling.
- Ensure old logos are replaced only at intended branding placements.
- Run relevant widget tests, `flutter analyze`, and `git diff --check`.

DELIVERABLE
Report modified files, chosen production asset paths, generated native resources, tests, visual issues and any required rebuild instructions.
Do not commit. Wait for human visual approval.
